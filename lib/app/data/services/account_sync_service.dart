import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_storage/get_storage.dart';

class AccountSyncService {
  static final Map<String, Future<void>> _syncRequests = {};
  static final Set<String> _syncAgain = {};
  static final Set<String> _syncAgainForce = {};

  AccountSyncService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GetStorage _storage = GetStorage();

  DocumentReference<Map<String, dynamic>>? get _libraryRef {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return null;
    return _firestore.collection('userProfiles').doc(user.uid)
        .collection('private').doc('library');
  }

  Future<void> syncLocalData({bool force = false}) async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return;
    final uid = user.uid;
    final active = _syncRequests[uid];
    if (active != null) {
      _syncAgain.add(uid);
      if (force) _syncAgainForce.add(uid);
      try {
        await active;
      } catch (_) {
        if (force) rethrow;
      }
      return;
    }
    final request = _drainSyncRequests(uid, force);
    _syncRequests[uid] = request;
    try {
      await request;
    } catch (_) {
      if (force) rethrow;
    } finally {
      if (identical(_syncRequests[uid], request)) _syncRequests.remove(uid);
    }
  }

  Future<void> _drainSyncRequests(String uid, bool force) async {
    var nextForce = force;
    try {
      while (_auth.currentUser?.uid == uid) {
        _syncAgain.remove(uid);
        await _syncLocalData(force: nextForce);
        final shouldRepeat = _syncAgain.remove(uid);
        nextForce = _syncAgainForce.remove(uid);
        if (!shouldRepeat) return;
      }
    } finally {
      _syncAgain.remove(uid);
      _syncAgainForce.remove(uid);
    }
  }

  Future<void> _syncLocalData({required bool force}) async {
    final ref = _libraryRef;
    final user = _auth.currentUser;
    if (ref == null || user == null) return;
    final profile = await _firestore.collection('userProfiles').doc(user.uid).get();
    if (!force && profile.data()?['syncFavorites'] == false) return;

    final localBookmarks = _mapValue(_storage.read('bookmarks'));
    final localHistory = _mapValue(_storage.read('reading_history'));
    final snapshot = await ref.get();
    final remote = snapshot.data() ?? const <String, dynamic>{};
    final deletedBookmarks = _mergeDeletionMaps(
      _mapValue(remote['deletedBookmarks']),
      _mapValue(_storage.read('deletedBookmarks_${user.uid}')),
    );
    final mergedBookmarks = _mergeBookmarks(
      _mapValue(remote['bookmarks']), localBookmarks, deletedBookmarks);
    final mergedHistory = _mergeMaps(
      _mapValue(remote['history']), localHistory, dateField: 'lastRead');

    // لا نكتب أو نعيد ملء التخزين المحلي إذا تغيّر الحساب أثناء انتظار الشبكة.
    if (_auth.currentUser?.uid != user.uid) return;
    await ref.set({
      'bookmarks': mergedBookmarks,
      'deletedBookmarks': deletedBookmarks,
      'history': mergedHistory,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (_auth.currentUser?.uid != user.uid) return;
    await _storage.write('bookmarks', mergedBookmarks);
    await _storage.write('reading_history', mergedHistory);
    await _storage.write('deletedBookmarks_${user.uid}', deletedBookmarks);
  }

  Future<void> removeBookmark(String comicId) async {
    final ref = _libraryRef;
    final user = _auth.currentUser;
    if (ref == null || user == null) return;
    final deletionKey = 'deletedBookmarks_${user.uid}';
    final localDeleted = _mapValue(_storage.read(deletionKey));
    localDeleted[comicId] = DateTime.now().toUtc().toIso8601String();
    await _storage.write(deletionKey, localDeleted);
    try {
      final profile = await _firestore.collection('userProfiles').doc(user.uid).get();
      if (profile.data()?['syncFavorites'] == false) return;
      final snapshot = await ref.get();
      final remote = snapshot.data() ?? const <String, dynamic>{};
      final bookmarks = _mapValue(remote['bookmarks'])..remove(comicId);
      final deleted = _mergeDeletionMaps(
        _mapValue(remote['deletedBookmarks']), localDeleted);
      if (_auth.currentUser?.uid != user.uid) return;
      await ref.set({
        'bookmarks': bookmarks,
        'deletedBookmarks': deleted,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Local tombstone remains queued; the next successful sync propagates it.
    }
  }

  Map<String, dynamic> _mergeDeletionMaps(
    Map<String, dynamic> remote,
    Map<String, dynamic> local,
  ) {
    final merged = <String, dynamic>{...remote};
    for (final entry in local.entries) {
      final remoteDate = _date(merged[entry.key]);
      final localDate = _date(entry.value);
      if (remoteDate == null || (localDate != null && localDate.isAfter(remoteDate))) {
        merged[entry.key] = entry.value;
      }
    }
    return merged;
  }

  Map<String, dynamic> _mergeBookmarks(
    Map<String, dynamic> remote,
    Map<String, dynamic> local,
    Map<String, dynamic> deleted,
  ) {
    final merged = <String, dynamic>{...remote};
    for (final entry in local.entries) {
      final tombstoneDate = _date(deleted[entry.key]);
      final newDate = _date(entry.value is Map ? entry.value['updatedAt'] : null);
      if (tombstoneDate != null && (newDate == null || !newDate.isAfter(tombstoneDate))) {
        continue;
      }
      if (tombstoneDate != null && newDate != null && newDate.isAfter(tombstoneDate)) {
        deleted.remove(entry.key);
      }
      final old = remote[entry.key];
      final oldDate = _date(old is Map ? old['updatedAt'] : null);
      if (old == null || newDate == null || oldDate == null || !oldDate.isAfter(newDate)) {
        merged[entry.key] = entry.value;
      }
    }
    for (final key in merged.keys.toList()) {
      final tombstoneDate = _date(deleted[key]);
      final item = merged[key];
      final itemDate = _date(item is Map ? item['updatedAt'] : null);
      if (tombstoneDate != null && (itemDate == null || !itemDate.isAfter(tombstoneDate))) {
        merged.remove(key);
      } else if (tombstoneDate != null && itemDate != null && itemDate.isAfter(tombstoneDate)) {
        deleted.remove(key);
      }
    }
    return merged;
  }

  Map<String, dynamic> _mergeMaps(
    Map<String, dynamic> remote,
    Map<String, dynamic> local, {
    String? dateField,
  }) {
    final merged = <String, dynamic>{...remote};
    for (final entry in local.entries) {
      final old = remote[entry.key];
      final oldDate = _date(old is Map ? old['updatedAt'] ?? old[dateField] : null);
      final newDate = _date(entry.value is Map
          ? entry.value['updatedAt'] ?? entry.value[dateField]
          : null);
      if (old == null || newDate == null || oldDate == null || !oldDate.isAfter(newDate)) {
        merged[entry.key] = entry.value;
      }
    }
    return merged;
  }

  Map<String, dynamic> _mapValue(dynamic value) => value is Map
      ? value.map((key, item) => MapEntry(
          '$key', item is Map ? Map<String, dynamic>.from(item) : item))
      : <String, dynamic>{};

  DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse('$value');
  }
}
