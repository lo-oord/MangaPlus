import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/theme/app_palette.dart';
import 'package:mangaplus/app/core/theme/design_tokens.dart';
import 'package:mangaplus/app/data/models/user_profile.dart';
import 'package:mangaplus/app/modules/profile/controllers/profile_controller.dart';
import 'package:mangaplus/app/widgets/app_buttons.dart';
import 'package:mangaplus/app/widgets/app_feedback.dart';
import 'package:mangaplus/app/widgets/app_surfaces.dart';
import 'package:mangaplus/app/widgets/brand_state.dart';

/// The account card at the top of the profile screen.
///
/// It renders only values the app actually stores (avatar, display name,
/// username, e-mail + verification, bio, join date) and exposes the two real
/// actions: change the avatar and edit the profile.
class ProfileIdentityCard extends StatelessWidget {
  const ProfileIdentityCard({
    super.key,
    required this.controller,
    required this.onEdit,
    required this.onOpenAuth,
    required this.onManageAccount,
  });

  final ProfileController controller;
  final VoidCallback onEdit;
  final VoidCallback onOpenAuth;
  final VoidCallback onManageAccount;

  @override
  Widget build(BuildContext context) => Obx(() {
        if (controller.accountLoading.value &&
            controller.accountProfile.value == null) {
          return const AppCard(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(child: MangaPlusLoader(size: 42)),
          );
        }
        final account = controller.accountProfile.value;
        if (account == null || account.isGuest) {
          return _guestCard(context, account);
        }
        return _accountCard(context, account);
      });

  Widget _guestCard(BuildContext context, UserProfile? account) {
    final p = context.palette;
    final name = account?.displayName.trim() ?? '';
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: p.surfaceVariant,
                child: Icon(Icons.person_outline_rounded, size: 30, color: p.icon),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'حسابك في MangaPlus'.tr : name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'وضع الضيف: بياناتك محفوظة على هذا الجهاز فقط'.tr,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'تسجيل الدخول أو إنشاء حساب'.tr,
            icon: Icons.login_rounded,
            expand: true,
            onPressed: onOpenAuth,
          ),
        ],
      ),
    );
  }

  Widget _accountCard(BuildContext context, UserProfile account) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final email = account.email.trim();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(controller: controller, account: account),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.displayName.trim().isEmpty
                          ? account.username
                          : account.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleLarge?.copyWith(fontSize: 20),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '@${account.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(
                        color: p.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (account.isVerified || account.isOfficialDeveloper) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: AppSpacing.xxs,
                        runSpacing: AppSpacing.xxs,
                        children: [
                          if (account.isVerified) const _VerifiedBadge(),
                          if (account.isOfficialDeveloper) const _OfficialBadge(),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              AppIconButton(
                icon: Icons.edit_outlined,
                size: 18,
                dense: true,
                tooltip: 'تعديل الملف الشخصي'.tr,
                onPressed: controller.savingAccount.value ? null : onEdit,
              ),
            ],
          ),
          if (email.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _emailRow(context, account, email),
          ],
          if (account.bio.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              account.bio.trim(),
              style: text.bodyMedium?.copyWith(color: p.textSecondary, height: 1.6),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(Icons.event_available_rounded, size: AppSizes.iconSm, color: p.icon),
              const SizedBox(width: AppSpacing.xxs),
              Expanded(
                child: Text(
                  '${'انضم في'.tr} ${_formatDate(account.createdAt)}',
                  style: text.bodySmall?.copyWith(color: p.textSecondary),
                ),
              ),
              AppIconButton(
                icon: Icons.tag_rounded,
                size: 16,
                dense: true,
                tooltip: 'نسخ معرّف الحساب'.tr,
                onPressed: () => _copyUid(account.uid),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          AppButton(
            label: 'تعديل الملف الشخصي'.tr,
            icon: Icons.edit_outlined,
            variant: AppButtonVariant.outline,
            expand: true,
            onPressed: controller.savingAccount.value ? null : onEdit,
          ),
        ],
      ),
    );
  }

  Widget _emailRow(BuildContext context, UserProfile account, String email) {
    final p = context.palette;
    final verified = account.emailVerified;
    return Row(
      children: [
        Icon(Icons.alternate_email_rounded, size: AppSizes.iconSm, color: p.icon),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            email,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(width: AppSpacing.xxs),
        GestureDetector(
          onTap: onManageAccount,
          child: AppPill(
            label: verified ? 'البريد موثق'.tr : 'البريد غير موثق'.tr,
            icon: verified ? Icons.verified_rounded : Icons.error_outline_rounded,
            tone: verified ? AppPillTone.success : AppPillTone.warning,
          ),
        ),
      ],
    );
  }

  Future<void> _copyUid(String uid) async {
    await Clipboard.setData(ClipboardData(text: uid));
    AppFeedback.show(
      title: 'تم النسخ'.tr,
      message: 'تم نسخ معرّف الحساب'.tr,
      type: AppNoticeType.success,
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}/$month/$day';
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.controller, required this.account});

  final ProfileController controller;
  final UserProfile account;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final hasPhoto = account.photoData.isNotEmpty || account.photoUrl.isNotEmpty;
    return Container(
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
            backgroundImage: _provider(account),
            child: hasPhoto
                ? null
                : Icon(Icons.person_rounded, size: 36, color: p.icon),
          ),
          PositionedDirectional(
            bottom: -2,
            end: -2,
            child: AppIconButton(
              icon: Icons.camera_alt_rounded,
              size: 14,
              dense: true,
              filled: true,
              tooltip: 'تغيير الصورة'.tr,
              onPressed:
                  controller.savingAccount.value ? null : controller.changeAvatar,
            ),
          ),
        ],
      ),
    );
  }

  ImageProvider? _provider(UserProfile account) {
    if (account.photoData.isNotEmpty) {
      try {
        return MemoryImage(base64Decode(account.photoData));
      } catch (_) {
        // An old or corrupt image must not hide the fallback avatar.
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
