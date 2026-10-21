import 'dart:io';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mangaplus/app/data/models/download_task.dart';
import 'package:mangaplus/app/data/models/downloaded_chapter.dart';
import 'package:mangaplus/app/data/services/download_manager_service.dart';
import 'package:mangaplus/app/widgets/app_feedback.dart';

class DownloadController extends GetxController {
  final GetStorage _storage = GetStorage();
  final DownloadManagerService manager = Get.find<DownloadManagerService>();
  final downloadedChapters = <DownloadedChapter>[].obs;
  final isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    loadLocalChapters();
    _storage.listenKey('downloadedChapters', (_) => loadLocalChapters());
  }

  Future<void> loadLocalChapters() async {
    isLoading.value = true;
    try {
      final raw = _storage.read<List<dynamic>>('downloadedChapters') ?? const [];
      final result = <DownloadedChapter>[];
      final seen = <String>{};
      for (final item in raw.whereType<Map>()) {
        try {
          final chapter = DownloadedChapter.fromJson(Map<String, dynamic>.from(item));
          if (chapter.localImagePaths.isNotEmpty &&
              chapter.localImagePaths.every((path) => File(path).existsSync()) &&
              seen.add(chapter.chapterId)) {
            result.add(chapter);
          }
        } catch (_) {}
      }
      downloadedChapters.assignAll(result);
    } catch (error) {
      AppFeedback.show(
        title: 'خطأ'.tr,
        message: 'تعذر تحميل قائمة التحميلات.'.tr,
        type: AppNoticeType.error,
      );
    } finally {
      isLoading.value = false;
    }
  }

  List<DownloadedChapter> chaptersForComic(String comicId) =>
      downloadedChapters.where((item) => item.comicId == comicId).toList();

  Future<void> deleteChapter(DownloadedChapter chapter) async {
    try {
      for (final path in chapter.localImagePaths) {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
      final raw = _storage.read<List<dynamic>>('downloadedChapters') ?? [];
      raw.removeWhere((item) => item is Map && item['chapterId'] == chapter.chapterId);
      await _storage.write('downloadedChapters', raw);
      AppFeedback.show(title: 'نجاح'.tr, message: 'تم حذف الفصل بنجاح'.tr,
          type: AppNoticeType.success);
    } catch (_) {
      AppFeedback.show(title: 'خطأ'.tr, message: 'تعذر حذف الفصل. حاول مجددًا.'.tr,
          type: AppNoticeType.error);
    }
  }

  Future<void> retryTask(DownloadTask task) => manager.retry(task.id,
      failedOnly: task.failedChapterIds.isNotEmpty);

  Future<void> deleteTask(DownloadTask task) => manager.removeTask(task.id);
}
