import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/data/models/user_profile.dart';
import 'package:mangaplus/app/data/services/account_sync_service.dart';
import 'package:mangaplus/app/data/services/auth_service.dart';

class AuthController extends GetxController {
  final AuthService service = Get.find<AuthService>();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();
  final displayName = TextEditingController();
  final username = TextEditingController();
  final bio = TextEditingController();
  final isRegister = false.obs;
  final isBusy = false.obs;
  final obscurePassword = true.obs;
  final obscureConfirmPassword = true.obs;
  final selectedCountry = Rxn<ArabCountry>();
  final birthDate = Rxn<DateTime>();
  final profile = Rxn<UserProfile>();
  final emailVerificationRequired = false.obs;
  final verificationCooldown = 0.obs;
  final usernameAvailability = UsernameAvailability.idle.obs;
  Timer? _usernameDebounce;
  int _usernameRequest = 0;

  static const countries = <ArabCountry>[
    ArabCountry('DZ', 'الجزائر'), ArabCountry('BH', 'البحرين'),
    ArabCountry('KM', 'جزر القمر'), ArabCountry('DJ', 'جيبوتي'),
    ArabCountry('EG', 'مصر'), ArabCountry('IQ', 'العراق'),
    ArabCountry('JO', 'الأردن'), ArabCountry('KW', 'الكويت'),
    ArabCountry('LB', 'لبنان'), ArabCountry('LY', 'ليبيا'),
    ArabCountry('MR', 'موريتانيا'), ArabCountry('MA', 'المغرب'),
    ArabCountry('OM', 'عُمان'), ArabCountry('PS', 'فلسطين'),
    ArabCountry('QA', 'قطر'), ArabCountry('SA', 'السعودية'),
    ArabCountry('SO', 'الصومال'), ArabCountry('SD', 'السودان'),
    ArabCountry('SY', 'سوريا'), ArabCountry('TN', 'تونس'),
    ArabCountry('AE', 'الإمارات'), ArabCountry('YE', 'اليمن'),
  ];

  @override
  void onInit() {
    super.onInit();
    profile.value = Get.arguments is UserProfile ? Get.arguments as UserProfile : null;
    username.addListener(_onUsernameChanged);
  }

  @override
  void onClose() {
    for (final controller in [email, password, confirmPassword, displayName, username, bio]) {
      controller.dispose();
    }
    _usernameDebounce?.cancel();
    super.onClose();
  }

  void _onUsernameChanged() {
    if (!isRegister.value) {
      usernameAvailability.value = UsernameAvailability.idle;
      return;
    }
    _usernameDebounce?.cancel();
    final value = AuthService.normalizeUsername(username.text);
    if (value.isEmpty) {
      usernameAvailability.value = UsernameAvailability.idle;
      return;
    }
    try {
      AuthService.validateUsername(value);
    } catch (_) {
      usernameAvailability.value = UsernameAvailability.invalid;
      return;
    }
    usernameAvailability.value = UsernameAvailability.checking;
    final request = ++_usernameRequest;
    _usernameDebounce = Timer(const Duration(milliseconds: 450), () async {
      try {
        final available = await service.isUsernameAvailable(value);
        if (request == _usernameRequest && value == AuthService.normalizeUsername(username.text)) {
          usernameAvailability.value = available ? UsernameAvailability.available : UsernameAvailability.taken;
        }
      } catch (_) {
        if (request == _usernameRequest) usernameAvailability.value = UsernameAvailability.error;
      }
    });
  }

  void setRegisterMode(bool value) {
    isRegister.value = value;
    _onUsernameChanged();
  }

