import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:workmanager/workmanager.dart';

import 'package:mangaplus/app/data/models/bookmark.dart';
import 'package:mangaplus/app/data/models/chapter.dart';
import 'package:mangaplus/app/data/services/app_notification_service.dart';
import 'package:mangaplus/app/data/services/comic_service.dart';
import 'package:mangaplus/app/data/sources/manga_source_registry.dart';

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
  static const String _backgroundEnabledKey = 'chapter_updates_background_enabled';
  static const String _frequencyKey = 'chapter_updates_frequency_hours';
  static const String _wifiOnlyKey = 'chapter_updates_wifi_only';
  static const String _lastOpenCheckKey = 'chapter_updates_last_open_check';
  static const String backgroundTaskName = 'mangaplus.chapter_updates';
  static const String _chapterChannelId = 'chapter_updates';
  static const MethodChannel _systemChannel = MethodChannel('com.mangaplus.app/system');

  final ComicService _comicService;
  final AppNotificationService _appNotificationService;
  final GetStorage _storage = GetStorage();
  final Map<String, Future<void>> _inFlight = {};
  FlutterLocalNotificationsPlugin? _notifications;
  String _languageCode = 'ar_SA';

  bool get backgroundEnabled => _storage.read(_backgroundEnabledKey) == true;
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

  Future<void> setFrequencyHours(int hours) async {
    await _storage.write(_frequencyKey, hours);
    if (backgroundEnabled) await scheduleBackgroundChecks();
  }

  Future<void> setWifiOnly(bool enabled) async {
    await _storage.write(_wifiOnlyKey, enabled);
    if (backgroundEnabled) await scheduleBackgroundChecks();
  }

  Future<void> scheduleBackgroundChecks() async {
    await Workmanager().registerPeriodicTask(
      backgroundTaskName,
      backgroundTaskName,
      frequency: Duration(hours: frequencyHours.clamp(1, 24).toInt()),
      constraints: Constraints(
        networkType: wifiOnly ? NetworkType.unmetered : NetworkType.connected,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(minutes: 15),
    );
  }

  Future<void> checkOnAppOpen() async {
    final last = DateTime.tryParse('${_storage.read(_lastOpenCheckKey) ?? ''}');
    if (last != null && DateTime.now().difference(last) < const Duration(hours: 6)) return;
    await _storage.write(_lastOpenCheckKey, DateTime.now().toUtc().toIso8601String());
    await checkFavorites();
  }

  Future<bool> isBatteryOptimizationIgnored() async {
    if (kIsWeb) return true;
    return await _systemChannel.invokeMethod<bool>('isBatteryOptimizationIgnored') ?? true;
  }

  Future<void> requestBatteryOptimizationExemption() async {
    if (kIsWeb) return;
    await _systemChannel.invokeMethod<void>('requestBatteryOptimizationExemption');
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
    final raw = _storage.read('bookmarks');
    final entries = raw is Map ? raw.entries : const <MapEntry<dynamic, dynamic>>[];
    final bookmarks = entries
        .map((entry) => BookmarkItem.fromJson(
              '${entry.key}',
              Map<String, dynamic>.from(entry.value as Map),
            ))
        .where((item) => !_isNovel(item) && item.comicId.trim().isNotEmpty)
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
      tracking[key] = _trackingEntry(latest);
      await _saveTracking(tracking);
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
      data: {'comicId': update.bookmark.comicId, 'source': 'chapter_updates'},
    );
    final plugin = _notifications;
    if (plugin == null) return;
    AndroidBitmap? cover;
    final coverUrl = update.bookmark.coverImage.trim();
    if (coverUrl.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(coverUrl)).timeout(const Duration(seconds: 8));
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          cover = ByteArrayAndroidBitmap(response.bodyBytes);
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
}

@pragma('vm:entry-point')
void chapterUpdateCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    await GetStorage.init();
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_mangaplus'),
      ),
    );
    final service = ChapterUpdateService();
    service.attachNotificationPlugin(plugin);
    await service.checkFavorites();
    return true;
  });
}
