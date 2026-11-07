import 'package:flutter_test/flutter_test.dart';
import 'package:mangaplus/app/core/utils/chapter_sequence.dart';
import 'package:mangaplus/app/data/models/chapter.dart';

ChapterElement _chapter(String title, {String? reference}) {
  final id = reference ?? 'https://example.test/series/$title';
  return ChapterElement(chapterId: id, title: title, url: id);
}

void main() {
  group('ChapterSequence order', () {
    test('detects a newest-first source list', () {
      final sequence = ChapterSequence.from([
        _chapter('Chapter 5'),
        _chapter('Chapter 4'),
        _chapter('Chapter 3'),
      ]);

      expect(sequence.order, ChapterOrder.descending);
      expect(
        sequence
            .adjacent(
              currentId: 'https://example.test/series/Chapter 4',
              currentTitle: 'Chapter 4',
              forward: true,
            )
            ?.title,
        'Chapter 5',
      );
      expect(
        sequence
            .adjacent(
              currentId: 'https://example.test/series/Chapter 4',
              currentTitle: 'Chapter 4',
              forward: false,
            )
            ?.title,
        'Chapter 3',
      );
    });

    test('follows an oldest-first source list instead of going backwards', () {
      final sequence = ChapterSequence.from([
        _chapter('Chapter 1'),
        _chapter('Chapter 2'),
        _chapter('Chapter 3'),
      ]);

      expect(sequence.order, ChapterOrder.ascending);
      expect(
        sequence
            .adjacent(
              currentId: 'https://example.test/series/Chapter 2',
              currentTitle: 'Chapter 2',
              forward: true,
            )
            ?.title,
        'Chapter 3',
      );
      expect(
        sequence
            .adjacent(
              currentId: 'https://example.test/series/Chapter 2',
              currentTitle: 'Chapter 2',
              forward: false,
            )
            ?.title,
        'Chapter 1',
      );
    });

    test('never skips a chapter when numbers have gaps', () {
      final sequence = ChapterSequence.from([
        _chapter('Chapter 9'),
        _chapter('Chapter 5'),
        _chapter('Chapter 2'),
      ]);

      final forward = sequence.adjacent(
        currentId: 'https://example.test/series/Chapter 2',
        currentTitle: 'Chapter 2',
        forward: true,
      );

      expect(forward?.title, 'Chapter 5');
    });

    test('supports decimals and Arabic-Indic digits', () {
      final sequence = ChapterSequence.from([
        _chapter('الفصل ٢.٥'),
        _chapter('الفصل ٢'),
        _chapter('الفصل ١'),
      ]);

      expect(sequence.order, ChapterOrder.descending);
      expect(ChapterSequence.chapterNumber('الفصل ٢.٥'), 2.5);
      expect(
        sequence
            .adjacent(
              currentId: 'https://example.test/series/الفصل ٢',
              currentTitle: 'الفصل ٢',
              forward: true,
            )
            ?.title,
        'الفصل ٢.٥',
      );
    });

    test('reads Arabic ordinal chapter titles', () {
      expect(ChapterSequence.chapterNumber('الفصل الأول'), 1);
      expect(ChapterSequence.chapterNumber('الفصل الثالث'), 3);
      expect(ChapterSequence.chapterNumber('الفصل العاشر'), 10);
    });

    test('reads Special, Extra and padded chapter numbers', () {
      expect(ChapterSequence.chapterNumber('Special 1'), 1);
      expect(ChapterSequence.chapterNumber('Extra 2'), 2);
      expect(ChapterSequence.chapterNumber('Chapter 01'), 1);
      expect(ChapterSequence.chapterNumber('Chapter 1.5'), 1.5);
    });

    test('ignores values with several unrelated numbers', () {
      expect(ChapterSequence.chapterNumber('Vol 3 Chapter 12'), 12);
      expect(ChapterSequence.chapterNumber('2024-05-01'), isNull);
    });
  });

  group('ChapterSequence adjacency', () {
    test('uses source order for unnumbered chapters', () {
      final sequence = ChapterSequence.from([
        _chapter('الفصل ج', reference: '/chapter-c'),
        _chapter('الفصل ب', reference: '/chapter-b'),
        _chapter('الفصل أ', reference: '/chapter-a'),
      ]);

      expect(sequence.order, ChapterOrder.unknown);
      expect(
        sequence
            .adjacent(
              currentId: '/chapter-b',
              currentTitle: 'الفصل ب',
              forward: true,
            )
            ?.chapterId,
        '/chapter-c',
      );
      expect(
        sequence
            .adjacent(
              currentId: '/chapter-b',
              currentTitle: 'الفصل ب',
              forward: false,
            )
            ?.chapterId,
        '/chapter-a',
      );
    });

    test('does not step past either end of the list', () {
      final sequence = ChapterSequence.from([
        _chapter('Chapter 2'),
        _chapter('Chapter 1'),
      ]);

      expect(
        sequence.adjacent(
          currentId: 'https://example.test/series/Chapter 2',
          currentTitle: 'Chapter 2',
          forward: true,
        ),
        isNull,
      );
      expect(
        sequence.adjacent(
          currentId: 'https://example.test/series/Chapter 1',
          currentTitle: 'Chapter 1',
          forward: false,
        ),
        isNull,
      );
    });

    test('deduplicates repeated chapters by id or url', () {
      final duplicate = ChapterElement(
        chapterId: 'https://example.test/series/Chapter 2',
        title: 'Chapter 2',
        url: '/series/chapter-2',
      );
      final sequence = ChapterSequence.from([
        _chapter('Chapter 3'),
        duplicate,
        ChapterElement(
          chapterId: 'https://example.test/series/Chapter 2',
          title: 'Chapter 2 duplicate',
          url: '/series/chapter-2',
        ),
        _chapter('Chapter 1'),
      ]);

      expect(sequence.length, 3);
    });

    test('uses a declared link when the current chapter is not in the list', () {
      final sequence = ChapterSequence.from([
        _chapter('Chapter 3'),
        _chapter('Chapter 2'),
        _chapter('Chapter 1'),
      ]);

      final adjacent = sequence.adjacent(
        currentId: 'https://example.test/read/external-chapter',
        currentTitle: 'External',
        forward: true,
        declaredNextChapter: 'https://example.test/series/Chapter 2',
      );

      expect(adjacent?.title, 'Chapter 2');
    });

    test('never returns the current chapter through a declared link', () {
      final sequence = ChapterSequence.from([
        _chapter('Chapter 2'),
        _chapter('Chapter 1'),
      ]);

      final adjacent = sequence.adjacent(
        currentId: 'https://example.test/series/Chapter 2',
        currentTitle: 'Chapter 2',
        forward: true,
        declaredNextChapter: 'https://example.test/series/Chapter 2',
      );

      expect(adjacent, isNull);
    });

    test('falls back to a unique title match with resolved base paths', () {
      final sequence = ChapterSequence.from([
        _chapter('الفصل 3', reference: '/chapter-3'),
        _chapter('الفصل 2', reference: '/chapter-2'),
        _chapter('الفصل 1', reference: '/chapter-1'),
      ]);

      final adjacent = sequence.adjacent(
        currentId: 'https://example.test/chapter-2',
        currentTitle: 'الفصل 2',
        forward: true,
      );

      expect(adjacent?.chapterId, '/chapter-3');
    });
  });
}
