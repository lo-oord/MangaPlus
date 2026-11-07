import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mangaplus/app/core/translations/ar_sa.dart';
import 'package:mangaplus/app/core/translations/en_us.dart';
import 'package:mangaplus/app/routes/app_pages.dart';

void main() {
  group('release identity', () {
    test('package name and Android application id stay MangaPlus', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final gradle = File('android/app/build.gradle').readAsStringSync();

      expect(pubspec, contains('name: mangaplus'));
      expect(gradle, contains('namespace \'com.mangaplus.app\''));
      expect(gradle, contains('applicationId "com.mangaplus.app"'));
    });

    test('the app still starts on the splash route', () {
      expect(AppPages.initial, Routes.SPLASH);
    });
  });

  group('route registration', () {
    test('route names are unique, absolute and all have builders', () {
      final names = AppPages.routes.map((page) => page.name).toList();

      expect(names.toSet().length, names.length);
      for (final name in names) {
        expect(name, startsWith('/'));
      }
      for (final page in AppPages.routes) {
        expect(page.page, isNotNull, reason: '${page.name} has no builder');
      }
      expect(names, contains(AppPages.initial));
      expect(names, contains(Routes.COMIC_DETAIL));
      expect(names, contains(Routes.CHAPTER));
    });
  });

  group('localization', () {
    test('every Arabic key has an English translation', () {
      final missing =
          arSA.keys.where((key) => !enUS.containsKey(key)).toList()..sort();

      expect(missing, isEmpty, reason: 'Untranslated keys: $missing');
    });

    test('no translation is blank', () {
      for (final entry in arSA.entries) {
        expect(entry.key.trim(), isNotEmpty);
        expect(entry.value.trim(), isNotEmpty, reason: entry.key);
      }
      for (final entry in enUS.entries) {
        expect(entry.key.trim(), isNotEmpty);
        expect(entry.value.trim(), isNotEmpty, reason: entry.key);
      }
    });
  });
}
