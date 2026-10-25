import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class BookmarkStateService {
  BookmarkStateService._();
  static final instance = BookmarkStateService._();

  final revision = 0.obs;
  final GetStorage _storage = GetStorage();

  bool get hasEligibleAccount {
    final user = FirebaseAuth.instance.currentUser;
    return user != null && !user.isAnonymous && user.emailVerified;
  }

  bool contains(String? comicId) {
    if (!hasEligibleAccount || comicId == null || comicId.isEmpty) return false;
    revision.value;
    final data = _storage.read('bookmarks');
    return data is Map && data.containsKey(comicId);
  }

  void changed() => revision.value++;
}
