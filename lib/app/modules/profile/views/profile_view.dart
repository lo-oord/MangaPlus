import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/theme/app_palette.dart';
import 'package:mangaplus/app/core/theme/design_tokens.dart';
import 'package:mangaplus/app/data/models/user_profile.dart';
import 'package:mangaplus/app/modules/profile/controllers/profile_controller.dart';
import 'package:mangaplus/app/modules/profile/views/reading_stats_panel.dart';
import 'package:mangaplus/app/routes/app_pages.dart';
import 'package:mangaplus/app/widgets/app_buttons.dart';
import 'package:mangaplus/app/widgets/app_dialogs.dart';
import 'package:mangaplus/app/widgets/app_surfaces.dart';
import 'package:mangaplus/app/widgets/brand_state.dart';
import 'package:mangaplus/app/widgets/mangaplus_app_bar.dart';
import 'package:mangaplus/app/widgets/theme_aware_builder.dart';

/// Settings hub.
///
/// The layout is built from the shared [AppSection] / [AppSettingsTile] pair, so
/// row heights, icon containers, dividers and section rhythm match every other
/// grouped screen in the app.
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
                _ProfileHeader(
                  controller: controller,
                  onOpenDetails: () => Get.toNamed(Routes.PROFILE_DETAILS),
                  onEditName: _editDisplayName,
                ),
                const SizedBox(height: AppSpacing.md),
                const ReadingStatsPanel(),
                const SizedBox(height: AppSpacing.section),
                AppSection(
                  title: 'التفضيلات'.tr,
                  children: [
                    _languageTile(context),
                    AppSettingsTile(
                      icon: controller.isDarkMode.value
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      title: 'المظهر'.tr,
                      subtitle:
                          controller.isDarkMode.value ? 'داكن'.tr : 'فاتح'.tr,
                      switchValue: controller.isDarkMode.value,
                      onSwitchChanged: controller.changeTheme,
                    ),
                  ],
                ),
                AppSection(
                  title: 'مكتبتي'.tr,
                  children: [
                    AppSettingsTile(
                      icon: Icons.notifications_none_rounded,
                      title: 'الإشعارات'.tr,
                      onTap: () => Get.toNamed(Routes.NOTIFICATIONS),
                    ),
                    AppSettingsTile(
                      icon: Icons.history_rounded,
                      title: 'سجل القراءة'.tr,
                      onTap: () => Get.toNamed(Routes.HISTORY),
                    ),
                    AppSettingsTile(
                      icon: Icons.download_outlined,
                      title: 'التحميلات'.tr,
                      onTap: () => Get.toNamed(Routes.DOWNLOAD),
                    ),
                    AppSettingsTile(
                      icon: Icons.storage_rounded,
                      title: 'التخزين المحلي'.tr,
                      onTap: () => Get.toNamed(Routes.LOCAL_LIBRARY),
                    ),
                  ],
                ),
                AppSection(
                  title: 'الإشعارات'.tr,
                  subtitle: 'تنبيهات الفصول الجديدة'.tr,
                  children: [
                    AppSettingsTile(
                      icon: Icons.favorite_border_rounded,
                      title: 'إشعارات المفضلات'.tr,
                      subtitle: 'تنبيه عند توفر فصل جديد في أعمالك المحفوظة'.tr,
                      switchValue:
                          controller.favoritesNotificationsEnabled.value,
                      onSwitchChanged: controller.setFavoritesNotifications,
                    ),
                    AppSettingsTile(
                      icon: Icons.menu_book_rounded,
                      title: 'إشعارات المانجا'.tr,
                      switchValue: controller.mangaNotificationsEnabled.value,
                      onSwitchChanged: controller.setMangaNotifications,
                    ),
                    AppSettingsTile(
                      icon: Icons.auto_stories_rounded,
                      title: 'إشعارات الروايات'.tr,
                      switchValue: controller.novelNotificationsEnabled.value,
                      onSwitchChanged: controller.setNovelNotifications,
                    ),
                  ],
                ),
                AppSection(
                  title: 'حول التطبيق'.tr,
                  children: [
                    AppSettingsTile(
                      icon: Icons.info_outline_rounded,
                      title: 'حول التطبيق'.tr,
                      value: 'الإصدار 1.1',
                      onTap: () => _showAboutDialog(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

  Widget _languageTile(BuildContext context) => PopupMenuButton<String>(
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
              Icon(
                Icons.expand_more_rounded,
                size: AppSizes.icon,
                color: context.palette.icon,
              ),
            ],
          ),
        ),
      );

  Future<void> _editDisplayName(String current) async {
    final name = TextEditingController(text: current);
    final result = await AppDialogs.show<bool>(
      title: 'الاسم الظاهر'.tr,
      icon: Icons.edit_outlined,
      content: TextField(
        controller: name,
        autofocus: true,
        maxLength: 40,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: 'الاسم الظاهر'.tr,
          hintText: 'اكتب اسمًا يظهر للآخرين'.tr,
        ),
        onSubmitted: (_) {
          if (name.text.trim().isNotEmpty) Get.back<bool>(result: true);
        },
      ),
      actions: [
        AppButton(
          label: 'إلغاء'.tr,
          variant: AppButtonVariant.ghost,
          compact: true,
          onPressed: () => Get.back<bool>(result: false),
        ),
        AppButton(
          label: 'حفظ'.tr,
          compact: true,
          onPressed: () {
            final value = name.text.trim();
            if (value.isNotEmpty && value.length <= 40) {
              Get.back<bool>(result: true);
            }
          },
        ),
      ],
    );
    if (result == true) await controller.updateDisplayName(name.text);
    name.dispose();
  }

  void _showAboutDialog(BuildContext context) => AppDialogs.show<void>(
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
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.palette.textSecondary,
                    height: 1.7,
                  ),
            ),
          ],
        ),
      );
}

