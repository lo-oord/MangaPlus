import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:mangaplus/app/data/services/app_notification_service.dart';

class NotificationPermissionPrompt {
  const NotificationPermissionPrompt._();

  static const String _askedKey = 'notification_permission_prompted';
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final GetStorage _storage = GetStorage();

  static bool _isGranted(AuthorizationStatus status) =>
      status == AuthorizationStatus.authorized ||
      status == AuthorizationStatus.provisional;

  static Future<void> showIfNeeded() async {
    if (kIsWeb) return;
    final service = Get.find<AppNotificationService>();
    final current = await _messaging.getNotificationSettings();
    if (_isGranted(current.authorizationStatus)) {
      await service.initialize();
      return;
    }
    if (_storage.read<bool>(_askedKey) == true || Get.isDialogOpen == true) return;

    await _storage.write(_askedKey, true);
    final isEnglish = Get.locale?.languageCode == 'en';
    final accepted = await Get.dialog<bool>(
      AlertDialog(
        title: Text(isEnglish ? 'Enable notifications' : 'تفعيل الإشعارات'),
        content: Text(isEnglish
            ? 'Allow notifications to receive new chapter alerts and MangaPlus announcements.'
            : 'اسمح بالإشعارات لتصلك تنبيهات الفصول الجديدة وإعلانات MangaPlus.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text(isEnglish ? 'Later' : 'لاحقًا'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: Text(isEnglish ? 'Continue' : 'متابعة'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
    if (accepted != true) return;

    final requested = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (_isGranted(requested.authorizationStatus)) {
      await service.initialize();
      return;
    }

    final openSettings = await Get.dialog<bool>(
      AlertDialog(
        title: Text(isEnglish ? 'Notifications are disabled' : 'الإشعارات غير مفعّلة'),
        content: Text(isEnglish
            ? 'You can enable notifications from this app’s system settings.'
            : 'يمكنك تفعيل الإشعارات من إعدادات التطبيق في النظام.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text(isEnglish ? 'Close' : 'إغلاق'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: Text(isEnglish ? 'Open settings' : 'فتح الإعدادات'),
          ),
        ],
      ),
    );
    if (openSettings == true) await openAppSettings();
  }
}
