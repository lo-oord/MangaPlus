import 'package:flutter_test/flutter_test.dart';
import 'package:mangaplus/app/core/reader/reader_page_geometry.dart';

void main() {
  group('readerPageDecodeSize', () {
    test('an ordinary page keeps the previous decode width', () {
      final size = readerPageDecodeSize(
        size: const ReaderPageSize(width: 800, height: 1176),
        viewportWidth: 400,
        viewportHeight: 800,
        devicePixelRatio: 3,
      );
      expect(size.width, 1200);
      // A measured page keeps its aspect ratio, so no height is requested.
      expect(size.height, isNull);
    });

    test('the quality setting still scales the decode width', () {
      final low = readerPageDecodeSize(
        size: const ReaderPageSize(width: 800, height: 1176),
        viewportWidth: 400,
        viewportHeight: 800,
        devicePixelRatio: 3,
        quality: 'low',
      );
      final high = readerPageDecodeSize(
        size: const ReaderPageSize(width: 800, height: 1176),
        viewportWidth: 400,
        viewportHeight: 800,
        devicePixelRatio: 3,
        quality: 'high',
      );
      expect(low.width, 900);
      expect(high.width, 1560);
    });

    test('a very tall webtoon page is bounded by the pixel budget', () {
      // 800x12000 at a 1200 px decode width would be 1200x18000 (~86 MB).
      final size = readerPageDecodeSize(
        size: const ReaderPageSize(width: 800, height: 12000),
        viewportWidth: 400,
        viewportHeight: 800,
        devicePixelRatio: 3,
      );
      final width = size.width!;
      final height = width * 12000 / 800;
      expect(width, lessThan(1200));
      expect(width, greaterThanOrEqualTo(700));
      expect(
        width * height,
        lessThanOrEqualTo(kReaderDecodedPagePixelBudget + 1000),
      );
      expect(size.height, isNull);
    });

    test('an extreme strip is bounded by the absolute height ceiling', () {
      // 800x48000 has a ~1:60 aspect ratio; the height ceiling binds first.
      final size = readerPageDecodeSize(
        size: const ReaderPageSize(width: 800, height: 48000),
        viewportWidth: 400,
        viewportHeight: 800,
        devicePixelRatio: 3,
      );
      final width = size.width!;
      expect(width, greaterThan(0));
      expect(width * 48000 / 800, lessThanOrEqualTo(kReaderMaximumDecodedPageHeight));
    });

    test('an unmeasured page asks for a bounded height until it is measured', () {
      final size = readerPageDecodeSize(
        size: null,
        viewportWidth: 400,
        viewportHeight: 800,
        devicePixelRatio: 3,
      );
      expect(size.width, 1200);
      expect(size.height, (800 * 3 * 3).clamp(1024, kReaderUnmeasuredPageMaxHeight));
      expect(size.height, lessThanOrEqualTo(kReaderUnmeasuredPageMaxHeight));
    });

    test('natural fit never decodes wider than the source image', () {
      final size = readerPageDecodeSize(
        size: const ReaderPageSize(width: 700, height: 1000),
        viewportWidth: 400,
        viewportHeight: 800,
        devicePixelRatio: 3,
        natural: true,
      );
      expect(size.width, 700);
    });

    test('a tiny viewport still produces a usable decode width', () {
      final size = readerPageDecodeSize(
        size: const ReaderPageSize(width: 800, height: 1176),
        viewportWidth: 120,
        viewportHeight: 200,
        devicePixelRatio: 1,
      );
      expect(size.width, 320);
    });

    test('degenerate inputs never produce a zero or infinite width', () {
      final size = readerPageDecodeSize(
        size: const ReaderPageSize(width: 0, height: 0),
        viewportWidth: 0,
        viewportHeight: 0,
        devicePixelRatio: 0,
      );
      expect(size.width, greaterThan(0));
      expect(size.width, lessThanOrEqualTo(2400));
    });
  });
}
