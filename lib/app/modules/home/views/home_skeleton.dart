import 'package:flutter/material.dart';
import 'package:mangaplus/app/core/theme/design_tokens.dart';
import 'package:mangaplus/app/widgets/app_skeleton.dart';

/// The placeholder shown while the home screen loads its first page.
///
/// It mirrors the real layout (hero, page dots, genre chips, latest grid) so
/// the first paint already has the final geometry and nothing jumps when the
/// data arrives.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key, this.cardRows = 3, this.chipCount = 5});

  /// Number of three-column rows of card placeholders under "الأحدث".
  final int cardRows;

  /// Number of genre chip placeholders.
  final int chipCount;

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const HomeHeroSkeleton(),
            const SizedBox(height: 25),
            const _PageDotsSkeleton(),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SkeletonBox(width: 112, height: 16, radius: 6),
                  const SizedBox(height: 12),
                  _GenreChipsSkeleton(count: chipCount),
                  const SizedBox(height: 12),
                  const SkeletonBox(width: 74, height: 16, radius: 6),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  for (var row = 0; row < cardRows; row++)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 14),
                      child: ComicCardsRowSkeleton(),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

/// The hero carousel placeholder: a full-bleed cover with the badge, title
/// block, metadata pills and the "read now" button.
class HomeHeroSkeleton extends StatelessWidget {
  const HomeHeroSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: SizedBox(
        width: double.infinity,
        height: 404,
        child: Stack(
          children: [
            const Positioned.fill(
              child: SkeletonBox(borderRadius: BorderRadius.zero),
            ),
            const Positioned(
              top: 16,
              right: 16,
              child: SkeletonBox(width: 92, height: 28, radius: 18),
            ),
            Positioned(
              left: 22,
              right: 22,
              bottom: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SkeletonBox(width: 96, height: 12, radius: 6),
                  const SizedBox(height: 9),
                  const SkeletonBox(width: 216, height: 20, radius: 7),
                  const SizedBox(height: 7),
                  const SkeletonBox(width: 148, height: 20, radius: 7),
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      SkeletonBox(width: 62, height: 26, radius: 18),
                      SizedBox(width: 7),
                      SkeletonBox(width: 70, height: 26, radius: 18),
                      SizedBox(width: 7),
                      SkeletonBox(width: 84, height: 26, radius: 18),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const SkeletonBox(
                    width: double.infinity,
                    height: AppSizes.controlHeight,
                    radius: AppRadii.sm,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageDotsSkeleton extends StatelessWidget {
  const _PageDotsSkeleton({this.count = 5});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 0; index < count; index++) ...[
          if (index > 0) const SizedBox(width: 8),
          const SkeletonBox(width: 6, height: 6, radius: 3),
        ],
      ],
    );
  }
}

class _GenreChipsSkeleton extends StatelessWidget {
  const _GenreChipsSkeleton({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    const widths = <double>[76, 58, 88, 66, 72, 54, 80, 62];
    return SizedBox(
      height: 30,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: SkeletonBox(
            width: widths[index % widths.length],
            height: 30,
            radius: 15,
          ),
        ),
      ),
    );
  }
}
