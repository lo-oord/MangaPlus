import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangaplus/app/widgets/manga_shimmer.dart';
import 'package:shimmer/shimmer.dart';

void main() {
  testWidgets('renders a correctly sized reusable skeleton image', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: MangaShimmer.box(width: 88, height: 120, radius: 12)),
        ),
      ),
    );

    expect(find.byType(Shimmer), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is SizedBox && widget.width == 88 && widget.height == 120,
      ),
      findsOneWidget,
    );
  });

  testWidgets('respects the system reduced-motion setting', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: const MaterialApp(
          home: Scaffold(body: MangaShimmer(child: SizedBox(width: 20, height: 20))),
        ),
      ),
    );

    final shimmer = tester.widget<Shimmer>(find.byType(Shimmer));
    expect(shimmer.enabled, isFalse);
  });
}
