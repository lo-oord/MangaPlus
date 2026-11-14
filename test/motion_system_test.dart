import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangaplus/app/core/navigation/app_navigation.dart';
import 'package:mangaplus/app/core/theme/app_motion.dart';
import 'package:mangaplus/app/core/theme/theme.dart';
import 'package:mangaplus/app/widgets/app_motion_widgets.dart';

Widget _host(Widget child, {bool reduceMotion = false}) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    home: MediaQuery(
      data: const MediaQueryData().copyWith(disableAnimations: reduceMotion),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

FadeTransition _entryFade(WidgetTester tester) {
  return tester.widget<FadeTransition>(
    find.descendant(
      of: find.byType(AnimatedEntry),
      matching: find.byType(FadeTransition),
    ),
  );
}

AnimatedScale _pressScale(WidgetTester tester) {
  return tester.widget<AnimatedScale>(
    find.descendant(
      of: find.byType(PressableScale),
      matching: find.byType(AnimatedScale),
    ),
  );
}

void main() {
  group('AppMotion', () {
    testWidgets('collapses durations and press scale for reduced motion',
        (tester) async {
      await tester.pumpWidget(
        _host(const SizedBox(width: 10, height: 10), reduceMotion: true),
      );
      final context = tester.element(find.byType(Scaffold));

      expect(AppMotion.reduceMotion(context), isTrue);
      expect(
        AppMotion.effective(context, AppMotion.slow),
        Duration.zero,
      );
      expect(AppMotion.effective(context, AppMotion.page), Duration.zero);
      expect(AppMotion.scaleFor(context), 1);
    });

    testWidgets('keeps the shared durations when motion is enabled',
        (tester) async {
      await tester.pumpWidget(
        _host(const SizedBox(width: 10, height: 10)),
      );
      final context = tester.element(find.byType(Scaffold));

      expect(AppMotion.reduceMotion(context), isFalse);
      expect(AppMotion.effective(context, AppMotion.slow), AppMotion.slow);
      expect(AppMotion.scaleFor(context), AppMotion.pressedScale);
    });
  });

  group('AnimatedEntry', () {
    testWidgets('animates in and settles fully visible', (tester) async {
      await tester.pumpWidget(_host(const AnimatedEntry(child: Text('جاهز'))));
      await tester.pump();
      expect(_entryFade(tester).opacity.value, lessThan(1));

      await tester.pumpAndSettle();
      expect(_entryFade(tester).opacity.value, 1);
      expect(find.text('جاهز'), findsOneWidget);
    });

    testWidgets('is already visible on the first frame with reduced motion',
        (tester) async {
      await tester.pumpWidget(
        _host(const AnimatedEntry(child: Text('جاهز')), reduceMotion: true),
      );
      await tester.pump();
      expect(_entryFade(tester).opacity.value, 1);
    });

    testWidgets('disposes cleanly while its delay is still pending',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const AnimatedEntry(
            delay: Duration(milliseconds: 400),
            child: Text('محتوى'),
          ),
        ),
      );
      await tester.pumpWidget(_host(const SizedBox.shrink()));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('محتوى'), findsNothing);
    });
  });

  group('PressableScale', () {
    testWidgets('shrinks on press and restores on release', (tester) async {
      await tester.pumpWidget(
        _host(
          const PressableScale(
            child: SizedBox(width: 80, height: 80),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PressableScale)),
      );
      await tester.pump();
      expect(_pressScale(tester).scale, AppMotion.pressedScale);

      await gesture.up();
      await tester.pump();
      expect(_pressScale(tester).scale, 1);
    });

    testWidgets('does not swallow taps from the wrapped control',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          PressableScale(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => taps++,
              child: const SizedBox(width: 80, height: 80),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(GestureDetector));
      await tester.pump();
      expect(taps, 1);
    });
  });

  group('AnimatedContentSwitcher', () {
    testWidgets('switches to the new child without leaving both mounted long',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const AnimatedContentSwitcher(
            child: Text('محمّل', key: ValueKey('loading')),
          ),
        ),
      );
      expect(find.text('محمّل'), findsOneWidget);

      await tester.pumpWidget(
        _host(
          const AnimatedContentSwitcher(
            child: Text('محتوى', key: ValueKey('content')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('محتوى'), findsOneWidget);
      expect(find.text('محمّل'), findsNothing);
    });
  });

  group('AppExpandable', () {
    testWidgets('reveals collapsed content only after a tap', (tester) async {
      await tester.pumpWidget(
        _host(
          const AppExpandable(
            title: 'إعدادات القارئ',
            child: Text('خيارات متقدمة'),
          ),
        ),
      );
      expect(find.text('خيارات متقدمة'), findsNothing);

      await tester.tap(find.text('إعدادات القارئ'));
      await tester.pumpAndSettle();
      expect(find.text('خيارات متقدمة'), findsOneWidget);
    });
  });

  group('AppNavigation', () {
    setUp(AppNavigation.resetThrottle);

    test('blocks a repeated push inside the duplicate window', () {
      final start = DateTime(2026, 1, 1, 12);
      expect(AppNavigation.shouldNavigate('/comic/1', now: start), isTrue);
      expect(
        AppNavigation.shouldNavigate(
          '/comic/1',
          now: start.add(const Duration(milliseconds: 120)),
        ),
        isFalse,
      );
    });

    test('allows the same route again after the window', () {
      final start = DateTime(2026, 1, 1, 12);
      expect(AppNavigation.shouldNavigate('/comic/1', now: start), isTrue);
      expect(
        AppNavigation.shouldNavigate(
          '/comic/1',
          now: start.add(const Duration(milliseconds: 400)),
        ),
        isTrue,
      );
    });

    test('never blocks a different route', () {
      final start = DateTime(2026, 1, 1, 12);
      expect(AppNavigation.shouldNavigate('/comic/1', now: start), isTrue);
      expect(
        AppNavigation.shouldNavigate(
          '/chapter/1',
          now: start.add(const Duration(milliseconds: 50)),
        ),
        isTrue,
      );
    });

    test('resetThrottle clears the pending duplicate', () {
      final start = DateTime(2026, 1, 1, 12);
      expect(AppNavigation.shouldNavigate('/comic/1', now: start), isTrue);
      AppNavigation.resetThrottle();
      expect(
        AppNavigation.shouldNavigate(
          '/comic/1',
          now: start.add(const Duration(milliseconds: 50)),
        ),
        isTrue,
      );
    });
  });
}
