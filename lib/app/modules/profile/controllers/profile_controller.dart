import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mangaplus/app/core/theme/theme_mode_preference.dart';
import 'package:mangaplus/app/data/models/user_profile.dart';
import 'package:mangaplus/app/data/services/account_sync_service.dart';
import 'package:mangaplus/app/data/services/auth_service.dart';
import 'package:mangaplus/app/data/services/notification_presentation.dart';
import 'package:mangaplus/app/routes/app_pages.dart';

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
    final savedTheme = ThemeModePreference.fromStorage(_storage.read<String>('themeMode'));
    isDarkMode.value = savedTheme == ThemeMode.dark;
    Get.changeThemeMode(savedTheme);
    _auth = Get.isRegistered<AuthService>() ? Get.find<AuthService>() : null;
    _loadAccount();
    super.onInit();
  }

  Future<void> _loadAccount() async {
    final auth = _auth;
    final user = auth?.currentUser;
    if (auth == null || user == null) { accountProfile.value = null; return; }
    accountLoading.value = true;
    try {
      accountProfile.value = await auth.loadProfile(user.uid);
      if (accountProfile.value != null && !user.isAnonymous) {
        final settings = await auth.loadSettings();
        final language = settings['language'];
        final theme = settings['themeMode'];
        if (language == 'ar_SA' || language == 'en_US') {
          selectedLanguage.value = language as String;
          Get.updateLocale(language == 'en_US' ? const Locale('en', 'US') : const Locale('ar', 'SA'));
          await _storage.write('language', language);
        }
        if (theme == 'dark' || theme == 'light') {
          isDarkMode.value = theme == 'dark';
          Get.changeThemeMode(theme == 'dark' ? ThemeMode.dark : ThemeMode.light);
          await _storage.write('themeMode', theme);
        }
      }
    } catch (error) {
      _message('تعذر تحميل الحساب'.tr, error.toString());
    } finally {
      accountLoading.value = false;
    }
  }

  Future<void> refreshAccount() => _loadAccount();
  Future<void> openAuth() async { await Get.toNamed(Routes.AUTH); await refreshAccount(); }

  Future<void> changeAvatar() async {
    final auth = _auth;
    final user = auth?.currentUser;
    if (auth == null || user == null || user.isAnonymous) {
      _message('تعذر تغيير الصورة'.tr, 'يجب تسجيل الدخول بحساب دائم لتعديل الصورة.'.tr);
      return;
    }
    try {
      final selected = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1200);
      if (selected == null) return;
      savingAccount.value = true;
      final ref = FirebaseStorage.instance.ref('userProfiles/${user.uid}/avatar');
      await ref.putFile(File(selected.path), SettableMetadata(contentType: _contentType(selected.name)));
      final url = await ref.getDownloadURL();
      accountProfile.value = await auth.updatePhotoUrl(url);
      _message('تم تحديث الصورة'.tr, 'تم حفظ صورة الملف الشخصي'.tr);
    } catch (error) {
      _message('تعذر رفع الصورة'.tr, error.toString());
    } finally { savingAccount.value = false; }
  }

  Future<void> updateDisplayName(String value) async {
    final auth = _auth;
    if (auth == null) return;
    savingAccount.value = true;
    try {
      accountProfile.value = await auth.updateDisplayName(value);
      _message('تم حفظ التغييرات'.tr, 'تم تحديث الاسم الظاهر'.tr);
    } catch (error) {
      _message('تعذر حفظ الإعداد'.tr, error.toString());
    } finally { savingAccount.value = false; }
  }

  String _contentType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> setFavoritesSync(bool enabled) async {
    final auth = _auth;
    final current = accountProfile.value;
    if (auth == null || current == null) return;
    savingAccount.value = true;
    try {
      accountProfile.value = await auth.setFavoritesSync(enabled);
      if (enabled) await AccountSyncService().syncLocalData(force: true);
      _message(enabled ? 'تم تشغيل المزامنة'.tr : 'تم إيقاف المزامنة'.tr,
          enabled ? 'ستتم مزامنة المفضلة وسجل القراءة مع حسابك'.tr : 'ستبقى بياناتك المحلية على هذا الجهاز'.tr);
    } catch (error) {
      _message('تعذر حفظ الإعداد'.tr, error.toString());
    } finally { savingAccount.value = false; }
  }

  Future<void> changePassword(String oldPassword, String newPassword) async {
    final auth = _auth;
    if (auth == null) return;
    savingAccount.value = true;
    try {
      await auth.changePassword(currentPassword: oldPassword, newPassword: newPassword);
      _message('تم تغيير كلمة المرور'.tr, 'تم تحديث كلمة مرور حسابك بنجاح'.tr);
    } catch (error) {
      _message('تعذر تغيير كلمة المرور'.tr, _authError(error));
    } finally { savingAccount.value = false; }
  }

  String _authError(Object error) {
    final value = error.toString();
    if (value.contains('wrong-password') || value.contains('invalid-credential')) return 'كلمة المرور الحالية غير صحيحة'.tr;
    if (value.contains('requires-recent-login')) return 'سجّل الدخول مجددًا ثم حاول مرة أخرى'.tr;
    if (value.contains('AuthException')) return value.replaceFirst('AuthException: ', '');
    return value;
  }

  Future<void> signOut() async {
    try { await _auth?.signOut(); accountProfile.value = null; }
    catch (error) { _message('تعذر تسجيل الخروج'.tr, error.toString()); }
  }

  Future<void> changeLanguage(String languageCode) async {
    if (languageCode != 'ar_SA' && languageCode != 'en_US') return;
    selectedLanguage.value = languageCode;
    Get.updateLocale(languageCode == 'en_US' ? const Locale('en', 'US') : const Locale('ar', 'SA'));
    await _storage.write('language', languageCode);
    try {
      await _auth?.saveSettings(language: languageCode, themeMode: isDarkMode.value ? 'dark' : 'light');
    } catch (error) {
      _message('تعذر حفظ الإعداد'.tr, error.toString());
    }
    try { await NotificationPresentation.updateLanguage(languageCode); } catch (_) {}
  }

  Future<void> changeTheme(bool darkMode) async {
    final mode = darkMode ? ThemeMode.dark : ThemeMode.light;
    await _storage.write('themeMode', ThemeModePreference.toStorage(mode));
    isDarkMode.value = darkMode;
    Get.changeThemeMode(mode);
    try {
      await _auth?.saveSettings(language: selectedLanguage.value, themeMode: darkMode ? 'dark' : 'light');
    } catch (error) {
      _message('تعذر حفظ الإعداد'.tr, error.toString());
    }
  }

  void _message(String title, String message) => Get.snackbar(title, message,
      snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(14));
}
