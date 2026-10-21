import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:mangaplus/app/data/models/bookmark.dart';
import 'package:mangaplus/app/data/models/comic_detail.dart';
import 'package:mangaplus/app/data/models/downloaded_chapter.dart';
import 'package:mangaplus/app/data/models/history.dart';
import 'package:mangaplus/app/data/services/app_data_service.dart';
import 'package:mangaplus/app/data/services/comic_service.dart';
import 'package:mangaplus/app/data/sources/team_x_source.dart';
import 'package:mangaplus/app/widgets/app_feedback.dart';
import 'package:path_provider/path_provider.dart';

class ComicDetailController extends GetxController {
  final ComicService _comicService = ComicService();
  final GetStorage _storage = GetStorage();
  final AppDataService _appDataService = Get.find<AppDataService>();

  final comicDetailData = ComicDetailData(
    comicDetail: ComicDetail(
      comicId: '',
      coverImage: '',
      title: '',
      nativeTitle: '',
      genres: [],
      releaseYear: '',
      author: '',
      status: '',
      type: '',
      totalChapters: '0',
      updatedOn: '',
      rating: '0.0',
      synopsis: '',
      chapters: [],
    ),
    source: '',
  ).obs;

  final isLoading = false.obs;
  final downloadingChapters = <String, double>{}.obs;
  final filteredChapters = <Chapter>[].obs;
  final selectedChapterIds = <String>[].obs;
  final isSelectionMode = false.obs;
  final isBulkDownloading = false.obs;
  final sortAscending = false.obs;
  final historyRevision = 0.obs;
  final bookmarkRevision = 0.obs;

  @override
  void onInit() {
    super.onInit();
    _syncDownloadingChapters();
    _storage.listenKey('downloadingChapters', (_) => _syncDownloadingChapters());
    final comicId = Get.arguments?.toString();
    if (comicId != null && comicId.isNotEmpty) {
      fetchComicDetail(comicId);
    } else {
      AppFeedback.show(
        title: 'خطأ'.tr,
        message: 'لم يتم تقديم معرّف المانجا'.tr,
        type: AppNoticeType.error,
      );
    }
  }

  void _syncDownloadingChapters() {
    final downloading = _storage.read<Map<String, dynamic>>('downloadingChapters') ?? {};
    downloadingChapters.assignAll(downloading.map((key, value) => MapEntry(
          key,
          value is num ? value.toDouble() : 0.0,
        )));
  }

  Future<void> fetchComicDetail(String comicId) async {
    try {
      isLoading(true);
      comicDetailData.value = await _comicService.fetchComicDetail(comicId);
    } catch (error) {
      debugPrint('Manga details request failed: $error');
      AppFeedback.show(
        title: 'خطأ'.tr,
        message: 'تعذر تحميل بيانات المانجا'.tr,
        type: AppNoticeType.error,
      );
    } finally {
      isLoading(false);
    }
  }

  void filterChapters(String query) {
    if (query.trim().isEmpty) {
      filteredChapters.clear();
      return;
    }
    final normalized = query.trim().toLowerCase();
    final chapters = comicDetailData.value.comicDetail.chapters;
    filteredChapters.assignAll(
      chapters.where((chapter) => chapter.title.toLowerCase().contains(normalized)),
    );
  }

  List<Chapter> sortedChapters(List<Chapter> chapters) {
    final result = List<Chapter>.of(chapters);
    result.sort((left, right) {
      final leftNumber = _chapterNumber(left.title);
      final rightNumber = _chapterNumber(right.title);
      final order = leftNumber != null && rightNumber != null
          ? leftNumber.compareTo(rightNumber)
          : left.title.toLowerCase().compareTo(right.title.toLowerCase());
      return sortAscending.value ? order : -order;
    });
    return result;
  }

  double? _chapterNumber(String title) {
    final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(title);
    return match == null ? null : double.tryParse(match.group(1)!);
  }

  void toggleSortOrder() => sortAscending.toggle();

  bool isBookmarked(String comicId) =>
      (_storage.read<Map<String, dynamic>>('bookmarks') ?? {}).containsKey(comicId);

