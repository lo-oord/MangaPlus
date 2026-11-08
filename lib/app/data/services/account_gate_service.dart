import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/data/services/auth_service.dart';
import 'package:mangaplus/app/routes/app_pages.dart';

class AccountGateService {
  /// Returns true only when a real, verified account is available right now.
  ///
  /// Offline state never causes a session to be treated as gone. If Firebase
  /// Auth still has a cached user, we keep using it; when a reload fails while
  /// offline, we continue with the last known state instead of forcing the user
  /// back to the login screen.
  Future<bool> requireAccount({String feature = 'المفضلة'}) async {
    final auth = Get.isRegistered<AuthService>()
        ? Get.find<AuthService>()
        : Get.put<AuthService>(AuthService(), permanent: true);
    final user = auth.currentUser;

    if (user == null) {
      await _maybeOpenAuthDialog(feature);
      return false;
    }

    if (user.isAnonymous) {
      await _maybeOpenAuthDialog(feature);
      return false;
    }

    // Try a fresh reload so recently-verified accounts can unlock features.
    final canProceed = await _tryRefreshVerified(user, auth);
    if (canProceed) return true;

    // If we are offline, keep the existing session instead of treating it as
    // expired. Drop to the login screen only when there is genuinely no account
    // state left to display.
    final offline = await _isOffline();
    if (offline) return false;

    if (user.emailVerified) {
      // Still verified but something else blocked the reload; retry once.
      await _tryRefreshVerified(user, auth);
      return user.emailVerified;
    }

    Get.snackbar(
      'تحقق من بريدك الإلكتروني'.tr,
      'يجب تأكيد البريد قبل استخدام هذه الميزة.'.tr,
      snackPosition: SnackPosition.BOTTOM,
    );
    return false;
  }

  Future<bool> _tryRefreshVerified(User user, AuthService auth) async {
    try {
      final wasVerified = user.emailVerified;
      await user.reload();
      final refreshed = auth.currentUser;
      if (refreshed == null || refreshed.uid != user.uid) return false;
      if (!wasVerified && refreshed.emailVerified) {
        await refreshed.getIdToken(true);
      }
      return refreshed.emailVerified;
    } catch (_) {
      // Keep the existing session during transient failures.
      return user.emailVerified;
    }
  }

  Future<bool> _isOffline() async {
    try {
      final results = await connectivity.checkConnectivity();
      return results.every((result) => result == ConnectivityResult.none);
    } catch (_) {
      // Unknown connectivity: treat as possibly offline and preserve state.
      return true;
    }
  }

  Future<void> _maybeOpenAuthDialog(String feature) async {
    final shouldOpen = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('سجّل الدخول أولًا'),
        content: Text(
          'تحتاج إلى إنشاء حساب أو تسجيل الدخول '
          'للاستخدام $feature ومزامنته بين أجهزتك.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('ليس الآن'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: const Text('التسجيل / تسجيل الدخول'),
          ),
        ],
      ),
      barrierDismissible: true,
    );
    if (shouldOpen != true) return;
    await Get.toNamed(Routes.AUTH);
  }

  Future<bool> get isOffline async {
    try {
      final results = await connectivity.checkConnectivity();
      return results.every((result) => result == ConnectivityResult.none);
    } catch (_) {
      return true;
    }
  }

  @override
  String toString() => 'AccountGateService';

  final connectivity = Connectivity();
}
