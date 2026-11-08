import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/core/theme/theme_mode_preference.dart';
import 'package:mangaplus/app/data/models/user_profile.dart';
import 'package:mangaplus/app/data/services/account_sync_service.dart';
import 'package:mangaplus/app/data/services/bookmark_state_service.dart';
import 'package:mangaplus/app/data/services/auth_service.dart';
import 'package:mangaplus/app/data/services/notification_presentation.dart';
import 'package:mangaplus/app/data/services/chapter_update_service.dart';
import 'package:mangaplus/app/modules/history/controllers/history_controller.dart';
import 'package:mangaplus/app/routes/app_pages.dart';

/// Sole local copy of the last known signed-in profile.
///
/// This is intentionally small and opinionated: it is a resilient read cache,
/// not a second authority. Firebase Auth / Firestore remain the only source of
/// truth for authentication and profile edits. This local copy exists only so
/// the app can still show a recognisable account while offline and so an open
/// session is never cleared just because Firestore happened to be unreachable.
const String _localAccountKey = 'localAccount';

UserProfile? _decodeLocalAccount(dynamic value) {
  if (value == null) return null;
  final map = value is Map<String, dynamic> ? value : <String, dynamic>{};
  final uid = map['uid'];
  if (uid is! String || uid.isEmpty) return null;
  final createdAt = map['createdAt'];
  if (createdAt == null) return null;
  return UserProfile(
    uid: uid,
    email: map['email'] as String? ?? '',
    displayName: map['displayName'] as String? ?? '',
    username: map['username'] as String? ?? '',
    countryCode: map['countryCode'] as String? ?? '',
    countryName: map['countryName'] as String? ?? '',
    createdAt: _parseLocalDate(createdAt),
    birthDate: map['birthDate'] as DateTime?,
    gender: map['gender'] as String? ?? '',
    bio: map['bio'] as String? ?? '',
    photoUrl: map['photoUrl'] as String? ?? '',
    photoData: map['photoData'] as String? ?? '',
    isGuest: map['isGuest'] == true,
    emailVerified: map['emailVerified'] == true,
    isVerified: map['isVerified'] == true,
    isOfficialDeveloper: map['isOfficialDeveloper'] == true,
    syncFavorites: map['syncFavorites'] != false,
    privacy: UserPrivacy.fromMap(map['privacy']),
  );
}

Map<String, dynamic>? _encodeLocalAccount(UserProfile account) {
  return {
    'uid': account.uid,
    'email': account.email,
    'displayName': account.displayName,
    'username': account.username,
    'countryCode': account.countryCode,
    'countryName': account.countryName,
    'createdAt': account.createdAt.toIso8601String(),
    if (account.birthDate != null) 'birthDate': account.birthDate!.toIso8601String(),
    'gender': account.gender,
    'bio': account.bio,
    'photoUrl': account.photoUrl,
    'photoData': account.photoData,
    'isGuest': account.isGuest,
    'emailVerified': account.emailVerified,
    'isVerified': account.isVerified,
    'isOfficialDeveloper': account.isOfficialDeveloper,
    'syncFavorites': account.syncFavorites,
    'privacy': account.privacy.toMap(),
  };
}

DateTime _parseLocalDate(dynamic value) {
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return DateTime.tryParse('$value') ?? DateTime.now();
}

class ProfileController extends GetxController {
  final GetStorage _storage = GetStorage();
  final RxString selectedLanguage = 'ar_SA'.obs;
  final RxBool isDarkMode = true.obs;
  final Rxn<UserProfile> accountProfile = Rxn<UserProfile>();
  final RxBool accountLoading = false.obs;
  final RxBool savingAccount = false.obs;
  final RxBool favoritesNotificationsEnabled = false.obs;
  final RxBool mangaNotificationsEnabled = true.obs;
  final RxBool novelNotificationsEnabled = true.obs;
  final RxBool recentOfflineAuthAction = false.obs;
  int _themeRevision = 0;
  late final AuthService? _auth;
  StreamSubscription<User?>? _authStateSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  bool get canChangePassword {
    final user = _auth?.currentUser;
    return user != null &&
        !user.isAnonymous &&
        user.providerData.any((provider) => provider.providerId == 'password');
  }

