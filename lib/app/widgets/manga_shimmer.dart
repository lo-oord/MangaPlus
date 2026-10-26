import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Shared, theme-aware skeleton animation. The existing shimmer dependency is
/// reused and the animation is automatically disabled for reduced-motion and
/// inactive ticker subtrees.
class MangaShimmer extends StatelessWidget {
  const MangaShimmer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF242B35) : const Color(0xFFE7EBF1),
      highlightColor: isDark ? const Color(0xFF34445A) : const Color(0xFFF7F9FC),
      period: const Duration(milliseconds: 1450),
      direction: ShimmerDirection.ltr,
      enabled: !reduceMotion && TickerMode.of(context),
      child: ExcludeSemantics(child: child),
    );
  }

  /// A non-animated shape for use inside one [MangaShimmer] group, avoiding a
  /// separate animation controller for every line in a skeleton.
  static Widget shape({
    double? width,
    double? height,
    double radius = 8,
    BorderRadius? borderRadius,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: borderRadius ?? BorderRadius.circular(radius),
      ),
      child: SizedBox(width: width, height: height),
    );
  }

  /// Animated placeholder for a single remote image that loads independently.
  static Widget box({
    double? width,
    required double height,
    double radius = 8,
    BorderRadius? borderRadius,
  }) {
    return MangaShimmer(
      child: shape(
        width: width,
        height: height,
        radius: radius,
        borderRadius: borderRadius,
      ),
    );
  }

  /// Fills the constraints supplied by an image or page placeholder.
  static Widget fill({BorderRadius? borderRadius}) {
    return MangaShimmer(
      child: SizedBox.expand(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: borderRadius,
          ),
        ),
      ),
    );
  }
}
