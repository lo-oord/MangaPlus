import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/modules/settings/controllers/settings_controller.dart';
import 'package:mangaplus/app/widgets/mangaplus_app_bar.dart';
import 'package:mangaplus/app/widgets/theme_aware_builder.dart';

class LanguageRegionView extends GetView<SettingsController> {
  const LanguageRegionView({super.key});

  @override
  Widget build(BuildContext context) => ThemeAwareBuilder(
        builder: (context) => Scaffold(
          backgroundColor: AppColors.background,
          appBar: MangaPlusAppBar(title: 'اللغة'.tr),
          body: Obx(() => ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  _card([
                    _title('لغة التطبيق'.tr),
                    const SizedBox(height: 12),
                    RadioListTile<String>(
                      title: Text(
                        'العربية'.tr,
                        style: TextStyle(
                          color: controller.language.value == 'ar_SA'
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        ' используется للعربية'.tr,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      value: 'ar_SA',
                      groupValue: controller.language.value,
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppColors.primary,
                      onChanged: (v) {
                        if (v != null) controller.setLanguage(v);
                      },
                    ),
                    const Divider(height: 1, color: AppColors.divider),
                    RadioListTile<String>(
                      title: Text(
                        'الإنجليزية'.tr,
                        style: TextStyle(
                          color: controller.language.value == 'en_US'
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'يُستخدم للإنجليزية'.tr,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      value: 'en_US',
                      groupValue: controller.language.value,
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppColors.primary,
                      onChanged: (v) {
                        if (v != null) controller.setLanguage(v);
                      },
                    ),
                  ]),
                  const SizedBox(height: 22),
                  _card([
                    _title('المنطقة والتاريخ'.tr),
                    const SizedBox(height: 12),
                    _readonlyTile(
                      icon: Icons.public_rounded,
                      title: 'المنطقة الافتراضية'.tr,
                      subtitle: 'السعودية'.tr,
                    ),
                  ]),
                ],
              )),
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

  Widget _readonlyTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) =>
      ListTile(
        leading: Icon(icon, color: AppColors.icon),
        title: Text(
          title,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        trailing: Icon(Icons.check_rounded,
            color: AppColors.primary, size: 22),
      );
}
