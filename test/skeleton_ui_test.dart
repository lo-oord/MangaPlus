import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangaplus/app/core/theme/theme.dart';
import 'package:mangaplus/app/modules/home/views/home_skeleton.dart';
import 'package:mangaplus/app/widgets/app_skeleton.dart';
import 'package:mangaplus/app/widgets/brand_state.dart';
import 'package:mangaplus/app/widgets/custom_card_normal.dart';
import 'package:shimmer/shimmer.dart';

Widget _host(Widget child, {bool reduceMotion = false}) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: child),
        ),
      ),
    ),
  );
}

void main() {
  group('skeletons', () {
    testWidgets('home skeleton replaces the loader with placeholders',
        (tester) async {
      await tester.pumpWidget(_host(const HomeSkeleton()));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(HomeHeroSkeleton), findsOneWidget);
      expect(find.byType(ComicCardSkeleton), findsWidgets);
      expect(find.byType(MangaPlusLoader), findsNothing);
      // One shimmer for the whole screen keeps a single ticker alive.
      expect(find.byType(Shimmer), findsOneWidget);
    });

    testWidgets('shimmer pauses when the platform disables animations',
        (tester) async {
      await tester.pumpWidget(_host(const HomeSkeleton(), reduceMotion: true));

      expect(tester.widget<Shimmer>(find.byType(Shimmer)).enabled, isFalse);
    });

    testWidgets('card placeholders keep the real cover aspect ratio',
        (tester) async {
      await tester.pumpWidget(_host(
        const Center(
          child: SizedBox(
            width: 300,
            child: ComicCardsRowSkeleton(count: 3, showMetadata: false),
          ),
        ),
      ));

      final covers = tester
          .widgetList<SkeletonBox>(find.byType(SkeletonBox))
          .where((box) => box.height != null && box.height! > 50)
          .toList();
      expect(covers, hasLength(3));
      for (final cover in covers) {
        expect(
          cover.height! / cover.width!,
          closeTo(CustomCardNormal.coverAspectRatio, 0.01),
        );
      }
    });
  });
}
