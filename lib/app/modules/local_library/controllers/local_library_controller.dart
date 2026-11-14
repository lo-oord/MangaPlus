import 'dart:io';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mangaplus/app/data/models/download_task.dart';
import 'package:mangaplus/app/data/models/downloaded_chapter.dart';
import 'package:mangaplus/app/data/services/download_manager_service.dart';
import 'package:mangaplus/app/widgets/app_feedback.dart';

class LocalComicGroup {
  final String comicId;
  final String title;
  final String coverImage;
  final List<DownloadedChapter> chapters;
  final int bytes;

  const LocalComicGroup({
    required this.comicId,
    required this.title,
    required this.coverImage,
    required this.chapters,
    required this.bytes,
  });

  String get sizeLabel {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class LocalLibraryController extends GetxController {
  final GetStorage _storage = GetStorage();
  final DownloadManagerService manager = Get.find<DownloadManagerService>();
  final groups = <LocalComicGroup>[].obs;
  final selectedComicIds = <String>{}.obs;
  final isSelectionMode = false.obs;
  final isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    load();
    _storage.listenKey('downloadedChapters', (_) => load());
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      final raw = _storage.read<List<dynamic>>('downloadedChapters') ?? const [];
      final byComic = <String, List<DownloadedChapter>>{};
      for (final item in raw.whereType<Map>()) {
        try {
          final chapter = DownloadedChapter.fromJson(Map<String, dynamic>.from(item));
          if (chapter.isNovel ? chapter.content.trim().isEmpty :
              (chapter.localImagePaths.isEmpty ||
               !chapter.localImagePaths.every((path) => File(path).existsSync()))) {
            continue;
          }
          byComic.putIfAbsent(chapter.comicId, () => []).add(chapter);
        } catch (_) {}
      }
      final result = <LocalComicGroup>[];
      for (final entry in byComic.entries) {
        final chapters = entry.value;
        var bytes = 0;
        for (final chapter in chapters) {
          if (chapter.isNovel) {
            bytes += chapter.content.length * 2;
          } else {
            for (final path in chapter.localImagePaths) {
              final file = File(path);
              if (file.existsSync()) bytes += file.lengthSync();
            }
          }
        }
        result.add(LocalComicGroup(
          comicId: entry.key,
          title: chapters.first.comicTitle,
          coverImage: chapters.first.coverImage,
          chapters: chapters,
          bytes: bytes,
        ));
      }
      result.sort((a, b) => a.title.compareTo(b.title));
      groups.assignAll(result);
    } finally {
      isLoading.value = false;
    }
  }

  void toggleSelection(String comicId) {
    isSelectionMode.value = true;
    if (!selectedComicIds.add(comicId)) selectedComicIds.remove(comicId);
    if (selectedComicIds.isEmpty) isSelectionMode.value = false;
    selectedComicIds.refresh();
  }

  void clearSelection() {
    selectedComicIds.clear();
    isSelectionMode.value = false;
  }

  Future<void> deleteSelected() async {
    final ids = selectedComicIds.toList();
    if (ids.isEmpty) return;
    for (final id in ids) {
      for (final task in manager.tasks.where((task) => task.comicId == id)) {
        if (task.status != DownloadTaskStatus.completed &&
            task.status != DownloadTaskStatus.cancelled) {
          await manager.cancel(task.id);
        }
      }
      await _deleteComic(id);
    }
    clearSelection();
    await load();
  }

  Future<void> _deleteComic(String comicId) async {
    final raw = _storage.read<List<dynamic>>('downloadedChapters') ?? [];
    final removed = raw.where((item) => item is Map && item['comicId'] == comicId);
    for (final item in removed.whereType<Map>()) {
      for (final path in List<String>.from(item['localImagePaths'] ?? const [])) {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
    }
    raw.removeWhere((item) => item is Map && item['comicId'] == comicId);
    await _storage.write('downloadedChapters', raw);
  }

  Future<void> deleteGroup(LocalComicGroup group) async {
    selectedComicIds.add(group.comicId);
    await deleteSelected();
    AppFeedback.show(title: 'نجاح'.tr, message: 'تم حذف المانجا من التخزين المحلي'.tr,
        type: AppNoticeType.success);
  }
}
