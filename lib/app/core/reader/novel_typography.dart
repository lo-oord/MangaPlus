import 'dart:math' as math;

/// Horizontal padding that keeps a novel chapter at a comfortable reading
/// measure on phones while still using the extra space on tablets.
///
/// [maxWidth] is the user's preferred text width. The padding is distributed
/// evenly, never drops below [minPadding], and never exceeds the space that is
/// actually available, so a very narrow window cannot produce negative padding.
double novelReadingPadding({
  required double viewportWidth,
  required double margins,
  required double maxWidth,
  double minPadding = 12,
}) {
  if (!viewportWidth.isFinite || viewportWidth <= 0) return minPadding;
  final safeMargins = margins.isFinite ? margins : minPadding;
  final safeMaxWidth = maxWidth.isFinite && maxWidth > 0 ? maxWidth : 720;
  final contentWidth = math.min(viewportWidth, safeMaxWidth);
  final extra = (viewportWidth - contentWidth) / 2;
  final padding = safeMargins + extra;
  final upperBound = math.max(minPadding, viewportWidth / 2 - 1);
  return padding.clamp(minPadding, upperBound).toDouble();
}
