import 'package:get/get.dart';
import 'package:mangaplus/app/widgets/app_feedback.dart';
import 'package:mangaplus/app/data/models/bookmark.dart';
import 'package:mangaplus/app/data/services/app_data_service.dart';

class BookmarkController extends GetxController {
  final _appDataService = AppDataService();
  final RxBool isLoading = true.obs;
  final RxList<BookmarkItem> bookmarks = <BookmarkItem>[].obs;

  Future<void> getBookmark() async {
    try {
      final bookmark = await _appDataService.getBookmarks();
      if (bookmark != null) {
        bookmarks.value = bookmark;
      }
    } catch (e) {
      AppFeedback.show(title: 'خطأ'.tr, message: 'تعذر تحميل المفضلة. حاول مجددًا.'.tr, type: AppNoticeType.error);
    } finally {
      isLoading.value = false;
    }
  }

  Future<BookmarkItem> addBookmark(BookmarkItem bookmark) async {
    try {
      await _appDataService.addBookmark(bookmark);
      if (!bookmarks.any((item) => item.comicId == bookmark.comicId)) {
        bookmarks.add(bookmark);
      }
      return bookmark;
    } catch (e) {
      AppFeedback.show(title: 'خطأ'.tr, message: 'تعذر إضافة القصة إلى المفضلة. حاول مجددًا.'.tr, type: AppNoticeType.error);
      rethrow;
    }
  }

  Future<bool> deleteBookmark(String comicId) async {
    try {
      await _appDataService.deleteBookmark(comicId);
      await getBookmark();
      return true;
    } catch (e) {
      AppFeedback.show(title: 'خطأ'.tr, message: 'تعذر حذف القصة من المفضلة. حاول مجددًا.'.tr, type: AppNoticeType.error);
      return false;
    }
  }

  @override
  void onInit() {
    getBookmark();
    super.onInit();
  }
}
