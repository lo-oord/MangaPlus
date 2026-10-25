import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:workmanager/workmanager.dart';

import 'package:mangaplus/app/data/models/bookmark.dart';
import 'package:mangaplus/app/data/models/comic_detail.dart';
import 'package:mangaplus/app/data/services/account_sync_service.dart';
import 'package:mangaplus/app/data/services/app_notification_service.dart';
import 'package:mangaplus/app/data/services/comic_service.dart';
import 'package:mangaplus/app/data/sources/manga_source_registry.dart';
import 'package:mangaplus/firebase_options.dart';

class ChapterUpdate {
  const ChapterUpdate({
    required this.bookmark,
    required this.chapters,
  });

  final BookmarkItem bookmark;
  final List<Chapter> chapters;
}

class ChapterCheckResult {
  const ChapterCheckResult({
    required this.checked,
    required this.updated,
    required this.failed,
  });

  final int checked;
  final int updated;
  final int failed;
}

class ChapterUpdateService {
  ChapterUpdateService({
    ComicService? comicService,
    AppNotificationService? appNotificationService,
  })  : _comicService = comicService ?? ComicService(),
        _appNotificationService = appNotificationService ?? AppNotificationService();

  static const String _trackingKey = 'chapter_update_tracking';
  static const String _unreadChaptersKey = 'chapter_updates_unread_chapters';
  static const String _backgroundEnabledKey = 'chapter_updates_background_enabled';
  static const String _mangaEnabledKey = 'chapter_updates_manga_enabled';
  static const String _novelEnabledKey = 'chapter_updates_novel_enabled';
  static const String _frequencyKey = 'chapter_updates_frequency_hours';
  static const String _wifiOnlyKey = 'chapter_updates_wifi_only';
  static const String backgroundTaskName = 'mangaplus.chapter_updates';
  static const String _chapterChannelId = 'chapter_updates';

  final ComicService _comicService;
  final AppNotificationService _appNotificationService;
  final GetStorage _storage = GetStorage();
  final Map<String, Future<void>> _inFlight = {};
  final RxInt unreadRevision = 0.obs;
  FlutterLocalNotificationsPlugin? _notifications;
  String _languageCode = 'ar_SA';

  bool get backgroundEnabled => _storage.read(_backgroundEnabledKey) != false;
  bool get mangaNotificationsEnabled => _storage.read(_mangaEnabledKey) != false;
  bool get novelNotificationsEnabled => _storage.read(_novelEnabledKey) != false;
  int get frequencyHours => (_storage.read(_frequencyKey) as int?) ?? 12;
  bool get wifiOnly => _storage.read(_wifiOnlyKey) == true;

  Future<void> initializeBackground() async {
    if (backgroundEnabled) await scheduleBackgroundChecks();
  }

  Future<void> setBackgroundEnabled(bool enabled) async {
    await _storage.write(_backgroundEnabledKey, enabled);
    if (enabled) {
      await scheduleBackgroundChecks();
    } else {
      await Workmanager().cancelByUniqueName(backgroundTaskName);
    }
  }

  Future<void> setMangaNotificationsEnabled(bool enabled) =>
      _storage.write(_mangaEnabledKey, enabled);

  Future<void> setNovelNotificationsEnabled(bool enabled) =>
      _storage.write(_novelEnabledKey, enabled);

  Future<void> setFrequencyHours(int hours) async {
    await _storage.write(_frequencyKey, hours);
    if (backgroundEnabled) await scheduleBackgroundChecks();
  }

  Future<void> setWifiOnly(bool enabled) async {
    await _storage.write(_wifiOnlyKey, enabled);
    if (backgroundEnabled) await scheduleBackgroundChecks();
  }

