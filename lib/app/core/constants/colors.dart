import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AppColors {
  static final ValueNotifier<int> _themeRevision = ValueNotifier<int>(0);
  static ValueListenable<int> get themeRevision => _themeRevision;
  static bool? _darkModeOverride;

  static bool get _isDark => _darkModeOverride ?? Get.isDarkMode;

  static void refreshTheme(bool darkMode) {
    _darkModeOverride = darkMode;
    _themeRevision.value++;
  }

  static const Color _darkBackground = Color(0xff111317);
  static const Color _darkSearchBar = Color(0xff1a1d22);
  static const Color _darkCard = Color(0xff202329);
  static const Color _lightBackground = Color(0xfff5f5f6);
  static const Color _lightSearchBar = Color(0xffebeced);
  static const Color _lightCard = Color(0xffffffff);

  static Color get background => _isDark ? _darkBackground : _lightBackground;
  static Color get searchBar => _isDark ? _darkSearchBar : _lightSearchBar;
  static Color get card => _isDark ? _darkCard : _lightCard;
  static Color get primary => _isDark ? const Color(0xff78a7ed) : const Color(0xff386fbe);
  static Color get accent => _isDark ? const Color(0xff91b8f0) : const Color(0xff5d8dd0);
  static Color get textPrimary =>
      _isDark ? const Color(0xfff0f1f3) : const Color(0xff24262a);
  static Color get textSecondary =>
      _isDark ? const Color(0xffa7abb4) : const Color(0xff686c74);
  static Color get divider =>
      _isDark ? const Color(0xff30333a) : const Color(0xffd9dadd);
  static Color get icon =>
      _isDark ? const Color(0xffb3b7c0) : const Color(0xff666a72);

  static const Color success = Color(0xff4caf75);
  static const Color warning = Color(0xffffc107);
  static const Color error = Color(0xfff44336);
  static const Color info = Color(0xff5d8dd0);
}