/// Account summary at the top of Settings.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.controller,
    required this.onOpenDetails,
    required this.onEditName,
  });

  final ProfileController controller;
  final VoidCallback onOpenDetails;
  final ValueChanged<String> onEditName;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (controller.accountLoading.value) {
      return const AppCard(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(child: MangaPlusLoader(size: 42)),
      );
    }
    final account = controller.accountProfile.value;
    if (account == null || account.isGuest) {
      final guestName = account?.displayName.trim() ?? '';
      return AppCard(
        onTap: onOpenDetails,
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: p.surfaceVariant,
              backgroundImage:
                  account == null ? null : _avatarProvider(account),
              child: account == null ||
                      (account.photoData.isEmpty && account.photoUrl.isEmpty)
                  ? Icon(
                      Icons.person_outline_rounded,
                      size: 32,
                      color: p.icon,
                    )
                  : null,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    guestName.isEmpty ? 'حسابك في MangaPlus'.tr : guestName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'سجّل الدخول لمزامنة القراءة والمفضلة'.tr,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'تسجيل الدخول'.tr,
                    icon: Icons.login_rounded,
                    compact: true,
                    onPressed: controller.openAuth,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return AppCard(
      onTap: onOpenDetails,
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(account.isVerified ? 3 : 0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: account.isVerified
                  ? Border.all(color: const Color(0xffD4A72C), width: 2.5)
                  : null,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: p.surfaceVariant,
                  backgroundImage: _avatarProvider(account),
                  child: account.photoData.isEmpty && account.photoUrl.isEmpty
                      ? Icon(Icons.person_rounded, size: 36, color: p.icon)
                      : null,
                ),
                PositionedDirectional(
                  bottom: -2,
                  end: -2,
                  child: IconButton(
                    tooltip: 'تغيير الصورة'.tr,
                    onPressed: controller.savingAccount.value
                        ? null
                        : controller.changeAvatar,
                    icon: const Icon(Icons.camera_alt_rounded, size: 15),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(30, 30),
                      fixedSize: const Size(30, 30),
                      padding: EdgeInsets.zero,
                      foregroundColor: p.onPrimary,
                      backgroundColor: p.primary,
                      shape: const CircleBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '@${account.username}',
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: p.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    if (account.isVerified) ...[
                      const SizedBox(width: AppSpacing.xxs),
                      const _VerifiedBadge(),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        account.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontSize: 19,
                            ),
                      ),
                    ),
                    AppIconButton(
                      icon: Icons.edit_outlined,
                      size: 18,
                      dense: true,
                      tooltip: 'تعديل الاسم الظاهر'.tr,
                      onPressed: controller.savingAccount.value
                          ? null
                          : () => onEditName(account.displayName),
                    ),
                  ],
                ),
                if (account.isOfficialDeveloper) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  const _OfficialBadge(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  ImageProvider? _avatarProvider(UserProfile account) {
    if (account.photoData.isNotEmpty) {
      try {
        return MemoryImage(base64Decode(account.photoData));
      } catch (_) {
        // بيانات الصورة القديمة أو غير الصالحة لا تمنع عرض رابط صورة احتياطي.
      }
    }
    return account.photoUrl.isEmpty
        ? null
        : CachedNetworkImageProvider(account.photoUrl);
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();

  static const Color _gold = Color(0xffD4A72C);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: _gold.withValues(alpha: .13),
          borderRadius: AppRadii.pillAll,
          border: Border.all(color: _gold.withValues(alpha: .45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified_rounded, size: 12, color: _gold),
            const SizedBox(width: 3),
            Text(
              'موثق'.tr,
              style: const TextStyle(
                color: _gold,
                fontSize: 10,
                height: 1.1,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
}

class _OfficialBadge extends StatelessWidget {
  const _OfficialBadge();

  static const Color _gold = Color(0xffD4A72C);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _gold.withValues(alpha: .10),
          borderRadius: AppRadii.xsAll,
          border: Border.all(color: _gold.withValues(alpha: .42)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield_rounded, size: 12, color: _gold),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                'حساب رسمي للمطور'.tr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _gold,
                  fontSize: 10,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
}
