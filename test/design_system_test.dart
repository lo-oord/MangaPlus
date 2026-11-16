import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangaplus/app/core/theme/app_palette.dart';
import 'package:mangaplus/app/core/theme/design_tokens.dart';
import 'package:mangaplus/app/core/theme/theme.dart';
import 'package:mangaplus/app/widgets/app_buttons.dart';
import 'package:mangaplus/app/widgets/app_loading_indicator.dart';
import 'package:mangaplus/app/widgets/app_surfaces.dart';
import 'package:mangaplus/app/widgets/brand_state.dart';

Widget _host(Widget child, {Brightness brightness = Brightness.dark}) {
  return MaterialApp(
    theme: brightness == Brightness.dark
        ? AppTheme.darkTheme
        : AppTheme.lightTheme,
    home: Scaffold(body: child),
  );
}

void main() {
  group('themes', () {
    test('both themes are built from the same palette contract', () {
      final light = AppTheme.lightTheme;
      final dark = AppTheme.darkTheme;

      expect(light.brightness, Brightness.light);
      expect(dark.brightness, Brightness.dark);
      expect(light.colorScheme.primary, AppPalette.light.primary);
      expect(dark.colorScheme.primary, AppPalette.dark.primary);
      expect(light.scaffoldBackgroundColor, AppPalette.light.background);
      expect(dark.scaffoldBackgroundColor, AppPalette.dark.background);

      // The palette is installed as a theme extension, so components read the
      // same values the ColorScheme is built from.
      expect(light.extension<AppPalette>(), isNotNull);
      expect(dark.extension<AppPalette>(), isNotNull);
      expect(AppTheme.themeFor(Brightness.light), same(light));
      expect(AppTheme.themeFor(Brightness.dark), same(dark));
    });

    test('palette lerp reaches both ends', () {
      final start = AppPalette.light.lerp(AppPalette.dark, 0);
      final end = AppPalette.light.lerp(AppPalette.dark, 1);
      expect(start.background, AppPalette.light.background);
      expect(end.background, AppPalette.dark.background);
      expect(end.isDark, isTrue);
    });

    test('component themes share one radius and control height', () {
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        final buttonShape = theme.filledButtonTheme.style?.shape?.resolve({})
            as RoundedRectangleBorder?;
        expect(
          buttonShape?.borderRadius,
          BorderRadius.circular(AppRadii.sm),
        );
        expect(
          theme.filledButtonTheme.style?.minimumSize?.resolve({})?.height,
          AppSizes.controlHeight,
        );
        expect(theme.cardTheme.margin, EdgeInsets.zero);
        expect(theme.dialogTheme.shape, isA<RoundedRectangleBorder>());
      }
    });
  });

  group('components', () {
    testWidgets('AppButton runs its action and shows a loading state',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(
        AppButton(
            label: 'قراءة',
            onPressed: () => taps++,
            icon: Icons.play_arrow_rounded),
      ));
      expect(find.text('قراءة'), findsOneWidget);
      await tester.tap(find.text('قراءة'));
      expect(taps, 1);

      await tester
          .pumpWidget(_host(const AppButton(label: 'قراءة', loading: true)));
      expect(find.byType(AppLoadingIndicator), findsOneWidget);
    });

    testWidgets('BrandState.loading uses the branded loader', (tester) async {
      await tester.pumpWidget(
        _host(const BrandState.loading(title: 'جارٍ التحميل')),
      );
      expect(find.text('جارٍ التحميل'), findsOneWidget);
      expect(find.byType(MangaPlusLoader), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('BrandState.empty renders a retry action', (tester) async {
      var retried = 0;
      await tester.pumpWidget(_host(
        BrandState.empty(
          title: 'لا توجد نتائج',
          actionLabel: 'إعادة المحاولة',
          onAction: () => retried++,
        ),
      ));
      expect(find.text('لا توجد نتائج'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsOneWidget);
      await tester.tap(find.text('إعادة المحاولة'));
      expect(retried, 1);
    });

    testWidgets('AppSection separates its rows with dividers', (tester) async {
      await tester.pumpWidget(_host(
        const SingleChildScrollView(
          child: AppSection(
            title: 'التفضيلات',
            children: [
              AppSettingsTile(title: 'اللغة', icon: Icons.language_rounded),
              AppSettingsTile(title: 'المظهر', icon: Icons.dark_mode_rounded),
            ],
          ),
        ),
      ));
      expect(find.text('التفضيلات'), findsOneWidget);
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('AppSettingsTile switch reflects and reports its value',
        (tester) async {
      bool? changed;
      await tester.pumpWidget(_host(
        AppSettingsTile(
          title: 'إشعارات المفضلات',
          subtitle: 'تنبيه عند توفر فصل جديد',
          switchValue: false,
          onSwitchChanged: (value) => changed = value,
        ),
      ));
      expect(find.byType(Switch), findsOneWidget);
      await tester.tap(find.byType(Switch));
      expect(changed, isTrue);
    });

    testWidgets('AppPill keeps its label on one line', (tester) async {
      await tester.pumpWidget(_host(
        const AppPill(label: 'عدد الفصول: 120', icon: Icons.menu_book_rounded),
      ));
      final label = tester.widget<Text>(find.text('عدد الفصول: 120'));
      expect(label.maxLines, 1);
      expect(label.overflow, TextOverflow.ellipsis);
    });

    testWidgets('AppCard becomes tappable when a callback is supplied',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(
        AppCard(onTap: () => taps++, child: const Text('تفاصيل')),
      ));
      await tester.tap(find.text('تفاصيل'));
      expect(taps, 1);
    });
  });
}
