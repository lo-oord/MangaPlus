import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/navigation/app_navigation.dart';
import 'package:mangaplus/app/core/theme/app_palette.dart';
import 'package:mangaplus/app/core/theme/design_tokens.dart';
import 'package:mangaplus/app/modules/profile/controllers/profile_controller.dart';
import 'package:mangaplus/app/modules/profile/controllers/reader_preferences_controller.dart';
import 'package:mangaplus/app/modules/profile/controllers/storage_usage_controller.dart';
import 'package:mangaplus/app/modules/profile/views/reading_stats_panel.dart';
import 'package:mangaplus/app/modules/profile/widgets/profile_identity_card.dart';
import 'package:mangaplus/app/modules/profile/widgets/profile_quick_actions.dart';
import 'package:mangaplus/app/routes/app_pages.dart';
import 'package:mangaplus/app/widgets/app_buttons.dart';
import 'package:mangaplus/app/widgets/app_dialogs.dart';
import 'package:mangaplus/app/widgets/app_surfaces.dart';
import 'package:mangaplus/app/widgets/brand_state.dart';
import 'package:mangaplus/app/widgets/mangaplus_app_bar.dart';
import 'package:mangaplus/app/widgets/theme_aware_builder.dart';

/// The unified profile and settings screen.
///
/// One screen covers the whole user journey: the account card, a compact
/// reading summary, quick actions, then the real account, appearance, reader,
/// library, notification and support sections. Every tile opens an existing
/// destination or writes a value the app already reads.
class ProfileView extends GetView<ProfileController> {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) => ThemeAwareBuilder(
        builder: (context) => Scaffold(
          backgroundColor: context.palette.background,
          appBar: MangaPlusAppBar(title: 'الإعدادات'.tr),
          body: Obx(
            () => ListView(
              padding: AppSpacing.pageInsets,
              children: [
                ProfileIdentityCard(
                  controller: controller,
                  onEdit: () => AppNavigation.toNamed(Routes.PROFILE_EDIT),
                  onOpenAuth: () => AppNavigation.toNamed(Routes.AUTH),
                  onManageAccount: () =>
                      AppNavigation.toNamed(Routes.ACCOUNT_SETTINGS),
                ),
                const SizedBox(height: AppSpacing.md),
                const ReadingStatsPanel(),
                const SizedBox(height: AppSpacing.section),
                AppSection(
                  title: 'إجراءات سريعة'.tr,
                  children: [
                    ProfileQuickActions(controller: controller),
                  ],
                ),
                AppSection(
                  title: 'الحساب'.tr,
                  subtitle: 'مدير الحساب والأمان'.tr,
                  children: [
                    AppSettingsTile(
                      icon: Icons.manage_accounts_outlined,
                      title: 'إدارة الحساب'.tr,
                      subtitle: 'البريد، كلمة المرور، حذف الحساب'.tr,
                      onTap: () =>
                          AppNavigation.toNamed(Routes.ACCOUNT_SETTINGS),
                    ),
                  ],
                ),
                AppSection(
                  title: 'المظهر'.tr,
                  children: [
                    _languageTile(context),
                    Obx(
                      () => AppSettingsTile(
                        icon: Icons.dark_mode_rounded,
                        title: 'المظهر'.tr,
                        subtitle: _themeSubtitle(),
                        switchValue:
                            controller.themeMode.value == ThemeMode.dark,
                        onSwitchChanged: (enabled) => controller
                            .changeThemeMode(
                              enabled ? ThemeMode.dark : ThemeMode.light,
                            ),
                      ),
                    ),
                  ],
                ),
                AppSection(
                  title: 'القارئ'.tr,
                  subtitle: 'تُحفظ الإعدادات على هذا الجهاز'.tr,
                  children: [
                    _readerTile(
                      context,
                      icon: Icons.fit_screen_rounded,
                      title: 'شكل العرض'.tr,
                      value: Get.find<ReaderPreferencesController>().fit.value,
                      options: const {
                        'width': 'حسب العرض',
                        'height': 'حسب الارتفاع',
                        'screen': 'حسب الشاشة',
                        'natural': 'طبيعي',
                      },
                      onSelect: Get.find<ReaderPreferencesController>().setFit,
                    ),
                    _readerTile(
                      context,
                      icon: Icons.read_more_rounded,
                      title: 'وضع القراءة'.tr,
                      value:
                          Get.find<ReaderPreferencesController>().readingMode.value,
                      options: const {
                        'scroll': 'تمرير',
                        'paged': 'صفحات',
                      },
                      onSelect:
                          Get.find<ReaderPreferencesController>().setReadingMode,
                    ),
                    _readerTile(
                      context,
                      icon: Icons.swap_horiz_rounded,
                      title: 'اتجاه الصفحات'.tr,
                      value:
                          Get.find<ReaderPreferencesController>().direction.value,
                      options: const {
                        'rtl': 'من اليمين إلى اليسار',
                        'ltr': 'من اليسار إلى اليمين',
                      },
                      onSelect:
                          Get.find<ReaderPreferencesController>().setDirection,
                    ),
                    _readerTile(
                      context,
                      icon: Icons.contrast_rounded,
                      title: 'خلفية الصفحات'.tr,
                      value:
                          Get.find<ReaderPreferencesController>().background.value,
                      options: const {
                        'black': 'أسود',
                        'white': 'أبيض',
                        'gray': 'رمادي',
                        'app': 'تطبيقي',
                      },
                      onSelect:
                          Get.find<ReaderPreferencesController>().setBackground,
                    ),
                    _readerTile(
                      context,
                      icon: Icons.image_rounded,
                      title: 'جودة الصور'.tr,
                      value: Get.find<ReaderPreferencesController>().imageQuality
                          .value,
                      options: const {
                        'low': 'منخفضة',
                        'medium': 'متوسطة',
                        'high': 'عالية',
                      },
                      onSelect: Get.find<ReaderPreferencesController>().setImageQuality,
                    ),
                    _readerTile(
                      context,
                      icon: Icons.screen_rotation_rounded,
                      title: 'اتجاه الشاشة'.tr,
                      value: Get.find<ReaderPreferencesController>().orientation
                          .value,
                      options: const {
                        'auto': 'تلقائي',
                        'portrait': 'عمودي',
                        'landscape': 'أفقي',
                      },
                      onSelect: Get.find<ReaderPreferencesController>().setOrientation,
                    ),
                  ],
                ),
                AppSection(
                  title: 'المكتبة والتزامن'.tr,
                  subtitle: 'حالة مزامنة البيانات'.tr,
                  children: [
                    Obx(
                      () => AppSettingsTile(
                        icon: Icons.cloud_sync_rounded,
                        title: 'حالة المزامنة'.tr,
                        value: _syncValue(controller.syncState.value),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => controller.syncNow(),
                      ),
                    ),
                    Obx(
                      () => AppSettingsTile(
                        icon: Icons.history_rounded,
                        title: 'آخر مزامنة'.tr,
                        value: controller.lastSyncAt.value == null
                            ? 'لا متزامنة بعد'.tr
                            : _formatSyncTime(controller.lastSyncAt.value!),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => controller.syncNow(),
                      ),
                    ),
                    Obx(
                      () => AppSettingsTile(
                        icon: Icons.favorite_border_rounded,
                        title: 'مزامنة المفضلة'.tr,
                        subtitle:
                            'مزامنة المفضلة وسجل القراءة مع حسابك'.tr,
                        switchValue: controller.favoritesNotificationsEnabled.value,
                        onSwitchChanged: controller.setFavoritesSync,
                      ),
                    ),
                  ],
                ),
                AppSection(
                  title: 'الإشعارات'.tr,
                  subtitle: 'تنبيهات الفصول الجديدة'.tr,
                  children: [
                    Obx(
                      () => AppSettingsTile(
                        icon: Icons.menu_book_rounded,
                        title: 'إشعارات المانجا'.tr,
                        switchValue: controller.mangaNotificationsEnabled.value,
                        onSwitchChanged: controller.setMangaNotifications,
                      ),
                    ),
                    Obx(
                      () => AppSettingsTile(
                        icon: Icons.auto_stories_rounded,
                        title: 'إشعارات الروايات'.tr,
                        switchValue: controller.novelNotificationsEnabled.value,
                        onSwitchChanged: controller.setNovelNotifications,
                      ),
                    ),
                    Obx(
                      () => AppSettingsTile(
                        icon: Icons.favorite_border_rounded,
                        title: 'إشعارات المفضلات'.tr,
                        subtitle: 'تنبيه عند توفر فصل جديد في أعمالك المحفوظة'.tr,
                        switchValue: controller.favoritesNotificationsEnabled.value,
                        onSwitchChanged: controller.setFavoritesNotifications,
                      ),
                    ),
                  ],
                ),
                AppSection(
                  title: 'التحميلات والتخزين'.tr,
                  children: [
                    _storageSection(context),
                    AppSettingsTile(
                      icon: Icons.storage_rounded,
                      title: 'إدارة التنزيلات'.tr,
                      subtitle: 'شاشة التحميلات والمكتبة المحلية'.tr,
                      onTap: () => AppNavigation.toNamed(Routes.LOCAL_LIBRARY),
                    ),
                  ],
                ),
                AppSection(
                  title: 'الدعم'.tr,
                  children: [
                    AppSettingsTile(
                      icon: Icons.info_outline_rounded,
                      title: 'حول التطبيق'.tr,
                      value: 'الإصدار 1.1'.tr,
                      onTap: () => _showAboutDialog(context),
                    ),
                  ],
                ),
                AppButton(
                  label: 'تسجيل الخروج'.tr,
                  icon: Icons.logout_rounded,
                  variant: AppButtonVariant.outline,
                  expand: true,
                  onPressed: () => controller.signOut(),
                ),
              ],
            ),
          ),
        ),
      );

  String _themeSubtitle() {
    switch (controller.themeMode.value) {
      case ThemeMode.light:
        return 'فاتح'.tr;
      case ThemeMode.dark:
        return 'داكن'.tr;
      case ThemeMode.system:
        return 'تلقائي (حسب الجهاز)'.tr;
    }
  }

  String _syncValue(AccountSyncState state) {
    switch (state) {
      case AccountSyncState.idle:
        return 'متزامن'.tr;
      case AccountSyncState.syncing:
        return 'جارٍ المزامنة'.tr;
      case AccountSyncState.failed:
        return 'فشلت المزامنة'.tr;
    }
  }

  String _formatSyncTime(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${value.year}/$month/$day $hour:$minute';
  }

  Widget _storageSection(BuildContext context) {
    final storage = Get.find<StorageUsageController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.storage_rounded, color: context.palette.primary),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'استهلاك التخزين'.tr,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Obx(
                () => Text(
                  'تنزيلات: ${storage.downloadedCount.value} • '
                  'ذاكرة صور: ${storage.cacheSizeLabel} • '
                  'ملفات مؤقتة: ${storage.incompleteSizeLabel}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'الملفات المؤقتة تبقى فقط بعد تعذّر التحميل، والتنزيلات تبقى ما تمت فعليًا.'.tr,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: context.palette.textSecondary, height: 1.6),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'مسح ذاكرة الصور'.tr,
                variant: AppButtonVariant.outline,
                compact: true,
                onPressed: () => storage.clearImageCache(),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppButton(
                label: 'مسح الملفات المؤقتة'.tr,
                variant: AppButtonVariant.outline,
                compact: true,
                onPressed: () => storage.clearTemporaryFiles(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _readerTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required Map<String, String> options,
    required Future<void> Function(String) onSelect,
  }) {
    return AppSettingsTile(
      icon: icon,
      title: title,
      value: options[value] ?? value,
      onTap: () => _openReaderChoice(
        title: title,
        value: value,
        options: options,
        onSelect: onSelect,
      ),
    );
  }

  Future<String?> _openReaderChoice({
    required String title,
    required String value,
    required Map<String, String> options,
    required Future<void> Function(String) onSelect,
  }) async {
    final selected = await AppDialogs.show<String>(
      title: title,
      icon: Icons.tune_rounded,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final entry in options.entries)
            AppSettingsTile(
              icon: Icons.radio_button_unchecked_rounded,
              title: entry.value,
              value: entry.key,
              onTap: () => Get.back<String>(result: entry.key),
            ),
        ],
      ),
    );
    if (selected == null) return null;
    await onSelect(selected);
    return selected;
  }

  Widget _languageTile(BuildContext context) {
    final controller = Get.find<ProfileController>();
    return PopupMenuButton<String>(
      tooltip: 'اللغة'.tr,
      onSelected: controller.changeLanguage,
      itemBuilder: (_) => [
        PopupMenuItem(value: 'ar_SA', child: Text('العربية'.tr)),
        PopupMenuItem(value: 'en_US', child: Text('الإنجليزية'.tr)),
      ],
      child: AppSettingsTile(
        icon: Icons.language_rounded,
        title: 'اللغة'.tr,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              controller.selectedLanguage.value == 'ar_SA'
                  ? 'العربية'.tr
                  : 'الإنجليزية'.tr,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(width: AppSpacing.xxs),
            const Icon(Icons.expand_more_rounded),
          ],
        ),
      ),
    );
  }

  Future<void> _showAboutDialog(BuildContext context) => AppDialogs.show<void>(
        title: 'حول التطبيق'.tr,
        icon: Icons.info_outline_rounded,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const MangaPlusLogo(size: 40),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'app_name'.tr,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${'قارئ مانجا ومانهوا'.tr}\n${'الإصدار'.tr}: 1.1',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: context.palette.textSecondary, height: 1.7),
            ),
          ],
        ),
      );
}
