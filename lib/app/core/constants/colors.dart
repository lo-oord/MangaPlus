import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/theme/app_palette.dart';

/// Backwards-compatible colour facade over [AppPalette].
///
/// Hundreds of widgets already read `AppColors.x`. Instead of keeping a second
/// palette alive next to the theme, every getter here resolves the palette of
/// the active brightness, so a value can never disagree with `ThemeData`.
/// New code should prefer `context.palette` (or `AppColors.of(context)`).
class AppColors {
  const AppColors._();

  static final ValueNotifier<int> _themeRevision = ValueNotifier<int>(0);
  static ValueListenable<int> get themeRevision => _themeRevision;
  static bool? _darkModeOverride;

  static bool get _isDark => _darkModeOverride ?? Get.isDarkMode;

  static void refreshTheme(bool darkMode) {
    _darkModeOverride = darkMode;
    _themeRevision.value++;
  }

  static AppPalette get palette => _isDark ? AppPalette.dark : AppPalette.light;

  static AppPalette of(BuildContext context) => AppPalette.of(context);

  // Surfaces.
  static Color get background => palette.background;
  static Color get surface => palette.surface;
  static Color get surfaceVariant => palette.surfaceVariant;
  static Color get surfaceElevated => palette.surfaceElevated;
  static Color get card => palette.card;
  static Color get searchBar => palette.searchBar;
  static Color get skeleton => palette.skeleton;

  // Brand.
  static Color get primary => palette.primary;
  static Color get onPrimary => palette.onPrimary;
  static Color get primaryContainer => palette.primaryContainer;
  static Color get onPrimaryContainer => palette.onPrimaryContainer;
  static Color get accent => palette.accent;

  // Content.
  static Color get textPrimary => palette.textPrimary;
  static Color get textSecondary => palette.textSecondary;
  static Color get textDisabled => palette.textDisabled;
  static Color get icon => palette.icon;

  // Lines and overlays.
  static Color get border => palette.border;
  static Color get divider => palette.divider;
  static Color get scrim => palette.scrim;

  /// Status colours stay `const` because they are also used inside constant
  /// widget expressions; components that need theme-tuned status colours read
  /// `context.palette.success` instead.
  static const Color success = Color(0xff4caf75);
  static const Color warning = Color(0xffffc107);
  static const Color error = Color(0xfff44336);
  static Color get info => palette.info;
}
