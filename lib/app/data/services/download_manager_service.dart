import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
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
  final http.Client _httpClient = http.Client();
  final tasks = <DownloadTask>[].obs;
  final chapterProgress = <String, double>{}.obs;
  final Set<String> _running = <String>{};
  bool _pumping = false;
  bool _backgroundReady = false;
  bool _notificationsReady = false;

  Future<DownloadManagerService> init() async {
    await _load();
    unawaited(_initializeBackgroundServices());
    return this;
  }

  Future<void> _initializeBackgroundServices() async {
    try {
      await _initNotifications();
    } catch (error) {
      debugPrint('Unable to initialize download notifications: $error');
    }
    _backgroundReady = true;
    await _pump();
  }

  @override
  void onClose() {
    _httpClient.close();
    super.onClose();
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
    final activeProgress = <String, double>{};
    for (final entry in legacy.entries) {
      final value = entry.value is num ? (entry.value as num).toDouble() : 0.0;
      if (value > 0 && value < 1) activeProgress[entry.key] = value;
    }
    chapterProgress.assignAll(activeProgress);
  }

  Future<void> _initNotifications() async {
    await _notifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_mangaplus'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final parts = response.payload?.split('|') ?? const [];
        if (parts.length != 2) return;
        final action = response.actionId?.isNotEmpty == true
            ? response.actionId!
            : parts.first;
        if (action == 'pause') pause(parts.last);
        if (action == 'resume') resume(parts.last);
        if (action == 'retry') retry(parts.last);
        if (action == 'cancel') cancel(parts.last);
      },
    );
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      _channelId,
      'تنزيلات MangaPlus',
      description: 'تقدم تنزيل الفصول',
      importance: Importance.low,
    ));
    _notificationsReady = true;
    final permissionRequest = android?.requestNotificationsPermission();
    if (permissionRequest != null) {
      unawaited(permissionRequest.then<void>((_) {}).catchError((Object error) {
        debugPrint('Unable to request notification permission: $error');
      }));
    }
  }

  Future<String?> enqueue({
    required String comicId,
    required String comicTitle,
    required String coverImage,
    required List<Chapter> chapters,
    bool grouped = false,
    bool isNovel = false,
  }) async {
    final downloaded = _storage.read<List<dynamic>>('downloadedChapters') ?? const [];
    final downloadedIds = downloaded
        .whereType<Map>()
        .where((item) => (item['isNovel'] == true || (item['content']?.toString().isNotEmpty ?? false)) == isNovel)
        .map((item) => '${item['chapterId'] ?? ''}')
        .toSet();
    final activeIds = tasks
        .where((task) => task.status != DownloadTaskStatus.completed &&
            task.status != DownloadTaskStatus.cancelled)
        .where((task) => task.isNovel == isNovel)
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
      isNovel: isNovel,
      chapters: requested,
      createdAt: now,
      updatedAt: now,
    );
    tasks.add(task);
    await _persist();
    unawaited(_notify(task));
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
    if (!_backgroundReady || _pumping) return;
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
        if (task.isNovel) {
          await _downloadNovelChapter(task, id, chapter['title'] ?? 'الفصل');
        } else {
          await _downloadChapter(task, id, chapter['title'] ?? 'الفصل');
        }
        await _clearChapterProgress(id);
        task = _task(original.id);
        if (task == null) return;
        if (task.status == DownloadTaskStatus.paused ||
            task.status == DownloadTaskStatus.cancelled) return;
        final completed = [...task.completedChapterIds, id].toSet().toList();
        final failed = [...task.failedChapterIds]..remove(id);
        await _replace(task.copyWith(
          completedChapterIds: completed,
          failedChapterIds: failed,
          chapterProgress: {...task.chapterProgress, id: 1.0},
          clearCurrentChapter: true,
        ));
      } catch (error) {
        await _clearChapterProgress(id);
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

  Future<void> _downloadNovelChapter(DownloadTask task, String chapterId, String chapterTitle) async {
    final current = _task(task.id);
    if (current?.status == DownloadTaskStatus.paused || current?.status == DownloadTaskStatus.cancelled) return;
    final data = await _comicService.fetchNovelChapter(chapterId);
    final afterFetch = _task(task.id);
    if (afterFetch?.status == DownloadTaskStatus.paused ||
        afterFetch?.status == DownloadTaskStatus.cancelled) return;
    final content = data.chapter.content.trim();
    if (content.isEmpty) throw StateError('لا يوجد محتوى نصي للفصل');
    chapterProgress[chapterId] = 1.0;
    chapterProgress.refresh();
    await _storage.write(_progressKey, chapterProgress);
    final live = _task(task.id);
    if (live != null) await _replace(live.copyWith(chapterProgress: {...live.chapterProgress, chapterId: 1.0}), notify: false);
    await _saveDownloadedNovelChapter(task, chapterId, chapterTitle, content);
  }
  Future<void> _saveDownloadedNovelChapter(DownloadTask task, String chapterId, String chapterTitle, String content) async {
    final localCover = await _ensureLocalCover(task);
    final raw = _storage.read<List<dynamic>>('downloadedChapters') ?? [];
    raw.removeWhere((item) => item is Map && item['chapterId'] == chapterId);
    raw.add(DownloadedChapter(comicId: task.comicId, chapterId: chapterId, comicTitle: task.comicTitle, chapterTitle: chapterTitle, coverImage: localCover, localImagePaths: const [], content: content, isNovel: true, downloadedAt: DateTime.now()).toJson());
    await _storage.write('downloadedChapters', raw);
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
    final paths = List<String?>.filled(data.chapter.images.length, null);
    var completedPages = 0;
    var lastNotifiedPercent = 0;
    var nextIndex = 0;
    Future<void> downloadImage() async {
      while (true) {
        final index = nextIndex++;
        if (index >= data.chapter.images.length) return;
        final current = _task(task.id);
        if (current?.status == DownloadTaskStatus.paused ||
            current?.status == DownloadTaskStatus.cancelled) return;
        final imageUri = Uri.parse(data.chapter.images[index]);
        final isMangaDar = imageUri.host == 'storage.mangadar.com' ||
            imageUri.host.endsWith('.storage.mangadar.com') ||
            imageUri.host == 'mangadar.com';
        final headers = isMangaDar
            ? <String, String>{
                'Referer': 'https://mangadar.com/',
                'User-Agent':
                    'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/131 Mobile Safari/537.36',
              }
            : imageUri.host.contains('olympustaff.com')
            ? source.imageRequestHeaders
            : <String, String>{
                'Referer': '${imageUri.scheme}://${imageUri.host}/',
                'User-Agent':
                    'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/131 Mobile Safari/537.36',
              };
        final response = await _httpClient
            .get(imageUri, headers: headers)
            .timeout(const Duration(seconds: 35));
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw HttpException('HTTP ${response.statusCode}');
        }
        final contentType = response.headers['content-type']?.toLowerCase() ?? '';
        final extension = contentType.contains('png')
            ? 'png'
            : contentType.contains('webp')
                ? 'webp'
                : contentType.contains('gif')
                    ? 'gif'
                    : 'jpg';
        final file = File('${temp.path}/page_${index + 1}.$extension');
        await file.writeAsBytes(response.bodyBytes, flush: false);
        paths[index] = file.path;
        completedPages++;
        final progress = completedPages / data.chapter.images.length;
        chapterProgress[chapterId] = progress;
        final isLastPage = completedPages == data.chapter.images.length;
        final shouldCheckpoint = isLastPage || completedPages % 3 == 0;
        if (shouldCheckpoint) {
          await _storage.write(_progressKey, chapterProgress);
        }
        final live = _task(task.id);
        if (live != null) {
          await _replace(live.copyWith(
            chapterProgress: {...live.chapterProgress, chapterId: progress},
          ), notify: false, persist: shouldCheckpoint);
        }
        final percent = (progress * 100).floor();
        if (isLastPage || percent - lastNotifiedPercent >= 12) {
          final notificationTask = _task(task.id);
          if (notificationTask != null) unawaited(_notify(notificationTask));
          lastNotifiedPercent = percent;
        }
      }
    }
    try {
      final concurrency = data.chapter.images.length < 5
          ? data.chapter.images.length
          : 5;
      await Future.wait(List.generate(concurrency, (_) => downloadImage()));
      final current = _task(task.id);
      if (completedPages != data.chapter.images.length ||
          current?.status == DownloadTaskStatus.paused ||
          current?.status == DownloadTaskStatus.cancelled) return;
      if (await finalDir.exists()) await finalDir.delete(recursive: true);
      await temp.rename(finalDir.path);
      final finalPaths = paths
          .map((path) => path!.replaceFirst(temp.path, finalDir.path))
          .toList(growable: false);
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
    final localCover = await _ensureLocalCover(task);
    final raw = _storage.read<List<dynamic>>('downloadedChapters') ?? [];
    raw.removeWhere((item) => item is Map && item['chapterId'] == chapterId);
    raw.add(DownloadedChapter(
      comicId: task.comicId,
      chapterId: chapterId,
      comicTitle: task.comicTitle,
      chapterTitle: chapterTitle,
      coverImage: localCover,
      localImagePaths: paths,
      downloadedAt: DateTime.now(),
    ).toJson());
    await _storage.write('downloadedChapters', raw);
  }

  Future<String> _ensureLocalCover(DownloadTask task) async {
    final cover = task.coverImage.trim();
    if (cover.isEmpty || cover.startsWith('/')) return cover;
    try {
      final base = await getApplicationDocumentsDirectory();
      final dir = Directory('${base.path}/chapters/${_key(task.comicId)}');
      await dir.create(recursive: true);
      final cachedFile = File('${dir.path}/cover.jpg');
      if (await cachedFile.exists() && await cachedFile.length() > 0) {
        return cachedFile.path;
      }
      final coverUri = Uri.parse(cover);
      final response = await _httpClient.get(coverUri, headers: {
        'Referer': '${coverUri.scheme}://${coverUri.host}/',
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/131 Mobile Safari/537.36',
      }).timeout(
            const Duration(seconds: 15),
          );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        await cachedFile.writeAsBytes(response.bodyBytes, flush: true);
        return cachedFile.path;
      }
    } catch (_) {}
    return cover;
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

  Future<void> _clearChapterProgress(String chapterId) async {
    chapterProgress.remove(chapterId);
    await _storage.write(_progressKey, chapterProgress);
  }

  Future<void> _replace(
    DownloadTask task, {
    bool notify = true,
    bool persist = true,
  }) async {
    final index = tasks.indexWhere((item) => item.id == task.id);
    if (index < 0) return;
    tasks[index] = task;
    tasks.refresh();
    if (persist) await _persist();
    if (notify) await _notify(task);
  }

  Future<void> _persist() async {
    await _storage.write(_tasksKey, tasks.map((task) => task.toJson()).toList());
  }

  Future<void> _notify(DownloadTask task) async {
    if (!_notificationsReady) return;
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
    } else if (task.status == DownloadTaskStatus.failed ||
        task.status == DownloadTaskStatus.partiallyCompleted) {
      actions.add(const AndroidNotificationAction('retry', 'إعادة المحاولة'));
    }
    if (task.status != DownloadTaskStatus.completed &&
        task.status != DownloadTaskStatus.cancelled) {
      actions.add(const AndroidNotificationAction('cancel', 'إلغاء'));
    }
    final coverPath = await _notificationCover(task);
    final currentChapter = task.chapters.firstWhereOrNull(
      (chapter) => chapter['id'] == task.currentChapterId,
    );
    final chapterLabel = currentChapter?['title'];
    await _notifications.show(
      task.id.hashCode,
      task.comicTitle,
      '${chapterLabel == null ? '' : 'الفصل الحالي: $chapterLabel • '}${task.completedCount}/${task.totalChapters} • $status • $percent%',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'تنزيلات MangaPlus',
          channelDescription: 'تقدم تنزيل الفصول',
          importance: Importance.low,
          priority: Priority.low,
          onlyAlertOnce: true,
          largeIcon: coverPath == null ? null : FilePathAndroidBitmap(coverPath),
          showProgress: task.status != DownloadTaskStatus.cancelled,
          maxProgress: 100,
          progress: percent,
          ongoing: task.status == DownloadTaskStatus.downloading,
          autoCancel: task.status != DownloadTaskStatus.downloading,

          actions: actions,
        ),
      ),
      payload: task.status == DownloadTaskStatus.downloading
          ? 'pause|${task.id}'
          : task.status == DownloadTaskStatus.paused || task.status == DownloadTaskStatus.queued
              ? 'resume|${task.id}'
              : task.status == DownloadTaskStatus.failed || task.status == DownloadTaskStatus.partiallyCompleted
                  ? 'retry|${task.id}'
                  : null,
    );
  }

  Future<String?> _notificationCover(DownloadTask task) async {
    final value = await _ensureLocalCover(task);
    if (value.startsWith('/') && await File(value).exists()) return value;
    return null;
  }
}