  Future<void> submit() async {
    if (isBusy.value) return;
    final valid = _validate();
    if (!valid) return;
    isBusy.value = true;
    try {
      if (isRegister.value) {
        final country = selectedCountry.value!;
        if (profile.value != null && service.currentUser?.providerData.any((provider) => provider.providerId == 'google.com') == true) {
          profile.value = await service.completeGoogleProfile(
            username: username.text,
            countryCode: country.code,
            countryName: country.name,
            birthDate: birthDate.value!,
          );
          Get.back(result: profile.value);
        } else {
          profile.value = await service.registerEmail(
            displayName: displayName.text,
            username: username.text,
            email: email.text,
            password: password.text,
            countryCode: country.code,
            countryName: country.name,
            birthDate: birthDate.value!,
          );
          emailVerificationRequired.value = true;
          _message('تم إنشاء الحساب', 'أرسلنا رسالة تحقق إلى بريدك الإلكتروني.');
        }
      } else {
        profile.value = await service.signInEmail(email.text, password.text);
        await AccountSyncService().syncLocalData();
        if (service.currentUser?.emailVerified != true && service.currentUser?.isAnonymous != true) {
          emailVerificationRequired.value = true;
        } else {
          Get.back(result: profile.value);
        }
      }
    } catch (error) {
      _message('تعذر تنفيذ العملية', _friendlyError(error));
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> signInGoogle() async {
    if (isBusy.value) return;
    isBusy.value = true;
    try {
      final result = await service.signInGoogle();
      if (result == null) return;
      if (result.username.isEmpty || result.countryCode.isEmpty) {
        profile.value = result;
        isRegister.value = true;
        displayName.text = result.displayName;
        _message('أكمل بياناتك', 'أضف اسم المستخدم والدولة وتاريخ الميلاد لإكمال الحساب.');
      } else {
        profile.value = result;
        await AccountSyncService().syncLocalData();
        Get.back(result: result);
      }
    } catch (error) {
      _message('تعذر تسجيل الدخول', _friendlyError(error));
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> continueAsGuest() async {
    if (isBusy.value) return;
    isBusy.value = true;
    try {
      profile.value = await service.continueAsGuest();
      Get.back(result: profile.value);
    } catch (error) {
      _message('تعذر بدء وضع الضيف', _friendlyError(error));
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> verifyEmail() async {
    if (isBusy.value) return;
    isBusy.value = true;
    try {
      final refreshed = await service.refreshProfile();
      if (service.currentUser?.emailVerified == true) {
        profile.value = refreshed;
        emailVerificationRequired.value = false;
        Get.back(result: refreshed);
      } else {
        _message('لم يتم التحقق بعد', 'افتح رسالة التحقق ثم اضغط هذا الزر مرة أخرى.');
      }
    } catch (error) {
      _message('تعذر التحقق', _friendlyError(error));
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> resendVerification() async {
    if (verificationCooldown.value > 0 || isBusy.value) return;
    try {
      await service.resendVerification();
      verificationCooldown.value = 60;
      _runCooldown();
      _message('تم الإرسال', 'تحقق من بريدك الإلكتروني.');
    } catch (error) {
      _message('تعذر الإرسال', _friendlyError(error));
    }
  }

  Future<void> resetPassword() async {
    if (email.text.trim().isEmpty || !GetUtils.isEmail(email.text.trim())) {
      _message('البريد الإلكتروني مطلوب', 'أدخل بريدك الإلكتروني أولًا.');
      return;
    }
    try {
      await service.sendPasswordReset(email.text);
      _message('تم إرسال الطلب', 'إذا كان البريد مسجلًا فستصلك رسالة الاستعادة.');
    } catch (_) {
      _message('تعذر إرسال الطلب', 'حاول مرة أخرى بعد قليل.');
    }
  }

  bool _validate() {
    final completingGoogle = isRegister.value &&
        profile.value != null &&
        service.currentUser?.providerData.any((provider) => provider.providerId == 'google.com') == true;
    if (completingGoogle) {
      try {
        AuthService.validateUsername(AuthService.normalizeUsername(username.text));
      } catch (error) {
        _message('اسم المستخدم غير صالح', '$error');
        return false;
      }
      if (!_usernameReady()) return false;
      if (selectedCountry.value == null || birthDate.value == null) {
        _message('بيانات الحساب ناقصة', 'اختر الدولة وتاريخ الميلاد.');
        return false;
      }
      return true;
    }
    if (!GetUtils.isEmail(email.text.trim())) {
      _message('تحقق من البريد', 'أدخل بريدًا إلكترونيًا صالحًا.');
      return false;
    }
    if (password.text.length < 8) {
      _message('كلمة المرور قصيرة', 'استخدم 8 أحرف على الأقل.');
      return false;
    }
    if (!isRegister.value) return true;
    if (displayName.text.trim().length < 2) {
      _message('الاسم مطلوب', 'أدخل اسمًا ظاهرًا من حرفين على الأقل.');
      return false;
    }
    try {
      AuthService.validateUsername(AuthService.normalizeUsername(username.text));
    } catch (error) {
      _message('اسم المستخدم غير صالح', '$error');
      return false;
    }
    if (!_usernameReady()) return false;
    if (password.text != confirmPassword.text) {
      _message('كلمتا المرور غير متطابقتين', 'أعد كتابة كلمة المرور نفسها.');
      return false;
    }
    if (selectedCountry.value == null || birthDate.value == null) {
      _message('بيانات الحساب ناقصة', 'اختر الدولة وتاريخ الميلاد.');
      return false;
    }
    if (birthDate.value!.isAfter(DateTime.now())) {
      _message('تاريخ غير صالح', 'لا يمكن اختيار تاريخ مستقبلي.');
      return false;
    }
    return true;
  }

  bool _usernameReady() {
    if (usernameAvailability.value == UsernameAvailability.available) return true;
    final message = usernameAvailability.value == UsernameAvailability.taken
        ? 'اسم المستخدم مأخوذ بالفعل.'
        : usernameAvailability.value == UsernameAvailability.checking
            ? 'انتظر انتهاء فحص اسم المستخدم.'
            : 'اكتب اسم مستخدم صالحًا وانتظر نتيجة الفحص.';
    _message('تحقق من اسم المستخدم', message);
    return false;
  }

  void _runCooldown() async {
    while (verificationCooldown.value > 0) {
      await Future<void>.delayed(const Duration(seconds: 1));
      verificationCooldown.value--;
    }
  }

  String _friendlyError(Object error) {
    if (error is AuthException) return error.message;
    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'email-already-in-use' => 'هذا البريد مستخدم بالفعل.',
        'invalid-credential' || 'wrong-password' || 'user-not-found' => 'بيانات الدخول غير صحيحة.',
        'network-request-failed' => 'تحقق من اتصال الإنترنت.',
        'weak-password' => 'كلمة المرور ضعيفة.',
        'operation-not-allowed' => 'طريقة التسجيل هذه غير مفعلة في Firebase Console.',
        'too-many-requests' => 'محاولات كثيرة. انتظر قليلًا ثم حاول مجددًا.',
        'user-disabled' => 'هذا الحساب معطل.',
        'popup-closed-by-user' || 'sign_in_canceled' => 'تم إلغاء تسجيل الدخول.',
        'account-exists-with-different-credential' => 'البريد مرتبط بطريقة تسجيل دخول أخرى.',
        _ => 'تعذر إكمال العملية. حاول مرة أخرى.',
      };
    }
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' => 'رفض Firebase العملية. تحقق من نشر قواعد Firestore.',
        'unavailable' || 'network-request-failed' => 'لا يوجد اتصال بالخدمة. تحقق من الإنترنت.',
        'failed-precondition' => 'خدمة Firebase غير مكتملة الإعداد لهذا المشروع.',
        _ => 'تعذر الاتصال بـ Firebase (${error.code}).',
      };
    }
    return 'تعذر إكمال العملية. حاول مرة أخرى.';
  }

  void _message(String title, String message) => Get.snackbar(
        title,
        message,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
}

class ArabCountry {
  const ArabCountry(this.code, this.name);
  final String code;
  final String name;
}
