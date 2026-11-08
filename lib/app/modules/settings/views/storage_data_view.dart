import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/modules/settings/controllers/settings_controller.dart';
import 'package:mangaplus/app/widgets/mangaplus_app_bar.dart';
import 'package:mangaplus/app/widgets/theme_aware_builder.dart';

class StorageDataView extends GetView<SettingsController> {
  const StorageDataView({super.key});

  @override
  Widget build(BuildContext context) => ThemeAwareBuilder(
        builder: (context) => Scaffold(
          backgroundColor: AppColors.background,
          appBar: MangaPlusAppBar(title: 'التخزين والذاكرات المؤقتة'.tr),
          body: Obx(() => ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  _card([
                    _title('استخدام التخزين المحلي'.tr),
                    const SizedBox(height: 12),
                    _storageRow(
                      icon: Icons.photo_library_rounded,
                      title: 'الصور المخزنة مؤقتًا (Cover Cache)'.tr,
                      subtitle:
                          '${controller.coverCacheCount.value} ${'ملف'.tr} • ${(controller.coverCacheSize.value / 1024 / 1024).toStringAsFixed(1)} MB',
                      onTap: controller.isCacheClearing.value
                          ? null
                          : () => _confirmClearCoverCache(context),
                    ),
                    const Divider(height: 1, color: AppColors.divider),
                    _storageRow(
                      icon: Icons.memory_rounded,
                      title: 'الذاكرة المؤقتة للتحميلات'.tr,
                      subtitle:
                          'الملفات المخزنة مؤقتًا للمانجا والروايات',
                      onTap: () {},
                    ),
                    const Divider(height: 1, color: AppColors.divider),
                    _storageRow(
                      icon: Icons.storage_bucket_rounded,
                      title: 'بيانات التطبيق الأساسية'.tr,
                      subtitle:
                          'الإعدادات وبيانات المستخدم المحلية',
                      onTap: () {},
                    ),
                  ]),
                  const SizedBox(height: 22),
                  _card([
                    _title('بيانات المستخدم'.tr),
                    const SizedBox(height: 12),
                    _infoRow(
                      icon: Icons.info_outline_rounded,
                      title: 'تنبيه هام'.tr,
                      description:
                          'لا يؤثر مسح الذاكرة المؤقتة على حسابك أو قراءاتك أو مفضلاتك أو سجل القراءة أو الإعدادات المخزنة.'.tr,
                    ),
                  ]),
                  const SizedBox(height: 22),
                  _card([
                    _title('إدارة الذاكرة المؤقتة'.tr),
                    const SizedBox(height: 12),
                    Obx(() => _actionTile(
                          icon: Icons.delete_sweep_rounded,
                          title: 'مسح الذاكرة المؤقتة للصور'.tr,
                          subtitle:
                              'إزالة الصور المخزنة مؤقتًا وتحرير مساحة'.tr,
                          onTap: controller.isCacheClearing.value
                              ? null
                              : () => _confirmClearCoverCache(context),
                          isDestructive: true,
                        )),
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

  Widget _storageRow({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
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
        trailing:
            onTap != null ? Icon(Icons.chevron_right_rounded, color: AppColors.icon) : null,
        onTap: onTap,
      );

  Widget _infoRow({
    required IconData icon,
    required String title,
    required String description,
  }) =>
      ListTile(
        leading: Icon(icon, color: AppColors.warning),
        title: Text(
          title,
          style: TextStyle(
            color: AppColors.warning,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          description,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      );

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    bool isDestructive = false,
  }) =>
      ListTile(
        leading: Icon(
          icon,
          color: isDestructive ? AppColors.error : AppColors.icon,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isDestructive ? AppColors.error : AppColors.textPrimary,
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
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: isDestructive ? AppColors.error : AppColors.icon,
        ),
        onTap: onTap,
      );

  Future<void> _confirmClearCoverCache(BuildContext context) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        title: Text('مسح الذاكرة المؤقتة للصور'.tr),
        content: Text(
          'سيتم إزالة الصور المخزنة مؤقتًا من التطبيق. لا يؤثر هذا على حسابك أو بيانات القراءة أو المفضلات.'.tr,
          textAlign: TextAlign.start,
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('إلغاء'.tr),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: Text('مسح'.tr),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await controller.clearCoverCache();
    await controller.refreshCoverCacheInfo();
  }
}