  @override
  void onInit() {
    selectedLanguage.value = _storage.read<String>('language') ?? 'ar_SA';
    final savedTheme = ThemeModePreference.fromStorage(_storage.read<String>('themeMode'));
    isDarkMode.value = savedTheme == ThemeMode.dark;
    _auth = Get.isRegistered<AuthService>() ? Get.find<AuthService>() : null;
    final chapterService = Get.find<ChapterUpdateService>();
    favoritesNotificationsEnabled.value = chapterService.backgroundEnabled;
    mangaNotificationsEnabled.value = chapterService.mangaNotificationsEnabled;
    novelNotificationsEnabled.value = chapterService.novelNotificationsEnabled;

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _onConnectivityChanged,
      onError: (_) => null,
    );

    final currentUser = _auth?.currentUser;
    if (currentUser == null) {
      accountProfile.value = null;
      accountLoading.value = false;
    } else if (currentUser.isAnonymous) {
      unawaited(_loadAccount());
    } else {
      unawaited(_loadAccount());
    }

    _authStateSubscription = _auth?.authStateChanges.listen(_onAuthStateChanged);
    super.onInit();
  }

  Future<void> _onAuthStateChanged(User? user) async {
    if (user == null) {
      _clearCachedAuthState();
      accountProfile.value = null;
      accountLoading.value = false;
      return;
    }

    if (user.isAnonymous) {
      unawaited(_loadAccount());
      return;
    }

    if (accountProfile.value == null) {
      unawaited(_loadAccount(allowOfflineFallback: true));
      return;
    }

    final current = _auth?.currentUser;
    if (current != null &&
        current.uid == user.uid &&
        !current.isAnonymous) {
      try {
        await current.reload();
        unawaited(_loadAccount(allowOfflineFallback: true));
        return;
      } catch (_) {
        // Keep existing profile and retry later.
      }
    }

    unawaited(_loadAccount(allowOfflineFallback: true));
  }

  Future<void> _clearCachedAuthState() async {
    try {
      await _storage.remove(_localAccountKey);
    } catch (_) {
      // Best-effort cleanup; profile rendering does not depend on this.
    }
  }

  Future<void> _loadAccount({bool allowOfflineFallback = false}) async {
    final themeRevisionAtStart = _themeRevision;
    final auth = _auth;
    final user = auth?.currentUser;

    if (auth == null || user == null) {
      accountProfile.value = null;
      accountLoading.value = false;
      return;
    }

    if (user.isAnonymous) {
      try {
        final profile = await auth
            .loadProfile(user.uid)
            .timeout(const Duration(seconds: 15));
        if (auth.currentUser?.uid == user.uid) {
          accountProfile.value = profile;
          await _saveLocalAccount(profile);
        }
      } catch (_) {
        // Guest profile may not exist remotely yet; keep existing UI state.
      }
      accountLoading.value = false;
      return;
    }

    accountLoading.value = true;
    UserProfile? loadedProfile;
    try {
      loadedProfile = await auth
          .loadProfile(user.uid)
          .timeout(const Duration(seconds: 15));
      if (auth.currentUser?.uid == user.uid) {
        accountProfile.value = loadedProfile;
        await _saveLocalAccount(loadedProfile);
      }
    } catch (error) {
      _message('تعذر تحميل الحساب'.tr, error.toString());
    } finally {
      accountLoading.value = false;
    }

    if (loadedProfile == null &&
        allowOfflineFallback &&
        auth.currentUser?.uid == user.uid &&
        !user.isAnonymous) {
      final cached = _readLocalAccount();
      if (cached != null && cached.uid == user.uid) {
        accountProfile.value = cached;
      }
    }

    if (loadedProfile != null &&
        !user.isAnonymous &&
        auth.currentUser?.uid == user.uid) {
      unawaited(_loadSettingsAndSync(auth, user.uid, themeRevisionAtStart));
    }
  }

  UserProfile? _readLocalAccount() {
    try {
      return _decodeLocalAccount(_storage.read(_localAccountKey));
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveLocalAccount(UserProfile? account) async {
    try {
      if (account == null) {
        await _storage.remove(_localAccountKey);
        return;
      }
      await _storage.write(_localAccountKey, _encodeLocalAccount(account));
    } catch (_) {
      // Local profile cache is best-effort; the app remains usable.
    }
  }

  Future<void> _loadSettingsAndSync(
    AuthService auth,
    String uid,
    int themeRevisionAtStart,
  ) async {
    try {
      final settings = await auth
          .loadSettings()
          .timeout(const Duration(seconds: 10));
      if (auth.currentUser?.uid != uid) return;
      final language = settings['language'];
      final theme = settings['themeMode'];
      if (language == 'ar_SA' || language == 'en_US') {
        selectedLanguage.value = language as String;
        Get.updateLocale(
          language == 'en_US' ? const Locale('en', 'US') : const Locale('ar', 'SA'),
        );
        await _storage.write('language', language);
      }
      if ((theme == 'dark' || theme == 'light') &&
          _themeRevision == themeRevisionAtStart) {
        isDarkMode.value = theme == 'dark';
        Get.changeThemeMode(theme == 'dark' ? ThemeMode.dark : ThemeMode.light);
        AppColors.refreshTheme(theme == 'dark');
        await _storage.write('themeMode', theme);
      }
    } catch (_) {
      // Profile display must not depend on optional remote settings.
    }

    if (auth.currentUser?.uid != uid) return;
    try {
      await AccountSyncService()
          .syncLocalData()
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      // Keep account rendering independent from background library sync.
    }
  }

  Future<void> refreshAccount() async {
    await _loadAccount(allowOfflineFallback: true);
  }

  Future<void> setFavoritesNotifications(bool value) async {
    favoritesNotificationsEnabled.value = value;
    final service = Get.find<ChapterUpdateService>();
    await service.setBackgroundEnabled(value);
    if (value && await service.isBatteryOptimizationIgnored() == false) {
      await service.requestBatteryOptimizationExemption();
    }
  }

  Future<void> setMangaNotifications(bool value) async {
    mangaNotificationsEnabled.value = value;
    await Get.find<ChapterUpdateService>().setMangaNotificationsEnabled(value);
  }

  Future<void> setNovelNotifications(bool value) async {
    novelNotificationsEnabled.value = value;
    await Get.find<ChapterUpdateService>().setNovelNotificationsEnabled(value);
  }

  Future<void> openAuth() async { await Get.toNamed(Routes.AUTH); await refreshAccount(); }

  Future<void> changeAvatar() async {
    final auth = _auth;
    final user = auth?.currentUser;
    if (auth == null || user == null || user.isAnonymous) {
      _message('تعذر تغيير الصورة'.tr, 'يجب تسجيل الدخول بحساب دائم لتعديل الصورة.'.tr);
      return;
    }
    try {
      final selected = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 55,
        maxWidth: 512,
        maxHeight: 512,
      );
      if (selected == null) return;
      savingAccount.value = true;
      final bytes = await selected.readAsBytes();
      if (bytes.isEmpty || bytes.length > 600 * 1024) {
        throw Exception('الصورة أكبر من الحد المسموح. اختر صورة أصغر.');
      }
      final photoData = base64Encode(bytes);
      final updated = await auth.updatePhotoData(photoData);
      accountProfile.value = updated;
      unawaited(_saveLocalAccount(updated));
      _message('تم تحديث الصورة'.tr, 'تم حفظ صورة الملف الشخصي'.tr);
    } catch (error) {
      _message('تعذر حفظ الصورة'.tr, error.toString());
    } finally {
      savingAccount.value = false;
    }
  }

  Future<void> updateDisplayName(String value) async {
    final auth = _auth;
    if (auth == null) return;
    savingAccount.value = true;
    try {
      final updated = await auth.updateDisplayName(value);
      accountProfile.value = updated;
      unawaited(_saveLocalAccount(updated));
      _message('تم حفظ التغييرات'.tr, 'تم تحديث الاسم الظاهر'.tr);
    } catch (error) {
      _message('تعذر حفظ الإعداد'.tr, error.toString());
    } finally {
      savingAccount.value = false;
    }
  }

  Future<void> updateBio(String value) async {
    final auth = _auth;
    if (auth == null) return;
    savingAccount.value = true;
    try {
      final updated = await auth.updateBio(value);
      accountProfile.value = updated;
      unawaited(_saveLocalAccount(updated));
      _message('تم حفظ التغييرات'.tr, 'تم تحديث النبذة'.tr);
    } catch (error) {
      _message('تعذر حفظ الإعداد'.tr, error.toString());
    } finally {
      savingAccount.value = false;
    }
  }


  Future<void> setFavoritesSync(bool enabled) async {
    final auth = _auth;
    final current = accountProfile.value;
    if (auth == null || current == null) return;
    savingAccount.value = true;
    try {
      final updated = await auth.setFavoritesSync(enabled);
      accountProfile.value = updated;
      unawaited(_saveLocalAccount(updated));
      if (enabled) {
        await AccountSyncService().syncLocalData(force: true);
      }
      _message(
        enabled ? 'تم تشغيل المزامنة'.tr : 'تم إيقاف المزامنة'.tr,
        enabled
            ? 'ستتم مزامنة المفضلة وسجل القراءة مع حسابك'.tr
            : 'ستبقى بياناتك المحلية على هذا الجهاز'.tr,
      );
    } catch (error) {
      _message('تعذر حفظ الإعداد'.tr, error.toString());
    } finally {
      savingAccount.value = false;
    }
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
    try {
      final hadAccount = _auth?.currentUser != null;
      // Never make logout depend on Firestore/network availability.
      await _auth?.signOut();
      if (hadAccount) {
        await _storage.write('bookmarks', <String, dynamic>{});
        await _storage.write('reading_history', <String, dynamic>{});
        await _storage.write('readChapters', <String, dynamic>{});
        BookmarkStateService.instance.changed();
        if (Get.isRegistered<HistoryController>()) {
          await Get.find<HistoryController>().getHistory();
        }
      }
      accountProfile.value = null;
    }
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
    _themeRevision++;
    final mode = darkMode ? ThemeMode.dark : ThemeMode.light;
    isDarkMode.value = darkMode;
    Get.changeThemeMode(mode);
    AppColors.refreshTheme(darkMode);
    try {
      await _storage.write('themeMode', ThemeModePreference.toStorage(mode));
    } catch (error) {
      _message('تعذر حفظ الإعداد'.tr, error.toString());
    }
    try {
      await _auth?.saveSettings(language: selectedLanguage.value, themeMode: darkMode ? 'dark' : 'light');
    } catch (error) {
      _message('تعذر حفظ الإعداد'.tr, error.toString());
    }
  }

  @override
  void onClose() {
    unawaited(_authStateSubscription?.cancel() ?? Future<void>.value());
    unawaited(_connectivitySubscription?.cancel() ?? Future<void>.value());
    super.onClose();
  }

  Future<void> _onConnectivityChanged(List<ConnectivityResult> results) async {
    if (results.any((result) => result != ConnectivityResult.none)) {
      if (recentOfflineAuthAction.value) {
        recentOfflineAuthAction.value = false;
        await _loadAccount(allowOfflineFallback: true);
      }
    }
  }

  void _message(String title, String message) => Get.snackbar(title, message,
      snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(14));
}
