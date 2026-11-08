import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/modules/settings/controllers/settings_controller.dart';
import 'package:mangaplus/app/routes/app_pages.dart';
import 'package:mangaplus/app/widgets/mangaplus_app_bar.dart';
import 'package:mangaplus/app/widgets/theme_aware_builder.dart';

class AboutView extends GetView<SettingsController> {
  const AboutView({super.key});

  @override
  Widget build(BuildContext context) => ThemeAwareBuilder(
        builder: (context) => Scaffold(
          backgroundColor: AppColors.background,
          appBar: MangaPlusAppBar(title: 'حول MangaPlus'.tr),
          body: Obx(() => ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  _logoCard(),
                  const SizedBox(height: 22),
                  _card([
                    _title('معلومات التطبيق'.tr),
                    const SizedBox(height: 12),
                    _infoRow(
                      icon: Icons.info_outline_rounded,
                      title: 'اسم التطبيق'.tr,
                      value: 'MangaPlus',
                    ),
                    const Divider(height: 1, color: AppColors.divider),
                    _infoRow(
                      icon: Icons.code_rounded,
                      title: 'رقم الإصدار'.tr,
                      value: controller.appVersion.value,
                    ),
                    const Divider(height: 1, color: AppColors.divider),
                    _infoRow(
                      icon: Icons.build_rounded,
                      title: 'رقم البناء'.tr,
                      value: controller.buildNumber.value,
                      onTap: controller.copyBuildId,
                    ),
                  ]),
                  const SizedBox(height: 22),
                  _card([
                    _title('روابط قانونية'.tr),
                    const SizedBox(height: 12),
                    _linkRow(
                      icon: Icons.privacy_tip_rounded,
                      title: 'سياسة الخصوصية'.tr,
                      onTap: () => Get.toNamed(Routes.PRIVACY_SECURITY),
                    ),
                    const Divider(height: 1, color: AppColors.divider),
                    _linkRow(
                      icon: Icons.description_outlined,
                      title: 'شروط الاستخدام'.tr,
                      onTap: () => Get.toNamed(Routes.PRIVACY_SECURITY),
                    ),
                  ]),
                  const SizedBox(height: 22),
                  _card([
                    _title('حقوق الملكية'.tr),
                    const SizedBox(height: 12),
                    _textRow(
                      text:
                          'MangaPlus تطبيق مفتوح المصدر يعرض المانجا والمانهوا للقراءة. جميع الحقوق محفوظة لمالكي المحتوى الأصلي.'.tr,
                    ),
                  ]),
                  const SizedBox(height: 22),
                  _card([
                    _title('الAcknowledgment'.tr),
                    const SizedBox(height: 12),
                    _textRow(
                      text:
                          'يشكر التطبيق جميع المطورين والمساهمين الذين ساعدوا في بناء MangaPlus وتحسينه.'.tr,
                    ),
                  ]),
                ],
              )),
        ),
      );

  Widget _logoCard() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.divider.withValues(alpha: .72)),
        ),
        child: Column(
          children: [
            Icon(
              Icons.menu_book_rounded,
              size: 64,
              color: AppColors.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'MangaPlus',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'قارئ مانجا ومانهوا'.tr,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );

  Widget _card(List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.divider.withValues(alpha: .72)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      );

  Widget _title(String title) => Padding(
        padding: const EdgeInsetsDirectional.only(start: 4),
        child: Text(
          title,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  Widget _infoRow({
    required IconData icon,
    required String title,
    required String value,
    VoidCallback? onTap,
  }) =>
      ListTile(
        leading: Icon(icon, color: AppColors.icon),
        title: Text(
          title,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              Icon(Icons.copy_rounded,
                  color: AppColors.icon, size: 18),
            ],
          ],
        ),
        onTap: onTap,
      );

  Widget _linkRow({
    required IconData icon,
    required String title,
    VoidCallback? onTap,
  }) =>
      ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(
          title,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: Icon(Icons.chevron_right_rounded,
            color: AppColors.icon),
        onTap: onTap,
      );

  Widget _textRow({required String text}) => Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          text,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
      );
}
