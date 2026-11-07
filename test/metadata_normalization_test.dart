import 'package:flutter_test/flutter_test.dart';
import 'package:mangaplus/app/core/translations/content_localization.dart';
import 'package:mangaplus/app/data/sources/source_values.dart';

void main() {
  group('SourceValues.status', () {
    test('maps English, Arabic and decorated labels onto canonical states', () {
      expect(SourceValues.status('Ongoing'), SourceValues.statusOngoing);
      expect(SourceValues.status('publishing'), SourceValues.statusOngoing);
      expect(SourceValues.status('مستمرة'), SourceValues.statusOngoing);
      expect(SourceValues.status('Ongoing (مستمرة)'), SourceValues.statusOngoing);
      expect(SourceValues.status('حالة: مكتملة'), SourceValues.statusCompleted);
      expect(SourceValues.status('Finished'), SourceValues.statusCompleted);
      expect(SourceValues.status('on_hiatus'), SourceValues.statusHiatus);
      expect(SourceValues.status('On Hold'), SourceValues.statusHiatus);
      expect(SourceValues.status('متروك'), SourceValues.statusHiatus);
      expect(SourceValues.status('Dropped'), SourceValues.statusCancelled);
      expect(SourceValues.status('ملغاة'), SourceValues.statusCancelled);
      expect(SourceValues.status('قادم'), SourceValues.statusUpcoming);
      expect(SourceValues.status('unknown'), SourceValues.statusUnknown);
    });

    test('unwraps maps and never invents a state', () {
      expect(
        SourceValues.status({'name': 'مكتمل'}),
        SourceValues.statusCompleted,
      );
      expect(SourceValues.status(''), '');
      expect(SourceValues.status(null), '');
      // A progress value is not a work status.
      expect(SourceValues.status('45%'), '');
      expect(SourceValues.status('62'), '');
      // Unknown labels survive verbatim instead of being replaced.
      expect(SourceValues.status('قيد المراجعة'), 'قيد المراجعة');
    });
  });

  group('SourceValues.chapterCount', () {
    test('counts unique chapter identities', () {
      final chapters = [
        {'url': 'https://x.test/c/2'},
        {'url': 'https://x.test/c/1'},
        {'url': 'https://x.test/c/2'},
      ];
      expect(SourceValues.chapterCount(chapters), '2');
    });

    test('counts chapter objects that only expose an id or number', () {
      expect(
        SourceValues.chapterCount([
          {'chapter_id': '7'},
          {'chapter_id': '8'},
          {'id': 9},
        ]),
        '3',
      );
    });

    test('reads counts from plain values and nested containers', () {
      expect(SourceValues.chapterCount(42), '42');
      expect(SourceValues.chapterCount('١٢ فصلًا'), '12');
      expect(SourceValues.chapterCount('1,204 chapters'), '1204');
      expect(
        SourceValues.chapterCount({
          'details': {
            'chaptersCount': 87,
          },
        }),
        '87',
      );
    });

    test('reports unknown instead of a misleading zero', () {
      expect(SourceValues.chapterCount(0), '');
      expect(SourceValues.chapterCount('0'), '');
      expect(SourceValues.chapterCount([]), '');
      expect(SourceValues.chapterCount({'total_chapters': 0}), '');
      expect(SourceValues.chapterCount(null), '');
    });
  });

  group('SourceValues.image', () {
    test('reads every common cover key', () {
      expect(
        SourceValues.image({'image_url': 'https://cdn.test/a.jpg'}),
        'https://cdn.test/a.jpg',
      );
      expect(
        SourceValues.image({'cover_image': 'https://cdn.test/b.jpg'}),
        'https://cdn.test/b.jpg',
      );
      expect(
        SourceValues.image({
          'poster': {'medium': 'https://cdn.test/c.jpg'},
        }),
        'https://cdn.test/c.jpg',
      );
    });

    test('resolves relative and protocol-relative URLs against the work URL', () {
      expect(
        SourceValues.image(
          {'image': '/covers/d.jpg'},
          baseUrl: 'https://site.test/manga/work',
        ),
        'https://site.test/covers/d.jpg',
      );
      expect(
        SourceValues.image(
          {'thumbnail': '//cdn.test/e.webp'},
          baseUrl: 'https://site.test/manga/work',
        ),
        'https://cdn.test/e.webp',
      );
      expect(
        SourceValues.image(
          {'image': 'covers/f.jpg'},
          baseUrl: 'https://site.test/manga/work/',
        ),
        'https://site.test/manga/work/covers/f.jpg',
      );
    });

    test('takes the first srcset candidate', () {
      expect(
        SourceValues.image({
          'image': 'https://cdn.test/small.jpg 1x, https://cdn.test/large.jpg 2x',
        }),
        'https://cdn.test/small.jpg',
      );
    });

    test('rejects missing, unsafe and site-chrome images', () {
      expect(SourceValues.image(const {}), '');
      expect(SourceValues.image({'image': 'null'}), '');
      expect(SourceValues.image({'image': 'data:image/png;base64,AAAA'}), '');
      expect(
        SourceValues.image({'image': '/assets/site-logo.png'},
            baseUrl: 'https://site.test/'),
        '',
      );
      expect(
        SourceValues.image({'image': '/img/placeholder.jpg'},
            baseUrl: 'https://site.test/'),
        '',
      );
      // A relative cover without a usable base cannot be shown.
      expect(SourceValues.image({'image': '/covers/g.jpg'}), '');
    });
  });

  group('SourceValues.year and type', () {
    test('extracts a release year from dates and epochs', () {
      expect(SourceValues.year('2019'), '2019');
      expect(SourceValues.year('2021-05-01'), '2021');
      expect(SourceValues.year('May 2020'), '2020');
      expect(SourceValues.year('1700000000'), '2023');
      expect(SourceValues.year(''), '');
      expect(SourceValues.year('ongoing'), '');
    });

    test('canonicalizes content types', () {
      expect(SourceValues.canonicalType('مانجا'), 'manga');
      expect(SourceValues.canonicalType('Manga'), 'manga');
      expect(SourceValues.canonicalType('مانهوا'), 'manhwa');
      expect(SourceValues.canonicalType('Manhwa'), 'manhwa');
      expect(SourceValues.canonicalType('مانهوا صينية'), 'manhua');
      expect(SourceValues.canonicalType('Manhua'), 'manhua');
      expect(SourceValues.canonicalType('رواية'), 'novel');
      expect(SourceValues.canonicalType('Light Novel'), 'novel');
      expect(SourceValues.canonicalType('', fallback: 'novel'), 'novel');
      expect(SourceValues.isNovelType('رواية'), isTrue);
      expect(SourceValues.isNovelType('مانجا'), isFalse);
    });
  });

  group('localizeContentStatus', () {
    test('localizes canonical tokens and decorated labels', () {
      expect(localizeContentStatus('hiatus'), 'متوقف مؤقتًا');
      expect(localizeContentStatus('on_hiatus'), 'متوقف مؤقتًا');
      expect(localizeContentStatus('مستمر'), 'مستمر');
      expect(localizeContentStatus('dropped'), 'ملغي');
      expect(localizeContentStatus('unknown'), 'غير معروف');
    });

    test('falls back for labels it does not understand', () {
      expect(localizeContentStatusOr('قيد المراجعة', 'غير معروف'), 'غير معروف');
      expect(localizeContentStatusOr('ongoing', 'غير معروف'), 'مستمر');
    });
  });
}
