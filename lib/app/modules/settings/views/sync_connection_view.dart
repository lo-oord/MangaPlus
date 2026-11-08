import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/modules/settings/controllers/settings_controller.dart';
import 'package:mangaplus/app/widgets/mangaplus_app_bar.dart';
import 'package:mangaplus/app/widgets/theme_aware_builder.dart';

class SyncConnectionView extends GetView<SettingsController> {
  const SyncConnectionView({super.key});

  @override
  Widget build(BuildContext context) => ThemeAwareBuilder(
        builder: (context) => Scaffold(
          backgroundColor: AppColors.background,
          appBar: MangaPlusAppBar(title: 'المزامنة والاتصال'.tr),
          body: Obx(() => ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  _card([
                    _title('حالة الاتصال'.tr),
                    const SizedBox(height: 12),
                    _statusRow(
                      icon: Icons.wifi_rounded,
                      title: 'اتصال الإنترنت'.tr,
                      subtitle: controller.isOffline.value
                          ? 'غير متصل بالإنترنت'
                          : 'متصل بالإنترنت',
                      status: controller.isOffline.value
                          ? AppColors.warning
                          : AppColors.success,
                    ),
                    const Divider(height: 1, color: AppColors.divider),
                    _statusRow(
                      icon: Icons.cloud_rounded,
                      title: 'خدمات الخلفية'.tr,
                      subtitle: controller.isOffline.value
                          ? 'لا يمكن الوصول للخدمات دون إنترنت'
                          : 'متاح عبر الإنترنت',
                      status: controller.isOffline.value
                          ? AppColors.warning
                          : AppColors.success,
                    ),
                    const Divider(height: 1, color: AppColors.divider),
                    _statusRow(
                      icon: Icons.sync_rounded,
                      title: 'آخر مزامنة ناجحة'.tr,
                      subtitle: controller.lastSyncLabel.value,
                      status: AppColors.textSecondary,
                    ),
                  ]),
                  const SizedBox(height: 22),
                  _card([
                    _title('حالة البيانات المحلية'.tr),
                    const SizedBox(height: 12),
                    _statusRow(
                      icon: Icons.storage_rounded,
                      title: 'البيانات المحلية'.tr,
                      subtitle: _localStatusMessage(),
                      status: AppColors.textSecondary,
                    ),
                  ]),
                  const SizedBox(height: 22),
                  _card([
                    _title('المزامنة اليدوية'.tr),
                    const SizedBox(height: 12),
                    _actionTile(
                      icon: Icons.sync_rounded,
                      title: 'مزامنة الآن'.tr,
                      subtitle: 'مزامنة بياناتك مع حسابك'.tr,
                      onTap: controller.isSyncing.value
                          ? null
                          : () => controller.syncNow(),
                      isDestructive: false,
                    ),
                  ]),
                  const SizedBox(height: 22),
                  _card([
                    _title('السلوك الافتراضي'.tr),
                    const SizedBox(height: 12),
                    _infoRow(
                      icon: Icons.info_outline_rounded,
                      title: 'السياسة الأساسية'.tr,
                      description:
                          'يحتفظ التطبيق ببياناتك المحلية عند فشل الشبكة، ولا نمسح الحساب أو القراءات بسبب انقطاع الإنترنت.'.tr,
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

  Widget _statusRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color status,
  }) =>
      ListTile(
        leading: Icon(icon, color: status),
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
        trailing: Icon(Icons.check_circle_rounded,
            color: status, size: 22),
      );

  Widget _infoRow({
    required IconData icon,
    required String title,
    required String description,
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

  String _localStatusMessage() {
    return 'تُح Burke بياناتك المحلية على هذا الجهاز ولا تُمحى عند فقدان الاتصال.';
  }
}
