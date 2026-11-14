import 'package:flutter/material.dart';

/// Single source of truth for the persisted theme preference.
///
/// The stored values are stable strings so older installations keep working:
/// anything unknown (including the old missing value) still resolves to dark,
/// and [ThemeMode.system] is only used when it was explicitly chosen.
class ThemeModePreference {
  const ThemeModePreference._();

  static ThemeMode fromStorage(String? value) => switch (value) {
        'light' => ThemeMode.light,
        'system' => ThemeMode.system,
        _ => ThemeMode.dark,
      };

  static String toStorage(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.system => 'system',
        ThemeMode.dark => 'dark',
      };
}
