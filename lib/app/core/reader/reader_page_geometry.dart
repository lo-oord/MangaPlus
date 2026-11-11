import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/painting.dart' show BoxFit;

/// How a manga page is fitted inside the reader viewport.
enum ReaderFitMode { width, height, screen, natural }

ReaderFitMode readerFitModeFrom(String? value) {
  switch (value) {
    case 'height':
      return ReaderFitMode.height;
    case 'screen':
      return ReaderFitMode.screen;
    case 'natural':
      return ReaderFitMode.natural;
    default:
      return ReaderFitMode.width;
  }
}

String readerFitModeValue(ReaderFitMode mode) {
  switch (mode) {
    case ReaderFitMode.width:
      return 'width';
    case ReaderFitMode.height:
      return 'height';
    case ReaderFitMode.screen:
      return 'screen';
    case ReaderFitMode.natural:
      return 'natural';
  }
}

/// The pixel dimensions of a page image.
///
/// The reader only needs these to reserve the exact amount of space a page will
/// occupy before the image is decoded. That is the difference between a stable
/// scroll and the old behaviour where every page started at a guessed height
/// and pushed the content below it once it finished decoding.
class ReaderPageSize {
  const ReaderPageSize({required this.width, required this.height});

  final int width;
  final int height;

  bool get isValid => width > 0 && height > 0;

  /// Width divided by height. Always positive for a valid size.
  double get aspectRatio => isValid ? width / height : 0;

  static ReaderPageSize? tryParse(dynamic raw) {
    if (raw is ReaderPageSize) return raw.isValid ? raw : null;
    if (raw is List && raw.length >= 2) {
      final width = raw[0];
      final height = raw[1];
      if (width is num && height is num) {
        return ReaderPageSize(width: width.round(), height: height.round());
      }
    }
    if (raw is Map) {
      final width = raw['w'] ?? raw['width'];
      final height = raw['h'] ?? raw['height'];
      if (width is num && height is num) {
        return ReaderPageSize(width: width.round(), height: height.round());
      }
    }
    return null;
  }

  List<int> toJson() => <int>[width, height];

  @override
  bool operator ==(Object other) =>
      other is ReaderPageSize && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() => 'ReaderPageSize(${width}x$height)';
}

/// A bounded, least-recently-used cache of measured page sizes.
///
/// Only the aspect ratio matters for layout, so entries are cheap. Keeping them
/// around is what lets a re-opened chapter (online or offline) reserve the right
/// height on the very first frame instead of re-measuring every page.
class ReaderPageMetricsStore {
  ReaderPageMetricsStore({
    Map<String, ReaderPageSize>? initial,
    this.capacity = 2400,
  }) : _sizes = LinkedHashMap<String, ReaderPageSize>() {
    if (initial != null) {
      for (final entry in initial.entries) {
        if (entry.key.trim().isEmpty || !entry.value.isValid) continue;
        _sizes[entry.key] = entry.value;
      }
      _prune();
    }
  }

  factory ReaderPageMetricsStore.fromJson(
    Map<String, dynamic>? json, {
    int capacity = 2400,
  }) {
    final parsed = <String, ReaderPageSize>{};
    if (json != null) {
      for (final entry in json.entries) {
        final size = ReaderPageSize.tryParse(entry.value);
        if (size == null) continue;
        parsed[entry.key] = size;
      }
    }
    return ReaderPageMetricsStore(initial: parsed, capacity: capacity);
  }

  final LinkedHashMap<String, ReaderPageSize> _sizes;
  final int capacity;

  int get length => _sizes.length;

  Map<String, ReaderPageSize> get entries =>
      UnmodifiableMapView<String, ReaderPageSize>(_sizes);

  ReaderPageSize? sizeOf(String? reference) {
    if (reference == null || reference.isEmpty) return null;
    return _sizes[reference];
  }

  bool isKnown(String? reference) =>
      reference != null &&
      reference.isNotEmpty &&
      _sizes.containsKey(reference);

  /// Stores [size] and returns whether it changed the stored value.
  bool put(String reference, ReaderPageSize? size) {
    if (reference.isEmpty || size == null || !size.isValid) return false;
    final previous = _sizes.remove(reference);
    _sizes[reference] = size;
    _prune();
    return previous != size;
  }

  void putAll(Map<String, ReaderPageSize> sizes) {
    for (final entry in sizes.entries) {
      final reference = entry.key;
      final size = entry.value;
      if (reference.isEmpty || !size.isValid) continue;
      _sizes.remove(reference);
      _sizes[reference] = size;
    }
    _prune();
  }

  bool remove(String reference) => _sizes.remove(reference) != null;

  void clear() => _sizes.clear();

  Map<String, dynamic> toJson() => <String, dynamic>{
        for (final entry in _sizes.entries) entry.key: entry.value.toJson(),
      };

  void _prune() {
    while (_sizes.length > capacity) {
      _sizes.remove(_sizes.keys.first);
    }
  }
}

/// The exact box a page occupies in the vertical reader.
class ReaderPageLayout {
  const ReaderPageLayout({
    required this.height,
    required this.imageWidth,
    required this.boxFit,
    required this.measured,
  });

  /// Height of the image box in logical pixels (never zero or infinite).
  final double height;

  /// Width the image is allowed to paint at.
  final double imageWidth;

  /// How the image is fitted inside the box; aspect ratio is never changed.
  final BoxFit boxFit;