  Future<void> toggleBookmark(ComicDetail comic) async {
    if (isBookmarked(comic.comicId)) {
      await _appDataService.deleteBookmark(comic.comicId);
      bookmarkRevision.value++;
      AppFeedback.show(
        title: 'المفضلة'.tr,
        message: 'أُزيل من الإشارات المرجعية'.tr,
        type: AppNoticeType.info,
      );
    } else {
      await _appDataService.addBookmark(BookmarkItem(
        comicId: comic.comicId,
        title: comic.title,
        coverImage: comic.coverImage,
        type: comic.type,
      ));
      bookmarkRevision.value++;
      AppFeedback.show(
        title: 'المفضلة'.tr,
        message: 'أُضيف إلى الإشارات المرجعية'.tr,
        type: AppNoticeType.success,
      );
    }
  }

  Future<void> addToHistory(
    ComicDetail comic,
    String chapterId,
    String chapterTitle,
  ) async {
    final readChapters = Map<String, dynamic>.from(
      _storage.read('readChapters') ?? <String, dynamic>{},
    );
    readChapters[chapterId] = DateTime.now().toIso8601String();
    await _storage.write('readChapters', readChapters);
    await _appDataService.addHistory(HistoryItem(
      comicId: comic.comicId,
      title: comic.title,
      coverImage: comic.coverImage,
      chapterId: chapterId,
      chapterTitle: chapterTitle,
      lastRead: DateTime.now(),
      type: comic.type,
    ));
    historyRevision.value++;
  }

  bool isChapterRead(String chapterId) {
    historyRevision.value;
    final readChapters = _storage.read('readChapters');
    if (readChapters is Map && readChapters.containsKey(chapterId)) return true;
    final history = _storage.read('reading_history');
    if (history is! Map) return false;
    return history.values.any(
      (entry) => entry is Map && entry['chapterId']?.toString() == chapterId,
    );
  }

  bool isChapterDownloaded(String chapterId) {
    final downloaded = _storage.read<List<dynamic>>('downloadedChapters') ?? [];
    return downloaded.any(
      (item) => item is Map && item['chapterId']?.toString() == chapterId,
    );
  }

  void toggleChapterSelection(Chapter chapter) {
    isSelectionMode.value = true;
    if (selectedChapterIds.contains(chapter.chapterId)) {
      selectedChapterIds.remove(chapter.chapterId);
    } else {
      selectedChapterIds.add(chapter.chapterId);
    }
    if (selectedChapterIds.isEmpty) isSelectionMode.value = false;
  }

  void toggleSelectionMode() {
    if (isSelectionMode.value) {
      clearChapterSelection();
    } else {
      isSelectionMode.value = true;
    }
  }

  void selectAllChapters(List<Chapter> chapters) {
    final allIds = chapters.map((chapter) => chapter.chapterId).toSet();
    final alreadySelected = allIds.isNotEmpty && allIds.every(selectedChapterIds.contains);
    if (alreadySelected) {
      for (final id in allIds) {
        selectedChapterIds.remove(id);
      }
      if (selectedChapterIds.isEmpty) isSelectionMode.value = false;
    } else {
      for (final id in allIds) {
        if (!selectedChapterIds.contains(id)) selectedChapterIds.add(id);
      }
      isSelectionMode.value = allIds.isNotEmpty;
    }
  }

  void clearChapterSelection() {
    selectedChapterIds.clear();
    isSelectionMode.value = false;
  }

