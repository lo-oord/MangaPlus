import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mangaplus/app/core/theme/theme_mode_preference.dart';
import 'package:mangaplus/app/data/services/notification_presentation.dart';
import 'package:mangaplus/app/data/models/user_profile.dart';
import 'package:mangaplus/app/data/services/auth_service.dart';

class ProfileController extends GetxController {
  final GetStorage _storage = GetStorage();
  final RxString selectedLanguage = 'ar_SA'.obs;
  final RxBool isDarkMode = true.obs;
  final Rxn<UserProfile> accountProfile = Rxn<UserProfile>();
  final RxBool accountLoading = false.obs;
  final RxBool savingAccount = false.obs;
  late final AuthService? _auth;

  @override
  void onInit() {
    selectedLanguage.value = _storage.read<String>('language') ?? 'ar_SA';
    final savedTheme = ThemeModePreference.fromStorage(
      _storage.read<String>('themeMode'),
    );
    isDarkMode.value = savedTheme == ThemeMode.dark;
    _auth = Get.isRegistered<AuthService>() ? Get.find<AuthService>() : null;
    _loadAccount();
    super.onInit();
  }

  Future<void> _loadAccount() async {
    final auth = _auth;
    final user = auth?.currentUser;
    if (auth == null || user == null) return;
    accountLoading.value = true;
    try {
      accountProfile.value = await auth.loadProfile(user.uid);
    } finally {
      accountLoading.value = false;
    }
  }

  Future<void> refreshAccount() => _loadAccount();

  Future<void> updatePrivacy(UserPrivacy privacy) async {
    final auth = _auth;
    final current = accountProfile.value;
    if (auth == null || current == null) return;
    savingAccount.value = true;
    try {
      accountProfile.value = await auth.updateProfile(
        displayName: current.displayName,
        bio: current.bio,
        privacy: privacy,
      );
    } finally {
      savingAccount.value = false;
    }
  }

  Future<void> signOut() async {
    await _auth?.signOut();
    accountProfile.value = null;
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
    final mode = darkMode ? ThemeMode.dark : ThemeMode.light;
    Get.changeThemeMode(mode);
    isDarkMode.value = darkMode;
    await _storage.write('themeMode', ThemeModePreference.toStorage(mode));
  }
}
