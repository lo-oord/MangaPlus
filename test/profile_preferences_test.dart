import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangaplus/app/core/theme/theme_mode_preference.dart';
import 'package:mangaplus/app/core/utils/app_permission_status.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  group('ThemeModePreference', () {
    test('keeps the historical dark default when nothing was stored', () {
      expect(ThemeModePreference.fromStorage(null), ThemeMode.dark);
      expect(ThemeModePreference.fromStorage('unknown'), ThemeMode.dark);
    });

    test('maps the local theme modes', () {
      expect(ThemeModePreference.fromStorage('light'), ThemeMode.light);
      expect(ThemeModePreference.fromStorage('system'), ThemeMode.system);
      expect(ThemeModePreference.toStorage(ThemeMode.dark), 'dark');
      expect(ThemeModePreference.toStorage(ThemeMode.light), 'light');
      expect(ThemeModePreference.toStorage(ThemeMode.system), 'system');
    });

    test('resolves the system mode to a stored dark or light value', () {
      expect(
        ThemeModePreference.toRemote(ThemeMode.system, systemIsDark: true),
        'dark',
      );
      expect(
        ThemeModePreference.toRemote(ThemeMode.system, systemIsDark: false),
        'light',
      );
      expect(
        ThemeModePreference.toRemote(ThemeMode.dark, systemIsDark: false),
        'dark',
      );
      expect(
        ThemeModePreference.toRemote(ThemeMode.light, systemIsDark: true),
        'light',
      );
    });
  });

  group('AppPermissionStatus', () {
    test('maps every platform permission state', () {
      expect(
        AppPermissionStatus.fromPermissionStatus(PermissionStatus.granted),
        AppPermissionStatus.granted,
      );
      expect(
        AppPermissionStatus.fromPermissionStatus(PermissionStatus.denied),
        AppPermissionStatus.denied,
      );
      expect(
        AppPermissionStatus.fromPermissionStatus(PermissionStatus.restricted),
        AppPermissionStatus.restricted,
      );
      expect(
        AppPermissionStatus.fromPermissionStatus(PermissionStatus.limited),
        AppPermissionStatus.limited,
      );
      expect(
        AppPermissionStatus.fromPermissionStatus(PermissionStatus
            .permanentlyDenied),
        AppPermissionStatus.permanentlyDenied,
      );
      expect(
        AppPermissionStatus.fromPermissionStatus(PermissionStatus.unknown),
        AppPermissionStatus.unknown,
      );
    });

    test('distinguishes granted, denied and permanently denied states', () {
      expect(AppPermissionStatus.granted.isGranted, isTrue);
      expect(AppPermissionStatus.denied.canRequest, isTrue);
      expect(AppPermissionStatus.permanentlyDenied.mustOpenSettings, isTrue);
      expect(AppPermissionStatus.unknown.mustOpenSettings, isFalse);
    });
  });
}
