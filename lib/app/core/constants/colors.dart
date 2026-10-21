import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AppColors {
  static bool get _isDark => Get.isDarkMode;

  static const Color _darkBackground = Color(0xff111a28);
  static const Color _darkSearchBar = Color(0xff1a2636);
  static const Color _darkCard = Color(0xff1d2b3d);
  static const Color _lightBackground = Color(0xfff8fafd);
  static const Color _lightSearchBar = Color(0xffedf3fa);
  static const Color _lightCard = Color(0xffffffff);

  static Color get background => _isDark ? _darkBackground : _lightBackground;
  static Color get searchBar => _isDark ? _darkSearchBar : _lightSearchBar;
  static Color get card => _isDark ? _darkCard : _lightCard;
  static Color get primary => const Color(0xff3e73b5);
  static Color get accent => const Color(0xff6a9bd2);
  static Color get textPrimary =>
      _isDark ? const Color(0xfff2f6fa) : const Color(0xff1e2a39);
  static Color get textSecondary =>
      _isDark ? const Color(0xffaec0d8) : const Color(0xff687b91);
  static Color get divider =>
      _isDark ? const Color(0xff33465e) : const Color(0xffd6e2ef);
  static Color get icon =>
      _isDark ? const Color(0xff9fb9d8) : const Color(0xff527eaf);

  static const Color success = Color(0xff4caf75);
  static const Color warning = Color(0xffffc107);
  static const Color error = Color(0xfff44336);
  static const Color info = Color(0xff6a9bd2);
}
