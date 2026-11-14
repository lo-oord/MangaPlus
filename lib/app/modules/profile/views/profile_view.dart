import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/navigation/app_navigation.dart';
import 'package:mangaplus/app/core/settings/reading_preferences.dart';
import 'package:mangaplus/app/core/theme/app_motion.dart';
import 'package:mangaplus/app/core/theme/app_palette.dart';
import 'package:mangaplus/app/core/theme/design_tokens.dart';
import 'package:mangaplus/app/data/models/user_profile.dart';
import 'package:mangaplus/app/modules/profile/controllers/profile_controller.dart';
import 'package:mangaplus/app/modules/profile/views/reading_stats_panel.dart';
import 'package:mangaplus/app/modules/profile/views/settings_about_view.dart';
import 'package:mangaplus/app/modules/profile/views/settings_appearance_view.dart';
import 'package:mangaplus/app/modules/profile/views/settings_notifications_view.dart';
import 'package:mangaplus/app/modules/profile/views/settings_reading_view.dart';
import 'package:mangaplus/app/routes/app_pages.dart';
import 'package:mangaplus/app/widgets/app_buttons.dart';
import 'package:mangaplus/app/widgets/app_dialogs.dart';
import 'package:mangaplus/app/widgets/app_surfaces.dart';
import 'package:mangaplus/app/widgets/brand_state.dart';
import 'package:mangaplus/app/widgets/mangaplus_app_bar.dart';
import 'package:mangaplus/app/widgets/theme_aware_builder.dart';

/// Settings hub.
///
/// Rows use the shared [AppSection] / [AppSettingsTile] pair so heights, icon
/// containers, dividers and section rhythm match every grouped screen. Only
/// settings that change real behaviour are listed here; each entry either opens
/// a dedicated page or navigates to the library it controls.
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
                  onOpenDetails: () =>
                      AppNavigation.toNamed(Routes.PROFILE_DETAILS),
                  onEditName: _editDisplayName,
                ),
                if (controller.accountProfile.value != null &&
                    !controller.accountProfile.value!.isGuest &&
                    !controller.accountProfile.value!.emailVerified) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _VerifyBanner(
                    controller: controller,
                    onResend: controller.resendVerificationEmail,
                    onRefresh: controller.refreshVerification,
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                const ReadingStatsPanel(),
                const SizedBox(height: AppSpacing.section),
                AppSection(
                  title: 'المظهر واللغة'.tr,
                  children: [
                    AppSettingsTile(
                      icon: Icons.palette_outlined,
                      title: 'المظهر'.tr,
                      value: _themeLabel,
                      onTap: () => _open(const SettingsAppearanceView()),
                    ),
                    _languageTile(context),
                  ],
                ),
                AppSection(
                  title: 'القراءة'.tr,
                  children: [
                    AppSettingsTile(
                      icon: Icons.auto_stories_outlined,
                      title: 'إعدادات القراءة الافتراضية'.tr,
                      value: ReadingPreferences.modeLabel(controller.readingMode.value),
                      onTap: () => _open(const SettingsReadingView()),
                    ),
                  ],
                ),
                AppSection(
                  title: 'المكتبة'.tr,
                  children: [
                    AppSettingsTile(
                      icon: Icons.notifications_none_rounded,
                      title: 'الإشعارات'.tr,
                      onTap: () => _open(const SettingsNotificationsView()),
                    ),
                    AppSettingsTile(
                      icon: Icons.bookmark_border_rounded,
                      title: 'المفضلة'.tr,
                      onTap: () => AppNavigation.toNamed(Routes.BOOKMARK),
                    ),
                    AppSettingsTile(
                      icon: Icons.history_rounded,
                      title: 'سجل القراءة'.tr,
                      onTap: () => AppNavigation.toNamed(Routes.HISTORY),
                    ),
                    AppSettingsTile(
                      icon: Icons.download_outlined,
                      title: 'التحميلات'.tr,
                      onTap: () => AppNavigation.toNamed(Routes.DOWNLOAD),
                    ),
                    AppSettingsTile(
                      icon: Icons.storage_rounded,
                      title: 'التخزين المحلي'.tr,
                      onTap: () => AppNavigation.toNamed(Routes.LOCAL_LIBRARY),
                    ),
                  ],
                ),
                AppSection(
                  title: 'حول'.tr,
                  children: [
                    AppSettingsTile(
                      icon: Icons.info_outline_rounded,
                      title: 'حول التطبيق والتراخيص'.tr,
                      value: '${'الإصدار'.tr} $kAppVersion',
                      onTap: () => _open(const SettingsAboutView()),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

  String get _themeLabel => switch (controller.themeMode.value) {
        ThemeMode.light => 'فاتح'.tr,
        ThemeMode.dark => 'داكن'.tr,
        ThemeMode.system => 'حسب النظام'.tr,
      };

  Future<void> _open(Widget page) async {
    await Get.to(
      () => page,
      transition: Transition.rightToLeftWithFade,
      duration: AppMotion.page,
      curve: AppMotion.emphasized,
    );
    controller.reloadReadingPreferences();
  }

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
}

/// Shown only while a registered account still has an unverified email.
class _VerifyBanner extends StatelessWidget {
  const _VerifyBanner({
    required this.controller,
    required this.onResend,
    required this.onRefresh,
  });

  final ProfileController controller;
  final Future<void> Function() onResend;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: p.warning.withValues(alpha: .10),
        borderRadius: AppRadii.mdAll,
        border: Border.all(color: p.warning.withValues(alpha: .45)),
      ),
      child: Row(
        children: [
          Icon(Icons.mark_email_unread_outlined, color: p.warning),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'بريدك غير موثق'.tr,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  'أكّد بريدك لتفعيل مزامنة القراءة.'.tr,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: p.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: controller.savingAccount.value ? null : onResend,
            child: Text('إرسال'.tr),
          ),
          TextButton(
            onPressed: controller.savingAccount.value ? null : onRefresh,
            child: Text('تحققت'.tr),
          ),
        ],
      ),
    );
  }
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
