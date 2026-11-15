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
import 'package:mangaplus/app/widgets/mangaplus_app_bar.dart';
import 'package:mangaplus/app/widgets/theme_aware_builder.dart';

/// Edits the fields the user actually owns.
///
/// Only the display name and the bio are editable; the username, e-mail,
/// verification flags, official flag and permissions are shown read-only
/// because Firebase owns them.
class ProfileEditView extends StatefulWidget {
  const ProfileEditView({super.key});

  @override
  State<ProfileEditView> createState() => _ProfileEditViewState();
}

class _ProfileEditViewState extends State<ProfileEditView> {
  late final ProfileController _controller;
  final TextEditingController _name = TextEditingController();
  final TextEditingController _bio = TextEditingController();
  bool _saving = false;
  String? _nameError;
  String? _bioError;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<ProfileController>();
    final account = _controller.accountProfile.value;
    _name.text = account?.displayName ?? '';
    _bio.text = account?.bio ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ThemeAwareBuilder(
        builder: (context) => Scaffold(
          backgroundColor: context.palette.background,
          appBar: MangaPlusAppBar(title: 'تعديل الملف الشخصي'.tr),
          body: Obx(() {
            final account = _controller.accountProfile.value;
            if (account == null || account.isGuest) {
              return Center(
                child: Padding(
                  padding: AppSpacing.pageInsets,
                  child: Text(
                    'سجّل الدخول بحساب دائم لتعديل ملفك الشخصي.'.tr,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              );
            }
            return ListView(
              padding: AppSpacing.pageInsets,
              children: [
                _preview(context, account),
                const SizedBox(height: AppSpacing.section),
                AppSection(
                  title: 'المعلومات القابلة للتعديل'.tr,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _name,
                            maxLength: 40,
                            textInputAction: TextInputAction.next,
                            enabled: !_saving,
                            decoration: InputDecoration(
                              labelText: 'الاسم الظاهر'.tr,
                              hintText: 'اكتب اسمًا يظهر للآخرين'.tr,
                              errorText: _nameError,
                            ),
                            onChanged: (_) {
                              if (_nameError != null) {
                                setState(() => _nameError = null);
                              }
                            },
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          TextField(
                            controller: _bio,
                            maxLength: 300,
                            maxLines: 4,
                            minLines: 3,
                            enabled: !_saving,
                            decoration: InputDecoration(
                              labelText: 'النبذة'.tr,
                              hintText: 'عرّف بنفسك في سطرين'.tr,
                              errorText: _bioError,
                              alignLabelWithHint: true,
                            ),
                            onChanged: (_) {
                              if (_bioError != null) {
                                setState(() => _bioError = null);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                AppSection(
                  title: 'معلومات الحساب'.tr,
                  subtitle: 'لا يمكن تعديل هذه الحقول من التطبيق'.tr,
                  children: [
                    AppSettingsTile(
                      icon: Icons.alternate_email_rounded,
                      title: 'اسم المستخدم'.tr,
                      value: '@${account.username}',
                      enabled: false,
                    ),
                    AppSettingsTile(
                      icon: Icons.mail_outline_rounded,
                      title: 'البريد الإلكتروني'.tr,
                      value: account.email.isEmpty ? 'غير متاح'.tr : account.email,
                      enabled: false,
                    ),
                    AppSettingsTile(
                      icon: account.emailVerified
                          ? Icons.verified_user_rounded
                          : Icons.gpp_maybe_rounded,
                      title: 'حالة البريد'.tr,
                      value: account.emailVerified
                          ? 'موثق'.tr
                          : 'غير موثق'.tr,
                      enabled: false,
                    ),
                    AppSettingsTile(
                      icon: Icons.tag_rounded,
                      title: 'معرّف الحساب'.tr,
                      value: account.uid,
                      onTap: () => _copy(account.uid),
                    ),
                  ],
                ),
                AppButton(
                  label: 'حفظ التعديلات'.tr,
                  icon: Icons.check_rounded,
                  expand: true,
                  loading: _saving,
                  onPressed: _saving ? null : () => _save(account),
                ),
              ],
            );
          }),
        ),
      );

  Widget _preview(BuildContext context, UserProfile account) {
    final p = context.palette;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'معاينة'.tr,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: p.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: p.surfaceVariant,
                backgroundImage: _provider(account),
                child: account.photoData.isEmpty && account.photoUrl.isEmpty
                    ? Icon(Icons.person_rounded, size: 30, color: p.icon)
                    : null,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _name,
                  builder: (context, value, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value.text.trim().isEmpty
                            ? account.username
                            : value.text.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        '@${account.username}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              AppButton(
                label: 'تغيير الصورة'.tr,
                icon: Icons.camera_alt_rounded,
                variant: AppButtonVariant.outline,
                compact: true,
                onPressed: _saving ? null : _controller.changeAvatar,
              ),
            ],
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
        // Fall through to the network avatar.
      }
    }
    return account.photoUrl.isEmpty
        ? null
        : CachedNetworkImageProvider(account.photoUrl);
  }

  Future<void> _copy(String uid) async {
    await Clipboard.setData(ClipboardData(text: uid));
    AppFeedback.show(
      title: 'تم النسخ'.tr,
      message: 'تم نسخ معرّف الحساب'.tr,
      type: AppNoticeType.success,
    );
  }

  Future<void> _save(UserProfile account) async {
    final name = _name.text.trim();
    final bio = _bio.text.trim();
    String? nameError;
    String? bioError;
    if (name.length < 2) nameError = 'أدخل اسمًا ظاهرًا من حرفين على الأقل.'.tr;
    if (name.length > 40) nameError = 'الحد الأقصى 40 حرفًا.'.tr;
    if (bio.length > 300) bioError = 'الحد الأقصى 300 حرف.'.tr;
    if (nameError != null || bioError != null) {
      setState(() {
        _nameError = nameError;
        _bioError = bioError;
      });
      return;
    }
    if (name == account.displayName.trim() && bio == account.bio.trim()) {
      AppFeedback.show(
        title: 'لا توجد تغييرات'.tr,
        message: 'لم تعدّل أي حقل بعد.'.tr,
      );
      return;
    }
    setState(() => _saving = true);
    final ok = await _controller.saveProfile(displayName: name, bio: bio);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Get.back<void>();
  }
}
