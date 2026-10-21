import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:mangaplus/app/data/models/comic_detail.dart';
import 'package:mangaplus/app/data/models/bookmark.dart';
import 'package:mangaplus/app/data/models/history.dart';
import 'package:mangaplus/app/data/models/downloaded_chapter.dart';
import 'package:mangaplus/app/data/services/comic_service.dart';
import 'package:mangaplus/app/data/sources/team_x_source.dart';
import 'package:mangaplus/app/data/services/app_data_service.dart';
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
    final downloading =
        _storage.read<Map<String, dynamic>>('downloadingChapters') ?? {};
    downloadingChapters.assignAll(downloading.map(
      (key, value) => MapEntry(key, (value as num).toDouble()),
    ));
  }

  Future<void> fetchComicDetail(String comicId) async {
    try {
      isLoading(true);
      comicDetailData.value = await _comicService.fetchComicDetail(comicId);
    } catch (error) {
      debugPrint('Team X details failed: $error');
      AppFeedback.show(
        title: 'خطأ'.tr,
        message: 'تعذر تحميل البيانات من Team X. تحقق من اتصال الإنترنت وحاول مجددًا.'.tr,
        type: AppNoticeType.error,
      );
    } finally {
      isLoading(false);
    }
  }

  void filterChapters(String query) {
    if (query.isEmpty) {
      filteredChapters.clear();
      return;
    }
    final chapters = comicDetailData.value.comicDetail.chapters;
    filteredChapters.assignAll(chapters.where((chapter) =>
        chapter.title.toLowerCase().contains(query.toLowerCase())));
  }

  bool isBookmarked(String comicId) =>
      (_storage.read<Map<String, dynamic>>('bookmarks') ?? {})
          .containsKey(comicId);

  final bookmarkRevision = 0.obs;

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
    await _appDataService.addHistory(HistoryItem(
      comicId: comic.comicId,
      title: comic.title,
      coverImage: comic.coverImage,
      chapterId: chapterId,
      chapterTitle: chapterTitle,
      lastRead: DateTime.now(),
      type: comic.type,
    ));
  }

  Future<void> downloadChapter(
    Chapter chapter,
    String comicId,
    String comicTitle,
    String coverImage,
  ) async {
    final source = TeamXSource();
    try {
      downloadingChapters[chapter.chapterId] = 0.0;
      await _storage.write('downloadingChapters', downloadingChapters);
      final downloadedChapters =
          _storage.read<List<dynamic>>('downloadedChapters') ?? [];
      if (downloadedChapters.any((item) => item['chapterId'] == chapter.chapterId)) {
        AppFeedback.show(
          title: 'معلومة'.tr,
          message: 'الفصل محمّل بالفعل'.tr,
          type: AppNoticeType.info,
        );
        return;
      }

      final chapterData = await _comicService.fetchChapter(chapter.chapterId);
      final images = chapterData.chapter.images;
      if (images.isEmpty) {
        AppFeedback.show(
          title: 'معلومة'.tr,
          message: 'لا توجد صور متاحة'.tr,
          type: AppNoticeType.info,
        );
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final safeId = chapter.chapterId.hashCode.toUnsigned(32).toRadixString(16);
      final chapterDir = Directory('${dir.path}/chapters/$safeId');
      await chapterDir.create(recursive: true);
      final localImagePaths = <String>[];
      for (var index = 0; index < images.length; index++) {
        final uri = Uri.parse(images[index]);
        final headers = source.resolveChapterUrl(chapter.chapterId).isNotEmpty
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
      downloadedChapters.add(record.toJson());
      await _storage.write('downloadedChapters', downloadedChapters);
      AppFeedback.show(
        title: 'نجاح'.tr,
        message: 'تم تنزيل الفصل بنجاح'.tr,
        type: AppNoticeType.success,
      );
    } catch (error) {
      debugPrint('Team X download failed: $error');
      AppFeedback.show(
        title: 'خطأ'.tr,
        message: 'تعذر تنزيل الفصل من Team X. تحقق من الاتصال ومساحة التخزين.'.tr,
        type: AppNoticeType.error,
      );
    } finally {
      downloadingChapters.remove(chapter.chapterId);
      await _storage.write('downloadingChapters', downloadingChapters);
    }
  }

  bool isChapterDownloaded(String chapterId) {
    final downloaded =
        _storage.read<List<dynamic>>('downloadedChapters') ?? [];
    return downloaded.any((item) => item['chapterId'] == chapterId);
  }
}
