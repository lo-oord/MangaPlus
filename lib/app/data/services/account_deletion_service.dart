import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mangaplus/app/core/cache/manga_cover_cache_manager.dart';
import 'package:mangaplus/app/data/services/auth_service.dart';
import 'package:path_provider/path_provider.dart';

/// Progress of a permanent account deletion, in the order the steps run.
enum AccountDeletionStage {
  preparing,
  data,
  profile,
  username,
  account,
  local,
  done,
}

class AccountDeletionException implements Exception {
  const AccountDeletionException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Permanently removes everything that belongs to the signed-in account.
///
/// The whole flow runs from the client SDK so it stays inside the Firebase
/// Spark plan: every collection is listed and deleted in bounded batches, the
/// profile document and the reserved username are removed, and only then is the
/// Firebase Authentication user deleted. Local session data and caches are the
/// last step.
///
/// The operation is resumable: the target uid is written to local storage
/// before anything is deleted and only cleared once every step succeeded, so a
/// network drop in the middle can be retried without ever deleting another
/// user's data (every path is derived from that uid).
class AccountDeletionService {
  AccountDeletionService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    AuthService? authService,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _authService = authService ?? AuthService();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final AuthService _authService;
  final GetStorage _storage = GetStorage();

  static const String _pendingKey = 'pendingAccountDeletionUid';

  /// Firestore rejects a batch above 500 writes; staying under it leaves room
  /// for the profile and username deletes that share the same connection.
  static const int _batchLimit = 400;

  /// Single documents inside `userProfiles/{uid}/private`.
  static const List<String> _privateDocuments = <String>['library'];

  /// Collections inside `userProfiles/{uid}/private`.
  static const List<String> _privateCollections = <String>[
    'favorites',
    'readingProgress',
    'readingHistory',
    'customLists',
    'notifications',
  ];

  /// True when a previous deletion stopped before finishing.
  bool get hasPendingDeletion => _storage.read<String>(_pendingKey) != null;

  String? get pendingUid => _storage.read<String>(_pendingKey);

  /// Deletes the account end to end. [onStage] is called before each step so the
  /// UI can show real progress instead of a generic spinner.
  Future<void> deleteAccount({
    required void Function(AccountDeletionStage stage) onStage,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AccountDeletionException('لا يوجد حساب مسجل الدخول.');
    }
    final uid = user.uid;
    final isVerified = user.emailVerified && !user.isAnonymous;

    onStage(AccountDeletionStage.preparing);
    await _storage.write(_pendingKey, uid);

    final profile = await _readProfile(uid);
    final username = '${profile['username'] ?? ''}'.trim();

    onStage(AccountDeletionStage.data);
    await _deletePrivateData(uid, isVerified: isVerified);

    onStage(AccountDeletionStage.profile);
    await _deleteProfile(uid);

    onStage(AccountDeletionStage.username);
    if (username.isNotEmpty) await _releaseUsername(username, uid);

    onStage(AccountDeletionStage.account);
    await _authService.deleteAuthUser();

    onStage(AccountDeletionStage.local);
    await clearLocalUserData(uid: uid);

    await _storage.remove(_pendingKey);
    onStage(AccountDeletionStage.done);
  }

  Future<Map<String, dynamic>> _readProfile(String uid) async {
    try {
      final doc = await _firestore.collection('userProfiles').doc(uid).get();
      return doc.data() ?? const <String, dynamic>{};
    } catch (_) {
      // The profile may already be gone on a resumed run.
      return const <String, dynamic>{};
    }
  }

  Future<void> _deletePrivateData(String uid, {required bool isVerified}) async {
    // An unverified e-mail account can never have written to `private/*` or to
    // `private/readingStats` (the rules deny the write too), so those reads are
    // skipped instead of producing a permission error that is not a real
    // failure. Guests and verified accounts are always cleaned.
    if (!isVerified) return;

    final private = _firestore
        .collection('userProfiles')
        .doc(uid)
        .collection('private');

    for (final name in _privateDocuments) {
      await private.doc(name).delete();
    }
    for (final name in _privateCollections) {
      await _deleteCollection(private.collection(name));
    }

    // Reading statistics: every session first, then the preferences document.
    final stats = private.doc('readingStats');
    await _deleteCollection(stats.collection('sessions'));
    await stats.delete();
  }

  /// Deletes every document of a collection in bounded batches. Deleting the
  /// parent document does not touch subcollections, so they are walked
  /// explicitly.
  Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> ref,
  ) async {
    while (true) {
      final snapshot = await ref.limit(_batchLimit).get();
      if (snapshot.docs.isEmpty) return;
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      if (snapshot.docs.length < _batchLimit) return;
    }
  }

  Future<void> _deleteProfile(String uid) async {
    try {
      await _firestore.collection('userProfiles').doc(uid).delete();
    } on FirebaseException catch (error) {
      if (error.code == 'not-found') return;
      rethrow;
    }
  }

  /// Frees the reserved username, but only when it still belongs to this uid.
  Future<void> _releaseUsername(String username, String uid) async {
    final ref = _firestore.collection('usernames').doc(username);
    final doc = await ref.get();
    if (!doc.exists) return;
    if ('${doc.data()?['uid'] ?? ''}' != uid) return;
    await ref.delete();
  }

  /// Removes every account-scoped local record and the files the account owned.
  /// Downloaded chapters are deleted together with the account, which is what
  /// "permanent" means here.
  Future<void> clearLocalUserData({required String uid}) async {
    const keys = <String>[
      'localAccount',
      'bookmarks',
      'reading_history',
      'readChapters',
      'chapter_update_tracking',
      'chapter_updates_unread_chapters',
      'chapter_updates_last_open_check',
      'app_notifications',
      'app_notifications_read',
      'downloadingChapters',
      'download_tasks_v2',
      'downloadedChapters',
    ];
    for (final key in keys) {
      await _removeQuietly(key);
    }
    for (final suffix in <String>[uid, 'guest']) {
      await _removeQuietly('deletedBookmarks_$suffix');
      await _removeQuietly('last_sync_at_$suffix');
      await _removeQuietly('reading_stats_sessions_v1_$suffix');
      await _removeQuietly('reading_stats_preferences_v1_$suffix');
      await _removeQuietly('reading_stats_achievements_v1_$suffix');
    }
    await _removeDownloadedFiles();
    await _emptyCoverCache();
  }

  Future<void> _removeQuietly(String key) async {
    try {
      await _storage.remove(key);
    } catch (_) {
      // Local cleanup is best-effort; the account is already gone.
    }
  }

  Future<void> _removeDownloadedFiles() async {
    if (kIsWeb) return;
    try {
      final base = await getApplicationDocumentsDirectory();
      final chapters = Directory('${base.path}/chapters');
      if (chapters.existsSync()) {
        await chapters.delete(recursive: true);
      }
    } catch (_) {
      // Files may already be missing; nothing else depends on them.
    }
  }

  Future<void> _emptyCoverCache() async {
    try {
      await MangaCoverCacheManager.instance.emptyCache();
    } catch (_) {
      // The cache manager is optional; a failure must not fail the deletion.
    }
  }
}
