import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:mangaplus/app/data/models/comic_detail.dart';
import 'package:mangaplus/app/data/models/download_task.dart';
import 'package:mangaplus/app/data/models/downloaded_chapter.dart';
import 'package:mangaplus/app/data/services/comic_service.dart';
import 'package:mangaplus/app/data/sources/team_x_source.dart';
import 'package:mangaplus/app/widgets/app_feedback.dart';
import 'package:path_provider/path_provider.dart';

class DownloadManagerService extends GetxService {
  static const _tasksKey = 'download_tasks_v2';
  static const _progressKey = 'downloadingChapters';
  static const _channelId = 'download_progress';
  final GetStorage _storage = GetStorage();
  final ComicService _comicService = ComicService();
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final tasks = <DownloadTask>[].obs;
  final chapterProgress = <String, double>{}.obs;
  final Set<String> _running = <String>{};
  bool _pumping = false;

  Future<DownloadManagerService> init() async {
    await _load();
    await _initNotifications();
    unawaited(_pump());
    return this;
  }

  Future<void> _load() async {
    final raw = _storage.read<List<dynamic>>(_tasksKey) ?? const [];
    tasks.assignAll(raw.whereType<Map>().map((item) {
      try {
        final task = DownloadTask.fromJson(Map<String, dynamic>.from(item));
        if (task.status == DownloadTaskStatus.downloading) {
          return task.copyWith(status: DownloadTaskStatus.queued);
        }
        return task;
      } catch (_) {
        return null;
      }
    }).whereType<DownloadTask>());
    final legacy = _storage.read<Map<String, dynamic>>(_progressKey) ?? {};
    chapterProgress.assignAll(legacy.map(
      (key, value) => MapEntry(key, value is num ? value.toDouble() : 0.0),
    ));
  }

