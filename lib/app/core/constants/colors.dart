import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AppColors {
  static bool get _isDark => Get.isDarkMode;

  static const Color _darkBackground = Color(0xff171b20);
  static const Color _darkSearchBar = Color(0xff252c33);
  static const Color _darkCard = Color(0xff20262d);
  static const Color _lightBackground = Color(0xfff7f7f5);
  static const Color _lightSearchBar = Color(0xffeceeec);
  static const Color _lightCard = Color(0xffffffff);

  static Color get background => _isDark ? _darkBackground : _lightBackground;
  static Color get searchBar => _isDark ? _darkSearchBar : _lightSearchBar;
  static Color get card => _isDark ? _darkCard : _lightCard;
  static Color get primary => const Color(0xff55758c);
  static Color get accent => const Color(0xff7895a5);
  static Color get textPrimary =>
      _isDark ? const Color(0xfff2f6fa) : const Color(0xff20262b);
  static Color get textSecondary =>
      _isDark ? const Color(0xffb5c5d4) : const Color(0xff68757d);
  static Color get divider =>
      _isDark ? const Color(0xff39434b) : const Color(0xffd4e1ec);
  static Color get icon =>
      _isDark ? const Color(0xffaab6bc) : const Color(0xff4d718e);

  static const Color success = Color(0xff4caf75);
  static const Color warning = Color(0xffffc107);
  static const Color error = Color(0xfff44336);
  static const Color info = Color(0xff7895a5);
}
