import 'package:flutter/material.dart';

/// Single mapping between the stored theme preference and [ThemeMode].
///
/// The stored value is the source of truth for this device. `system` is kept
/// only locally because the remote settings document still accepts `dark` and
/// `light` only; [toRemote] resolves it to the brightness currently in use.
class ThemeModePreference {
  const ThemeModePreference._();

  static const String light = 'light';
  static const String dark = 'dark';
  static const String system = 'system';

  /// An install that never chose a theme keeps the original dark default, so
  /// adding [ThemeMode.system] does not flip existing users to a light UI.
  static ThemeMode fromStorage(String? value) => switch (value) {
        light => ThemeMode.light,
        system => ThemeMode.system,
        _ => ThemeMode.dark,
      };

  static String toStorage(ThemeMode mode) => switch (mode) {
        ThemeMode.light => light,
        ThemeMode.system => system,
        ThemeMode.dark => dark,
      };

  /// Value written to the remote settings document, which only accepts
  /// `dark`/`light`. `system` is resolved to the brightness in use so another
  /// device still receives a usable preference.
  static String toRemote(ThemeMode mode, {required bool systemIsDark}) =>
      switch (mode) {
        ThemeMode.light => light,
        ThemeMode.dark => dark,
        ThemeMode.system => systemIsDark ? dark : light,
      };
}
