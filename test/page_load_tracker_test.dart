import 'package:flutter_test/flutter_test.dart';
import 'package:mangaplus/app/core/utils/page_load_tracker.dart';

void main() {
  group('PageLoadTracker', () {
    test('reports the real loaded ratio, not a scroll estimate', () {
      final tracker = PageLoadTracker(4);

      expect(tracker.progress, 0);
      tracker.markLoaded(0);
      expect(tracker.progress, 0.25);
      tracker.markLoaded(1);
      tracker.markLoaded(3);
      expect(tracker.progress, 0.75);
      expect(tracker.isComplete, isFalse);
      tracker.markLoaded(2);
      expect(tracker.progress, 1);
      expect(tracker.isComplete, isTrue);
    });

    test('failed pages are not counted as loaded until retried', () {
      final tracker = PageLoadTracker(2);
      tracker.markLoaded(0);
      tracker.markFailed(1);

      expect(tracker.progress, 0.5);
      expect(tracker.failedCount, 1);
      expect(tracker.isComplete, isFalse);

      tracker.retry(1);
      expect(tracker.failedCount, 0);
      expect(tracker.pendingCount, 1);

      tracker.markLoaded(1);
      expect(tracker.progress, 1);
    });

    test('a failed page that later loads is removed from failures', () {
      final tracker = PageLoadTracker(1)..markFailed(0);
      expect(tracker.failedCount, 1);
      tracker.markLoaded(0);
      expect(tracker.failedCount, 0);
      expect(tracker.loadedCount, 1);
    });

    test('ignores out-of-range page indexes', () {
      final tracker = PageLoadTracker(2);
      tracker.markLoaded(-1);
      tracker.markLoaded(2);
      tracker.markFailed(9);
      tracker.retry(4);

      expect(tracker.loadedCount, 0);
      expect(tracker.failedCount, 0);
      expect(tracker.progress, 0);
    });

    test('appending a chapter keeps the pages already loaded', () {
      final tracker = PageLoadTracker(2)..markLoaded(0);
      tracker.expandTo(5);

      expect(tracker.total, 5);
      expect(tracker.loadedCount, 1);
      expect(tracker.progress, 0.2);
    });

    test('prepending pages shifts loaded indexes with their pages', () {
      final tracker = PageLoadTracker(2)
        ..markLoaded(0)
        ..markFailed(1);
      tracker.prepend(3);

      expect(tracker.total, 5);
      expect(tracker.isLoaded(3), isTrue);
      expect(tracker.isFailed(4), isTrue);
      expect(tracker.isLoaded(0), isFalse);
    });

    test('a new chapter resets the real counters', () {
      final tracker = PageLoadTracker(2)..markLoaded(0);
      tracker.reset(3);

      expect(tracker.total, 3);
      expect(tracker.loadedCount, 0);
      expect(tracker.failedCount, 0);
      expect(tracker.progress, 0);
    });

    test('unknown page count never invents a percentage', () {
      final tracker = PageLoadTracker(0);

      expect(tracker.hasPages, isFalse);
      expect(tracker.progress, 0);
      expect(tracker.isComplete, isFalse);
    });
  });
}
