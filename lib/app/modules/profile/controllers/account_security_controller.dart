import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/data/services/account_deletion_service.dart';
import 'package:mangaplus/app/data/services/auth_service.dart';

/// Drives every sensitive account action: e-mail confirmation and change,
/// password change and permanent deletion.
///
/// Each method returns `true` only when the underlying Firebase call completed;
/// failures are mapped to a readable message and surfaced through [lastError],
/// so the screen never reports success on its own.
class AccountSecurityController extends GetxController {
  late final AuthService _auth;
  late final AccountDeletionService _deletion;

  final RxBool busy = false.obs;
  final RxBool deleting = false.obs;
  final RxString deletionStage = ''.obs;
  final RxString lastError = ''.obs;
  final RxBool hasPendingDeletion = false.obs;
  final RxInt resendCooldown = 0.obs;

  Timer? _cooldownTimer;

  @override
  void onInit() {
    _auth = Get.isRegistered<AuthService>()
        ? Get.find<AuthService>()
        : Get.put(AuthService(), permanent: true);
    _deletion = AccountDeletionService(authService: _auth);
    hasPendingDeletion.value = _deletion.hasPendingDeletion;
    super.onInit();
  }

  @override
  void onClose() {
    _cooldownTimer?.cancel();
    super.onClose();
  }

  bool get canChangePassword => _auth.canReauthenticateWithPassword;
  bool get canUseGoogle => _auth.canReauthenticateWithGoogle;

  String? get currentEmail => _auth.currentUser?.email;
  bool get emailVerified => _auth.currentUser?.emailVerified ?? false;

  /// Sends the confirmation link for the current address.
  Future<bool> resendVerification() async {
    if (resendCooldown.value > 0) return false;
    busy.value = true;
    lastError.value = '';
    try {
      await _auth.resendVerification();
      _startCooldown(60);
      return true;
    } catch (error) {
      lastError.value = friendlyError(error);
      return false;
    } finally {
      busy.value = false;
    }
  }

  /// Sends a confirmation link to [newEmail]; the address only changes after the
  /// user opens it.
  Future<bool> requestEmailChange({
    required String newEmail,
    required String password,
  }) async {
    busy.value = true;
    lastError.value = '';
    try {
      await _auth.requestEmailChange(newEmail: newEmail, password: password);
      return true;
    } catch (error) {
      lastError.value = friendlyError(error);
      return false;
    } finally {
      busy.value = false;
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (newPassword.length < 8) {
      lastError.value = 'استخدم 8 أحرف على الأقل لكلمة المرور الجديدة.';
      return false;
    }
    busy.value = true;
    lastError.value = '';
    try {
      await _auth.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return true;
    } catch (error) {
      lastError.value = friendlyError(error);
      return false;
    } finally {
      busy.value = false;
    }
  }

  /// Reauthenticates, then permanently deletes the account.
  ///
  /// [password] is required for password accounts; Google accounts pass
  /// `useGoogle: true` and confirm with the Google sheet instead.
  Future<bool> deleteAccount({
    String? password,
    bool useGoogle = false,
  }) async {
    if (deleting.value) return false;
    deleting.value = true;
    lastError.value = '';
    deletionStage.value = 'جارٍ التحقق من الهوية…';
    try {
      if (useGoogle) {
        await _auth.reauthenticateWithGoogle();
      } else {
        await _auth.reauthenticateWithPassword(password ?? '');
      }
      await _deletion.deleteAccount(
        onStage: (stage) => deletionStage.value = _stageLabel(stage),
      );
      hasPendingDeletion.value = false;
      return true;
    } catch (error) {
      lastError.value = friendlyError(error);
      hasPendingDeletion.value = _deletion.hasPendingDeletion;
      return false;
    } finally {
      deleting.value = false;
    }
  }

  String _stageLabel(AccountDeletionStage stage) => switch (stage) {
        AccountDeletionStage.preparing => 'تجهيز الحذف…',
        AccountDeletionStage.data => 'حذف المكتبة وسجل القراءة…',
        AccountDeletionStage.profile => 'حذف بيانات الملف الشخصي…',
        AccountDeletionStage.username => 'تحرير اسم المستخدم…',
        AccountDeletionStage.account => 'حذف حساب الدخول…',
        AccountDeletionStage.local => 'تنظيف بيانات الجهاز…',
        AccountDeletionStage.done => 'تم الحذف.',
      };

  void _startCooldown(int seconds) {
    resendCooldown.value = seconds;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (resendCooldown.value <= 1) {
        resendCooldown.value = 0;
        timer.cancel();
      } else {
        resendCooldown.value--;
      }
    });
  }

  /// Turns Firebase and service errors into one Arabic sentence.
  static String friendlyError(Object error) {
    if (error is AccountDeletionException) return error.message;
    if (error is AuthException) return error.message;
    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'wrong-password' || 'invalid-credential' => 'كلمة المرور غير صحيحة.',
        'requires-recent-login' => 'سجّل الدخول مجددًا ثم حاول مرة أخرى.',
        'email-already-in-use' => 'هذا البريد مستخدم في حساب آخر.',
        'invalid-email' => 'أدخل بريدًا إلكترونيًا صالحًا.',
        'weak-password' => 'كلمة المرور ضعيفة.',
        'too-many-requests' => 'محاولات كثيرة. انتظر قليلًا ثم حاول مجددًا.',
        'network-request-failed' => 'تحقق من اتصال الإنترنت.',
        'user-mismatch' || 'user-disabled' => 'تعذر إكمال العملية لهذا الحساب.',
        _ => 'تعذر إكمال العملية. حاول مرة أخرى.',
      };
    }
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' => 'رفض Firebase العملية. حاول لاحقًا أو تواصل مع الدعم.',
        'unavailable' => 'تعذر الوصول إلى الخادم. تحقق من الاتصال.',
        'not-found' => 'لم تعد البيانات موجودة.',
        _ => 'تعذر إكمال العملية. حاول مرة أخرى.',
      };
    }
    return 'تعذر إكمال العملية. حاول مرة أخرى.';
  }
}
