import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/data/services/auth_service.dart';
import 'package:mangaplus/app/routes/app_pages.dart';

class AccountGateService {
  Future<bool> requireAccount({String feature = 'المفضلة'}) async {
    final auth = Get.isRegistered<AuthService>()
        ? Get.find<AuthService>()
        : Get.put<AuthService>(AuthService(), permanent: true);
    var activeUser = auth.currentUser;
    if (activeUser != null && !activeUser.isAnonymous) {
      try {
        final wasVerified = activeUser.emailVerified;
        await activeUser.reload();
        activeUser = auth.currentUser;
        if (!wasVerified && activeUser?.emailVerified == true) {
          await activeUser!.getIdToken(true);
        }
      } catch (_) {
        // Keep the cached state; Firebase rules remain authoritative offline.
      }
    }
    if (activeUser != null &&
        !activeUser.isAnonymous &&
        activeUser.emailVerified) {
      return true;
    }

    if (activeUser != null &&
        !activeUser.isAnonymous &&
        !activeUser.emailVerified) {
      Get.snackbar(
        'تحقق من بريدك الإلكتروني'.tr,
        'يجب تأكيد البريد قبل استخدام هذه الميزة.'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    final shouldOpen = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('سجّل الدخول أولًا'),
        content: Text('تحتاج إلى إنشاء حساب أو تسجيل الدخول لاستخدام $feature ومزامنته بين أجهزتك.'),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('ليس الآن')),
          FilledButton(onPressed: () => Get.back(result: true), child: const Text('التسجيل / تسجيل الدخول')),
        ],
      ),
      barrierDismissible: true,
    );
    if (shouldOpen != true) return false;
    await Get.toNamed(Routes.AUTH);
    final refreshed = auth.currentUser;
    return refreshed != null &&
        !refreshed.isAnonymous &&
        refreshed.emailVerified;
  }
}