  Future<void> downloadSelectedChapters(ComicDetail comic) async {
    final selection = selectedChapterIds.toSet();
    if (selection.isEmpty || isBulkDownloading.value) return;
    isBulkDownloading.value = true;
    var downloadedCount = 0;
    try {
      for (final chapter in comic.chapters.where(
        (chapter) => selection.contains(chapter.chapterId),
      )) {
        if (isChapterDownloaded(chapter.chapterId)) continue;
        if (await downloadChapter(
          chapter,
          comic.comicId,
          comic.title,
          comic.coverImage,
          showFeedback: false,
        )) {
          downloadedCount++;
        }
      }
    } finally {
      isBulkDownloading.value = false;
      clearChapterSelection();
    }
    AppFeedback.show(
      title: downloadedCount > 0 ? 'نجاح'.tr : 'معلومة'.tr,
      message: downloadedCount > 0
          ? 'تم تنزيل @value فصول بنجاح'.trParams({'value': '$downloadedCount'})
          : 'لا توجد فصول جديدة للتنزيل'.tr,
      type: downloadedCount > 0 ? AppNoticeType.success : AppNoticeType.info,
    );
  }

  Future<bool> downloadChapter(
    Chapter chapter,
    String comicId,
    String comicTitle,
    String coverImage, {
    bool showFeedback = true,
  }) async {
    final source = TeamXSource();
    try {
      if (isChapterDownloaded(chapter.chapterId)) {
        if (showFeedback) {
          AppFeedback.show(
            title: 'معلومة'.tr,
            message: 'الفصل محمّل بالفعل'.tr,
            type: AppNoticeType.info,
          );
        }
        return false;
      }
      downloadingChapters[chapter.chapterId] = 0.0;
      await _storage.write('downloadingChapters', downloadingChapters);

      final chapterData = await _comicService.fetchChapter(chapter.chapterId);
      final images = chapterData.chapter.images;
      if (images.isEmpty) {
        if (showFeedback) {
          AppFeedback.show(
            title: 'معلومة'.tr,
            message: 'لا توجد صور متاحة'.tr,
            type: AppNoticeType.info,
          );
        }
        return false;
      }

      final dir = await getApplicationDocumentsDirectory();
      final safeId = chapter.chapterId.hashCode.toUnsigned(32).toRadixString(16);
      final chapterDir = Directory('${dir.path}/chapters/$safeId');
      await chapterDir.create(recursive: true);
      final localImagePaths = <String>[];
      for (var index = 0; index < images.length; index++) {
        final uri = Uri.parse(images[index]);
        final chapterUrl = source.resolveChapterUrl(chapter.chapterId);
        final headers = chapterUrl.isNotEmpty
            ? source.imageRequestHeaders
            : const <String, String>{};
        final response = await http.get(uri, headers: headers).timeout(
              const Duration(seconds: 35),
            );
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw HttpException('Image download failed (${response.statusCode})');
        }
        final extension = response.headers['content-type']?.contains('png') == true
            ? 'png'
            : 'jpg';
        final file = File('${chapterDir.path}/page_${index + 1}.$extension');
        await file.writeAsBytes(response.bodyBytes, flush: true);
        localImagePaths.add(file.path);
        downloadingChapters[chapter.chapterId] = (index + 1) / images.length;
        downloadingChapters.refresh();
        await _storage.write('downloadingChapters', downloadingChapters);
      }

      final record = DownloadedChapter(
        comicId: comicId,
        chapterId: chapter.chapterId,
        comicTitle: comicTitle,
        chapterTitle: chapter.title,
        coverImage: coverImage,
        localImagePaths: localImagePaths,
        downloadedAt: DateTime.now(),
      );
      final downloadedChapters =
          _storage.read<List<dynamic>>('downloadedChapters') ?? [];
      downloadedChapters.add(record.toJson());
      await _storage.write('downloadedChapters', downloadedChapters);
      if (showFeedback) {
        AppFeedback.show(
          title: 'نجاح'.tr,
          message: 'تم تنزيل الفصل بنجاح'.tr,
          type: AppNoticeType.success,
        );
      }
      return true;
    } catch (error) {
      debugPrint('Chapter download failed: $error');
      if (showFeedback) {
        AppFeedback.show(
          title: 'خطأ'.tr,
          message: 'تعذر تنزيل الفصل'.tr,
          type: AppNoticeType.error,
        );
      }
      return false;
    } finally {
      downloadingChapters.remove(chapter.chapterId);
      await _storage.write('downloadingChapters', downloadingChapters);
    }
  }
}
