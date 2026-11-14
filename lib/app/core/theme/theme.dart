import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mangaplus/app/core/theme/app_palette.dart';
import 'package:mangaplus/app/core/theme/design_tokens.dart';

/// Builds both application themes from one palette and one set of tokens.
///
/// There is deliberately a single builder: before this, light and dark were two
/// hand-maintained copies of the same component styles, which is how they
/// drifted apart. Every colour now comes from [AppPalette] and every size,
/// radius and duration from [AppSpacing], [AppRadii], [AppSizes] and
/// [AppDurations].
class AppTheme {
  const AppTheme._();

  static final ThemeData lightTheme = _build(AppPalette.light);
  static final ThemeData darkTheme = _build(AppPalette.dark);

  static ThemeData themeFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkTheme : lightTheme;

  static ThemeData _build(AppPalette p) {
    final scheme = ColorScheme(
      brightness: p.brightness,
      primary: p.primary,
      onPrimary: p.onPrimary,
      primaryContainer: p.primaryContainer,
      onPrimaryContainer: p.onPrimaryContainer,
      secondary: p.secondary,
      onSecondary: p.onPrimary,
      secondaryContainer: p.primaryContainer,
      onSecondaryContainer: p.onPrimaryContainer,
      tertiary: p.accent,
      onTertiary: p.onPrimary,
      error: p.error,
      onError: p.onError,
      errorContainer: p.error.withValues(alpha: .14),
      onErrorContainer: p.error,
      surface: p.surface,
      onSurface: p.textPrimary,
      surfaceContainerLowest: p.background,
      surfaceContainerLow: p.surface,
      surfaceContainer: p.surface,
      surfaceContainerHigh: p.surfaceVariant,
      surfaceContainerHighest: p.surfaceVariant,
      onSurfaceVariant: p.textSecondary,
      outline: p.border,
      outlineVariant: p.divider,
      shadow: Colors.black,
      scrim: p.scrim,
      inverseSurface: p.isDark ? p.textPrimary : const Color(0xff202329),
      onInverseSurface: p.isDark ? p.background : p.textPrimary,
      inversePrimary:
          p.isDark ? AppPalette.light.primary : AppPalette.dark.primary,
      surfaceTint: Colors.transparent,
    );

    final textTheme = _textTheme(p);
    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: p.isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: p.isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: p.background,
      systemNavigationBarIconBrightness:
          p.isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    );