  Future<void> scheduleBackgroundChecks() async {
    await Workmanager().cancelByUniqueName(backgroundTaskName);
    await Workmanager().registerPeriodicTask(
      backgroundTaskName,
      backgroundTaskName,
      // Android WorkManager rejects periodic intervals shorter than 15 minutes.
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: wifiOnly ? NetworkType.unmetered : NetworkType.connected,
      ),
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(minutes: 15),
    );
  }

  Future<void> checkOnAppOpen() async {
    if (!backgroundEnabled) return;
    try {
      await checkFavorites();
    } catch (error) {
      // A later resume, connectivity event, or timer cycle can retry this check.
      debugPrint('Unable to check favorite chapters on app open: $error');
    }
  }

  void attachNotificationPlugin(
    FlutterLocalNotificationsPlugin plugin, {
    String languageCode = 'ar_SA',
  }) {
    _notifications = plugin;
    _languageCode = languageCode;
  }

  Future<ChapterCheckResult> checkFavorites({
    Future<void> Function(ChapterUpdate update)? onUpdate,
  }) async {
    try {
      await AccountSyncService().syncLocalData();
    } catch (error) {
      debugPrint('Unable to sync favorites before chapter check: $error');
    }
    final raw = _storage.read('bookmarks');
    final entries = raw is Map ? raw.entries : const <MapEntry<dynamic, dynamic>>[];
    final bookmarks = entries
        .where((entry) => entry.value is Map)
        .map((entry) => BookmarkItem.fromJson(
              '${entry.key}',
              Map<String, dynamic>.from(entry.value as Map),
            ))
        .where((item) => _isAllowed(item) && item.comicId.trim().isNotEmpty)
        .toList(growable: false);

    var checked = 0;
    var updated = 0;
    var failed = 0;
    for (final bookmark in bookmarks) {
      try {
        final update = await _checkOne(bookmark);
        checked++;
        if (update != null) {
          updated++;
          await onUpdate?.call(update);
          await _showNotification(update);
          final source = MangaSourceRegistry.forUrl(update.bookmark.comicId);
          if (source != null && update.chapters.isNotEmpty) {
            final tracking = _tracking();
            tracking['${source.id}|${update.bookmark.comicId}'] =
                _trackingEntry(update.chapters.first);
            await _saveTracking(tracking);
          }
        }
      } catch (error) {
        failed++;
        debugPrint('Unable to check ${bookmark.comicId}: $error');
      }
    }
    return ChapterCheckResult(checked: checked, updated: updated, failed: failed);
  }

  Future<ChapterUpdate?> _checkOne(BookmarkItem bookmark) async {
    final source = MangaSourceRegistry.forUrl(bookmark.comicId);
    if (source == null) return null;
    final key = '${source.id}|${bookmark.comicId}';
    final active = _inFlight[key];
    if (active != null) {
      await active;
      return null;
    }
    final completer = Completer<void>();
    _inFlight[key] = completer.future;
    try {
      final details = await _comicService
          .fetchComicDetail(bookmark.comicId)
          .timeout(const Duration(seconds: 25));
      final chapters = details.comicDetail.chapters
          .where((chapter) => chapter.chapterId.trim().isNotEmpty)
          .toList(growable: false);
      if (chapters.isEmpty) return null;

      final tracking = _tracking();
      final previous = tracking[key];
      final latest = chapters.first;
      if (previous == null) {
        tracking[key] = _trackingEntry(latest);
        await _saveTracking(tracking);
        return null;
      }

      final lastId = '${previous['lastChapterId'] ?? ''}';
      final lastIndex = chapters.indexWhere((chapter) => chapter.chapterId == lastId);
      if (lastIndex < 0) {
        // The source changed its ids or returned another branch. Re-baseline silently.
        tracking[key] = _trackingEntry(latest);
        await _saveTracking(tracking);
        return null;
      }
      if (lastIndex == 0) return null;

      final newChapters = chapters.take(lastIndex).toList(growable: false);
      return ChapterUpdate(bookmark: bookmark, chapters: newChapters);
    } finally {
      completer.complete();
      _inFlight.remove(key);
    }
  }

  Map<String, dynamic> _tracking() {
    final raw = _storage.read(_trackingKey);
    if (raw is! Map) return <String, dynamic>{};
    return Map<String, dynamic>.from(raw);
  }

  Map<String, dynamic> _trackingEntry(Chapter chapter) => {
        'lastChapterId': chapter.chapterId,
        'lastChapterTitle': chapter.title,
        'checkedAt': DateTime.now().toUtc().toIso8601String(),
      };

  Future<void> _saveTracking(Map<String, dynamic> tracking) =>
      _storage.write(_trackingKey, tracking);

  bool isNewChapter(String comicId, String chapterId) =>
      newChapterIds(comicId).contains(chapterId);

  Set<String> newChapterIds(String comicId) {
    final raw = _storage.read(_unreadChaptersKey);
    if (raw is! Map) return <String>{};
    final chapters = raw[comicId];
    if (chapters is! List) return <String>{};
    return chapters.map((value) => '$value').where((id) => id.isNotEmpty).toSet();
  }

  Future<void> markChapterRead(String comicId, String chapterId) async {
    if (comicId.isEmpty || chapterId.isEmpty) return;
    final raw = _storage.read(_unreadChaptersKey);
    if (raw is! Map) return;
    final unread = Map<String, dynamic>.from(raw);
    final chapters = unread[comicId];
    if (chapters is! List) return;
    final remaining = chapters.map((value) => '$value').toSet();
    if (!remaining.remove(chapterId)) return;
    if (remaining.isEmpty) {
      unread.remove(comicId);
    } else {
      unread[comicId] = remaining.toList(growable: false);
    }
    await _storage.write(_unreadChaptersKey, unread);
    unreadRevision.value++;
  }

  Future<void> _recordNewChapters(String comicId, Iterable<Chapter> chapters) async {
    final raw = _storage.read(_unreadChaptersKey);
    final unread = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final ids = unread[comicId] is List
        ? (unread[comicId] as List).map((value) => '$value').toSet()
        : <String>{};
    final before = ids.length;
    ids.addAll(chapters.map((chapter) => chapter.chapterId.trim()).where((id) => id.isNotEmpty));
    if (ids.length == before) return;
    unread[comicId] = ids.toList(growable: false);
    await _storage.write(_unreadChaptersKey, unread);
    unreadRevision.value++;
  }

  Future<void> _showNotification(ChapterUpdate update) async {
    final title = update.bookmark.title.trim().isEmpty
        ? 'فصل جديد متاح'
        : update.bookmark.title;
    final isEnglish = _languageCode == 'en_US' || _languageCode == 'en';
    final chapterNumber = _chapterNumber(update.chapters.first.title);
    final body = chapterNumber == null
        ? (isEnglish
            ? '${update.chapters.first.title} is available now 🎉🔥'
            : '${update.chapters.first.title} متوفر الآن 🎉🔥')
        : (isEnglish
            ? 'Chapter $chapterNumber is available now 🎉🔥'
            : 'الفصل $chapterNumber متوفر الآن 🎉🔥');
    final notificationId = _stableId('${update.bookmark.comicId}|${update.chapters.first.chapterId}');
    await _appNotificationService.recordLocalNotification(
      id: 'chapter|${update.bookmark.comicId}|${update.chapters.first.chapterId}',
      title: title,
      body: body,
      imageUrl: update.bookmark.coverImage,
      data: {
        'comicId': update.bookmark.comicId,
        'chapterId': update.chapters.first.chapterId,
        'source': 'chapter_updates',
      },
    );
    await _recordNewChapters(
      update.bookmark.comicId,
      update.chapters,
    );
    final plugin = _notifications;
    if (plugin == null) return;
    AndroidBitmap<Object>? cover;
    final coverUrl = update.bookmark.coverImage.trim();
    if (coverUrl.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(coverUrl)).timeout(const Duration(seconds: 8));
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          cover = ByteArrayAndroidBitmap(response.bodyBytes) as AndroidBitmap<Object>;
        }
      } catch (_) {
        // The notification remains useful when a cover cannot be downloaded.
      }
    }
    await plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(AndroidNotificationChannel(
          _chapterChannelId,
          isEnglish ? 'New chapters' : 'الفصول الجديدة',
          description: isEnglish ? 'New chapters from your favorites.' : 'فصول جديدة من أعمالك المفضلة.',
          importance: Importance.high,
        ));
    await plugin.show(
      notificationId,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _chapterChannelId,
          isEnglish ? 'New chapters' : 'الفصول الجديدة',
          channelDescription: isEnglish ? 'New chapters from your favorites.' : 'فصول جديدة من أعمالك المفضلة.',
          icon: 'ic_stat_mangaplus',
          color: const Color(0xff5b9bd5),
          importance: Importance.high,
          priority: Priority.high,
          largeIcon: cover,
        ),
      ),
      payload: update.bookmark.comicId,
    );
  }

  int _stableId(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }

  String? _chapterNumber(String title) {
    final match = RegExp(
      r'(?:الفصل|chapter|ch\.?)[^0-9]*([0-9]+(?:[.,][0-9]+)?)',
      caseSensitive: false,
    ).firstMatch(title);
    return match?.group(1)?.replaceAll(',', '.');
  }

  bool _isNovel(BookmarkItem item) {
    final type = item.type.trim().toLowerCase();
    return type == 'novel' || type == 'رواية';
  }

  bool _isAllowed(BookmarkItem item) =>
      _isNovel(item) ? novelNotificationsEnabled : mangaNotificationsEnabled;
}

@pragma('vm:entry-point')
void chapterUpdateCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      DartPluginRegistrant.ensureInitialized();
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      await GetStorage.init();
      final plugin = FlutterLocalNotificationsPlugin();
      await plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_mangaplus'),
        ),
      );
      final service = ChapterUpdateService();
      service.attachNotificationPlugin(plugin);
      final result = await service.checkFavorites();
      // Tell WorkManager to retry after transient source/network failures.
      return result.failed == 0;
    } catch (error, stackTrace) {
      debugPrint('Background favorite chapter check failed: $error\n$stackTrace');
      return false;
    }
  });
}
