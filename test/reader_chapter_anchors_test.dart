import 'package:flutter_test/flutter_test.dart';
import 'package:mangaplus/app/core/utils/reader_chapter_anchors.dart';

const _a = 'https://example.test/series/chapter-1';
const _b = 'https://example.test/series/chapter-2';
const _c = 'https://example.test/series/chapter-3';

void main() {
  group('merged novel stream anchors', () {
    test('a single chapter owns the whole content', () {
      final anchors = ReaderChapterAnchors.single(_a);

      expect(anchors.activeChapterId(0), _a);
      expect(anchors.activeChapterId(4200), _a);
    });

    test('an appended chapter starts at the previous end of the content', () {
      final anchors = ReaderChapterAnchors.single(_a)
        ..append(chapterId: _b, boundaryOffset: 1000);

      expect(anchors.activeChapterId(0), _a);
      expect(anchors.activeChapterId(990), _a);
      expect(anchors.activeChapterId(1000), _b);
      expect(anchors.activeChapterId(90000), _b);
    });

    test('appending never moves an existing boundary backwards', () {
      final anchors = ReaderChapterAnchors.single(_a)
        ..append(chapterId: _b, boundaryOffset: 1000)
        ..append(chapterId: _c, boundaryOffset: 0);

      expect(anchors.offsetOf(_c), 1000);
      expect(anchors.activeChapterId(1200), _c);
      expect(anchors.activeChapterId(500), _a);
    });

    test('a prepended chapter takes the top and shifts the others down', () {
      final anchors = ReaderChapterAnchors.single(_b)
        ..append(chapterId: _c, boundaryOffset: 2000)
        ..prepend(chapterId: _a, addedExtent: 800);

      expect(anchors.offsetOf(_a), 0);
      expect(anchors.offsetOf(_b), 800);
      expect(anchors.offsetOf(_c), 2800);
      expect(anchors.activeChapterId(100), _a);
      expect(anchors.activeChapterId(900), _b);
      expect(anchors.activeChapterId(3000), _c);
    });

    test('a missing extent still keeps the order valid', () {
      final anchors = ReaderChapterAnchors.single(_b)
        ..prepend(chapterId: _a, addedExtent: 0);

      expect(anchors.offsetOf(_a), 0);
      expect(anchors.offsetOf(_b), 0);
      expect(anchors.activeChapterId(0), _b);
    });

    test('lookups resolve relative and absolute references of one chapter', () {
      final anchors = ReaderChapterAnchors.single(_a);

      expect(anchors.contains(_a), isTrue);
      expect(anchors.contains('/series/chapter-1'), isTrue);
      expect(anchors.contains('https://example.test/series/chapter-2'), isFalse);
      expect(anchors.offsetOf(''), isNull);
    });

    test('a non-finite offset resolves to the last chapter', () {
      final anchors = ReaderChapterAnchors.single(_a)
        ..append(chapterId: _b, boundaryOffset: 500);

      expect(anchors.activeChapterId(double.infinity), _b);
    });

    test('copies are independent, so a failed transition can restore state',
        () {
      final anchors = ReaderChapterAnchors.single(_a);
      final backup = anchors.copy();

      anchors.append(chapterId: _b, boundaryOffset: 500);
      expect(anchors.contains(_b), isTrue);

      final restored = backup.copy();
      expect(restored.contains(_b), isFalse);
      expect(restored.activeChapterId(900), _a);
    });

    test('reset drops every merged chapter', () {
      final anchors = ReaderChapterAnchors.single(_a)
        ..append(chapterId: _b, boundaryOffset: 500)
        ..reset(_c);

      expect(anchors.anchors.length, 1);
      expect(anchors.contains(_a), isFalse);
      expect(anchors.activeChapterId(5000), _c);
    });
  });
}
