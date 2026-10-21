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
    final theme = Theme.of(context);
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
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: const MangaPlusLogo(size: 68),
                ),
                const SizedBox(height: 10),
                Text(
                  'MangaPlus',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'قارئ مانجا ومانهوا'.tr,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
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
                          Text('اللغة'.tr,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              )),
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
                  title: Text('المظهر'.tr,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      )),
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
              _infoRow(Icons.info_outline_rounded, 'اسم التطبيق'.tr,
                  'MangaPlus'),
              Divider(height: 1, color: AppColors.divider),
              _infoRow(Icons.verified_outlined, 'الإصدار'.tr, '1.0.0'),
              Divider(height: 1, color: AppColors.divider),
              _infoRow(Icons.tag_rounded, 'معرّف الحزمة'.tr,
                  'com.mangaplus.app'),
              Divider(height: 1, color: AppColors.divider),
              _infoRow(
                Icons.auto_stories_outlined,
                'مصدر المحتوى'.tr,
                'غير مضاف بعد'.tr,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'سيضاف مصدر المحتوى في مرحلة لاحقة. لا يتصل التطبيق حاليًا بخدمة مانجا خارجية.'
                .tr,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
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

  Widget _infoRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.icon),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _navigationRow(IconData icon, String label, VoidCallback onTap) =>
      ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(label, style: TextStyle(color: AppColors.textPrimary)),
        trailing: Icon(Icons.chevron_right_rounded, color: AppColors.icon),
        onTap: onTap,
      );
}
