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
          final isAvailable = chapter.isNovel
              ? chapter.content.trim().isNotEmpty
              : chapter.localImagePaths.isNotEmpty &&
                  chapter.localImagePaths.every((path) => File(path).existsSync());
          if (isAvailable &&
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

  Future<void> deleteChapter(
    DownloadedChapter chapter, {
    bool notify = true,
  }) async {
    try {
      for (final path in chapter.localImagePaths) {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
      final raw = _storage.read<List<dynamic>>('downloadedChapters') ?? [];
      raw.removeWhere((item) => item is Map && item['chapterId'] == chapter.chapterId);
      await _storage.write('downloadedChapters', raw);
      await loadLocalChapters();
      if (notify) {
        AppFeedback.show(title: 'نجاح'.tr, message: 'تم حذف الفصل بنجاح'.tr,
            type: AppNoticeType.success);
      }
    } catch (_) {
      AppFeedback.show(title: 'خطأ'.tr, message: 'تعذر حذف الفصل. حاول مجددًا.'.tr,
          type: AppNoticeType.error);
    }
  }

  /// Deletes the files belonging to [task] and one task-level confirmation.
  Future<void> deleteTaskFiles(DownloadTask task) async {
    final ids = task.chapters.map((chapter) => chapter['id']).whereType<String>().toSet();
    final matching = downloadedChapters.where(
      (chapter) => chapter.comicId == task.comicId && ids.contains(chapter.chapterId),
    ).toList();
    if (matching.isEmpty) {
      AppFeedback.show(
        title: 'لا توجد ملفات'.tr,
        message: 'لا توجد فصول محفوظة لهذه المهمة.'.tr,
        type: AppNoticeType.info,
      );
      return;
    }
    for (final chapter in matching) {
      await deleteChapter(chapter, notify: false);
    }
    AppFeedback.show(
      title: 'نجاح'.tr,
      message: 'تم حذف ${matching.length} فصل من التخزين المحلي.'.tr,
      type: AppNoticeType.success,
    );
  }

  /// Deletes the files of every completed task in one confirmed action.
  /// Task records stay so the history still explains what was downloaded.
  Future<void> deleteCompletedFiles() async {
    final completed = manager.tasks
        .where((task) => task.status == DownloadTaskStatus.completed)
        .toList();
    if (completed.isEmpty) {
      AppFeedback.show(
        title: 'لا توجد ملفات مكتملة'.tr,
        message: 'لا توجد تحميلات مكتملة لحذف ملفاتها.'.tr,
        type: AppNoticeType.info,
      );
      return;
    }
    var deleted = 0;
    for (final task in completed) {
      final ids = task.chapters
          .map((chapter) => chapter['id'])
          .whereType<String>()
          .toSet();
      final matching = downloadedChapters
          .where(
            (chapter) =>
                chapter.comicId == task.comicId &&
                ids.contains(chapter.chapterId),
          )
          .toList();
      for (final chapter in matching) {
        await deleteChapter(chapter, notify: false);
        deleted++;
      }
    }
    AppFeedback.show(
      title: 'نجاح'.tr,
      message: deleted == 0
          ? 'لم توجد ملفات محفوظة لهذه المهام.'.tr
          : 'تم حذف $deleted فصل من التخزين المحلي.'.tr,
      type: AppNoticeType.success,
    );
  }

  Future<void> retryFailedTasks() async {
    final failed = manager.tasks.where(
      (task) =>
          task.status == DownloadTaskStatus.failed ||
          task.status == DownloadTaskStatus.partiallyCompleted,
    );
    for (final task in failed.toList()) {
      await manager.retry(task.id, failedOnly: true);
    }
  }

  Future<void> clearCompletedRecords() async {
    final removed = await manager.removeCompletedTasks();
    AppFeedback.show(
      title: removed == 0 ? 'لا شيء لمسحه'.tr : 'نجاح'.tr,
      message: removed == 0
          ? 'لا توجد سجلات مكتملة.'.tr
          : 'أُزيلت $removed سجلات مكتملة، وبقيت الملفات المحمّلة.'.tr,
      type: removed == 0 ? AppNoticeType.info : AppNoticeType.success,
    );
  }

  Future<void> retryTask(DownloadTask task) => manager.retry(task.id,
      failedOnly: task.failedChapterIds.isNotEmpty);

  Future<void> deleteTask(DownloadTask task) => manager.removeTask(task.id);
}
