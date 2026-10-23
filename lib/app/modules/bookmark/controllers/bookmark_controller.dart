import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mangaplus/app/data/models/bookmark.dart';
import 'package:mangaplus/app/data/services/app_data_service.dart';
import 'package:mangaplus/app/data/services/account_gate_service.dart';
import 'package:mangaplus/app/data/services/account_sync_service.dart';
import 'package:mangaplus/app/data/services/comic_service.dart';
import 'package:mangaplus/app/widgets/app_feedback.dart';

class BookmarkController extends GetxController {
  final AppDataService _appDataService = AppDataService();
  final GetStorage _storage = GetStorage();
  final AccountGateService _accountGate = AccountGateService();
  final RxBool isLoading = true.obs;
  final RxList<BookmarkItem> bookmarks = <BookmarkItem>[].obs;

  Future<void> getBookmark({bool syncCloud = true}) async {
    try {
      final values = await _appDataService.getBookmarks();
      bookmarks.assignAll(values ?? const <BookmarkItem>[]);
      if (syncCloud) unawaited(_syncThenRefresh());
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

  Future<void> _syncThenRefresh() async {
    try {
      await AccountSyncService().syncLocalData();
      if (isClosed) return;
      final values = await _appDataService.getBookmarks();
      bookmarks.assignAll(values ?? const <BookmarkItem>[]);
    } catch (_) {
      // Locally saved bookmarks remain available while cloud sync is unavailable.
    }
  }

  Future<BookmarkItem> addBookmark(BookmarkItem bookmark) async {
    if (!await _accountGate.requireAccount()) return bookmark;
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
    if (!await _accountGate.requireAccount()) return false;
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
    super.onInit();
    _storage.listenKey('bookmarks', (_) => getBookmark(syncCloud: false));
    getBookmark();
  }
}
