import 'package:flutter/material.dart';

/// The single source of truth for every colour in MangaPlus.
///
/// The palette is a [ThemeExtension], so a widget can read the colours of the
/// theme it is actually rendered in (`context.palette`) and both themes are
/// built from the same field names. [AppPalette.light] and [AppPalette.dark] are
/// the only two instances the app ships; the legacy `AppColors` facade reads
/// them instead of holding its own copies.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.surfaceElevated,
    required this.card,
    required this.searchBar,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondary,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.icon,
    required this.border,
    required this.divider,
    required this.success,
    required this.warning,
    required this.error,
    required this.onError,
    required this.info,
    required this.scrim,
    required this.skeleton,
    required this.brightness,
  });

  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color surfaceElevated;
  final Color card;
  final Color searchBar;

  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color secondary;
  final Color accent;

  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;
  final Color icon;

  final Color border;
  final Color divider;

  final Color success;
  final Color warning;
  final Color error;
  final Color onError;
  final Color info;

  final Color scrim;
  final Color skeleton;

  final Brightness brightness;

  bool get isDark => brightness == Brightness.dark;

  static const AppPalette light = AppPalette(
    background: Color(0xfff4f5f7),
    surface: Color(0xffffffff),
    surfaceVariant: Color(0xffebeced),
    surfaceElevated: Color(0xffffffff),
    card: Color(0xffffffff),
    searchBar: Color(0xffebeced),
    primary: Color(0xff386fbe),
    onPrimary: Color(0xffffffff),
    primaryContainer: Color(0xffdbe7f9),
    onPrimaryContainer: Color(0xff17365f),
    secondary: Color(0xff5d8dd0),
    accent: Color(0xff5d8dd0),
    textPrimary: Color(0xff24262a),
    textSecondary: Color(0xff686c74),
    textDisabled: Color(0xffa3a7ae),
    icon: Color(0xff666a72),
    border: Color(0xffdfe2e7),
    divider: Color(0xffd9dadd),
    success: Color(0xff3f9e63),
    warning: Color(0xffcf930f),
    error: Color(0xfff44336),
    onError: Color(0xffffffff),
    info: Color(0xff5d8dd0),
    scrim: Color(0x73000000),
    skeleton: Color(0xffe3e5e9),
    brightness: Brightness.light,
  );

  static const AppPalette dark = AppPalette(
    background: Color(0xff111317),
    surface: Color(0xff202329),
    surfaceVariant: Color(0xff1a1d22),
    surfaceElevated: Color(0xff262a31),
    card: Color(0xff202329),
    searchBar: Color(0xff1a1d22),
    primary: Color(0xff78a7ed),
    onPrimary: Color(0xff0c1826),
    primaryContainer: Color(0xff1d3350),
    onPrimaryContainer: Color(0xffd7e6fb),
    secondary: Color(0xff91b8f0),
    accent: Color(0xff91b8f0),
    textPrimary: Color(0xfff0f1f3),
    textSecondary: Color(0xffa7abb4),
    textDisabled: Color(0xff6b7079),
    icon: Color(0xffb3b7c0),
    border: Color(0xff30333a),
    divider: Color(0xff30333a),
    success: Color(0xff4caf75),
    warning: Color(0xffffc107),
    error: Color(0xffef5350),
    onError: Color(0xff1b0d0c),
    info: Color(0xff91b8f0),
    scrim: Color(0x99000000),
    skeleton: Color(0xff262a31),
    brightness: Brightness.dark,
  );

  /// Resolves the palette of [context], falling back to the closest brightness
  /// when the app was built by a bare `MaterialApp` (tests, previews).
  static AppPalette of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<AppPalette>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? card,
    Color? primary,
    Color? textPrimary,
    Color? textSecondary,
    Color? error,
  }) {
    return AppPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceVariant: surfaceVariant,
      surfaceElevated: surfaceElevated,
      card: card ?? this.card,
      searchBar: searchBar,
      primary: primary ?? this.primary,
      onPrimary: onPrimary,
      primaryContainer: primaryContainer,
      onPrimaryContainer: onPrimaryContainer,
      secondary: secondary,
      accent: accent,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textDisabled: textDisabled,
      icon: icon,
      border: border,
      divider: divider,
      success: success,
      warning: warning,
      error: error ?? this.error,
      onError: onError,
      info: info,
      scrim: scrim,
      skeleton: skeleton,
      brightness: brightness,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t) ?? a;
    return AppPalette(
      background: mix(background, other.background),
      surface: mix(surface, other.surface),
      surfaceVariant: mix(surfaceVariant, other.surfaceVariant),
      surfaceElevated: mix(surfaceElevated, other.surfaceElevated),
      card: mix(card, other.card),
      searchBar: mix(searchBar, other.searchBar),
      primary: mix(primary, other.primary),
      onPrimary: mix(onPrimary, other.onPrimary),
      primaryContainer: mix(primaryContainer, other.primaryContainer),
      onPrimaryContainer: mix(onPrimaryContainer, other.onPrimaryContainer),
      secondary: mix(secondary, other.secondary),
      accent: mix(accent, other.accent),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      textDisabled: mix(textDisabled, other.textDisabled),
      icon: mix(icon, other.icon),
      border: mix(border, other.border),
      divider: mix(divider, other.divider),
      success: mix(success, other.success),
      warning: mix(warning, other.warning),
      error: mix(error, other.error),
      onError: mix(onError, other.onError),
      info: mix(info, other.info),
      scrim: mix(scrim, other.scrim),
      skeleton: mix(skeleton, other.skeleton),
      brightness: t < 0.5 ? brightness : other.brightness,
    );
  }
}

/// `context.palette` is the preferred way to read colours inside a widget.
extension AppPaletteContext on BuildContext {
  AppPalette get palette => AppPalette.of(this);
}
