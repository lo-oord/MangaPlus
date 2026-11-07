import 'package:mangaplus/app/core/utils/chapter_reference_identity.dart';

/// Where one chapter starts inside a merged reader stream.
class ReaderChapterAnchor {
  const ReaderChapterAnchor({required this.chapterId, required this.offset});

  final String chapterId;

  /// Scroll offset at which this chapter starts inside the merged content.
  final double offset;

  @override
  String toString() => 'ReaderChapterAnchor($chapterId @ $offset)';
}

/// Maps a scroll offset inside a merged reader stream onto the chapter that
/// actually occupies that position.
///
/// The reader merges the next (or previous) chapter into the same list so the
/// boundary has no loading frame. That merge also moves the "current chapter"
/// pointer to the newly merged chapter, while the reader may still be looking
/// at text that belongs to an earlier one. Navigation buttons, the chapter
/// header and bookmarks must follow the chapter the reader is actually reading,
/// not the last one merged in.
class ReaderChapterAnchors {
  ReaderChapterAnchors.single(String chapterId)
      : _anchors = <ReaderChapterAnchor>[
          ReaderChapterAnchor(chapterId: chapterId, offset: 0),
        ];

  ReaderChapterAnchors._(this._anchors);

  final List<ReaderChapterAnchor> _anchors;

  List<ReaderChapterAnchor> get anchors =>
      List<ReaderChapterAnchor>.unmodifiable(_anchors);

  ReaderChapterAnchors copy() =>
      ReaderChapterAnchors._(List<ReaderChapterAnchor>.of(_anchors));

  bool get isEmpty => _anchors.isEmpty;

  /// The chapter that contains [offset]. Falls back to the first anchor.
  String? activeChapterId(double offset) {
    if (_anchors.isEmpty) return null;
    var active = _anchors.first;
    if (!offset.isFinite) return _anchors.last.chapterId;
    for (final anchor in _anchors) {
      if (anchor.offset <= offset + 1) {
        active = anchor;
      } else {
        break;
      }
    }
    return active.chapterId;
  }

  bool contains(String reference) => offsetOf(reference) != null;

  /// The starting offset of [reference] inside the merged stream, if present.
  double? offsetOf(String reference) {
    if (reference.trim().isEmpty) return null;
    for (final anchor in _anchors) {
      if (anchor.chapterId.isEmpty) continue;
      if (ChapterReferenceIdentity.matches(
        anchor.chapterId,
        reference,
        baseReference: anchor.chapterId,
      )) {
        return anchor.offset;
      }
    }
    return null;
  }

  void reset(String chapterId) {
    _anchors
      ..clear()
      ..add(ReaderChapterAnchor(chapterId: chapterId, offset: 0));
  }

  /// Adds [chapterId] below the existing anchors.
  ///
  /// [boundaryOffset] is the scroll extent the content had before it was
  /// merged; anchors never move backwards, so an unknown or stale value simply
  /// keeps the previous boundary.
  void append({required String chapterId, required double boundaryOffset}) {
    final safeBoundary = boundaryOffset.isFinite && boundaryOffset > 0
        ? boundaryOffset
        : 0.0;
    final offset = _anchors.isEmpty || safeBoundary < _anchors.last.offset
        ? (_anchors.isEmpty ? 0.0 : _anchors.last.offset)
        : safeBoundary;
    _anchors.add(ReaderChapterAnchor(chapterId: chapterId, offset: offset));
  }

  /// Adds [chapterId] above the existing anchors after [addedExtent] pixels of
  /// content were inserted, shifting every existing boundary down.
  void prepend({required String chapterId, required double addedExtent}) {
    final shift = addedExtent.isFinite && addedExtent > 0 ? addedExtent : 0.0;
    for (var index = 0; index < _anchors.length; index++) {
      _anchors[index] = ReaderChapterAnchor(
        chapterId: _anchors[index].chapterId,
        offset: _anchors[index].offset + shift,
      );
    }
    _anchors.insert(0, ReaderChapterAnchor(chapterId: chapterId, offset: 0));
  }
}
