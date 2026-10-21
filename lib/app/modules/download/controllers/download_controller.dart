import 'dart:io';
import 'package:get/get.dart';
import 'package:mangaplus/app/widgets/app_feedback.dart';
import 'package:mangaplus/app/data/models/downloaded_chapter.dart';
import 'package:get_storage/get_storage.dart';
import 'package:path_provider/path_provider.dart';

class DownloadController extends GetxController {
  final GetStorage _storage = GetStorage();
  var downloadedChapters = <DownloadedChapter>[].obs;
  final RxBool isLoading = true.obs;
  var _lastStorageValue = <dynamic>[];

  @override
  void onInit() {
    // Ensure GetStorage is initialized
    if (!_storage.hasData('downloadedChapters')) {
      _storage.write('downloadedChapters', []);
    }
    loadDownloadedChapters();
    _storage.listenKey('downloadedChapters', (value) {
      print('GetStorage updated: $value');
      if (value.toString() != _lastStorageValue.toString()) {
        _lastStorageValue = value;
        loadDownloadedChapters();
      }
    });
    super.onInit();
  }

  Future<void> loadDownloadedChapters() async {
    isLoading.value = true;
    try {
      final chapters = _storage.read<List<dynamic>>('downloadedChapters') ?? [];
      print('Loaded chapters from storage: $chapters');
      final uniqueChapters = <DownloadedChapter>[];
      final seenChapterIds = <String>{};

      for (var json in chapters) {
        try {
          final chapter = DownloadedChapter.fromJson(json);
          if (isValidChapter(chapter) && !seenChapterIds.contains(chapter.chapterId)) {
            uniqueChapters.add(chapter);
            seenChapterIds.add(chapter.chapterId);
          } else {
            print('Skipping invalid or duplicate chapter: ${chapter.chapterId}');
          }
        } catch (e) {
          print('Error parsing chapter: $json, Error: $e');
        }
      }

      // Fallback: Scan file system if GetStorage is empty
      if (uniqueChapters.isEmpty && chapters.isEmpty) {
        final fallbackChapters = await scanFileSystemForChapters();
        uniqueChapters.addAll(fallbackChapters);
      }

      downloadedChapters.assignAll(uniqueChapters);
      if (chapters.length != uniqueChapters.length) {
        await _storage.write('downloadedChapters', uniqueChapters.map((c) => c.toJson()).toList());
        await _storage.save();
      }
      print('Parsed downloadedChapters: ${downloadedChapters.length} chapters');
    } catch (e) {
      print('Error loading downloaded chapters: $e');
      downloadedChapters.clear();
      AppFeedback.show(title: 'خطأ'.tr, message: 'تعذر تحميل قائمة التنزيلات.'.tr, type: AppNoticeType.error);
    } finally {
      isLoading.value = false;
    }
  }

  bool isValidChapter(DownloadedChapter chapter) {
    try {
      return chapter.localImagePaths.isNotEmpty &&
          chapter.localImagePaths.every((path) => File(path).existsSync());
    } catch (e) {
      print('Error validating chapter ${chapter.chapterId}: $e');
      return false;
    }
  }

  Future<List<DownloadedChapter>> scanFileSystemForChapters() async {
    final chapters = <DownloadedChapter>[];
    try {
      final dir = await getApplicationDocumentsDirectory();
      final chaptersDir = Directory('${dir.path}/chapters');
      if (!await chaptersDir.exists()) {
        print('Chapters directory does not exist');
        return chapters;
      }

      final comicDirs = await chaptersDir.list().where((entity) => entity is Directory).toList();
      for (var comicDir in comicDirs) {
        final chapterDirs = await Directory(comicDir.path).list().where((entity) => entity is Directory).toList();
        for (var chapterDir in chapterDirs) {
          final files = await Directory(chapterDir.path).list().where((entity) => entity is File).toList();
          final imagePaths = files.map((file) => file.path).toList();
          if (imagePaths.isNotEmpty) {
            final comicId = comicDir.path.split('/').last;
            final chapterId = chapterDir.path.split('/').last;
            chapters.add(DownloadedChapter(
              comicId: comicId,
              chapterId: chapterId,
              comicTitle: 'كوميكس غير معروف'.tr, // Placeholder, update if metadata available
              chapterTitle: '${'الفصل'.tr} $chapterId',
              coverImage: '',
              localImagePaths: imagePaths,
              downloadedAt: DateTime.now(),
            ));
            print('Found chapter in file system: $chapterId');
          }
        }
      }
    } catch (e) {
      print('Error scanning file system: $e');
    }
    return chapters;
  }

  Future<void> deleteChapter(DownloadedChapter chapter) async {
    try {
      final dir = Directory(
          '${(await getApplicationDocumentsDirectory()).path}/chapters/${chapter.comicId}/${chapter.chapterId}');
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        print('Deleted directory: ${dir.path}');
      }
      downloadedChapters.removeWhere((c) => c.chapterId == chapter.chapterId);
      await _storage.write('downloadedChapters', downloadedChapters.map((c) => c.toJson()).toList());
      await _storage.save();
      print('Updated storage after deletion: ${downloadedChapters.length} chapters remaining');
      AppFeedback.show(title: 'نجاح'.tr, message: 'تم حذف الفصل بنجاح'.tr, type: AppNoticeType.success);
    } catch (e) {
      print('Error deleting chapter: $e');
      AppFeedback.show(title: 'خطأ'.tr, message: 'تعذر حذف الفصل. حاول مجددًا.'.tr, type: AppNoticeType.error);
    }
  }

  Future<void> debugStorageAndFiles() async {
    final chapters = _storage.read<List<dynamic>>('downloadedChapters') ?? [];
    print('GetStorage content: $chapters');
    print('Current downloadedChapters: ${downloadedChapters.map((c) => c.toJson())}');

    final dir = await getApplicationDocumentsDirectory();
    final chaptersDir = Directory('${dir.path}/chapters');
    if (await chaptersDir.exists()) {
      final contents = await chaptersDir.list(recursive: true).toList();
      print('Chapters directory contents: $contents');
      for (var chapter in downloadedChapters) {
        for (var path in chapter.localImagePaths) {
          print('File $path exists: ${File(path).existsSync()}');
        }
      }
    } else {
      print('Chapters directory does not exist');
    }
  }
}
