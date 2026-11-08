import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/core/theme/theme_mode_preference.dart';
import 'package:mangaplus/app/modules/settings/controllers/settings_controller.dart';
import 'package:mangaplus/app/widgets/mangaplus_app_bar.dart';
import 'package:mangaplus/app/widgets/theme_aware_builder.dart';

class AppearanceSettingsView extends GetView<SettingsController> {
  const AppearanceSettingsView({super.key});

  @override
  Widget build(BuildContext context) => ThemeAwareBuilder(
        builder: (context) => Scaffold(
          backgroundColor: AppColors.background,
          appBar: MangaPlusAppBar(title: 'المظهر'.tr),
          body: Obx(() => ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  _card([
                    _title('نظام السمات'.tr),
                    const SizedBox(height: 12),
                    _themeOption(
                      label: 'فاتح',
                      subtitle: 'وضع الفاتح'.tr,
                      icon: Icons.light_mode_rounded,
                      value: controller.isDarkMode.value == false,
                      onTap: () => controller.setDarkMode(false),
                    ),
                    const Divider(height: 1, color: AppColors.divider),
                    _themeOption(
                      label: 'داكن',
                      subtitle: 'وضع الداكن'.tr,
                      icon: Icons.dark_mode_rounded,
                      value: controller.isDarkMode.value == true,
                      onTap: () => controller.setDarkMode(true),
                      active: true,
                    ),
                    const Divider(height: 1, color: AppColors.divider),
                    _themeOption(
                      label: 'تلقائي',
                      subtitle: 'حسب إعدادات النظام'.tr,
                      icon: Icons.settings_suggest_rounded,
                      value: ThemeModePreference.fromStorage(
                              controller._storage.read<String>('themeMode')) ==
                          ThemeMode.system,
                      onTap: () async {
                        await controller._storage.write('themeMode', 'system');
                        Get.changeThemeMode(ThemeMode.system);
                        if (Get.isRegistered<SettingsController>()) {
                          final controller = Get.find<SettingsController>();
                          controller.isDarkMode.value =
                              Get.isDarkMode;
                        }
                      },
                    ),
                  ]),
                  const SizedBox(height: 22),
                  _card([
                    _title('تخصيص الواجهة'.tr),
                    const SizedBox(height: 12),
                    _subtleTile(
                      icon: Icons.text_fields,
                      title: 'حجم النص القياسي'.tr,
                      subtitle: 'تغيير حجم الخط الافتراضي'.tr,
                      onTap: () => _showFontSizeDialog(context),
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

  Widget _themeOption({
    required String label,
    required String subtitle,
    required IconData icon,
    required bool value,
    required VoidCallback onTap,
    bool active = false,
  }) =>
      ListTile(
        leading: Icon(
          icon,
          color: value ? AppColors.primary : AppColors.icon,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: value ? AppColors.textPrimary : AppColors.textSecondary,
            fontWeight: value ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        trailing: value
            ? Icon(Icons.check_circle_rounded,
                color: AppColors.primary, size: 26)
            : null,
        onTap: onTap,
      );

  Widget _subtleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
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
        trailing: Icon(Icons.chevron_right_rounded,
            color: AppColors.icon),
        onTap: onTap,
      );

  Future<void> _showFontSizeDialog(BuildContext context) async {
    final current = 16.0;
    final sizes = [14.0, 15.0, 16.0, 17.0, 18.0, 19.0];
    final selected = await Get.dialog<double>(
      AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        title: Text('حجم النص القياسي'.tr),
        content: SizedBox(
          width: 280,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'اختر حجم الخط القياسي للتطبيق'.tr,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 16),
              ...sizes.map((s) => RadioListTile<double>(
                    title: Text(s.toInt().toString(),
                        style: TextStyle(color: AppColors.textPrimary)),
                    value: s,
                    groupValue: current,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.primary,
                    onChanged: (v) => Get.back(result: v),
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: current),
            child: Text('OK'.tr),
          ),
        ],
      ),
    );
    if (selected == null) return;
  }
}
