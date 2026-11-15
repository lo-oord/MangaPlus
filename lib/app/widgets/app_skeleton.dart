import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/theme/app_palette.dart';
import 'package:mangaplus/app/core/theme/design_tokens.dart';
import 'package:mangaplus/app/widgets/custom_card_normal.dart';
import 'package:shimmer/shimmer.dart';

/// Wraps static placeholder shapes in a single shimmer sweep.
///
/// One [Shimmer] covers a whole skeleton instead of one per box, so the
/// highlight stays coherent across cards and the tree keeps a single ticker.
/// The animation is switched off when the platform asks for reduced motion;
/// the shapes keep their colour so the layout is still readable.
class AppSkeleton extends StatelessWidget {
  const AppSkeleton({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final base = palette.skeleton;
    // Dark surfaces need a faint lift, light ones a near-white highlight;
    // lerping the palette colour keeps both themes on the same recipe.
    final highlight = Color.lerp(base, Colors.white, palette.isDark ? .10 : .62)!;
    return Semantics(
      label: 'جارٍ تحميل المحتوى'.tr,
      container: true,
      child: ExcludeSemantics(
        child: Shimmer.fromColors(
          baseColor: base,
          highlightColor: highlight,
          period: const Duration(milliseconds: 1400),
          direction: ShimmerDirection.rtl,
          enabled: !reduceMotion,
          child: child,
        ),
      ),
    );
  }
}

/// A single rounded placeholder block.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.radius = AppRadii.sm,
    this.borderRadius,
    this.margin,
    this.shape = BoxShape.rectangle,
  });

  final double? width;
  final double? height;
  final double radius;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? margin;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: context.palette.skeleton,
        shape: shape,
        borderRadius: shape == BoxShape.circle
            ? null
            : (borderRadius ?? BorderRadius.circular(radius)),
      ),
    );
  }
}

/// A card placeholder that mirrors [CustomCardNormal]: cover, title, rating row
/// and release date. Sizes come from the real card so the layout does not jump
/// when the content replaces the skeleton.
class ComicCardSkeleton extends StatelessWidget {
  const ComicCardSkeleton({
    super.key,
    required this.width,
    this.showMetadata = true,
  });

  final double width;
  final bool showMetadata;

  @override
  Widget build(BuildContext context) {
    final coverHeight = width * CustomCardNormal.coverAspectRatio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkeletonBox(width: width, height: coverHeight, radius: AppRadii.sm),
        const SizedBox(height: 7),
        SkeletonBox(width: width * .78, height: 11, radius: 5),
        if (showMetadata) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const SkeletonBox(width: 10, height: 10, shape: BoxShape.circle),
              const SizedBox(width: 4),
              SkeletonBox(width: width * .28, height: 9, radius: 4),
              const SizedBox(width: 8),
              SkeletonBox(width: width * .24, height: 9, radius: 4),
            ],
          ),
          const SizedBox(height: 5),
          SkeletonBox(width: width * .42, height: 9, radius: 4),
        ],
      ],
    );
  }
}

/// One row of [count] card placeholders laid out like the home "latest" grid.
class ComicCardsRowSkeleton extends StatelessWidget {
  const ComicCardsRowSkeleton({
    super.key,
    this.count = 3,
    this.spacing = 8,
    this.showMetadata = true,
  });

  final int count;
  final double spacing;
  final bool showMetadata;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var slot = 0; slot < count; slot++) ...[
          if (slot > 0) SizedBox(width: spacing),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => ComicCardSkeleton(
                width: constraints.maxWidth,
                showMetadata: showMetadata,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A grid of card placeholders for the genre and search style grids.
class ComicGridSkeleton extends StatelessWidget {
  const ComicGridSkeleton({
    super.key,
    this.itemCount = 9,
    this.crossAxisCount = 3,
    this.padding = const EdgeInsets.fromLTRB(12, 8, 12, 24),
    this.crossAxisSpacing = 8,
    this.mainAxisSpacing = 10,
    this.mainAxisExtent = 236,
  });

  final int itemCount;
  final int crossAxisCount;
  final EdgeInsetsGeometry padding;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final double mainAxisExtent;

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      child: GridView.builder(
        padding: padding,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: crossAxisSpacing,
          mainAxisSpacing: mainAxisSpacing,
          mainAxisExtent: mainAxisExtent,
        ),
        itemCount: itemCount,
        itemBuilder: (context, index) => LayoutBuilder(
          builder: (context, constraints) =>
              ComicCardSkeleton(width: constraints.maxWidth),
        ),
      ),
    );
  }
}
