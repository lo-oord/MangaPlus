import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/data/models/bookmark.dart';
import 'package:mangaplus/app/data/services/app_data_service.dart';
import 'package:mangaplus/app/data/services/comic_service.dart';
import 'package:mangaplus/app/widgets/app_feedback.dart';

class BookmarkController extends GetxController {
  final AppDataService _appDataService = AppDataService();
  final RxBool isLoading = true.obs;
  final RxList<BookmarkItem> bookmarks = <BookmarkItem>[].obs;

  Future<void> getBookmark() async {
    try {
      final values = await _appDataService.getBookmarks();
      bookmarks.assignAll(values ?? const <BookmarkItem>[]);
    } catch (error) {
      debugPrint('Unable to load local bookmarks: $error');
      AppFeedback.show(
        title: 'خطأ'.tr,
        message: 'تعذر تحميل المفضلة. حاول مجددًا.'.tr,
        type: AppNoticeType.error,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<BookmarkItem> addBookmark(BookmarkItem bookmark) async {
    await _appDataService.addBookmark(bookmark);
    final index = bookmarks.indexWhere((item) => item.comicId == bookmark.comicId);
    if (index < 0) {
      bookmarks.add(bookmark);
    } else {
      bookmarks[index] = bookmark;
    }
    return bookmark;
  }

  Future<bool> deleteBookmark(String comicId) async {
    try {
      await _appDataService.deleteBookmark(comicId);
      bookmarks.removeWhere((item) => item.comicId == comicId);
      return true;
    } catch (error) {
      debugPrint('Unable to remove bookmark: $error');
      AppFeedback.show(
        title: 'خطأ'.tr,
        message: 'تعذر حذف القصة من المفضلة. حاول مجددًا.'.tr,
        type: AppNoticeType.error,
      );
      return false;
    }
  }

  Future<void> refreshBookmark(String comicId) async {
    if (!comicId.startsWith('teamx://')) return;
    try {
      final data = await ComicService().fetchComicDetail(comicId);
      final comic = data.comicDetail;
      if (comic.title.isEmpty) return;
      await addBookmark(BookmarkItem(
        comicId: comic.comicId,
        title: comic.title,
        coverImage: comic.coverImage,
        type: comic.type,
      ));
    } catch (error) {
      debugPrint('Unable to refresh Team X bookmark metadata: $error');
    }
  }

  @override
  void onInit() {
    getBookmark();
    super.onInit();
  }
}
