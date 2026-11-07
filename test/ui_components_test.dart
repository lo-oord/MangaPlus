import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/core/utils/bidi_text.dart';
import 'package:mangaplus/app/widgets/brand_state.dart';
import 'package:mangaplus/app/widgets/mangaplus_app_bar.dart';

void main() {
  setUp(() => AppColors.refreshTheme(false));

  group('bidiTextDirection', () {
    test('resolves the first strong character', () {
      expect(bidiTextDirection('مرحبا'), TextDirection.rtl);
      expect(bidiTextDirection('MangaPlus'), TextDirection.ltr);
      expect(bidiTextDirection('مرحبا MangaPlus'), TextDirection.rtl);
      expect(bidiTextDirection('MangaPlus مرحبا'), TextDirection.ltr);
    });

    test('falls back for neutral or empty text', () {
      expect(bidiTextDirection('123 !'), TextDirection.ltr);
      expect(bidiTextDirection(''), TextDirection.ltr);
      expect(bidiTextDirection(null), TextDirection.ltr);
      expect(
        bidiTextDirection('123', fallback: TextDirection.rtl),
        TextDirection.rtl,
      );
    });
  });

  testWidgets('MangaPlusAppBar keeps one height and an RTL page title',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          appBar: MangaPlusAppBar(title: 'الإعدادات'),
          body: SizedBox.shrink(),
        ),
      ),
    );

    final bar = tester.widget<AppBar>(find.byType(AppBar));
    expect(bar.preferredSize.height, 60);
    expect(bar.centerTitle, isTrue);

    final title = tester.widget<Text>(find.text('الإعدادات'));
    expect(title.overflow, TextOverflow.ellipsis);
    expect(title.maxLines, 1);
    expect(title.textDirection, TextDirection.rtl);
  });

  testWidgets('MangaPlusAppBar supports a content driven title',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          appBar: MangaPlusAppBar(
            centerTitle: false,
            titleWidget: Text('اسم عمل طويل جدًا'),
          ),
          body: SizedBox.shrink(),
        ),
      ),
    );

    final bar = tester.widget<AppBar>(find.byType(AppBar));
    expect(bar.centerTitle, isFalse);
    expect(find.text('اسم عمل طويل جدًا'), findsOneWidget);
  });

  testWidgets('MangaPlusLoader shows its label and real progress',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: MangaPlusLoader(progress: 0.42, label: 'جارٍ تحميل الفصول'),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('جارٍ تحميل الفصول'), findsOneWidget);
    expect(find.text('42%'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // Replacing the loader must dispose its ticker without leaking.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('determinate progress needs no running animation',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: MangaPlusLoader(progress: 0.2))),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.binding.transientCallbackCount, 0);
    expect(find.text('20%'), findsOneWidget);
  });

  testWidgets('MangaPlusLoader honours reduced motion', (tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: Scaffold(body: Center(child: MangaPlusLoader())),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
