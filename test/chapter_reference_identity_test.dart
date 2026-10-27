import 'package:flutter_test/flutter_test.dart';
import 'package:mangaplus/app/core/utils/chapter_reference_identity.dart';

void main() {
  group('ChapterReferenceIdentity', () {
    test('matches a relative list link with its resolved read-history URL', () {
      const current = 'https://reader.example/manga/series/chapter/3';
      const storedReadId = 'https://reader.example/manga/series/chapter/2';
      const chapterListId = '../chapter/2';

      expect(
        ChapterReferenceIdentity.matches(
          chapterListId,
          storedReadId,
          baseReference: current,
        ),
        isTrue,
      );
    });

    test('normalizes trailing slashes and host casing', () {
      expect(
        ChapterReferenceIdentity.matches(
          'https://READER.example/chapter/2/',
          'https://reader.example/chapter/2',
        ),
        isTrue,
      );
    });

    test('does not equate different chapter query values', () {
      expect(
        ChapterReferenceIdentity.matches(
          'https://reader.example/read?id=2',
          'https://reader.example/read?id=3',
        ),
        isFalse,
      );
    });
  });
}
