import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_storage/get_storage.dart';

class AccountSyncService {
  AccountSyncService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GetStorage _storage = GetStorage();

  DocumentReference<Map<String, dynamic>>? get _libraryRef {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return null;
    return _firestore.collection('userProfiles').doc(user.uid).collection('private').doc('library');
  }

  Future<void> syncLocalData() async {
    final ref = _libraryRef;
    if (ref == null) return;
    final local = <String, dynamic>{
      'bookmarks': _mapValue(_storage.read('bookmarks')),
      'history': _mapValue(_storage.read('reading_history')),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final snapshot = await ref.get();
    final remote = snapshot.data() ?? const <String, dynamic>{};
    final mergedBookmarks = _mergeMaps(
      _mapValue(remote['bookmarks']),
      local['bookmarks'] as Map<String, dynamic>,
    );
    final mergedHistory = _mergeMaps(
      _mapValue(remote['history']),
      local['history'] as Map<String, dynamic>,
    );
    await ref.set({
      'bookmarks': mergedBookmarks,
      'history': mergedHistory,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _storage.write('bookmarks', mergedBookmarks);
    await _storage.write('reading_history', mergedHistory);
  }

  Map<String, dynamic> _mergeMaps(Map<String, dynamic> remote, Map<String, dynamic> local) {
    final merged = <String, dynamic>{...remote};
    for (final entry in local.entries) {
      final old = remote[entry.key];
      final oldDate = _date(old is Map ? old['updatedAt'] ?? old['lastRead'] : null);
      final newDate = _date(entry.value is Map ? entry.value['updatedAt'] ?? entry.value['lastRead'] : null);
      if (old == null || newDate == null || oldDate == null || !oldDate.isAfter(newDate)) {
        merged[entry.key] = entry.value;
      }
    }
    return merged;
  }

  Map<String, dynamic> _mapValue(dynamic value) => value is Map
      ? value.map((key, item) => MapEntry('$key', item is Map ? Map<String, dynamic>.from(item) : item))
      : <String, dynamic>{};

  DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return DateTime.tryParse('$value');
  }
}
