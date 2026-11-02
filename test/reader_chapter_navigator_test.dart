import 'package:flutter_test/flutter_test.dart';
import 'package:mangaplus/app/core/utils/reader_chapter_navigator.dart';
import 'package:mangaplus/app/data/models/chapter.dart';

ChapterElement _chapter(int number) => ChapterElement(
      chapterId: 'https://example.test/series/chapter-$number',
      title: 'الفصل $number',
      url: 'https://example.test/series/chapter-$number',
    );

void main() {
  group('ReaderChapterNavigator', () {
    final chapters = [_chapter(5), _chapter(3), _chapter(2), _chapter(1)];

    test('finds the closest newer chapter without skipping', () {
      final adjacent = ReaderChapterNavigator.adjacentChapter(
        chapters: chapters,
        currentChapterId: _chapter(2).chapterId,
        currentChapterTitle: 'الفصل 2',
        forward: true,
      );

      expect(adjacent?.chapterId, _chapter(3).chapterId);
    });

    test('finds the closest older chapter without skipping', () {
      final adjacent = ReaderChapterNavigator.adjacentChapter(
        chapters: chapters,
        currentChapterId: _chapter(3).chapterId,
        currentChapterTitle: 'الفصل 3',
        forward: false,
      );

      expect(adjacent?.chapterId, _chapter(2).chapterId);
    });

    test('uses source order when chapter titles are not numbered', () {
      final unnumbered = [
        ChapterElement(chapterId: '/chapter-c', title: 'الفصل ج', url: '/chapter-c'),
        ChapterElement(chapterId: '/chapter-b', title: 'الفصل ب', url: '/chapter-b'),
        ChapterElement(chapterId: '/chapter-a', title: 'الفصل أ', url: '/chapter-a'),
      ];

      final adjacent = ReaderChapterNavigator.adjacentChapter(
        chapters: unnumbered,
        currentChapterId: 'https://example.test/chapter-b',
        currentChapterTitle: 'الفصل ب',
        forward: true,
      );

      expect(adjacent?.chapterId, '/chapter-c');
    });

    test('returns no chapter beyond either end of the sequence', () {
      expect(
        ReaderChapterNavigator.adjacentChapter(
          chapters: chapters,
          currentChapterId: _chapter(5).chapterId,
          currentChapterTitle: 'الفصل 5',
          forward: true,
        ),
        isNull,
      );
      expect(
        ReaderChapterNavigator.adjacentChapter(
          chapters: chapters,
          currentChapterId: _chapter(1).chapterId,
          currentChapterTitle: 'الفصل 1',
          forward: false,
        ),
        isNull,
      );
    });
  });
}
