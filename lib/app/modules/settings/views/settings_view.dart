import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/modules/settings/controllers/settings_controller.dart';
import 'package:mangaplus/app/routes/app_pages.dart';
import 'package:mangaplus/app/widgets/mangaplus_app_bar.dart';
import 'package:mangaplus/app/widgets/theme_aware_builder.dart';
import 'package:mangaplus/app/widgets/brand_state.dart';

class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) => ThemeAwareBuilder(
        builder: (context) => Scaffold(
          backgroundColor: AppColors.background,
          appBar: MangaPlusAppBar(title: 'الإعدادات'.tr),
          body: Obx(() => _buildBody(context)),
        ),
      );

  Widget _buildBody(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _sectionTitle('الحساب والملف الشخصي'.tr),
        _sectionGap(),
        _settingsCard([
          _navigationTile(
            icon: Icons.person_rounded,
            title: 'الحساب والملف الشخصي'.tr,
            subtitle: 'إدارة الهوية، كلمة المرور، وطرق الدخول'.tr,
            onTap: () => Get.toNamed(Routes.PROFILE_DETAILS),
          ),
        ]),
        const SizedBox(height: 22),
        _sectionTitle('المظهر والتخصيص'.tr),
        _sectionGap(),
        _settingsCard([
          _navigationTile(
            icon: Icons.palette_rounded,
            title: 'المظهر'.tr,
            subtitle: 'الوضع الداكن، الفاتح، أو التلقائي'.tr,
            onTap: () => Get.toNamed(Routes.APPEARANCE),
          ),
        ]),
        const SizedBox(height: 22),
        _sectionTitle('تجربة القراءة'.tr),
        _sectionGap(),
        _settingsCard([
          _navigationTile(
            icon: Icons.menu_book_rounded,
            title: 'إعدادات القارئ'.tr,
            subtitle: 'الاتجاه، التمرير، والتصفح'.tr,
            onTap: () => Get.toNamed(Routes.READER),
          ),
        ]),
        const SizedBox(height: 22),
        _sectionTitle('الإشعارات'.tr),
        _sectionGap(),
        _settingsCard([
          Obx(() => SwitchListTile.adaptive(
                value: controller.favoritesNotifications.value,
                onChanged: controller.setFavoritesNotifications,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                secondary: Icon(Icons.favorite_border_rounded, color: AppColors.icon),
                title: Text('إشعارات المفضلات'.tr,
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                subtitle: Text('تنبيه عند توفر فصل جديد في الأعمال المحفوظة'.tr,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                activeColor: AppColors.primary,
              )),
          const Divider(height: 1, color: AppColors.divider),
          Obx(() => SwitchListTile.adaptive(
                value: controller.mangaNotifications.value,
                onChanged: controller.setMangaNotifications,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                secondary: Icon(Icons.menu_book_rounded, color: AppColors.icon),
                title: Text('إشعارات المانجا'.tr,
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                subtitle: Text('التتبع والإشعارات المتعلقة بالمانجا'.tr,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                activeColor: AppColors.primary,
              )),
          const Divider(height: 1, color: AppColors.divider),
          Obx(() => SwitchListTile.adaptive(
                value: controller.novelNotifications.value,
                onChanged: controller.setNovelNotifications,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                secondary: Icon(Icons.auto_stories_rounded, color: AppColors.icon),
                title: Text('إشعارات الروايات'.tr,
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                subtitle: Text('التتبع والإشعارات المتعلقة بالروايات'.tr,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                activeColor: AppColors.primary,
              )),
          const Divider(height: 1, color: AppColors.divider),
          _navigationTile(
            icon: Icons.notifications_active_rounded,
            title: 'الإشعارات والرسائل'.tr,
            subtitle: 'رسائل التطبيق والإعلانات المهمة'.tr,
            onTap: () => Get.toNamed(Routes.NOTIFICATIONS),
          ),
        ]),
        const SizedBox(height: 22),
        _sectionTitle('اللغة والمنطقة'.tr),
        _sectionGap(),
        _settingsCard([
          _navigationTile(
            icon: Icons.language_rounded,
            title: 'اللغة'.tr,
            subtitle: 'العربية أو الإنجليزية'.tr,
            onTap: () => Get.toNamed(Routes.LANGUAGE_REGION),
          ),
        ]),
        const SizedBox(height: 22),
        _sectionTitle('التخزين وإدارة البيانات'.tr),
        _sectionGap(),
        _settingsCard([
          _navigationTile(
            icon: Icons.storage_rounded,
            title: 'التخزين والذاكرة المؤقتة'.tr,
            subtitle: 'مسح الصور المخزنة مؤقتًا ومراجعة البيانات'.tr,
            onTap: () => Get.toNamed(Routes.STORAGE),
          ),
        ]),
        const SizedBox(height: 22),
        _sectionTitle('الخصوصية والأمان'.tr),
        _sectionGap(),
        _settingsCard([
          _navigationTile(
            icon: Icons.security_rounded,
            title: 'الخصوصية والأمان'.tr,
            subtitle: 'إدارة الحساب، كلمة المرور، وتسجيل الخروج'.tr,
            onTap: () => Get.toNamed(Routes.PRIVACY_SECURITY),
          ),
        ]),
        const SizedBox(height: 22),
        _sectionTitle('الاتصال والمزامنة'.tr),
        _sectionGap(),
        _settingsCard([
          _syncSummaryTile(),
          const Divider(height: 1, color: AppColors.divider),
          _navigationTile(
            icon: Icons.sync_rounded,
            title: 'المزامنة والاتصال'.tr,
            subtitle: 'حالة الاتصال ومركز المزامنة'.tr,
            onTap: () => Get.toNamed(Routes.SYNC_CONNECTION),
          ),
        ]),
        const SizedBox(height: 22),
        _sectionTitle('الدعم والمساعدة'.tr),
        _sectionGap(),
        _settingsCard([
          _navigationTile(
            icon: Icons.help_outline_rounded,
            title: 'مركز المساعدة'.tr,
            subtitle: 'الأسئلة الشائعة والإرشادات'.tr,
            onTap: () => Get.toNamed(Routes.HELP),
          ),
          const Divider(height: 1, color: AppColors.divider),
          _navigationTile(
            icon: Icons.feedback_rounded,
            title: 'إرسال ملاحظات'.tr,
            subtitle: 'اقتراحاتك تساعدنا على التحسين'.tr,
            onTap: () => Get.toNamed(Routes.FEEDBACK),
          ),
        ]),
        const SizedBox(height: 22),
        _sectionTitle('حول MangaPlus'.tr),
        _sectionGap(),
        _settingsCard([
          _navigationTile(
            icon: Icons.info_outline_rounded,
            title: 'حول التطبيق'.tr,
            subtitle: 'الإصدار، البناء، ومعلومات التطبيق'.tr,
            onTap: () => Get.toNamed(Routes.ABOUT),
          ),
        ]),
        const SizedBox(height: 22),
        _settingsCard([
          Obx(() => _actionTile(
                icon: Icons.restore_outlined,
                title: 'إعادة تعيين الإعدادات الافتراضية'.tr,
                subtitle: 'استعادة قيم التطبيق دون حذف حسابك'.tr,
                onTap: controller.isResetting.value
                    ? null
                    : () => controller.resetAppSettings(),
                isDestructive: false,
              )),
        ]),
      ],
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

  Widget _sectionGap() => const SizedBox(height: 9);

  Widget _settingsCard(List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.divider.withValues(alpha: .72)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      );

  Widget _navigationTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) =>
      ListTile(
        leading: Icon(icon, color: AppColors.icon),
        title: Text(
          title,
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: AppColors.icon),
        onTap: onTap,
      );

  Widget _syncSummaryTile() => Obx(() => ListTile(
        leading: Icon(
          controller.isSyncing.value ? Icons.sync_rounded : Icons.cloud_queue_rounded,
          color: controller.isOffline.value ? AppColors.warning : AppColors.primary,
        ),
        title: Text(
          'حالة المزامنة'.tr,
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          _syncSubtitle(),
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        trailing: controller.isSyncing.value
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
            : Icon(Icons.chevron_right_rounded, color: AppColors.icon),
        onTap: () => Get.toNamed(Routes.SYNC_CONNECTION),
      ));

  String _syncSubtitle() {
    final offline = controller.isOffline.value;
    final syncing = controller.isSyncing.value;
    if (syncing) return 'جارٍ المزامنة...'.tr;
    final label = controller.lastSyncLabel.value;
    if (offline) {
      return 'غير متصل بالإنترنت • $label'.tr;
    }
    return 'متصل بالإنترنت • $label'.tr;
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    bool isDestructive = false,
  }) =>
      ListTile(
        leading: Icon(icon, color: isDestructive ? AppColors.error : AppColors.icon),
        title: Text(
          title,
          style: TextStyle(
            color: isDestructive ? AppColors.error : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(subtitle, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: isDestructive ? AppColors.error : AppColors.icon,
        ),
        onTap: onTap,
      );
}
