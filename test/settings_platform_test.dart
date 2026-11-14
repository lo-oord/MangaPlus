import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangaplus/app/core/auth/auth_validation.dart';
import 'package:mangaplus/app/core/settings/reading_preferences.dart';
import 'package:mangaplus/app/core/storage/storage_utils.dart';
import 'package:mangaplus/app/core/theme/theme_mode_preference.dart';
import 'package:mangaplus/app/data/models/download_task.dart';
import 'package:mangaplus/app/modules/download/download_sections.dart';

DownloadTask _task(String id, DownloadTaskStatus status) => DownloadTask(
      id: id,
      comicId: 'comic-$id',
      comicTitle: 'عمل $id',
      coverImage: '',
      chapters: const [
        {'id': 'c1', 'title': 'الفصل 1'},
      ],
      status: status,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  group('ThemeModePreference', () {
    test('keeps the legacy default and round-trips all three modes', () {
      expect(ThemeModePreference.fromStorage(null), ThemeMode.dark);
      expect(ThemeModePreference.fromStorage('anything'), ThemeMode.dark);
      for (final mode in ThemeMode.values) {
        expect(
          ThemeModePreference.fromStorage(
            ThemeModePreference.toStorage(mode),
          ),
          mode,
        );
      }
    });
  });

  group('ReadingPreferences', () {
    test('normalizes unknown values to the existing defaults', () {
      expect(ReadingPreferences.normalizeMode('paged'), 'paged');
      expect(ReadingPreferences.normalizeMode('scroll'), 'scroll');
      expect(ReadingPreferences.normalizeMode('unknown'), 'scroll');
      expect(ReadingPreferences.normalizeDirection('ltr'), 'ltr');
      expect(ReadingPreferences.normalizeDirection('unknown'), 'rtl');
    });

    test('labels match the actual stored values', () {
      expect(ReadingPreferences.modeLabel('paged'), 'صفحات');
      expect(ReadingPreferences.modeLabel('scroll'), 'تمرير متصل');
      expect(ReadingPreferences.directionLabel('rtl'), 'يمين إلى يسار');
      expect(ReadingPreferences.directionLabel('ltr'), 'يسار إلى يمين');
    });
  });

  group('AuthValidation', () {
    test('rejects empty and malformed email addresses', () {
      expect(AuthValidation.emailError(''), isNotNull);
      expect(AuthValidation.emailError('not-an-email'), isNotNull);
      expect(AuthValidation.emailError(' user@example.com '), isNull);
    });

    test('requires a letter and a digit for new passwords', () {
      expect(AuthValidation.passwordError(''), isNotNull);
      expect(AuthValidation.passwordError('short1'), isNotNull);
      expect(AuthValidation.passwordError('onlyletters'), isNotNull);
      expect(AuthValidation.passwordError('12345678'), isNotNull);
      expect(AuthValidation.passwordError('secret123'), isNull);
    });

    test('confirmation must match exactly', () {
      expect(AuthValidation.confirmError('secret123', ''), isNotNull);
      expect(AuthValidation.confirmError('secret123', 'secret124'), isNotNull);
      expect(AuthValidation.confirmError('secret123', 'secret123'), isNull);
    });

    test('strength increases with length and variety', () {
      expect(AuthValidation.passwordStrength('abc123'), 0);
      expect(AuthValidation.passwordStrength('Abcdef123456'), greaterThan(0));
      expect(
        AuthValidation.passwordStrength(r'Abcdef12345!'),
        2,
      );
      expect(AuthValidation.strengthLabel(0), 'ضعيفة');
      expect(AuthValidation.strengthLabel(2), 'قوية');
    });
  });

  group('formatBytes', () {
    test('formats measured sizes without fake precision', () {
      expect(formatBytes(0), '0 KB');
      expect(formatBytes(-4), '0 KB');
      expect(formatBytes(500), '500 B');
      expect(formatBytes(2048), '2.0 KB');
      expect(formatBytes(5 * 1024 * 1024), '5.0 MB');
      expect(formatBytes(110 * 1024 * 1024), '110 MB');
    });
  });

  group('DownloadSections', () {
    test('places every status in exactly one section', () {
      final sections = DownloadSections.from([
        _task('a', DownloadTaskStatus.downloading),
        _task('b', DownloadTaskStatus.paused),
        _task('c', DownloadTaskStatus.queued),
        _task('d', DownloadTaskStatus.completed),
        _task('e', DownloadTaskStatus.failed),
        _task('f', DownloadTaskStatus.partiallyCompleted),
        _task('g', DownloadTaskStatus.cancelled),
      ]);

      expect(sections.active.map((task) => task.id), ['a', 'b']);
      expect(sections.queued.map((task) => task.id), ['c']);
      expect(sections.completed.map((task) => task.id), ['d']);
      expect(sections.failed.map((task) => task.id), ['e', 'f', 'g']);
      expect(sections.total, 7);
      expect(sections.isEmpty, isFalse);
    });

    test('an empty queue reports empty', () {
      final sections = DownloadSections.from(const []);
      expect(sections.isEmpty, isTrue);
      expect(sections.total, 0);
    });
  });
}
