import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/data/services/download_manager_service.dart';
import 'package:mangaplus/app/routes/app_pages.dart';

class NotificationPresentation {
  const NotificationPresentation._();

  static const String channelId = 'high_importance_channel';
  static const String weeklySummaryPayload = 'reading_stats_weekly';
  static const Set<String> _downloadActions = {
    'pause',
    'resume',
    'retry',
    'cancel',
  };

  static AndroidNotificationChannel channelFor(String languageCode) {
    final isEnglish = languageCode == 'en_US' || languageCode == 'en';
    return AndroidNotificationChannel(
      channelId,
      isEnglish ? 'Important notifications' : 'الإشعارات المهمة',
      description: isEnglish
          ? 'Important MangaPlus alerts.'
          : 'تُستخدم هذه القناة للتنبيهات المهمة في MangaPlus.',
      importance: Importance.high,
    );
  }

  static Future<void> updateLanguage(String languageCode) async {
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channelFor(languageCode));
  }

  /// Single tap handler shared by the app shell and the download manager.
  /// Both initialise [FlutterLocalNotificationsPlugin], and the last
  /// initialisation replaces the response callback, so routing every action
  /// through one function keeps navigation and download controls working
  /// regardless of initialisation order.
  static Future<void> handleResponse(NotificationResponse response) async {
    final payload = response.payload?.trim() ?? '';
    final parts = payload.split('|');
    final action = response.actionId?.trim().isNotEmpty == true
        ? response.actionId!.trim()
        : (parts.isEmpty ? '' : parts.first);
    if (parts.length == 2 && _downloadActions.contains(action)) {
      final manager = Get.isRegistered<DownloadManagerService>()
          ? Get.find<DownloadManagerService>()
          : null;
      if (manager != null) {
        switch (action) {
          case 'pause':
            await manager.pause(parts.last);
          case 'resume':
            await manager.resume(parts.last);
          case 'retry':
            await manager.retry(parts.last);
          case 'cancel':
            await manager.cancel(parts.last);
        }
      }
      return;
    }
    if (payload == weeklySummaryPayload) {
      Get.toNamed(Routes.PROFILE);
      return;
    }
    if (payload.isNotEmpty) {
      Get.toNamed(Routes.COMIC_DETAIL, arguments: payload);
      return;
    }
    Get.toNamed(Routes.NOTIFICATIONS);
  }
}
