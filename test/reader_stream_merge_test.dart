import 'package:flutter_test/flutter_test.dart';
import 'package:mangaplus/app/core/utils/reader_stream_merge.dart';

void main() {
  group('mergeReaderStreamPages', () {
    test('appends the next chapter and lands on its first page in paged mode', () {
      final result = mergeReaderStreamPages(
        currentPages: const ['chapter-1-page-1', 'chapter-1-page-2'],
        adjacentPages: const ['chapter-2-page-1', 'chapter-2-page-2'],
        currentRanges: const [
          ReaderChapterPageRange(
            chapterId: 'chapter-1',
            startIndex: 0,
            pageCount: 2,
          ),
        ],
        adjacentChapterId: 'chapter-2',
        currentPage: 1,
        prepend: false,
        pagedReader: true,
      );

      expect(result.pages, [
        'chapter-1-page-1',
        'chapter-1-page-2',
        'chapter-2-page-1',
        'chapter-2-page-2',
      ]);
      expect(result.currentPage, 2);
      expect(result.chapterRanges.map((range) => range.chapterId), [
        'chapter-1',
        'chapter-2',
      ]);
      expect(result.chapterRanges.last.startIndex, 2);
    });

    test('keeps the visible page when appending in continuous scroll mode', () {
      final result = mergeReaderStreamPages(
        currentPages: const ['chapter-1-page-1', 'chapter-1-page-2'],
        adjacentPages: const ['chapter-2-page-1'],
        currentRanges: const [
          ReaderChapterPageRange(
            chapterId: 'chapter-1',
            startIndex: 0,
            pageCount: 2,
          ),
        ],
        adjacentChapterId: 'chapter-2',
        currentPage: 0,
        prepend: false,
        pagedReader: false,
      );

      expect(result.currentPage, 0);
    });

    test('prepends the previous chapter and lands on its last page in paged mode', () {
      final result = mergeReaderStreamPages(
        currentPages: const ['chapter-2-page-1', 'chapter-2-page-2'],
        adjacentPages: const ['chapter-1-page-1', 'chapter-1-page-2'],
        currentRanges: const [
          ReaderChapterPageRange(
            chapterId: 'chapter-2',
            startIndex: 0,
            pageCount: 2,
          ),
        ],
        adjacentChapterId: 'chapter-1',
        currentPage: 0,
        prepend: true,
        pagedReader: true,
      );

      expect(result.pages, [
        'chapter-1-page-1',
        'chapter-1-page-2',
        'chapter-2-page-1',
        'chapter-2-page-2',
      ]);
      expect(result.currentPage, 1);
      expect(result.chapterRanges.first.chapterId, 'chapter-1');
      expect(result.chapterRanges.first.startIndex, 0);
      expect(result.chapterRanges.last.startIndex, 2);
    });

    test('shifts the visible page index when prepending in continuous scroll mode', () {
      final result = mergeReaderStreamPages(
        currentPages: const ['chapter-2-page-1', 'chapter-2-page-2'],
        adjacentPages: const ['chapter-1-page-1', 'chapter-1-page-2'],
        currentRanges: const [
          ReaderChapterPageRange(
            chapterId: 'chapter-2',
            startIndex: 0,
            pageCount: 2,
          ),
        ],
        adjacentChapterId: 'chapter-1',
        currentPage: 1,
        prepend: true,
        pagedReader: false,
      );

      expect(result.currentPage, 3);
    });
  });
}
