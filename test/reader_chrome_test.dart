import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangaplus/app/core/reader/reader_reading_preset.dart';
import 'package:mangaplus/app/core/theme/theme.dart';
import 'package:mangaplus/app/modules/chapter/widgets/reader_chrome.dart';

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(body: child),
    );

void main() {
  group('ReaderChromeAutoHide', () {
    testWidgets('hides exactly once after the delay', (tester) async {
      var hidden = 0;
      final autoHide = ReaderChromeAutoHide(
        onHide: () => hidden++,
        delay: const Duration(milliseconds: 200),
      );
      addTearDown(autoHide.dispose);

      autoHide.schedule();
      autoHide.schedule();
      await tester.pump(const Duration(milliseconds: 150));
      expect(hidden, 0);

      await tester.pump(const Duration(milliseconds: 100));
      expect(hidden, 1);

      await tester.pump(const Duration(seconds: 2));
      expect(hidden, 1);
      expect(autoHide.isPending, isFalse);
    });

    testWidgets('cancel stops a pending hide', (tester) async {
      var hidden = 0;
      final autoHide = ReaderChromeAutoHide(
        onHide: () => hidden++,
        delay: const Duration(milliseconds: 200),
      );
      addTearDown(autoHide.dispose);

      autoHide.schedule();
      autoHide.cancel();
      await tester.pump(const Duration(milliseconds: 400));
      expect(hidden, 0);
      expect(autoHide.isPending, isFalse);
    });

    testWidgets('pause blocks scheduling until resumed', (tester) async {
      var hidden = 0;
      final autoHide = ReaderChromeAutoHide(
        onHide: () => hidden++,
        delay: const Duration(milliseconds: 120),
      );
      addTearDown(autoHide.dispose);

      autoHide.pause();
      autoHide.schedule();
      await tester.pump(const Duration(milliseconds: 300));
      expect(hidden, 0);
      expect(autoHide.isPaused, isTrue);

      autoHide.resume();
      autoHide.schedule();
      await tester.pump(const Duration(milliseconds: 160));
      expect(hidden, 1);
    });

    testWidgets('dispose cancels a pending hide', (tester) async {
      var hidden = 0;
      final autoHide = ReaderChromeAutoHide(
        onHide: () => hidden++,
        delay: const Duration(milliseconds: 100),
      );

      autoHide.schedule();
      autoHide.dispose();
      await tester.pump(const Duration(milliseconds: 300));
      expect(hidden, 0);
    });
  });

  group('webtoon preset', () {
    test('requires continuous scroll, fit width, no gap and one page', () {
      expect(
        readerIsWebtoonPreset(
          isNovel: false,
          mode: 'scroll',
          fit: 'width',
          gap: 0,
          doublePage: false,
        ),
        isTrue,
      );
    });

    test('rejects every other combination', () {
      bool preset({
        bool novel = false,
        String mode = 'scroll',
        String fit = 'width',
        double gap = 0,
        bool doublePage = false,
      }) =>
          readerIsWebtoonPreset(
            isNovel: novel,
            mode: mode,
            fit: fit,
            gap: gap,
            doublePage: doublePage,
          );

      expect(preset(mode: 'paged'), isFalse);
      expect(preset(fit: 'screen'), isFalse);
      expect(preset(gap: 4), isFalse);
      expect(preset(doublePage: true), isFalse);
      expect(preset(novel: true), isFalse);
    });
  });

  group('ReaderTopBar', () {
    testWidgets('shows manga, chapter, page and progress', (tester) async {
      await tester.pumpWidget(
        _host(
          ReaderTopBar(
            comicTitle: 'عنوان المانجا',
            chapterTitle: 'الفصل الرابع',
            coverReference: '',
            pageLabel: '3 / 20',
            progress: .15,
            onBack: () {},
            onBookmark: () {},
            onTools: () {},
          ),
        ),
      );

      expect(find.text('عنوان المانجا'), findsOneWidget);
      expect(find.text('الفصل الرابع'), findsOneWidget);
      expect(find.text('3 / 20'), findsOneWidget);
      expect(find.text('15%'), findsOneWidget);
    });

    testWidgets('invokes back, bookmark and tools', (tester) async {
      var back = 0;
      var bookmark = 0;
      var tools = 0;
      await tester.pumpWidget(
        _host(
          ReaderTopBar(
            comicTitle: '',
            chapterTitle: 'الفصل',
            coverReference: '',
            pageLabel: '1 / 2',
            progress: 0,
            onBack: () => back++,
            onBookmark: () => bookmark++,
            onTools: () => tools++,
          ),
        ),
      );

      await tester.tap(find.byTooltip('رجوع'));
      await tester.tap(find.byTooltip('حفظ موضع القراءة'));
      await tester.tap(find.byTooltip('أدوات القارئ'));
      expect(back, 1);
      expect(bookmark, 1);
      expect(tools, 1);
    });
  });

  group('ReaderBottomBar', () {
    testWidgets('shows page label with progress and enables actions',
        (tester) async {
      var pages = 0;
      var chapters = 0;
      var mode = 0;
      double? seeked;
      var seekEnded = 0;
      await tester.pumpWidget(
        _host(
          ReaderBottomBar(
            chapterTitle: 'الفصل الرابع',
            pageLabel: '3 / 20',
            progress: .15,
            onSeek: (value) => seeked = value,
            onSeekEnd: () => seekEnded++,
            onPages: () => pages++,
            onChapters: () => chapters++,
            onToggleMode: () => mode++,
          ),
        ),
      );

      expect(find.text('3 / 20 • 15%'), findsOneWidget);

      await tester.tap(find.byTooltip('الصفحات'));
      await tester.tap(find.byTooltip('قائمة الفصول'));
      await tester.tap(find.byTooltip('تبديل وضع القراءة'));
      expect(pages, 1);
      expect(chapters, 1);
      expect(mode, 1);

      await tester.drag(find.byType(Slider), const Offset(80, 0));
      expect(seeked, isNotNull);
      expect(seekEnded, 1);
    });

    testWidgets('disables chapter buttons when there is no neighbour',
        (tester) async {
      await tester.pumpWidget(
        _host(
          ReaderBottomBar(
            pageLabel: '1 / 1',
            progress: 0,
            onSeek: (_) {},
            onSeekEnd: () {},
            onPages: () {},
            onChapters: () {},
          ),
        ),
      );

      final previous = tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip('الفصل السابق'),
          matching: find.byType(IconButton),
        ),
      );
      final next = tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip('الفصل التالي'),
          matching: find.byType(IconButton),
        ),
      );
      expect(previous.onPressed, isNull);
      expect(next.onPressed, isNull);
    });

    testWidgets('shows a retry affordance for failed pages', (tester) async {
      var retried = 0;
      await tester.pumpWidget(
        _host(
          ReaderBottomBar(
            pageLabel: '2 / 9',
            progress: .2,
            failedPages: 2,
            onRetryFailedPages: () => retried++,
            onSeek: (_) {},
            onSeekEnd: () {},
            onPages: () {},
            onChapters: () {},
          ),
        ),
      );

      expect(find.text('2 فشل'), findsOneWidget);
      await tester.tap(find.text('2 فشل'));
      expect(retried, 1);
    });
  });
}
