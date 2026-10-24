import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mangaplus/app/data/models/bookmark.dart';
import 'package:mangaplus/app/data/services/app_data_service.dart';
import 'package:mangaplus/app/data/services/account_gate_service.dart';
import 'package:mangaplus/app/data/services/account_sync_service.dart';
import 'package:mangaplus/app/data/services/comic_service.dart';
import 'package:mangaplus/app/data/services/dropsauce_import_service.dart';
import 'package:mangaplus/app/widgets/app_feedback.dart';

enum BookmarkSortOrder {
  newest,
  oldest,
  titleAscending,
  titleDescending,
  ratingHighest,
  ratingLowest,
}

enum BookmarkTypeFilter { all, manga, novel }

class BookmarkController extends GetxController {
  final AppDataService _appDataService = AppDataService();
  final GetStorage _storage = GetStorage();
  final AccountGateService _accountGate = AccountGateService();
  final RxBool isLoading = true.obs;
  final RxList<BookmarkItem> bookmarks = <BookmarkItem>[].obs;
  final sortOrder = BookmarkSortOrder.newest.obs;
  final typeFilter = BookmarkTypeFilter.all.obs;
  final searchQuery = ''.obs;
  final isImporting = false.obs;
  final importCompleted = false.obs;
  final importCurrentIndex = 0.obs;
  final importTotal = 0.obs;
  final importCurrentTitle = ''.obs;
  final importedMangaCount = 0.obs;
  final importedNovelCount = 0.obs;
  final RxList<String> importedTitles = <String>[].obs;
  final RxList<DropsauceFavoriteRecord> importFailures = <DropsauceFavoriteRecord>[].obs;
  final RxSet<String> selectedBookmarkIds = <String>{}.obs;
  final importResolvedCount = 0.obs;
  bool _metadataBackfillInProgress = false;

  bool isSelected(String comicId) => selectedBookmarkIds.contains(comicId);

  void toggleSelection(String comicId) {
    if (selectedBookmarkIds.contains(comicId)) {
      selectedBookmarkIds.remove(comicId);
    } else {
      selectedBookmarkIds.add(comicId);
    }
  }

  void selectAllVisible() {
    selectedBookmarkIds
      ..clear()
      ..addAll(visibleBookmarks.map((item) => item.comicId));
  }

  void clearSelection() => selectedBookmarkIds.clear();

  Future<void> deleteSelected() async {
    final ids = selectedBookmarkIds.toList(growable: false);
    if (ids.isEmpty || !await _accountGate.requireAccount()) return;
    for (final id in ids) {
      try {
        await _appDataService.deleteBookmark(id);
        bookmarks.removeWhere((item) => item.comicId == id);
      } catch (error) {
        debugPrint('Unable to remove selected bookmark: $error');
      }
    }
    clearSelection();
  }