  /// Whether [height] came from a measured aspect ratio or from the fallback.
  final bool measured;

  @override
  String toString() =>
      'ReaderPageLayout(h: $height, w: $imageWidth, fit: $boxFit, measured: $measured)';
}

/// Typical manga page aspect ratio (width / height). Used only until the real
/// dimensions of a page have been measured; it is never allowed to change an
/// already measured page.
const double kReaderFallbackPageAspectRatio = 0.68;

/// Upper bound for a single page box. Webtoon strips can be extremely tall but
/// Flutter cannot lay out an unbounded child; 20000 logical pixels is far
/// beyond any real page while still keeping the list finite.
const double kReaderMaximumPageHeight = 20000;

ReaderPageLayout resolveReaderPageLayout({
  required ReaderPageSize? size,
  required ReaderFitMode fit,
  required double viewportWidth,
  required double viewportHeight,
}) {
  final width =
      viewportWidth.isFinite && viewportWidth > 0 ? viewportWidth : 1.0;
  final height =
      viewportHeight.isFinite && viewportHeight > 0 ? viewportHeight : 1.0;
  final aspect = size != null && size.isValid
      ? size.aspectRatio
      : kReaderFallbackPageAspectRatio;
  final measured = size != null && size.isValid;

  double pageHeight;
  double imageWidth;
  BoxFit boxFit;
  switch (fit) {
    case ReaderFitMode.width:
      pageHeight = width / aspect;
      imageWidth = width;
      boxFit = BoxFit.fitWidth;
      break;
    case ReaderFitMode.height:
      pageHeight = height;
      imageWidth = width;
      boxFit = BoxFit.fitHeight;
      break;
    case ReaderFitMode.screen:
      pageHeight = math.min(height, width / aspect);
      imageWidth = width;
      boxFit = BoxFit.contain;
      break;
    case ReaderFitMode.natural:
      pageHeight = measured ? size.height.toDouble() : width / aspect;
      imageWidth = measured ? math.min(size.width.toDouble(), width) : width;
      boxFit = BoxFit.scaleDown;
      break;
  }
  if (!pageHeight.isFinite || pageHeight <= 0) pageHeight = height;
  pageHeight = pageHeight.clamp(1.0, kReaderMaximumPageHeight).toDouble();
  return ReaderPageLayout(
    height: pageHeight,
    imageWidth: imageWidth,
    boxFit: boxFit,
    measured: measured,
  );
}

/// One page position inside the vertical reader.
class ReaderPagePosition {
  const ReaderPagePosition({
    required this.index,
    required this.fractionWithinPage,
  });

  final int index;

  /// 0 at the top of the page, 1 at its bottom.
  final double fractionWithinPage;

  @override
  bool operator ==(Object other) =>
      other is ReaderPagePosition &&
      other.index == index &&
      other.fractionWithinPage == fractionWithinPage;

  @override
  int get hashCode => Object.hash(index, fractionWithinPage);
}

/// An immutable index of page extents that answers "which page is under the
/// viewport centre?" in O(log n), without touching render objects.
///
/// The previous reader walked every page key and called `localToGlobal` on each
/// scroll notification. That is layout work on the UI thread during a fling,
/// and it was a direct cause of dropped frames and visible stutter.
class ReaderPageScrollIndex {
  ReaderPageScrollIndex(List<double> extents)
      : _starts = List<double>.filled(extents.length, 0),
        _total = 0 {
    var offset = 0.0;
    for (var index = 0; index < extents.length; index++) {
      _starts[index] = offset;
      final extent = extents[index];
      offset += extent.isFinite && extent > 0 ? extent : 0;
    }
    _total = offset;
  }

  final List<double> _starts;
  double _total;

  static final ReaderPageScrollIndex empty = ReaderPageScrollIndex(const []);

  int get pageCount => _starts.length;
  double get totalExtent => _total;

  double startOf(int index) {
    if (index < 0) return 0;
    if (index >= _starts.length) return _total;
    return _starts[index];
  }

  /// The page under the viewport centre.
  ReaderPagePosition positionAt(
    double scrollOffset,
    double viewportExtent, {
    int fallbackIndex = 0,
  }) {
    if (_starts.isEmpty) {
      return ReaderPagePosition(index: 0, fractionWithinPage: 0);
    }
    final centre = (scrollOffset.isFinite ? scrollOffset : 0) +
        (viewportExtent.isFinite && viewportExtent > 0
            ? viewportExtent / 2
            : 0.0);
    var index = _indexForOffset(centre);
    if (index < 0) index = 0;
    if (index >= _starts.length) index = _starts.length - 1;
    final start = _starts[index];
    final end = index + 1 < _starts.length ? _starts[index + 1] : _total;
    final extent = end - start;
    final fraction = extent <= 0
        ? 0.0
        : ((centre - start) / extent).clamp(0.0, 1.0).toDouble();
    if (viewportExtent <= 0) {
      return ReaderPagePosition(
        index: fallbackIndex.clamp(0, _starts.length - 1).toInt(),
        fractionWithinPage: 0,
      );
    }
    return ReaderPagePosition(
      index: index,
      fractionWithinPage: fraction,
    );
  }

  /// Largest page whose start is at or before [offset].
  int _indexForOffset(double offset) {
    var low = 0;
    var high = _starts.length - 1;
    var result = 0;
    while (low <= high) {
      final mid = (low + high) >> 1;
      if (_starts[mid] <= offset + 0.01) {
        result = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return result;
  }
}
