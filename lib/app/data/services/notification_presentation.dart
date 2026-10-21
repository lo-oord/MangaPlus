import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationPresentation {
  const NotificationPresentation._();

  static const String channelId = 'high_importance_channel';

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
}