  Future<void> _initNotifications() async {
    await _notifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_mangaplus'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final parts = response.payload?.split('|') ?? const [];
        if (parts.length != 2) return;
        if (parts.first == 'pause') pause(parts.last);
        if (parts.first == 'resume') resume(parts.last);
        if (parts.first == 'cancel') cancel(parts.last);
      },
    );
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      _channelId,
      'تنزيلات MangaPlus',
      description: 'تقدم تنزيل فصول المانجا',
      importance: Importance.low,
    ));
    await android?.requestNotificationsPermission();
  }

  Future<String?> enqueue({
    required String comicId,
    required String comicTitle,
    required String coverImage,
    required List<Chapter> chapters,
    bool grouped = false,
  }) async {
    final downloaded = _storage.read<List<dynamic>>('downloadedChapters') ?? const [];
    final downloadedIds = downloaded
        .whereType<Map>()
        .map((item) => '${item['chapterId'] ?? ''}')
        .toSet();
    final activeIds = tasks
        .where((task) => task.status != DownloadTaskStatus.completed &&
            task.status != DownloadTaskStatus.cancelled)
        .expand((task) => task.chapters)
        .map((chapter) => chapter['id'])
        .whereType<String>()
        .toSet();
    final requested = chapters
        .where((chapter) =>
            !downloadedIds.contains(chapter.chapterId) &&
            !activeIds.contains(chapter.chapterId))
        .map((chapter) => {'id': chapter.chapterId, 'title': chapter.title})
        .toList(growable: false);
    if (requested.isEmpty) return null;
    final now = DateTime.now();
    final task = DownloadTask(
      id: '${now.microsecondsSinceEpoch}_${comicId.hashCode}',
      comicId: comicId,
      comicTitle: comicTitle,
      coverImage: coverImage,
      chapters: requested,
      createdAt: now,
      updatedAt: now,
    );
    tasks.add(task);
    await _persist();
    unawaited(_pump());
    return task.id;
  }

  Future<void> pause(String taskId) async {
    final task = _task(taskId);
    if (task == null || task.status == DownloadTaskStatus.completed) return;
    await _replace(task.copyWith(status: DownloadTaskStatus.paused));
    await _notify(task.copyWith(status: DownloadTaskStatus.paused));
  }

  Future<void> resume(String taskId) async {
    final task = _task(taskId);
    if (task == null || task.status == DownloadTaskStatus.completed) return;
    await _replace(task.copyWith(status: DownloadTaskStatus.queued, clearError: true));
    unawaited(_pump());
  }

  Future<void> cancel(String taskId) async {
    final task = _task(taskId);
    if (task == null) return;
    await _replace(task.copyWith(status: DownloadTaskStatus.cancelled));
    await _cleanupTemp(task);
    await _notify(task.copyWith(status: DownloadTaskStatus.cancelled));
  }

  Future<void> retry(String taskId, {bool failedOnly = true}) async {
    final task = _task(taskId);
    if (task == null) return;
    final failed = task.failedChapterIds.toSet();
    final completed = failedOnly
        ? task.completedChapterIds
        : const <String>[];
    final progress = Map<String, double>.from(task.chapterProgress)
      ..removeWhere((id, _) => failed.contains(id) || !failedOnly);
    await _replace(task.copyWith(
      status: DownloadTaskStatus.queued,
      completedChapterIds: completed,
      failedChapterIds: const [],
      chapterProgress: progress,
      clearError: true,
    ));
    unawaited(_pump());
  }

  Future<void> removeTask(String taskId) async {
    tasks.removeWhere((task) => task.id == taskId);
    await _persist();
  }

  DownloadTask? _task(String id) {
    final index = tasks.indexWhere((task) => task.id == id);
    return index < 0 ? null : tasks[index];
  }

  Future<void> _pump() async {
    if (_pumping) return;
    _pumping = true;
    try {
      while (true) {
        final next = tasks.firstWhereOrNull((task) =>
            task.status == DownloadTaskStatus.queued &&
            !_running.contains(task.id));
        if (next == null) break;
        _running.add(next.id);
        unawaited(_runTask(next).whenComplete(() {
          _running.remove(next.id);
          unawaited(_pump());
        }));
        if (_running.length >= 2) break;
      }
    } finally {
      _pumping = false;
    }
  }

  Future<void> _runTask(DownloadTask original) async {
    var task = _task(original.id);
    if (task == null) return;
    await _replace(task.copyWith(status: DownloadTaskStatus.downloading));
    task = _task(original.id);
    if (task == null) return;
    for (final chapter in task.chapters) {
      task = _task(original.id);
      if (task == null || task.status == DownloadTaskStatus.paused ||
          task.status == DownloadTaskStatus.cancelled) return;
      final id = chapter['id']!;
      if (task.completedChapterIds.contains(id)) continue;
      await _replace(task.copyWith(currentChapterId: id));
      try {
        await _downloadChapter(task, id, chapter['title'] ?? 'الفصل');
        task = _task(original.id);
        if (task == null) return;
        final completed = [...task.completedChapterIds, id].toSet().toList();
        final failed = [...task.failedChapterIds]..remove(id);
        await _replace(task.copyWith(
          completedChapterIds: completed,
          failedChapterIds: failed,
          chapterProgress: {...task.chapterProgress, id: 1.0},
          clearCurrentChapter: true,
        ));
      } catch (error) {
        task = _task(original.id);
        if (task == null) return;
        await _replace(task.copyWith(
          failedChapterIds: {...task.failedChapterIds, id}.toList(),
          errorMessage: '$error',
          clearCurrentChapter: true,
        ));
      }
    }
    task = _task(original.id);
    if (task == null) return;
    final status = task.completedCount == task.totalChapters
        ? DownloadTaskStatus.completed
        : task.completedCount > 0
            ? DownloadTaskStatus.partiallyCompleted
            : DownloadTaskStatus.failed;
    await _replace(task.copyWith(status: status, clearCurrentChapter: true));
    await _notify(_task(original.id)!);
  }

  Future<void> _downloadChapter(
    DownloadTask task,
    String chapterId,
    String chapterTitle,
  ) async {
    final data = await _comicService.fetchChapter(chapterId);
    if (data.chapter.images.isEmpty) throw StateError('لا توجد صفحات للفصل');
    final base = await getApplicationDocumentsDirectory();
    final comicKey = _key(task.comicId);
    final chapterKey = _key(chapterId);
    final root = Directory('${base.path}/chapters/$comicKey');
    final temp = Directory('${root.path}/$chapterKey.tmp');
    final finalDir = Directory('${root.path}/$chapterKey');
    await temp.create(recursive: true);
    final source = TeamXSource();
    final paths = <String>[];
    try {
      for (var index = 0; index < data.chapter.images.length; index++) {
        final current = _task(task.id);
        if (current?.status == DownloadTaskStatus.paused ||
            current?.status == DownloadTaskStatus.cancelled) return;
        final response = await http
            .get(Uri.parse(data.chapter.images[index]), headers: source.imageRequestHeaders)
            .timeout(const Duration(seconds: 35));
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw HttpException('HTTP ${response.statusCode}');
        }
        final extension = response.headers['content-type']?.contains('png') == true
            ? 'png'
            : 'jpg';
        final file = File('${temp.path}/page_${index + 1}.$extension');
        await file.writeAsBytes(response.bodyBytes, flush: true);
        paths.add(file.path);
        final progress = (index + 1) / data.chapter.images.length;
        chapterProgress[chapterId] = progress;
        chapterProgress.refresh();
        await _storage.write(_progressKey, chapterProgress);
        final live = _task(task.id);
        if (live != null) {
          await _replace(live.copyWith(
            chapterProgress: {...live.chapterProgress, chapterId: progress},
          ), notify: false);
        }
        await _notify(_task(task.id)!);
      }
      if (await finalDir.exists()) await finalDir.delete(recursive: true);
      await temp.rename(finalDir.path);
      final finalPaths = paths.map((path) => path.replaceFirst(temp.path, finalDir.path)).toList();
      await _saveDownloadedChapter(task, chapterId, chapterTitle, finalPaths);
    } catch (_) {
      if (await temp.exists()) await temp.delete(recursive: true);
      rethrow;
    }
  }

  Future<void> _saveDownloadedChapter(
    DownloadTask task,
    String chapterId,
    String chapterTitle,
    List<String> paths,
  ) async {
    final raw = _storage.read<List<dynamic>>('downloadedChapters') ?? [];
    raw.removeWhere((item) => item is Map && item['chapterId'] == chapterId);
    raw.add(DownloadedChapter(
      comicId: task.comicId,
      chapterId: chapterId,
      comicTitle: task.comicTitle,
      chapterTitle: chapterTitle,
      coverImage: task.coverImage,
      localImagePaths: paths,
      downloadedAt: DateTime.now(),
    ).toJson());
    await _storage.write('downloadedChapters', raw);
  }

  Future<void> _cleanupTemp(DownloadTask task) async {
    final base = await getApplicationDocumentsDirectory();
    final root = Directory('${base.path}/chapters/${_key(task.comicId)}');
    if (!await root.exists()) return;
    await for (final entity in root.list()) {
      if (entity.path.endsWith('.tmp')) await entity.delete(recursive: true);
    }
  }

  String _key(String value) => value.hashCode.toUnsigned(32).toRadixString(16);

  Future<void> _replace(DownloadTask task, {bool notify = true}) async {
    final index = tasks.indexWhere((item) => item.id == task.id);
    if (index < 0) return;
    tasks[index] = task;
    tasks.refresh();
    await _persist();
    if (notify) await _notify(task);
  }

  Future<void> _persist() async {
    await _storage.write(_tasksKey, tasks.map((task) => task.toJson()).toList());
  }

  Future<void> _notify(DownloadTask task) async {
    final status = task.status == DownloadTaskStatus.downloading
        ? 'جارٍ التحميل'
        : task.status == DownloadTaskStatus.completed
            ? 'مكتمل'
            : task.status == DownloadTaskStatus.paused
                ? 'متوقف مؤقتًا'
                : task.status == DownloadTaskStatus.failed
                    ? 'فشل'
                    : task.status == DownloadTaskStatus.partiallyCompleted
                        ? 'مكتمل جزئيًا'
                        : task.status == DownloadTaskStatus.cancelled
                            ? 'ملغى'
                            : 'قيد الانتظار';
    final percent = (task.progress * 100).round();
    final actions = <AndroidNotificationAction>[];
    if (task.status == DownloadTaskStatus.downloading) {
      actions.add(const AndroidNotificationAction('pause', 'إيقاف مؤقت'));
    } else if (task.status == DownloadTaskStatus.paused ||
        task.status == DownloadTaskStatus.queued) {
      actions.add(const AndroidNotificationAction('resume', 'استئناف'));
    }
    if (task.status != DownloadTaskStatus.completed &&
        task.status != DownloadTaskStatus.cancelled) {
      actions.add(const AndroidNotificationAction('cancel', 'إلغاء'));
    }
    await _notifications.show(
      task.id.hashCode,
      task.comicTitle,
      '${task.completedCount}/${task.totalChapters} • $status • $percent%',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'تنزيلات MangaPlus',
          channelDescription: 'تقدم تنزيل فصول المانجا',
          importance: Importance.low,
          priority: Priority.low,
          onlyAlertOnce: true,
          showProgress: task.status == DownloadTaskStatus.downloading,
          maxProgress: 100,
          progress: percent,
          ongoing: task.status == DownloadTaskStatus.downloading,
          autoCancel: task.status != DownloadTaskStatus.downloading,
          actions: actions,
        ),
      ),
      payload: '${task.status == DownloadTaskStatus.downloading ? 'pause' : 'resume'}|${task.id}',
    );
  }
}
