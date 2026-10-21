import 'package:get/get.dart';
import 'package:mangaplus/app/data/models/bookmark.dart';
import 'package:mangaplus/app/data/services/app_data_service.dart';

class BookmarkController extends GetxController {
  final _appDataService = AppDataService();
  final RxList<BookmarkItem> bookmarks = <BookmarkItem>[].obs;

  Future<void> getBookmark() async {
    try {
      final bookmark = await _appDataService.getBookmarks();
      if (bookmark != null) {
        bookmarks.value = bookmark;
      }
    } catch (e) {
      Get.snackbar('خطأ', 'تعذر تحميل المفضلة. حاول مجددًا.');
    }
  }

  Future<BookmarkItem> addBookmark(BookmarkItem bookmark) async {
    try {
      await _appDataService.addBookmark(bookmark);
      return bookmark;
    } catch (e) {
      Get.snackbar('خطأ', 'تعذر إضافة القصة إلى المفضلة. حاول مجددًا.');
      rethrow;
    }
  }

  Future<void> deleteBookmark(String comicId) async {
    try {
      await _appDataService.deleteBookmark(comicId);
      getBookmark();
    } catch (e) {
      Get.snackbar('خطأ', 'تعذر حذف القصة من المفضلة. حاول مجددًا.');
    }
  }

  @override
  void onInit() {
    getBookmark();
    super.onInit();
  }
}
