import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/core/settings/onboarding_service.dart';
import 'package:mangaplus/app/core/settings/reading_preferences.dart';
import 'package:mangaplus/app/core/theme/app_motion.dart';
import 'package:mangaplus/app/core/theme/app_palette.dart';
import 'package:mangaplus/app/core/theme/design_tokens.dart';
import 'package:mangaplus/app/core/theme/theme_mode_preference.dart';
import 'package:mangaplus/app/data/services/notification_presentation.dart';
import 'package:mangaplus/app/routes/app_pages.dart';
import 'package:mangaplus/app/widgets/app_buttons.dart';
import 'package:mangaplus/app/widgets/app_dialogs.dart';
import 'package:mangaplus/app/widgets/brand_state.dart';
import 'package:mangaplus/app/widgets/theme_aware_builder.dart';
import 'package:permission_handler/permission_handler.dart';

/// Three short screens, no tutorial copy. Every choice is written to the same
/// storage keys the rest of the app already reads and can be changed later.
class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final GetStorage _storage = GetStorage();
  late final PageController _pages;
  int _step = 0;

  late String _language;
  late ThemeMode _theme;
  late String _mode;
  late String _direction;
  bool _notifications = false;
  bool _finishing = false;

  static const int _lastStep = 2;

  @override
  void initState() {
    super.initState();
    _pages = PageController();
    _language = _storage.read<String>('language') ?? 'ar_SA';
    _theme = ThemeModePreference.fromStorage(
      _storage.read<String>('themeMode'),
    );
    _mode = ReadingPreferences.mode;
    _direction = ReadingPreferences.direction;
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _goTo(int step) {
    setState(() => _step = step.clamp(0, _lastStep));
    _pages.animateToPage(
      _step,
      duration: AppMotion.page,
      curve: AppMotion.emphasized,
    );
  }

  Future<void> _setLanguage(String code) async {
    setState(() => _language = code);
    await _storage.write('language', code);
    Get.updateLocale(
      code == 'en_US' ? const Locale('en', 'US') : const Locale('ar', 'SA'),
    );
    unawaited(NotificationPresentation.updateLanguage(code));
  }

  Future<void> _setTheme(ThemeMode mode) async {
    setState(() => _theme = mode);
    Get.changeThemeMode(mode);
    AppColors.refreshTheme(
      mode == ThemeMode.dark ||
          (mode == ThemeMode.system &&
              WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                  Brightness.dark),
    );
    await _storage.write('themeMode', ThemeModePreference.toStorage(mode));
  }

  Future<void> _finish({bool skipped = false}) async {
    if (_finishing) return;
    setState(() => _finishing = true);
    try {
      if (!skipped) {
        await OnboardingService.saveReadingDefaults(
          mode: _mode,
          direction: _direction,
        );
        if (_notifications) {
          await Permission.notification.request();
        }
      }
      await OnboardingService.complete();
      if (!mounted) return;
      Get.offAllNamed(Routes.MAIN);
    } catch (error) {
      if (!mounted) return;
      setState(() => _finishing = false);
      Get.snackbar(
        'تعذر إكمال الإعداد'.tr,
        error.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _skip() async {
    final skip = await AppDialogs.confirm(
      title: 'تخطي الإعداد'.tr,
      message: 'يمكنك تغيير كل هذه الخيارات لاحقًا من الإعدادات.'.tr,
      confirmLabel: 'تخطي'.tr,
      icon: Icons.skip_next_rounded,
    );
    if (skip == true) await _finish(skipped: true);
  }

  @override
  Widget build(BuildContext context) => ThemeAwareBuilder(
        builder: (context) => Scaffold(
          backgroundColor: context.palette.background,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.md,
                    0,
                  ),
                  child: Row(
                    children: [
                      Obx(
                        () => AnimatedOpacity(
                          opacity: _step == 0 ? 0 : 1,
                          duration: AppMotion.fast,
                          child: TextButton(
                            onPressed: _step == 0 ? null : () => _goTo(_step - 1),
                            child: Text('السابق'.tr),
                          ),
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _finishing ? null : _skip,
                        child: Text('تخطي'.tr),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _pages,
                    onPageChanged: (index) => setState(() => _step = index),
                    children: [
                      _welcome(context),
                      _choices(context),
                      _reading(context),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _lastStep + 1,
                          (index) => AnimatedContainer(
                            duration: AppMotion.fast,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: index == _step ? 22 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: index == _step
                                  ? context.palette.primary
                                  : context.palette.divider,
                              borderRadius: AppRadii.pillAll,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SizedBox(
                        width: double.infinity,
                        child: AppButton(
                          label: _step == _lastStep
                              ? 'ابدأ القراءة'.tr
                              : 'متابعة'.tr,
                          icon: _step == _lastStep
                              ? Icons.auto_stories_rounded
                              : Icons.arrow_forward_rounded,
                          expand: true,
                          loading: _finishing,
                          onPressed: _finishing
                              ? null
                              : () => _step == _lastStep
                                  ? _finish()
                                  : _goTo(_step + 1),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _welcome(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: context.palette.primary.withValues(alpha: .10),
                  shape: BoxShape.circle,
                ),
                child: const MangaPlusLogo(size: 96),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'مرحبًا في MangaPlus'.tr,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'اختر ما يناسبك في خطوتين سريعتين.'.tr,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.palette.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      );

  Widget _choices(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        children: [
          _heading(context, 'اللغة والمظهر'.tr, 'يمكنك تغييرهما في أي وقت.'.tr),
          const SizedBox(height: AppSpacing.md),
          _optionTile(
            context,
            icon: Icons.language_rounded,
            title: 'العربية'.tr,
            selected: _language == 'ar_SA',
            onTap: () => _setLanguage('ar_SA'),
          ),
          const SizedBox(height: AppSpacing.xs),
          _optionTile(
            context,
            icon: Icons.translate_rounded,
            title: 'English',
            selected: _language == 'en_US',
            onTap: () => _setLanguage('en_US'),
          ),
          const SizedBox(height: AppSpacing.lg),
          _heading(context, 'المظهر'.tr, 'يُطبّق فورًا.'.tr),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _themeOption(context, ThemeMode.light, 'فاتح', Icons.light_mode_rounded),
              const SizedBox(width: AppSpacing.xs),
              _themeOption(context, ThemeMode.dark, 'داكن', Icons.dark_mode_rounded),
              const SizedBox(width: AppSpacing.xs),
              _themeOption(context, ThemeMode.system, 'النظام', Icons.brightness_auto_rounded),
            ],
          ),
        ],
      );

  Widget _reading(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        children: [
          _heading(
            context,
            'طريقة القراءة'.tr,
            'القيم الافتراضية فقط، وكل فصل يمكنك تغييره من القارئ.'.tr,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _choice(context, 'تمرير متصل'.tr, _mode == 'scroll',
                  () => setState(() => _mode = 'scroll')),
              const SizedBox(width: AppSpacing.xs),
              _choice(context, 'صفحات'.tr, _mode == 'paged',
                  () => setState(() => _mode = 'paged')),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _heading(context, 'اتجاه القراءة'.tr, null),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _choice(context, 'يمين إلى يسار'.tr, _direction == 'rtl',
                  () => setState(() => _direction = 'rtl')),
              const SizedBox(width: AppSpacing.xs),
              _choice(context, 'يسار إلى يمين'.tr, _direction == 'ltr',
                  () => setState(() => _direction = 'ltr')),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _optionTile(
            context,
            icon: Icons.notifications_active_outlined,
            title: 'تنبيهات الفصول الجديدة'.tr,
            subtitle: 'اختياري، ويُطلب إذن النظام مرة واحدة.'.tr,
            selected: _notifications,
            trailing: Switch.adaptive(
              value: _notifications,
              activeColor: context.palette.primary,
              onChanged: (value) => setState(() => _notifications = value),
            ),
            onTap: () => setState(() => _notifications = !_notifications),
          ),
        ],
      );

  Widget _heading(BuildContext context, String title, String? subtitle) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.palette.textSecondary,
                  ),
            ),
          ],
        ],
      );

  Widget _optionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required bool selected,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    final p = context.palette;
    return Material(
      color: selected ? p.primary.withValues(alpha: .10) : p.card,
      borderRadius: AppRadii.mdAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.mdAll,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: AppRadii.mdAll,
            border: Border.all(
              color: selected ? p.primary : p.border.withValues(alpha: .9),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: p.primary.withValues(alpha: .12),
                  borderRadius: AppRadii.smAll,
                ),
                child: Icon(icon, size: 19, color: p.primary),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: p.textSecondary,
                            ),
                      ),
                  ],
                ),
              ),
              trailing ??
                  AnimatedContainer(
                    duration: AppMotion.fast,
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? p.primary : Colors.transparent,
                      border: Border.all(
                        color: selected ? p.primary : p.divider,
                        width: 1.6,
                      ),
                    ),
                    child: selected
                        ? Icon(Icons.check_rounded, size: 14, color: p.onPrimary)
                        : null,
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _themeOption(
    BuildContext context,
    ThemeMode mode,
    String label,
    IconData icon,
  ) {
    final selected = _theme == mode;
    final p = context.palette;
    return Expanded(
      child: InkWell(
        onTap: () => _setTheme(mode),
        borderRadius: AppRadii.mdAll,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: selected ? p.primary.withValues(alpha: .12) : p.card,
            borderRadius: AppRadii.mdAll,
            border: Border.all(color: selected ? p.primary : p.divider),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? p.primary : p.icon),
              const SizedBox(height: 5),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _choice(
    BuildContext context,
    String label,
    bool selected,
    VoidCallback onTap,
  ) {
    final p = context.palette;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.mdAll,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: selected ? p.primary.withValues(alpha: .12) : p.card,
            borderRadius: AppRadii.mdAll,
            border: Border.all(color: selected ? p.primary : p.divider),
          ),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: selected ? p.primary : p.textPrimary,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
