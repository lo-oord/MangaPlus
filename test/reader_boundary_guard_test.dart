import 'package:flutter_test/flutter_test.dart';
import 'package:mangaplus/app/core/utils/reader_boundary_guard.dart';

void main() {
  group('scroll reader (manga and novel)', () {
    test('a freshly opened chapter at the end does not advance by itself', () {
      final guard = ReaderBoundaryGuard();

      expect(
        guard.consumeScrollEdge(atStart: false, atEnd: true),
        ReaderBoundaryMove.none,
      );
    });

    test('a reader gesture at the end advances exactly once', () {
      final guard = ReaderBoundaryGuard()..onUserMotion();

      expect(
        guard.consumeScrollEdge(atStart: false, atEnd: true),
        ReaderBoundaryMove.forward,
      );
      // The same gesture keeps producing end-of-content notifications.
      expect(
        guard.consumeScrollEdge(atStart: false, atEnd: true),
        ReaderBoundaryMove.none,
      );
    });

    test('layout notifications after a transition never cascade', () {
      final guard = ReaderBoundaryGuard()..onUserMotion();
      guard.consumeScrollEdge(atStart: false, atEnd: true);

      // A short chapter whose content does not fill the viewport: the end of
      // the content is true on every layout pass.
      guard.onTransitionCompleted();
      for (var frame = 0; frame < 12; frame++) {
        expect(
          guard.consumeScrollEdge(atStart: false, atEnd: true),
          ReaderBoundaryMove.none,
          reason: 'frame $frame must not open another chapter',
        );
      }
    });

    test('a chapter that fits the viewport does not jump to the previous one',
        () {
      final guard = ReaderBoundaryGuard();

      expect(
        guard.consumeScrollEdge(atStart: true, atEnd: true),
        ReaderBoundaryMove.none,
      );
    });

    test('scrolling back up from the top goes to the previous chapter', () {
      final guard = ReaderBoundaryGuard()..onUserMotion();

      expect(
        guard.consumeScrollEdge(atStart: true, atEnd: false),
        ReaderBoundaryMove.backward,
      );
      expect(
        guard.consumeScrollEdge(atStart: true, atEnd: false),
        ReaderBoundaryMove.none,
      );
    });

    test('restoring a saved offset never counts as reader motion', () {
      final guard = ReaderBoundaryGuard()
        ..onTransitionCompleted()
        ..onUserMotion()
        ..onTransitionCompleted();

      for (var frame = 0; frame < 5; frame++) {
        expect(
          guard.consumeScrollEdge(atStart: false, atEnd: true),
          ReaderBoundaryMove.none,
        );
      }
      expect(guard.isArmed, isFalse);
    });

    test('a gesture that ends away from the edge cannot leak into a relayout',
        () {
      final guard = ReaderBoundaryGuard()..onUserMotion();

      // The reader drags, stops in the middle of the chapter, then changes the
      // font size. The relayout lands at the end of the content.
      guard.onScrollSettled(atEdge: false);
      guard.onTransitionCompleted();
      expect(
        guard.consumeScrollEdge(atStart: false, atEnd: true),
        ReaderBoundaryMove.none,
      );
    });

    test('a gesture that settles exactly at the edge still advances', () {
      final guard = ReaderBoundaryGuard()..onUserMotion();

      guard.onScrollSettled(atEdge: true);
      expect(
        guard.consumeScrollEdge(atStart: false, atEnd: true),
        ReaderBoundaryMove.forward,
      );
    });

    test('a new gesture after a transition may advance again', () {
      final guard = ReaderBoundaryGuard()..onUserMotion();
      guard.consumeScrollEdge(atStart: false, atEnd: true);
      guard.onTransitionCompleted();

      guard.onUserMotion();
      expect(
        guard.consumeScrollEdge(atStart: false, atEnd: true),
        ReaderBoundaryMove.forward,
      );
    });
  });

  group('paged manga reader', () {
    test('a single-page chapter does not advance when it opens', () {
      final guard = ReaderBoundaryGuard()..onTransitionCompleted(landingPage: 0);

      expect(guard.consumePageBoundary(0, 1), ReaderBoundaryMove.none);
      // Rebuilding the page view re-reports the same page.
      expect(guard.consumePageBoundary(0, 1), ReaderBoundaryMove.none);
      guard.onScrollSettled(atEdge: false);
      expect(guard.consumePageBoundary(0, 1), ReaderBoundaryMove.none);
    });

    test('landing on the last page after a merge is not a flip', () {
      final guard = ReaderBoundaryGuard()..onTransitionCompleted(landingPage: 9);

      expect(guard.consumePageBoundary(9, 10), ReaderBoundaryMove.none);
      expect(guard.consumePageBoundary(9, 10), ReaderBoundaryMove.none);
    });

    test('flipping into the last page advances exactly once', () {
      final guard = ReaderBoundaryGuard()..onTransitionCompleted(landingPage: 0);

      expect(guard.consumePageBoundary(0, 2), ReaderBoundaryMove.none);
      expect(guard.consumePageBoundary(1, 2), ReaderBoundaryMove.forward);
      expect(guard.consumePageBoundary(1, 2), ReaderBoundaryMove.none);
    });

    test('a programmatic seek to the last page does not advance', () {
      // Regression guard for restoring bookmarks and saved progress.

      final guard = ReaderBoundaryGuard()..onTransitionCompleted(landingPage: 0);
      guard.consumePageBoundary(0, 6);

      guard.onTransitionCompleted(landingPage: 5);
      expect(guard.consumePageBoundary(5, 6), ReaderBoundaryMove.none);
      // A real flip after the seek still works.
      guard.onTransitionCompleted(landingPage: 3);
      guard.consumePageBoundary(3, 6);
      expect(guard.consumePageBoundary(5, 6), ReaderBoundaryMove.forward);
    });

    test('the first observed page of a chapter never advances', () {
      final guard = ReaderBoundaryGuard();

      expect(guard.consumePageBoundary(3, 4), ReaderBoundaryMove.none);
      expect(guard.consumePageBoundary(3, 4), ReaderBoundaryMove.none);
    });
  });
}
