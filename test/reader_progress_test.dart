import 'package:flutter_test/flutter_test.dart';
import 'package:mangaplus/app/core/utils/reader_progress.dart';
import 'package:mangaplus/app/core/utils/reader_stream_merge.dart';

void main() {
  group('ReaderProgress', () {
    test('normalizes scroll offsets and handles empty extents', () {
      expect(ReaderProgress.scroll(offset: 25, maxExtent: 100), 0.25);
      expect(ReaderProgress.scroll(offset: -10, maxExtent: 100), 0);
      expect(ReaderProgress.scroll(offset: 150, maxExtent: 100), 1);
      expect(ReaderProgress.scroll(offset: 20, maxExtent: 0), 0);
    });

    test('calculates progress within the active chapter range', () {
      const range = ReaderChapterPageRange(
        chapterId: 'chapter-2',
        startIndex: 8,
        pageCount: 4,
      );
      expect(
        ReaderProgress.page(
          pageIndex: 9,
          pageCount: 12,
          range: range,
          fractionWithinPage: 0.5,
        ),
        0.375,
      );
      expect(
        ReaderProgress.page(
          pageIndex: 11,
          pageCount: 12,
          range: range,
          fractionWithinPage: 1,
        ),
        1,
      );
    });

    test('maps chapter progress back to a bounded page index', () {
      const range = ReaderChapterPageRange(
        chapterId: 'chapter-2',
        startIndex: 8,
        pageCount: 4,
      );
      expect(
        ReaderProgress.pageAt(progress: 0.5, pageCount: 12, range: range),
        10,
      );
      expect(
        ReaderProgress.pageAt(progress: 1, pageCount: 12, range: range),
        11,
      );
      expect(
        ReaderProgress.pageAt(progress: 0, pageCount: 12, range: range),
        8,
      );
    });
  });
}
