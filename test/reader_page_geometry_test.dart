import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangaplus/app/core/reader/reader_page_geometry.dart';

void main() {
  group('resolveReaderPageLayout', () {
    const size = ReaderPageSize(width: 1000, height: 1500);

    test('reserves the measured aspect ratio for fit width', () {
      final layout = resolveReaderPageLayout(
        size: size,
        fit: ReaderFitMode.width,
        viewportWidth: 400,
        viewportHeight: 800,
      );
      expect(layout.height, closeTo(600, .001));
      expect(layout.measured, isTrue);
      expect(layout.boxFit, BoxFit.fitWidth);
    });

    test('height and screen fits never distort the image', () {
      final heightFit = resolveReaderPageLayout(
        size: size,
        fit: ReaderFitMode.height,
        viewportWidth: 400,
        viewportHeight: 500,
      );
      expect(heightFit.height, 500);
      expect(heightFit.boxFit, BoxFit.fitHeight);

      final screenFit = resolveReaderPageLayout(
        size: size,
        fit: ReaderFitMode.screen,
        viewportWidth: 400,
        viewportHeight: 500,
      );
      // 400 / 0.6667 = 600 > 500, so the page is bounded by the height.
      expect(screenFit.height, 500);
      expect(screenFit.boxFit, BoxFit.contain);
    });

    test('natural size is never upscaled past the viewport width', () {
      final layout = resolveReaderPageLayout(
        size: size,
        fit: ReaderFitMode.natural,
        viewportWidth: 400,
        viewportHeight: 800,
      );
      expect(layout.height, 1500);
      expect(layout.imageWidth, 400);
      expect(layout.boxFit, BoxFit.scaleDown);
    });

    test('unknown sizes use a stable fallback, never zero', () {
      final layout = resolveReaderPageLayout(
        size: null,
        fit: ReaderFitMode.width,
        viewportWidth: 400,
        viewportHeight: 800,
      );
      expect(
          layout.height, closeTo(400 / kReaderFallbackPageAspectRatio, .001));
      expect(layout.measured, isFalse);
      expect(layout.height, greaterThan(0));
    });

    test('invalid and huge sizes stay finite', () {
      final invalid = resolveReaderPageLayout(
        size: const ReaderPageSize(width: 0, height: 0),
        fit: ReaderFitMode.width,
        viewportWidth: 0,
        viewportHeight: 0,
      );
      expect(invalid.height.isFinite, isTrue);
      expect(invalid.height, greaterThan(0));

      final huge = resolveReaderPageLayout(
        size: const ReaderPageSize(width: 800, height: 900000),
        fit: ReaderFitMode.natural,
        viewportWidth: 400,
        viewportHeight: 800,
      );
      expect(huge.height, kReaderMaximumPageHeight);
    });
  });

  group('ReaderPageScrollIndex', () {
    final index = ReaderPageScrollIndex(const [100, 200, 300]);

    test('finds the page and fraction under the viewport centre', () {
      final position = index.positionAt(150, 100);
      expect(position.index, 1);
      expect(position.fractionWithinPage, closeTo(.5, .001));
    });

    test('clamps offsets outside the content', () {
      expect(index.positionAt(-50, 100).index, 0);
      expect(index.positionAt(9999, 100).index, 2);
      expect(ReaderPageScrollIndex.empty.positionAt(0, 100).index, 0);
    });

    test('exposes exact starts and total extent', () {
      expect(index.startOf(0), 0);
      expect(index.startOf(2), 300);
      expect(index.totalExtent, 600);
    });
  });

  group('ReaderPageMetricsStore', () {
    test('is a bounded LRU keyed by page reference', () {
      final store = ReaderPageMetricsStore(capacity: 2);
      expect(
          store.put('a', const ReaderPageSize(width: 10, height: 20)), isTrue);
      store.put('b', const ReaderPageSize(width: 10, height: 20));
      store.put('c', const ReaderPageSize(width: 10, height: 20));
      expect(store.sizeOf('a'), isNull);
      expect(store.sizeOf('c'), isNotNull);
      expect(store.length, 2);
    });

    test('round-trips through JSON and ignores invalid entries', () {
      final store = ReaderPageMetricsStore.fromJson({
        'a': [100, 200],
        'b': [0, 0],
        'c': {'w': 300, 'h': 600},
      });
      expect(store.length, 2);
      expect(store.sizeOf('a'), const ReaderPageSize(width: 100, height: 200));
      expect(store.toJson()['c'], [300, 600]);
    });
  });
}