    final buttonTextStyle = textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: .2,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.background,
      canvasColor: p.background,
      shadowColor: Colors.black,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      iconTheme: IconThemeData(color: p.icon, size: AppSizes.iconMd),
      extensions: <ThemeExtension<dynamic>>[p],
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: p.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        toolbarHeight: AppSizes.appBarHeight,
        systemOverlayStyle: overlayStyle,
        iconTheme:
            IconThemeData(color: p.textPrimary, size: AppSizes.iconLg - 2),
        actionsIconTheme: IconThemeData(color: p.icon, size: AppSizes.iconMd),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: p.textPrimary,
          height: 1.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: p.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.mdAll,
          side: BorderSide(color: p.border.withValues(alpha: .85)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          disabledBackgroundColor: p.surfaceVariant,
          disabledForegroundColor: p.textDisabled,
          elevation: 0,
          minimumSize: const Size(64, AppSizes.controlHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.smAll),
          textStyle: buttonTextStyle,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          disabledBackgroundColor: p.surfaceVariant,
          disabledForegroundColor: p.textDisabled,
          elevation: 0,
          minimumSize: const Size(64, AppSizes.controlHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.smAll),
          textStyle: buttonTextStyle,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.primary,
          disabledForegroundColor: p.textDisabled,
          side: BorderSide(color: p.border, width: 1.2),
          minimumSize: const Size(64, AppSizes.controlHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.smAll),
          textStyle: buttonTextStyle,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.primary,
          disabledForegroundColor: p.textDisabled,
          minimumSize: const Size(48, AppSizes.compactControlHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.xsAll),
          textStyle: buttonTextStyle,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: p.icon,
          minimumSize: const Size(AppSizes.touchTarget, AppSizes.touchTarget),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.smAll),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        elevation: 2,
        focusElevation: 2,
        hoverElevation: 2,
        highlightElevation: 3,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceVariant,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadii.mdAll,
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.mdAll,
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.mdAll,
          borderSide: BorderSide(color: p.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadii.mdAll,
          borderSide: BorderSide(color: p.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadii.mdAll,
          borderSide: BorderSide(color: p.error, width: 1.5),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(color: p.textSecondary),
        floatingLabelStyle: textTheme.bodyMedium?.copyWith(color: p.primary),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: p.textSecondary.withValues(alpha: .78),
        ),
        helperStyle: textTheme.bodySmall?.copyWith(color: p.textSecondary),
        errorStyle: textTheme.bodySmall?.copyWith(color: p.error),
        prefixIconColor: p.icon,
        suffixIconColor: p.icon,
        counterStyle: textTheme.bodySmall?.copyWith(color: p.textSecondary),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? p.primary : null,
        ),
        checkColor: WidgetStatePropertyAll(p.onPrimary),
        side: BorderSide(color: p.border, width: 1.4),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.xsAll),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? p.primary : null,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return p.onPrimary;
          return p.isDark ? p.textSecondary : p.surface;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return p.primary;
          return p.border;
        }),
        trackOutlineColor: WidgetStatePropertyAll(p.border),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: p.primary,
        inactiveTrackColor: p.border,
        thumbColor: p.primary,
        overlayColor: p.primary.withValues(alpha: .14),
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
        valueIndicatorColor: p.primary,
        valueIndicatorTextStyle: textTheme.labelMedium?.copyWith(
          color: p.onPrimary,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.primary,
        linearTrackColor: p.primary.withValues(alpha: .18),
        circularTrackColor: p.primary.withValues(alpha: .18),
      ),
      dividerTheme: DividerThemeData(
        color: p.divider,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        barrierColor: p.scrim,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.lgAll),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: p.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: p.textSecondary,
          height: 1.6,
        ),
        actionsPadding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          0,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: p.surface,
        modalBarrierColor: p.scrim,
        elevation: 0,
        modalElevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheetTop),
        clipBehavior: Clip.antiAlias,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surfaceVariant,
        selectedColor: p.primary.withValues(alpha: .18),
        disabledColor: p.surfaceVariant,
        secondarySelectedColor: p.primary.withValues(alpha: .18),
        side: BorderSide(color: p.border),
        shape: const StadiumBorder(),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
        labelStyle: textTheme.labelMedium?.copyWith(
          color: p.textSecondary,
          fontWeight: FontWeight.w700,
        ),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: p.primary,
          fontWeight: FontWeight.w700,
        ),
        brightness: p.brightness,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: p.primary,
        unselectedLabelColor: p.textSecondary,
        indicatorColor: p.primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        labelStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.isDark ? p.surfaceElevated : const Color(0xff303338),
          borderRadius: AppRadii.xsAll,
        ),
        textStyle: textTheme.bodySmall?.copyWith(color: Colors.white),
        waitDuration: const Duration(milliseconds: 420),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.smAll),
        textStyle: textTheme.bodyMedium?.copyWith(color: p.textPrimary),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.surfaceElevated,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: p.textPrimary),
        actionTextColor: p.primary,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.smAll),
        elevation: 2,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.icon,
        textColor: p.textPrimary,
        minVerticalPadding: AppSpacing.xs,
        titleTextStyle: textTheme.titleSmall?.copyWith(
          color: p.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: textTheme.bodySmall?.copyWith(
          color: p.textSecondary,
          height: 1.45,
        ),
        leadingAndTrailingTextStyle: textTheme.bodySmall?.copyWith(
          color: p.textSecondary,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.surface,
        selectedItemColor: p.primary,
        unselectedItemColor: p.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: textTheme.labelSmall,
        unselectedLabelStyle: textTheme.labelSmall,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        indicatorColor: p.primary.withValues(alpha: .14),
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelSmall),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.primary,
        selectionColor: p.primary.withValues(alpha: .28),
        selectionHandleColor: p.primary,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(3),
        thumbColor:
            WidgetStatePropertyAll(p.textSecondary.withValues(alpha: .5)),
        radius: const Radius.circular(AppRadii.pill),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  /// One typographic scale for both themes.
  ///
  /// MangaPlus no longer asks for a `Poppins` family that the app does not
  /// bundle; text is rendered with the platform font, which also gives full
  /// Arabic shaping coverage. Line heights are generous because the primary
  /// locale is Arabic.
  static TextTheme _textTheme(AppPalette p) {
    TextStyle style(
      double size,
      FontWeight weight, {
      double height = 1.4,
      Color? color,
      double? letterSpacing,
    }) =>
        TextStyle(
          fontSize: size,
          fontWeight: weight,
          height: height,
          color: color ?? p.textPrimary,
          letterSpacing: letterSpacing,
        );

    return TextTheme(
      displayLarge: style(32, FontWeight.w700, height: 1.22),
      displayMedium: style(28, FontWeight.w700, height: 1.24),
      displaySmall: style(24, FontWeight.w700, height: 1.28),
      headlineLarge: style(22, FontWeight.w700, height: 1.3),
      headlineMedium: style(20, FontWeight.w700, height: 1.32),
      headlineSmall: style(18, FontWeight.w700, height: 1.34),
      titleLarge: style(17, FontWeight.w700, height: 1.35),
      titleMedium: style(15, FontWeight.w600, height: 1.4),
      titleSmall: style(14, FontWeight.w600, height: 1.4),
      bodyLarge: style(15, FontWeight.w400, height: 1.6),
      bodyMedium: style(14, FontWeight.w400, height: 1.55),
      bodySmall:
          style(12.5, FontWeight.w400, height: 1.45, color: p.textSecondary),
      labelLarge: style(14, FontWeight.w600, height: 1.3),
      labelMedium: style(12, FontWeight.w600, height: 1.3),
      labelSmall:
          style(11, FontWeight.w500, height: 1.3, color: p.textSecondary),
    );
  }
}
