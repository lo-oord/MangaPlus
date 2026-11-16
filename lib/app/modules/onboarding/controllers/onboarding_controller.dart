import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mangaplus/app/core/theme/theme_mode_preference.dart';
import 'package:mangaplus/app/routes/app_pages.dart';

class OnboardingController extends GetxController {
  static const storageKey = 'onboarding_completed';

  final GetStorage _storage = GetStorage();
  final PageController pageController = PageController();

  final RxInt currentPage = 0.obs;
  final RxString selectedLanguage = 'ar_SA'.obs;
  final RxBool isDarkMode = true.obs;

  int get pageCount => 3;
  bool get isLastPage => currentPage.value == pageCount - 1;

  @override
  void onInit() {
    super.onInit();
    selectedLanguage.value =
        _storage.read<String>('language') ?? 'ar_SA';
    isDarkMode.value = ThemeModePreference.fromStorage(
          _storage.read<String>('themeMode'),
        ) ==
        ThemeMode.dark;
  }

  void onPageChanged(int index) {
    currentPage.value = index;
  }

  void next() {
    if (isLastPage) {
      complete();
      return;
    }
    pageController.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void back() {
    if (currentPage.value == 0) return;
    pageController.previousPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> selectLanguage(String code) async {
    selectedLanguage.value = code;
    await _storage.write('language', code);
    final locale = code == 'en_US'
        ? const Locale('en', 'US')
        : const Locale('ar', 'SA');
    Get.updateLocale(locale);
  }

  Future<void> setDarkMode(bool dark) async {
    isDarkMode.value = dark;
    final mode = dark ? ThemeMode.dark : ThemeMode.light;
    await _storage.write('themeMode', ThemeModePreference.toStorage(mode));
    Get.changeThemeMode(mode);
  }

  Future<void> complete() async {
    await _storage.write(storageKey, true);
    Get.offAllNamed(Routes.MAIN);
  }

  @override
  void onClose() {
    pageController.dispose();
    super.onClose();
  }
}
