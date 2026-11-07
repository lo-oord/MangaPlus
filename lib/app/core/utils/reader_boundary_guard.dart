/// What the reader should do after the edge of the current content is reached.
enum ReaderBoundaryMove { none, forward, backward }

/// Decides whether reaching the edge of the current content may start a chapter
/// transition.
///
/// Readers used to advance whenever a scroll or page notification reported the
/// boundary. A transition itself re-lays out the content, so the boundary
/// condition was still true right after it completed: a one-page manga chapter
/// or a short novel chapter was consumed immediately, one after another, and a
/// single flip could skip several chapters. Programmatic jumps (restoring a
/// saved offset, re-syncing the page controller, seeking) had the same effect
/// although the reader never asked to move.
///
/// The guard therefore allows at most one automatic transition per reader
/// motion, and never for the frame a transition lands on.
class ReaderBoundaryGuard {
  ReaderBoundaryGuard({bool armed = false}) : _armed = armed;

  /// Whether a reader motion happened since the last transition.
  bool _armed;
  int? _lastPage;
  int? _landingPage;

  bool get isArmed => _armed;

  /// The reader moved the content (drag, fling, overscroll, page flip).
  void onUserMotion() {
    _armed = true;
  }

  /// The scroll settled. A gesture that ends away from an edge is over, so a
  /// later relayout (opening the settings, a font-size change, images that
  /// change their height) can never inherit it and open a chapter by itself.
  void onScrollSettled({required bool atEdge}) {
    if (!atEdge) _armed = false;
  }

  /// A chapter transition (or an initial chapter load) just landed on
  /// [landingPage] in paged mode. Until the reader moves again, boundary
  /// notifications are layout, not intent.
  void onTransitionCompleted({int? landingPage}) {
    _armed = false;
    _landingPage = landingPage;
    if (landingPage != null) _lastPage = landingPage;
  }

  /// Scroll mode: asks once per reader motion whether the reader is at an edge
  /// that should move the chapter.
  ///
  /// [atStart] should only be passed when the reader is actually scrolling
  /// backwards (an upward drag), so a short chapter that fits the viewport does
  /// not jump to the previous chapter on load.
  ReaderBoundaryMove consumeScrollEdge({
    required bool atStart,
    required bool atEnd,
  }) {
    if (!_armed) return ReaderBoundaryMove.none;
    if (atEnd) {
      _armed = false;
      return ReaderBoundaryMove.forward;
    }
    if (atStart) {
      _armed = false;
      return ReaderBoundaryMove.backward;
    }
    return ReaderBoundaryMove.none;
  }

  /// Paged mode: a chapter only advances when the reader flipped *into* the
  /// last page. Landing on the last page of a freshly loaded chapter, or a
  /// rebuild that re-reports the same page, is not a flip.
  ReaderBoundaryMove consumePageBoundary(int page, int pageCount) {
    if (pageCount <= 0) return ReaderBoundaryMove.none;
    final landing = _landingPage;
    if (landing != null) {
      _landingPage = null;
      _lastPage = page;
      if (page == landing) return ReaderBoundaryMove.none;
    }
    final previous = _lastPage;
    _lastPage = page;
    if (page != pageCount - 1) return ReaderBoundaryMove.none;
    if (previous == null || previous == page) return ReaderBoundaryMove.none;
    return ReaderBoundaryMove.forward;
  }
}
