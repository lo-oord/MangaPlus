import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mangaplus/app/data/services/notification_presentation.dart';

class ProfileController extends GetxController {
  final GetStorage _storage = GetStorage();
  final RxString selectedLanguage = 'ar_SA'.obs;
  final RxBool isDarkMode = true.obs;

  @override
  void onInit() {
    selectedLanguage.value = _storage.read<String>('language') ?? 'ar_SA';
    final savedTheme = _storage.read<String>('themeMode') ?? 'dark';
    isDarkMode.value = savedTheme == 'dark';
    super.onInit();
  }

  Future<void> changeLanguage(String languageCode) async {
    if (languageCode != 'ar_SA' && languageCode != 'en_US') return;
    selectedLanguage.value = languageCode;
    Get.updateLocale(languageCode == 'en_US'
        ? const Locale('en', 'US')
        : const Locale('ar', 'SA'));
    await _storage.write('language', languageCode);
    try {
      await NotificationPresentation.updateLanguage(languageCode);
    } catch (_) {
      // Language selection remains available even if the OS channel cannot update.
    }
  }

  Future<void> changeTheme(bool darkMode) async {
    isDarkMode.value = darkMode;
    final mode = darkMode ? ThemeMode.dark : ThemeMode.light;
    Get.changeThemeMode(mode);
    await _storage.write('themeMode', darkMode ? 'dark' : 'light');
  }
}
