import 'package:flutter/material.dart';

class ThemeModePreference {
  const ThemeModePreference._();

  static ThemeMode fromStorage(String? value) =>
      value == 'light' ? ThemeMode.light : ThemeMode.dark;

  static String toStorage(ThemeMode mode) =>
      mode == ThemeMode.light ? 'light' : 'dark';
}
