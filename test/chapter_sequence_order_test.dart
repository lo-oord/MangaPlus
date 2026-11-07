import 'package:flutter_test/flutter_test.dart';
import 'package:mangaplus/app/core/utils/chapter_sequence.dart';
import 'package:mangaplus/app/data/models/chapter.dart';

ChapterElement _chapter(String title, {String? reference}) {
  final id = reference ?? 'https://example.test/series/$title';
  return ChapterElement(chapterId: id, title: title, url: id);
}

String _ref(String title) => 'https://example.test/series/$title';

String? _forward(ChapterSequence sequence, String title) => sequence
    .adjacent(
      currentId: _ref(title),
      currentTitle: title,
      forward: true,
    )
    ?.title;

String? _backward(ChapterSequence sequence, String title) => sequence
    .adjacent(
      currentId: _ref(title),
      currentTitle: title,
      forward: false,
    )
    ?.title;

void main() {
  group('chapter order survives chapters without a number', () {
    test('an oldest-first list with one special chapter stays ascending', () {
      final sequence = ChapterSequence.from([
        _chapter('Chapter 1'),
        _chapter('Chapter 2'),
        _chapter('Special'),
        _chapter('Chapter 4'),
      ]);

      expect(sequence.order, ChapterOrder.ascending);
      // The reader is looking at chapter 2; the next row is the special, not
      // chapter 1 (which the old "assume newest-first" rule returned).
      expect(_forward(sequence, 'Chapter 2'), 'Special');
      expect(_backward(sequence, 'Chapter 2'), 'Chapter 1');
    });

    test('a newest-first list with one special chapter stays descending', () {
      final sequence = ChapterSequence.from([
        _chapter('Chapter 4'),
        _chapter('Special'),
        _chapter('Chapter 2'),
        _chapter('Chapter 1'),
      ]);

      expect(sequence.order, ChapterOrder.descending);
      expect(_forward(sequence, 'Chapter 2'), 'Special');
      expect(_backward(sequence, 'Chapter 2'), 'Chapter 1');
    });

    test('titled chapters never flip the direction of an ascending list', () {
      final sequence = ChapterSequence.from([
        _chapter('الفصل 1'),
        _chapter('الفصل 2'),
        _chapter('الفصل 3 - نهاية القوس'),
        _chapter('الفصل 4'),
      ]);

      expect(sequence.order, ChapterOrder.ascending);
      expect(_forward(sequence, 'الفصل 2'), 'الفصل 3 - نهاية القوس');
    });

    test('a duplicated number does not erase the direction', () {
      final sequence = ChapterSequence.from([
        _chapter('Chapter 5'),
        _chapter('Chapter 5.0', reference: 'https://example.test/series/5.0'),
        _chapter('Chapter 4'),
        _chapter('Chapter 3'),
      ]);

      expect(sequence.length, 4);
      expect(sequence.order, ChapterOrder.descending);
      expect(_forward(sequence, 'Chapter 4'), 'Chapter 5.0');
    });

    test('a single out-of-order row does not erase the direction', () {
      final sequence = ChapterSequence.from([
        _chapter('Chapter 10'),
        _chapter('Chapter 9'),
        _chapter('Chapter 8'),
        _chapter('Chapter 1'),
        _chapter('Chapter 2'),
      ]);

      expect(sequence.order, ChapterOrder.descending);
      expect(_forward(sequence, 'Chapter 9'), 'Chapter 10');
    });
  });

  group('declared links teach the direction when no number exists', () {
    final unnumbered = [
      _chapter('الفصل أ', reference: '/chapter-a'),
      _chapter('الفصل ب', reference: '/chapter-b'),
      _chapter('الفصل ج', reference: '/chapter-c'),
    ];

    test('a next link below the current row means the list is ascending', () {
      final sequence = ChapterSequence.from(unnumbered);

      final adjacent = sequence.adjacent(
        currentId: 'https://example.test/chapter-b',
        currentTitle: 'الفصل ب',
        forward: true,
        declaredNextChapter: 'https://example.test/chapter-c',
      );

      expect(sequence.order, ChapterOrder.unknown);
      expect(adjacent?.chapterId, '/chapter-c');
    });

    test('a next link above the current row means the list is descending', () {
      final sequence = ChapterSequence.from(unnumbered);

      final adjacent = sequence.adjacent(
        currentId: 'https://example.test/chapter-b',
        currentTitle: 'الفصل ب',
        forward: true,
        declaredNextChapter: 'https://example.test/chapter-a',
      );

      expect(adjacent?.chapterId, '/chapter-a');
    });

    test('previous links are used when no next link is available', () {
      final sequence = ChapterSequence.from(unnumbered);

      final adjacent = sequence.adjacent(
        currentId: 'https://example.test/chapter-b',
        currentTitle: 'الفصل ب',
        forward: false,
        declaredPreviousChapter: 'https://example.test/chapter-c',
      );

      expect(adjacent?.chapterId, '/chapter-c');
    });

    test('a declared link pointing at the current chapter is ignored', () {
      final sequence = ChapterSequence.from(unnumbered);

      final adjacent = sequence.adjacent(
        currentId: 'https://example.test/chapter-b',
        currentTitle: 'الفصل ب',
        forward: true,
        declaredNextChapter: 'https://example.test/chapter-b',
      );

      // Without usable evidence the documented newest-first fallback is kept,
      // but the current chapter itself is never returned.
      expect(adjacent?.chapterId, '/chapter-a');
    });
  });

  group('adjacency never skips a row', () {
    test('walks 1..11 one step at a time', () {
      final sequence = ChapterSequence.from([
        for (final number in [11, 10, 5, 4, 3, 2, 1]) _chapter('Chapter $number'),
      ]);

      var current = 'Chapter 1';
      final visited = <String>[];
      while (true) {
        final next = _forward(sequence, current);
        if (next == null) break;
        visited.add(next);
        current = next;
        if (visited.length > 12) break;
      }

      expect(visited, [
        'Chapter 2',
        'Chapter 3',
        'Chapter 4',
        'Chapter 5',
        'Chapter 10',
        'Chapter 11',
      ]);
    });

    test('decimal chapters sit between their neighbours', () {
      final sequence = ChapterSequence.from([
        _chapter('Chapter 3'),
        _chapter('Chapter 2.5'),
        _chapter('Chapter 2'),
        _chapter('Chapter 1.5'),
        _chapter('Chapter 1.1'),
        _chapter('Chapter 1'),
      ]);

      expect(sequence.order, ChapterOrder.descending);
      expect(_forward(sequence, 'Chapter 1'), 'Chapter 1.1');
      expect(_forward(sequence, 'Chapter 1.1'), 'Chapter 1.5');
      expect(_forward(sequence, 'Chapter 2'), 'Chapter 2.5');
      expect(_backward(sequence, 'Chapter 3'), 'Chapter 2.5');
    });

    test('manhwa-style oldest-first lists step forward once', () {
      final sequence = ChapterSequence.from([
        for (final number in [1, 2, 3, 4, 10, 11]) _chapter('الفصل $number'),
      ]);

      expect(sequence.order, ChapterOrder.ascending);
      expect(_forward(sequence, 'الفصل 2'), 'الفصل 3');
    });
  });
}