  List<BookmarkItem> get visibleBookmarks {
    final query = searchQuery.value.trim().toLowerCase();
    final filter = typeFilter.value;
    final result = bookmarks.where((bookmark) {
      if (query.isNotEmpty && !bookmark.title.toLowerCase().contains(query)) {
        return false;
      }
      final type = bookmark.type.trim().toLowerCase();
      final isNovel = type == 'novel' || type == 'رواية';
      if (filter == BookmarkTypeFilter.novel && !isNovel) return false;
      if (filter == BookmarkTypeFilter.manga && isNovel) return false;
      return true;
    }).toList(growable: true);

    DateTime addedAt(BookmarkItem item) =>
        DateTime.tryParse(item.createdAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
    double rating(BookmarkItem item) {
      final value = RegExp(r'\d+(?:[.,]\d+)?').firstMatch(item.rating)?.group(0);
      return double.tryParse(value?.replaceAll(',', '.') ?? '') ?? 0;
    }
    int byTitle(BookmarkItem a, BookmarkItem b) =>
        a.title.toLowerCase().compareTo(b.title.toLowerCase());

    switch (sortOrder.value) {
      case BookmarkSortOrder.newest:
        result.sort((a, b) => addedAt(b).compareTo(addedAt(a)));
        break;
      case BookmarkSortOrder.oldest:
        result.sort((a, b) => addedAt(a).compareTo(addedAt(b)));
        break;
      case BookmarkSortOrder.titleAscending:
        result.sort(byTitle);
        break;
      case BookmarkSortOrder.titleDescending:
        result.sort((a, b) => byTitle(b, a));
        break;
      case BookmarkSortOrder.ratingHighest:
        result.sort((a, b) => rating(b).compareTo(rating(a)));
        break;
      case BookmarkSortOrder.ratingLowest:
        result.sort((a, b) => rating(a).compareTo(rating(b)));
        break;
    }
    return result;
  }

  void setSortOrder(BookmarkSortOrder value) => sortOrder.value = value;
  void setTypeFilter(BookmarkTypeFilter value) => typeFilter.value = value;
  void setSearchQuery(String value) => searchQuery.value = value;

  Future<List<DropsauceFavoriteRecord>?> pickDropsauceBackup() async {
    if (!await _accountGate.requireAccount()) return null;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['zip', 'bk'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return null;
      final file = result.files.single;
      final bytes = file.bytes ??
          (file.path == null ? null : await File(file.path!).readAsBytes());
      if (bytes == null || bytes.isEmpty) {
        throw const FormatException('تعذر قراءة ملف النسخة الاحتياطية.');
      }
      final records = DropsauceImportService.parse(bytes);
      if (records.isEmpty) {
        throw const FormatException('لم يتم العثور على أعمال مفضلة داخل الملف.');
      }
      return records;
    } catch (error) {
      AppFeedback.show(
        title: 'تعذر استيراد المفضلة'.tr,
        message: '$error'.replaceFirst('FormatException: ', ''),
        type: AppNoticeType.error,
      );
      return null;
    }
  }

  Future<void> importDropsauceFavorites(
    List<DropsauceFavoriteRecord> records,
  ) async {
    if (isImporting.value) return;
    isImporting.value = true;
    importCompleted.value = false;
    importCurrentIndex.value = 0;
    importTotal.value = records.length;
    importCurrentTitle.value = '';
    importedMangaCount.value = 0;
    importedNovelCount.value = 0;
    importResolvedCount.value = 0;
    importedTitles.clear();
    importFailures.clear();

    try {
      for (var index = 0; index < records.length; index++) {
        var record = records[index];
        importCurrentIndex.value = index + 1;
        importCurrentTitle.value = record.title;
        if (!record.isImportable && '${record.failureReason}'.contains('مصدر')) {
          importCurrentTitle.value = 'التحقق من مصدر: ${record.title}';
          final resolved = await DropsauceImportService.resolveMissingSource(record);
          if (resolved != null) {
            record = resolved;
            importResolvedCount.value++;
          }
        }
        if (record.failureReason != null) {
          importFailures.add(record);
        } else {
          try {
            await _appDataService.addBookmark(BookmarkItem(
              comicId: record.comicId,
              title: record.title,
              coverImage: record.coverImage,
              type: record.type,
              status: record.status,
              rating: record.rating,
              createdAt: DateTime.now().toUtc().toIso8601String(),
            ));
            final existingIndex = bookmarks.indexWhere(
              (item) => item.comicId == record.comicId,
            );
            final imported = BookmarkItem(
              comicId: record.comicId,
              title: record.title,
              coverImage: record.coverImage,
              type: record.type,
              status: record.status,
              rating: record.rating,
              createdAt: DateTime.now().toUtc().toIso8601String(),
            );
            if (existingIndex < 0) {
              bookmarks.add(imported);
            } else {
              bookmarks[existingIndex] = imported;
            }
            importedTitles.add(record.title);
            if (record.type.trim().toLowerCase() == 'novel') {
              importedNovelCount.value++;
            } else {
              importedMangaCount.value++;
            }
          } catch (error) {
            importFailures.add(DropsauceFavoriteRecord(
              title: record.title,
              url: record.url,
              coverImage: record.coverImage,
              type: record.type,
              status: record.status,
              rating: record.rating,
              sourceTitle: record.sourceTitle,
              source: record.source,
              failureReason: '$error'.replaceFirst('Exception: ', ''),
            ));
          }
        }
        await Future<void>.delayed(Duration.zero);
      }
    } finally {
      isImporting.value = false;
      importCompleted.value = true;
      importCurrentTitle.value = '';
      unawaited(_refreshMissingMetadata());
    }
  }

  Future<void> getBookmark({bool syncCloud = true}) async {
    try {
      final values = await _appDataService.getBookmarks();
      bookmarks.assignAll(values ?? const <BookmarkItem>[]);
      clearSelection();
      unawaited(_refreshMissingMetadata());
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
      clearSelection();
      unawaited(_refreshMissingMetadata());
    } catch (_) {
      // Locally saved bookmarks remain available while cloud sync is unavailable.
    }
  }

  Future<void> _refreshMissingMetadata() async {
    if (_metadataBackfillInProgress || isClosed) return;
    final pending = bookmarks
        .where((item) => item.status.trim().isEmpty ||
            item.rating.trim().isEmpty ||
            item.coverImage.trim().isEmpty)
        .toList(growable: false);
    if (pending.isEmpty) return;

    _metadataBackfillInProgress = true;
    var nextIndex = 0;
    Future<void> worker() async {
      while (!isClosed) {
        final index = nextIndex++;
        if (index >= pending.length) return;
        final saved = pending[index];
        try {
          final detail = await ComicService()
              .fetchComicDetail(saved.comicId)
              .timeout(const Duration(seconds: 15));
          final comic = detail.comicDetail;
          if (comic.title.trim().isEmpty || isClosed) continue;
          final currentIndex = bookmarks.indexWhere(
            (item) => item.comicId == saved.comicId,
          );
          if (currentIndex < 0) continue;
          final current = bookmarks[currentIndex];
          final refreshed = BookmarkItem(
            comicId: current.comicId,
            title: current.title.isNotEmpty ? current.title : comic.title,
            coverImage: current.coverImage.isNotEmpty
                ? current.coverImage
                : comic.coverImage,
            type: current.type.isNotEmpty ? current.type : comic.type,
            status: comic.status.trim().isNotEmpty ? comic.status : current.status,
            rating: comic.rating.trim().isNotEmpty ? comic.rating : current.rating,
            createdAt: current.createdAt,
          );
          await _appDataService.addBookmark(refreshed);
          if (!isClosed) bookmarks[currentIndex] = refreshed;
        } catch (error) {
          debugPrint('Unable to refresh bookmark metadata: $error');
        }
      }
    }

    try {
      final workerCount = pending.length < 3 ? pending.length : 3;
      await Future.wait(List.generate(workerCount, (_) => worker()));
    } finally {
      _metadataBackfillInProgress = false;
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
      final existingIndex = bookmarks.indexWhere((item) => item.comicId == comicId);
      final existing = existingIndex < 0 ? null : bookmarks[existingIndex];
      await addBookmark(BookmarkItem(
        comicId: comic.comicId,
        title: comic.title,
        coverImage: comic.coverImage,
        type: comic.type,
        status: comic.status,
        rating: comic.rating,
        createdAt: existing?.createdAt ?? DateTime.now().toUtc().toIso8601String(),
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
