import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/settings/onboarding_service.dart';
import 'package:mangaplus/app/core/theme/app_palette.dart';
import 'package:mangaplus/app/core/theme/design_tokens.dart';
import 'package:mangaplus/app/routes/app_pages.dart';
import 'package:mangaplus/app/widgets/app_dialogs.dart';
import 'package:mangaplus/app/widgets/app_surfaces.dart';
import 'package:mangaplus/app/widgets/brand_state.dart';
import 'package:mangaplus/app/widgets/mangaplus_app_bar.dart';
import 'package:mangaplus/app/widgets/theme_aware_builder.dart';

/// The application version is kept in one place. `pubspec.yaml` is currently
/// `1.1.0+1`; the build number is not read at runtime because no package_info
/// dependency is installed, so only the version string shown here is claimed.
const String kAppVersion = '1.1.0';

class SettingsAboutView extends StatelessWidget {
  const SettingsAboutView({super.key});

  Future<void> _replayOnboarding(BuildContext context) async {
    final confirmed = await AppDialogs.confirm(
      title: 'إعادة الإعداد الأولي'.tr,
      message: 'ستظهر خطوات اللغة والمظهر والقراءة مرة أخرى. لن تُحذف '
          'إعداداتك الحالية أو بياناتك.'.tr,
      confirmLabel: 'إعادة'.tr,
      icon: Icons.restart_alt_rounded,
    );
    if (confirmed != true) return;
    await OnboardingService.restart();
    Get.offAllNamed(Routes.ONBOARDING);
  }

  @override
  Widget build(BuildContext context) => ThemeAwareBuilder(
        builder: (context) => Scaffold(
          backgroundColor: context.palette.background,
          appBar: MangaPlusAppBar(title: 'حول التطبيق'.tr),
          body: ListView(
            padding: AppSpacing.pageInsets,
            children: [
              AppCard(
                child: Column(
                  children: [
                    const MangaPlusLogo(size: 72),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'app_name'.tr,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${'الإصدار'.tr} $kAppVersion',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.palette.textSecondary,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'قارئ مانجا ومانهوا وروايات بالعربية.'.tr,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: context.palette.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.section),
              AppSection(
                title: 'معلومات'.tr,
                children: [
                  AppSettingsTile(
                    icon: Icons.article_outlined,
                    title: 'تراخيص المصادر المفتوحة'.tr,
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: 'MangaPlus',
                      applicationVersion: kAppVersion,
                      applicationLegalese:
                          'GPL-3.0 — يشمل محوّل Team X.',
                    ),
                  ),
                  AppSettingsTile(
                    icon: Icons.restart_alt_rounded,
                    title: 'إعادة الإعداد الأولي'.tr,
                    subtitle: 'عرض خطوات البداية مرة أخرى.'.tr,
                    onTap: () => _replayOnboarding(context),
                  ),
                ],
              ),
              AppSection(
                title: 'الدعم'.tr,
                children: [
                  AppSettingsTile(
                    icon: Icons.info_outline_rounded,
                    title: 'التواصل مع المطور'.tr,
                    subtitle:
                        'لا يوجد رابط دعم عام مضمّن في هذا الإصدار؛ استخدم '
                        'قناة المشروع على GitHub.'.tr,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}
