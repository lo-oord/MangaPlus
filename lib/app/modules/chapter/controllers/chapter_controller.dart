import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mangaplus/app/data/models/chapter.dart';
import 'package:mangaplus/app/data/services/comic_service.dart';
import 'package:mangaplus/app/routes/app_pages.dart';
import 'package:mangaplus/app/widgets/app_feedback.dart';

class ChapterController extends GetxController {
  final ComicService _comicService = ComicService();
  final GetStorage _storage = GetStorage();

  late final Map<String, dynamic> arguments =
      Map<String, dynamic>.from(Get.arguments as Map);
  late final String chapterId = '${arguments['chapterId'] ?? ''}';

  final chapterData = ChapterData(
    chapter: DataChapter(
      chapterId: '',
      title: '',
      images: [],
      previousChapter: '',
      nextChapter: null,
      chapters: [],
    ),
    source: '',
  ).obs;

  final isLoading = false.obs;
  final isOffline = false.obs;
  final hasError = false.obs;
  final localImages = <String>[].obs;

  Future<void> fetchChapter(String id) async {
    try {
      isLoading(true);
      hasError(false);
      final downloadedChapters =
          _storage.read<List<dynamic>>('downloadedChapters') ?? [];
      final downloadedChapter = downloadedChapters.firstWhereOrNull(
        (json) => json['chapterId'] == id,
      );

      if (downloadedChapter != null) {
        isOffline.value = true;
        localImages.assignAll(
          List<String>.from(downloadedChapter['localImagePaths'] ?? const []),
        );
        chapterData.value = ChapterData(
          chapter: DataChapter(
            chapterId: id,
            title: '${downloadedChapter['chapterTitle'] ?? id}',
            images: localImages.toList(growable: false),
            previousChapter: '',
            nextChapter: null,
            chapters: const [],
          ),
          source: 'local',
        );
      } else {
        isOffline.value = false;
        final loaded = await _comicService.fetchChapter(id);
        final fallbackTitle = '${arguments['chapterTitle'] ?? ''}'.trim();
        final title = loaded.chapter.title.trim().isEmpty ||
                loaded.chapter.title.trim() == 'الفصل' ||
                loaded.chapter.title.trim().toLowerCase() == 'chapter'
            ? fallbackTitle
            : loaded.chapter.title;
        chapterData.value = ChapterData(
          chapter: DataChapter(
            chapterId: loaded.chapter.chapterId,
            title: title,
            images: loaded.chapter.images,
            previousChapter: loaded.chapter.previousChapter,
            nextChapter: loaded.chapter.nextChapter,
            chapters: loaded.chapter.chapters,
          ),
          source: loaded.source,
        );
      }
    } catch (error) {
      hasError(true);
      debugPrint('Team X chapter request failed: $error');
    } finally {
      isLoading(false);
    }
  }

  void navigateToChapter(String? id) {
    if (id != null && id.isNotEmpty && !isNavigating.value) {
      isNavigating.value = true;
      Get.offNamed(Routes.CHAPTER, arguments: {
        'chapterId': id,
        'comicId': arguments['comicId'],
        'comicTitle': arguments['comicTitle'],
        'coverImage': arguments['coverImage'],
      });
    }
  }

  final showNavigation = false.obs;
  final showChapterList = false.obs;
  final currentPage = 0.obs;
  final readerFit = 'width'.obs;
  final continuousNavigation = true.obs;
  final isNavigating = false.obs;
  bool endNoticeShown = false;

  bool get canUseChapterList => chapterData.value.chapter.chapters.isNotEmpty;

  void _loadReaderPreferences() {
    readerFit.value = _storage.read<String>('reader_fit') ?? 'width';
    continuousNavigation.value =
        _storage.read<bool>('reader_continuous_navigation') ?? true;
  }

  Future<void> setReaderFit(String value) async {
    readerFit.value = value;
    await _storage.write('reader_fit', value);
  }

  Future<void> setContinuousNavigation(bool value) async {
    continuousNavigation.value = value;
    await _storage.write('reader_continuous_navigation', value);
  }

  Future<void> handleScroll(ScrollMetrics metrics) async {
    if (!continuousNavigation.value || isNavigating.value || isOffline.value) {
      return;
    }
    final next = chapterData.value.chapter.nextChapter;
    if (metrics.extentAfter <= 28 && next != null && next.isNotEmpty) {
      navigateToChapter(next);
    } else if (metrics.extentAfter <= 28 && !endNoticeShown) {
      endNoticeShown = true;
      AppFeedback.show(
        title: 'نهاية الفصل'.tr,
        message: 'لا توجد فصول أخرى'.tr,
      );
    }
  }

  void toggleNavigationVisibility() {
    showNavigation.toggle();
    if (!showNavigation.value) showChapterList.value = false;
  }

  void toggleChapterListVisibility() {
    showChapterList.toggle();
    if (showChapterList.value) showNavigation.value = true;
  }

  @override
  void onInit() {
    super.onInit();
    _loadReaderPreferences();
    fetchChapter(chapterId);
  }
}
