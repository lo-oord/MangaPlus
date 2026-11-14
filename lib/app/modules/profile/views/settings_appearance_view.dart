import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/theme/app_palette.dart';
import 'package:mangaplus/app/core/theme/design_tokens.dart';
import 'package:mangaplus/app/modules/profile/controllers/profile_controller.dart';
import 'package:mangaplus/app/widgets/app_surfaces.dart';
import 'package:mangaplus/app/widgets/mangaplus_app_bar.dart';
import 'package:mangaplus/app/widgets/theme_aware_builder.dart';

class SettingsAppearanceView extends GetView<ProfileController> {
  const SettingsAppearanceView({super.key});

  @override
  Widget build(BuildContext context) => ThemeAwareBuilder(
        builder: (context) => Scaffold(
          backgroundColor: context.palette.background,
          appBar: MangaPlusAppBar(title: 'المظهر واللغة'.tr),
          body: Obx(
            () => ListView(
              padding: AppSpacing.pageInsets,
              children: [
                AppSection(
                  title: 'المظهر'.tr,
                  subtitle: 'يُطبّق فورًا على كل الشاشات.'.tr,
                  children: [
                    _ThemeTile(
                      mode: ThemeMode.light,
                      label: 'فاتح'.tr,
                      icon: Icons.light_mode_rounded,
                      selected: controller.themeMode.value == ThemeMode.light,
                      onTap: () => controller.setThemeMode(ThemeMode.light),
                    ),
                    _ThemeTile(
                      mode: ThemeMode.dark,
                      label: 'داكن'.tr,
                      icon: Icons.dark_mode_rounded,
                      selected: controller.themeMode.value == ThemeMode.dark,
                      onTap: () => controller.setThemeMode(ThemeMode.dark),
                    ),
                    _ThemeTile(
                      mode: ThemeMode.system,
                      label: 'حسب النظام'.tr,
                      icon: Icons.brightness_auto_rounded,
                      selected: controller.themeMode.value == ThemeMode.system,
                      onTap: () => controller.setThemeMode(ThemeMode.system),
                    ),
                  ],
                ),
                AppSection(
                  title: 'اللغة'.tr,
                  subtitle: 'لغة الواجهة والتنبيهات.'.tr,
                  children: [
                    AppSettingsTile(
                      icon: Icons.language_rounded,
                      title: 'العربية'.tr,
                      switchValue: controller.selectedLanguage.value == 'ar_SA',
                      onSwitchChanged: (selected) {
                        if (selected) controller.changeLanguage('ar_SA');
                      },
                    ),
                    AppSettingsTile(
                      icon: Icons.translate_rounded,
                      title: 'English',
                      switchValue: controller.selectedLanguage.value == 'en_US',
                      onSwitchChanged: (selected) {
                        if (selected) controller.changeLanguage('en_US');
                      },
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: AppSpacing.xxs,
                    top: AppSpacing.xxs,
                  ),
                  child: Text(
                    'اختيار «حسب النظام» يتبع إعداد المظهر في نظام التشغيل '
                    'ويتغير معه تلقائيًا.'.tr,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.palette.textSecondary,
                          height: 1.5,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.mode,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final ThemeMode mode;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppSettingsTile(
      icon: icon,
      title: label,
      onTap: onTap,
      trailing: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 22,
        height: 22,
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
    );
  }
}
