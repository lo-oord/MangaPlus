import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/theme/design_tokens.dart';

import '../controllers/onboarding_controller.dart';

class OnboardingView extends GetView<OnboardingController> {
  const OnboardingView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, 0),
              child: Row(
                children: [
                  Obx(() => controller.currentPage.value > 0
                      ? IconButton(
                          onPressed: controller.back,
                          icon: const Icon(Icons.arrow_back_rounded),
                          tooltip: 'رجوع'.tr,
                        )
                      : const SizedBox(width: 48, height: 48)),
                  const Spacer(),
                  TextButton(
                    onPressed: controller.complete,
                    child: Text(
                      'تخطي'.tr,
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: controller.pageController,
                onPageChanged: controller.onPageChanged,
                children: [
                  _IntroPage(
                    icon: Icons.auto_stories_rounded,
                    title: 'مرحبًا بك في MangaPlus'.tr,
                    subtitle:
                        'اقرأ المانجا والروايات بسهولة مع تجربة قراءة مريحة ومنظمة.'
                            .tr,
                  ),
                  _IntroPage(
                    icon: Icons.explore_rounded,
                    title: 'اكتشف وتابع ما تحب'.tr,
                    subtitle:
                        'تصفح أحدث الأعمال، احفظ مفضلتك، وتابع تقدمك في مكان واحد.'
                            .tr,
                  ),
                  _SetupPage(controller: controller),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
              child: Column(
                children: [
                  Obx(() => _PageIndicator(
                        count: controller.pageCount,
                        index: controller.currentPage.value,
                        activeColor: colorScheme.primary,
                        inactiveColor: colorScheme.outlineVariant,
                      )),
                  const SizedBox(height: AppSpacing.lg),
                  Obx(() => SizedBox(
                        width: double.infinity,
                        height: AppSizes.controlHeight,
                        child: FilledButton(
                          onPressed: controller.next,
                          child: Text(
                            controller.isLastPage
                                ? 'ابدأ الآن'.tr
                                : 'التالي'.tr,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroPage extends StatelessWidget {
  const _IntroPage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: .45),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 54, color: colorScheme.primary),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupPage extends StatelessWidget {
  const _SetupPage({required this.controller});

  final OnboardingController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: .45),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.tune_rounded, size: 38, color: colorScheme.primary),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'إعداد سريع'.tr,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'اختر اللغة والمظهر المفضلين لك. يمكنك تغييرهما لاحقًا من الإعدادات.'
                .tr,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _SectionCard(
            title: 'اللغة'.tr,
            child: Obx(() => Column(
                  children: [
                    _ChoiceTile(
                      label: 'العربية'.tr,
                      selected: controller.selectedLanguage.value == 'ar_SA',
                      onTap: () => controller.selectLanguage('ar_SA'),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _ChoiceTile(
                      label: 'English'.tr,
                      selected: controller.selectedLanguage.value == 'en_US',
                      onTap: () => controller.selectLanguage('en_US'),
                    ),
                  ],
                )),
          ),
          const SizedBox(height: AppSpacing.md),
          _SectionCard(
            title: 'المظهر'.tr,
            child: Obx(() => Column(
                  children: [
                    _ChoiceTile(
                      icon: Icons.dark_mode_rounded,
                      label: 'داكن'.tr,
                      selected: controller.isDarkMode.value,
                      onTap: () => controller.setDarkMode(true),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _ChoiceTile(
                      icon: Icons.light_mode_rounded,
                      label: 'فاتح'.tr,
                      selected: !controller.isDarkMode.value,
                      onTap: () => controller.setDarkMode(false),
                    ),
                  ],
                )),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: AppRadii.mdAll,
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: .5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bg = selected ? colorScheme.primaryContainer.withValues(alpha: .55) : Colors.transparent;
    final border = selected ? colorScheme.primary.withValues(alpha: .5) : colorScheme.outlineVariant.withValues(alpha: .4);
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.smAll,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: AppRadii.smAll,
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: selected
                  ? Icon(Icons.check_circle_rounded, key: const ValueKey('on'), color: colorScheme.primary, size: 22)
                  : Icon(Icons.radio_button_unchecked_rounded, key: const ValueKey('off'), color: colorScheme.outline, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({
    required this.count,
    required this.index,
    required this.activeColor,
    required this.inactiveColor,
  });

  final int count;
  final int index;
  final Color activeColor;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? activeColor : inactiveColor,
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }
}
