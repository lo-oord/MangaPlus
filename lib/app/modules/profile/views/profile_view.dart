import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/modules/profile/controllers/profile_controller.dart';
import 'package:mangaplus/app/routes/app_pages.dart';
import 'package:mangaplus/app/widgets/brand_state.dart';

class ProfileView extends GetView<ProfileController> {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('الإعدادات'.tr),
        centerTitle: true,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        children: [
          _sectionTitle('التفضيلات'.tr),
          const SizedBox(height: 10),
          _settingsCard(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Icon(Icons.language_rounded, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'اللغة'.tr,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Obx(
                            () => DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: controller.selectedLanguage.value,
                                isExpanded: true,
                                dropdownColor: AppColors.card,
                                iconEnabledColor: AppColors.icon,
                                style: TextStyle(color: AppColors.textPrimary),
                                items: [
                                  DropdownMenuItem(
                                    value: 'ar_SA',
                                    child: Text('العربية'.tr),
                                  ),
                                  DropdownMenuItem(
                                    value: 'en_US',
                                    child: Text('الإنجليزية'.tr),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    controller.changeLanguage(value);
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppColors.divider),
              Obx(
                () => SwitchListTile.adaptive(
                  value: controller.isDarkMode.value,
                  onChanged: controller.changeTheme,
                  secondary: Icon(
                    controller.isDarkMode.value
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    color: AppColors.primary,
                  ),
                  title: Text(
                    'المظهر'.tr,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    controller.isDarkMode.value ? 'داكن'.tr : 'فاتح'.tr,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  activeColor: AppColors.primary,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _sectionTitle('مكتبتي'.tr),
          const SizedBox(height: 10),
          _settingsCard(
            children: [
              _navigationRow(
                Icons.history_rounded,
                'سجل القراءة'.tr,
                () => Get.toNamed(Routes.HISTORY),
              ),
              Divider(height: 1, color: AppColors.divider),
              _navigationRow(
                Icons.download_outlined,
                'التنزيلات'.tr,
                () => Get.toNamed(Routes.DOWNLOAD),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _sectionTitle('حول التطبيق'.tr),
          const SizedBox(height: 10),
          _settingsCard(
            children: [
              _navigationRow(
                Icons.info_outline_rounded,
                'حول التطبيق'.tr,
                _showAboutDialog,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    Get.dialog(
      AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            const MangaPlusLogo(size: 34),
            const SizedBox(width: 12),
            Text('حول التطبيق'.tr),
          ],
        ),
        content: Text(
          '${'app_name'.tr}\n${'قارئ مانجا ومانهوا'.tr}\n\n${'الإصدار'.tr}: 1.1',
          style: TextStyle(color: AppColors.textSecondary, height: 1.6),
        ),
        actions: [
          TextButton(onPressed: Get.back, child: Text('حسنًا'.tr)),
        ],
      ),
    );
  }
  Widget _sectionTitle(String title) => Padding(
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

  Widget _settingsCard({required List<Widget> children}) => Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.divider.withValues(alpha: 0.72)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      );

  Widget _navigationRow(IconData icon, String label, VoidCallback onTap) =>
      ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(label, style: TextStyle(color: AppColors.textPrimary)),
        trailing: Icon(Icons.chevron_right_rounded, color: AppColors.icon),
        onTap: onTap,
      );
}
