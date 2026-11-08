import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:mangaplus/app/data/services/account_sync_service.dart';
import 'package:mangaplus/app/data/services/app_notification_service.dart';
import 'package:mangaplus/app/data/services/auth_service.dart';
import 'package:mangaplus/app/data/services/chapter_update_service.dart';
import 'package:mangaplus/app/modules/profile/controllers/profile_controller.dart';
import 'package:mangaplus/app/modules/chapter/controllers/chapter_controller.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class SettingsController extends GetxController {
  SettingsController();

  final GetStorage _storage = GetStorage();
  final AuthService _auth = Get.isRegistered<AuthService>()
      ? Get.find<AuthService>()
      : AuthService();
  final AppNotificationService _notifications =
      Get.isRegistered<AppNotificationService>()
          ? Get.find<AppNotificationService>()
          : AppNotificationService();

  final RxBool isDarkMode = false.obs;
  final RxString language = 'ar_SA'.obs;
  final RxBool favoritesNotifications = false.obs;
  final RxBool mangaNotifications = true.obs;
  final RxBool novelNotifications = false.obs;
  final RxBool isSyncing = false.obs;
  final RxString lastSyncLabel = ''.obs;
  final RxBool isOffline = false.obs;
  final RxString appVersion = ''.obs;
  final RxString buildNumber = ''.obs;
  final RxBool cacheSizeCalulating = false.obs;
  final RxInt coverCacheCount = 0.obs;
  final RxInt coverCacheSize = 0.obs;
  final RxBool isCacheClearing = false.obs;
  final RxBool isResetting = false.obs;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _lastSyncMonitor;

  @override
  void onInit() {
    super.onInit();
    _loadAppInfo();
    _loadSettings();
    _startConnectivityWatch();
    _refreshLastSyncLabel();
  }

  @override
  void onClose() {
    _connectivitySubscription?.cancel();
    _lastSyncMonitor?.cancel();
    super.onClose();
  }

  Future<void> _loadAppInfo() async {
    try {
      final pkg = await Platform.packageInfo;
      appVersion.value = pkg.version;
      buildNumber.value = pkg.buildNumber.isNotEmpty ? pkg.buildNumber : '—';
    } catch (_) {
      appVersion.value = '—';
      buildNumber.value = '—';
    }
  }

  Future<void> _loadSettings() async {
    final savedLanguage = _storage.read<String>('language') ?? 'ar_SA';
    final savedTheme = _storage.read<String>('themeMode');
    language.value = savedLanguage;
    isDarkMode.value = savedTheme == 'dark';
    if (Get.isRegistered<ChapterUpdateService>()) {
      final chapterService = Get.find<ChapterUpdateService>();
      favoritesNotifications.value = chapterService.backgroundEnabled;
      mangaNotifications.value = chapterService.mangaNotificationsEnabled;
      novelNotifications.value = chapterService.novelNotificationsEnabled;
    }
  }

  Future<void> _startConnectivityWatch() async {
    if (kIsWeb) return;
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(_onConnectivity);
    _onConnectivity(await Connectivity().checkConnectivity());
  }

  void _onConnectivity(List<ConnectivityResult> results) {
    final offline = results.every((result) => result == ConnectivityResult.none);
    if (isOffline.value != offline) {
      isOffline.value = offline;
    }
  }

  Future<void> _refreshLastSyncLabel() async {
    final lastSyncRaw = _storage.read<String>('lastSync');
    if (lastSyncRaw == null || lastSyncRaw.isEmpty) {
      lastSyncLabel.value = 'لم تتم مزامنة بعد'.tr;
      return;
    }
    try {
      final parsed = DateTime.tryParse(lastSyncRaw);
      if (parsed == null) {
        lastSyncLabel.value = lastSyncRaw;
        return;
      }
      final now = DateTime.now();
      final diff = now.difference(parsed);
      if (diff.inMinutes < 1) {
        lastSyncLabel.value = 'تمت المزامنة قبل لحظات'.tr;
      } else if (diff.inHours < 1) {
        lastSyncLabel.value = 'تمت المزامنة قبل ${diff.inMinutes} ${'دقيقة'.tr}';
      } else if (diff.inDays < 1) {
        lastSyncLabel.value = 'تمت المزامنة قبل ${diff.inHours} ${'ساعة'.tr}';
      } else {
        lastSyncLabel.value =
            'تمت المزامنة ${parsed.day}/${parsed.month}/${parsed.year}';
      }
    } catch (_) {
      lastSyncLabel.value = lastSyncRaw;
    }
  }

  Future<void> _recordSync() async {
    await _storage.write('lastSync', DateTime.now().toIso8601String());
    _refreshLastSyncLabel();
  }

  Future<void> setDarkMode(bool value) async {
    isDarkMode.value = value;
    Get.changeThemeMode(value ? ThemeMode.dark : ThemeMode.light);
    AppColors.refreshTheme(value);
    await _storage.write('themeMode', value ? 'dark' : 'light');
    try {
      await _auth.saveSettings(
        language: language.value,
        themeMode: value ? 'dark' : 'light',
      );
    } catch (_) {}
    if (Get.isRegistered<ProfileController>()) {
      final profileController = Get.find<ProfileController>();
      profileController.isDarkMode.value = value;
    }
  }

  Future<void> setLanguage(String value) async {
    language.value = value;
    Get.updateLocale(
      value == 'en_US'
          ? const Locale('en', 'US')
          : const Locale('ar', 'SA'),
    );
    await _storage.write('language', value);
    try {
      await _auth.saveSettings(language: value, themeMode: isDarkMode.value ? 'dark' : 'light');
    } catch (_) {}
    if (Get.isRegistered<ProfileController>()) {
      final profileController = Get.find<ProfileController>();
      profileController.selectedLanguage.value = value;
      await profileController._storage.write('language', value);
    }
  }

  Future<void> setFavoritesNotifications(bool value) async {
    favoritesNotifications.value = value;
    if (Get.isRegistered<ChapterUpdateService>()) {
      final chapterService = Get.find<ChapterUpdateService>();
      await chapterService.setBackgroundEnabled(value);
      if (value && await chapterService.isBatteryOptimizationIgnored() == false) {
        await chapterService.requestBatteryOptimizationExemption();
      }
    }
  }

  Future<void> setMangaNotifications(bool value) async {
    mangaNotifications.value = value;
    if (Get.isRegistered<ChapterUpdateService>()) {
      await Get.find<ChapterUpdateService>().setMangaNotificationsEnabled(value);
    }
  }

  Future<void> setNovelNotifications(bool value) async {
    novelNotifications.value = value;
    if (Get.isRegistered<ChapterUpdateService>()) {
      await Get.find<ChapterUpdateService>().setNovelNotificationsEnabled(value);
    }
  }

  Future<void> syncNow() async {
    if (isSyncing.value) return;
    if (isOffline.value) {
      Get.snackbar(
        'غير متصل بالإنترنت'.tr,
        'لا يمكن مزامنة البيانات دون اتصال بالإنترنت'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    isSyncing.value = true;
    try {
      final auth = Get.isRegistered<AuthService>() ? Get.find<AuthService>() : null;
      final user = auth?.currentUser;
      if (user == null || user.isAnonymous) {
        Get.snackbar(
          'لا يوجد حساب نشط'.tr,
          'سجّل الدخول لمزامنة بياناتك بين الأجهزة'.tr,
          snackPosition: SnackPosition.BOTTOM,
        );
        isSyncing.value = false;
        return;
      }
      await AccountSyncService().syncLocalData(force: true);
      await _recordSync();
      Get.snackbar(
        'تمت المزامنة'.tr,
        'تم مزامنة بياناتك مع حسابك'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (error) {
      Get.snackbar(
        'فشلت المزامنة'.tr,
        error.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isSyncing.value = false;
    }
  }

  Future<void> refreshCoverCacheInfo() async {
    cacheSizeCalulating.value = true;
    try {
      final cacheManager = MangaCoverCacheManager.instance;
      final info = await cacheManager.getCacheInfo();
      coverCacheCount.value = info.filesCount;
      coverCacheSize.value = info.size;
    } catch (_) {
      coverCacheCount.value = 0;
      coverCacheSize.value = 0;
    } finally {
      cacheSizeCalulating.value = false;
    }
  }

  Future<void> clearCoverCache() async {
    isCacheClearing.value = true;
    try {
      await MangaCoverCacheManager.instance.emptyCache();
      coverCacheCount.value = 0;
      coverCacheSize.value = 0;
      Get.snackbar(
        'تم مسح المحتوى المؤقت'.tr,
        'تم مسح الصور المخزنة مؤقتًا'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (error) {
      Get.snackbar(
        'فشل المسح'.tr,
        error.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isCacheClearing.value = false;
    }
  }

  Future<void> resetAppSettings() async {
    if (isResetting.value) return;
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        title: Text('إعادة تعيين الإعدادات'.tr),
        content: Text(
          'هذا الإجراء سيسترجع إعدادات التطبيق إلى القيم الافتراضية بدون مسح حسابك أو بيانات القراءة أو المفضلة.'.tr,
          textAlign: TextAlign.start,
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('إلغاء'.tr),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: Text('إعادة التعيين'.tr),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    isResetting.value = true;
    try {
      await _storage.remove('themeMode');
      await _storage.remove('language');
      isDarkMode.value = false;
      language.value = 'ar_SA';
      Get.changeThemeMode(ThemeMode.light);
      AppColors.refreshTheme(false);
      Get.updateLocale(const Locale('ar', 'SA'));
      await _auth.saveSettings(language: 'ar_SA', themeMode: 'light');
      if (Get.isRegistered<ChapterUpdateService>()) {
        final chapterService = Get.find<ChapterUpdateService>();
        await chapterService.setBackgroundEnabled(true);
        await chapterService.setMangaNotificationsEnabled(true);
        await chapterService.setNovelNotificationsEnabled(false);
      }
      favoritesNotifications.value = true;
      mangaNotifications.value = true;
      novelNotifications.value = false;
      Get.snackbar(
        'تمت إعادة التعيين'.tr,
        'تم استعادة إعدادات التطبيق الافتراضية'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (error) {
      Get.snackbar(
        'فشلت إعادة التعيين'.tr,
        error.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isResetting.value = false;
    }
  }

  void copyBuildId() {
    if (buildNumber.value.isEmpty || buildNumber.value == '—') return;
    Get.clipboard.text = 'MangaPlus Build ${buildNumber.value}';
    Get.snackbar(
      'تم نسخ رقم الإصدار'.tr,
      'تم نسخ حالة الإصدار إلى الحافظة'.tr,
      snackPosition: SnackPosition.BOTTOM,
    );
  }
}
