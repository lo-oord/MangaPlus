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
import 'package:mangaplus/app/data/services/download_manager_service.dart';
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
  final downloadRevision = 0.obs;

  @override
  void onInit() {
    super.onInit();
    _syncDownloadingChapters();
    _storage.listenKey('downloadingChapters', (_) => _syncDownloadingChapters());
    _storage.listenKey('downloadedChapters', (_) => downloadRevision.value++);
    final arguments = Get.arguments;
    final comicId = arguments is Map
        ? '${arguments['comicId'] ?? ''}'
        : arguments?.toString();
    if (arguments is Map && arguments['localOnly'] == true) {
      _loadLocalComic(arguments);
      return;
    }
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

  void _loadLocalComic(Map<dynamic, dynamic> arguments) {
    final comicId = '${arguments['comicId'] ?? ''}';
    final raw = _storage.read<List<dynamic>>('downloadedChapters') ?? const [];
    final saved = raw.whereType<Map>().where(
      (item) => '${item['comicId'] ?? ''}' == comicId,
    ).toList(growable: false);
    final chapters = saved.map((item) => Chapter(
          chapterId: '${item['chapterId'] ?? ''}',
          title: '${item['chapterTitle'] ?? ''}',
          link: '${item['chapterId'] ?? ''}',
          releaseTime: '',
        )).where((chapter) => chapter.chapterId.isNotEmpty).toList(growable: false);
    final first = saved.isEmpty ? <String, dynamic>{} : saved.first;
    comicDetailData.value = ComicDetailData(
      source: 'local',
      comicDetail: ComicDetail(
        comicId: comicId,
        coverImage: '${first['coverImage'] ?? arguments['coverImage'] ?? ''}',
        title: '${first['comicTitle'] ?? arguments['comicTitle'] ?? 'مانجا'}',
        nativeTitle: '',
        genres: const [],
        releaseYear: '',
        author: '',
        status: 'محفوظ محليًا',
        type: 'manga',
        totalChapters: '${chapters.length}',
        updatedOn: '',
        rating: '',
        synopsis: 'الفصول المحفوظة على هذا الجهاز'.tr,
        chapters: chapters,
      ),
    );
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

  HistoryItem? readingHistoryFor(String comicId) {
    final entries = _storage.read<Map<String, dynamic>>('reading_history') ?? {};
    final raw = entries[comicId];
    if (raw is! Map) return null;
    try {
      return HistoryItem.fromMap(
        comicId,
        Map<String, dynamic>.from(raw),
      );
    } catch (_) {
      return null;
    }
  }

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
    downloadRevision.value;
    final downloaded = _storage.read<List<dynamic>>('downloadedChapters') ?? [];
    return downloaded.any(
      (item) => item is Map && item['chapterId']?.toString() == chapterId,
    );
  }

  Future<void> deleteDownloadedChapter(String chapterId) async {
    final raw = _storage.read<List<dynamic>>('downloadedChapters') ?? [];
    final matches = raw.whereType<Map>().where(
      (item) => '${item['chapterId'] ?? ''}' == chapterId,
    ).toList(growable: false);
    for (final item in matches) {
      for (final path in List<String>.from(item['localImagePaths'] ?? const [])) {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
    }
    raw.removeWhere((item) => item is Map && '${item['chapterId'] ?? ''}' == chapterId);
    await _storage.write('downloadedChapters', raw);
    downloadRevision.value++;
    downloadingChapters.remove(chapterId);
    historyRevision.value++;
  }

  void toggleChapterSelection(Chapter chapter) {
    if (isChapterDownloaded(chapter.chapterId)) return;
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
    final allIds = chapters
        .where((chapter) => !isChapterDownloaded(chapter.chapterId))
        .map((chapter) => chapter.chapterId)
        .toSet();
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
    if (selection.isEmpty) return;
    final chapters = comic.chapters
        .where((chapter) => selection.contains(chapter.chapterId))
        .toList(growable: false);
    final manager = Get.find<DownloadManagerService>();
    final taskId = await manager.enqueue(
      comicId: comic.comicId,
      comicTitle: comic.title,
      coverImage: comic.coverImage,
      chapters: chapters,
      grouped: true,
    );
    clearChapterSelection();
    AppFeedback.show(
      title: taskId == null ? 'معلومة'.tr : 'نجاح'.tr,
      message: taskId == null
          ? 'لا توجد فصول جديدة للتنزيل'.tr
          : 'تمت إضافة المهمة إلى قائمة التحميلات'.tr,
      type: taskId == null ? AppNoticeType.info : AppNoticeType.success,
    );
  }

  Future<bool> downloadChapter(
    Chapter chapter,
    String comicId,
    String comicTitle,
    String coverImage, {
    bool showFeedback = true,
  }) async {
    final taskId = await Get.find<DownloadManagerService>().enqueue(
      comicId: comicId,
      comicTitle: comicTitle,
      coverImage: coverImage,
      chapters: [chapter],
      grouped: false,
    );
    if (showFeedback) {
      AppFeedback.show(
        title: taskId == null ? 'معلومة'.tr : 'نجاح'.tr,
        message: taskId == null
            ? 'الفصل محمّل بالفعل'.tr
            : 'تمت إضافة الفصل إلى قائمة التحميلات'.tr,
        type: taskId == null ? AppNoticeType.info : AppNoticeType.success,
      );
    }
    return taskId != null;
  }

}
