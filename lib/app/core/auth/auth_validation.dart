/// Pure validation used by the authentication form and its tests.
///
/// Firebase remains the authority: these checks only prevent an obviously
/// invalid request from being sent and give the user a useful message.
class AuthValidation {
  const AuthValidation._();

  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? emailError(String value) {
    final email = value.trim();
    if (email.isEmpty) return 'أدخل البريد الإلكتروني.';
    if (!_email.hasMatch(email)) return 'أدخل بريدًا إلكترونيًا صالحًا.';
    return null;
  }

  static String? passwordError(String value) {
    if (value.isEmpty) return 'أدخل كلمة المرور.';
    if (value.length < 8) return 'استخدم 8 أحرف على الأقل.';
    final hasLetter = RegExp(r'[A-Za-zء-ي]').hasMatch(value);
    final hasDigit = RegExp(r'\d').hasMatch(value);
    if (!hasLetter || !hasDigit) {
      return 'أضف حرفًا ورقمًا على الأقل.';
    }
    return null;
  }

  static String? confirmError(String password, String confirmation) {
    if (confirmation.isEmpty) return 'أكّد كلمة المرور.';
    if (password != confirmation) return 'كلمتا المرور غير متطابقتين.';
    return null;
  }

  /// 0 = weak, 1 = medium, 2 = strong. Only used for visual feedback.
  static int passwordStrength(String value) {
    var score = 0;
    if (value.length >= 8) score++;
    if (value.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(value) &&
        RegExp(r'[a-z]').hasMatch(value)) {
      score++;
    }
    if (RegExp(r'\d').hasMatch(value)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(value)) score++;
    if (score <= 2) return 0;
    if (score <= 3) return 1;
    return 2;
  }

  static String strengthLabel(int strength) => switch (strength) {
        0 => 'ضعيفة',
        1 => 'متوسطة',
        _ => 'قوية',
      };
}
