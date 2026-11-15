import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/navigation/app_navigation.dart';
import 'package:mangaplus/app/core/theme/app_palette.dart';
import 'package:mangaplus/app/core/theme/design_tokens.dart';
import 'package:mangaplus/app/modules/profile/controllers/account_security_controller.dart';
import 'package:mangaplus/app/modules/profile/controllers/profile_controller.dart';
import 'package:mangaplus/app/routes/app_pages.dart';
import 'package:mangaplus/app/widgets/app_buttons.dart';
import 'package:mangaplus/app/widgets/app_feedback.dart';
import 'package:mangaplus/app/widgets/app_surfaces.dart';
import 'package:mangaplus/app/widgets/mangaplus_app_bar.dart';
import 'package:mangaplus/app/widgets/theme_aware_builder.dart';

/// Account management: identity, e-mail state, security and the destructive
/// actions. It reads the live Firebase user, so the e-mail and its verification
/// state are always the truth, never a cached copy.
class AccountSettingsView extends StatelessWidget {
  const AccountSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = Get.find<ProfileController>();
    final security = Get.find<AccountSecurityController>();
    return ThemeAwareBuilder(
      builder: (context) => Scaffold(
        backgroundColor: context.palette.background,
        appBar: MangaPlusAppBar(title: 'إدارة الحساب'.tr),
        body: Obx(() {
          final account = profile.accountProfile.value;
          if (account == null || account.isGuest) {
            return ListView(
              padding: AppSpacing.pageInsets,
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person_outline_rounded,
                              color: context.palette.icon),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              'أنت تستخدم وضع الضيف'.tr,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'إدارة الحساب والبريد وكلمة المرور متاحة للحسابات الدائمة. بياناتك الحالية محفوظة على هذا الجهاز.'.tr,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(height: 1.6),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        label: 'تسجيل الدخول أو إنشاء حساب'.tr,
                        icon: Icons.login_rounded,
                        expand: true,
                        onPressed: () => AppNavigation.toNamed(Routes.AUTH),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          security.statusRevision.value;
          final email = security.currentEmail ?? account.email;
          final verified = security.emailVerified;
          final cooldown = security.resendCooldown.value;

          return ListView(
            padding: AppSpacing.pageInsets,
            children: [
              AppSection(
                title: 'الحساب'.tr,
                children: [
                  AppSettingsTile(
                    icon: Icons.alternate_email_rounded,
                    title: 'اسم المستخدم'.tr,
                    value: '@${account.username}',
                    enabled: false,
                  ),
                  AppSettingsTile(
                    icon: Icons.tag_rounded,
                    title: 'معرّف الحساب'.tr,
                    value: account.uid,
                    onTap: () => _copy(context, account.uid),
                  ),
                  AppSettingsTile(
                    icon: Icons.event_available_rounded,
                    title: 'تاريخ الانضمام'.tr,
                    value: _formatDate(account.createdAt),
                    enabled: false,
                  ),
                ],
              ),
              AppSection(
                title: 'البريد الإلكتروني'.tr,
                children: [
                  AppSettingsTile(
                    icon: Icons.mail_outline_rounded,
                    title: 'البريد الحالي'.tr,
                    value: email.isEmpty ? 'غير متاح'.tr : email,
                    enabled: false,
                  ),
                  AppSettingsTile(
                    icon: verified
                        ? Icons.verified_user_rounded
                        : Icons.gpp_maybe_rounded,
                    title: 'حالة التحقق'.tr,
                    value: verified ? 'موثق'.tr : 'غير موثق'.tr,
                    enabled: false,
                  ),
                  if (!verified)
                    AppSettingsTile(
                      icon: Icons.mark_email_read_outlined,
                      title: 'إعادة إرسال رابط التحقق'.tr,
                      subtitle: cooldown > 0
                          ? '${'يمكنك الإرسال مجددًا بعد'.tr} $cooldown ${'ثانية'.tr}'
                          : 'أرسل رابطًا جديدًا إلى بريدك'.tr,
                      onTap: (security.busy.value || cooldown > 0)
                          ? null
                          : () => _resend(security),
                    ),
                  if (!verified)
                    AppSettingsTile(
                      icon: Icons.refresh_rounded,
                      title: 'تحديث حالة التحقق'.tr,
                      subtitle: 'اضغط بعد تأكيد بريدك من الرسالة'.tr,
                      onTap: security.busy.value
                          ? null
                          : () => _refreshVerification(security, profile),
                    ),
                  AppSettingsTile(
                    icon: Icons.edit_outlined,
                    title: 'تغيير البريد الإلكتروني'.tr,
                    subtitle: 'سنرسل رابط تأكيد إلى العنوان الجديد'.tr,
                    onTap: security.busy.value
                        ? null
                        : () => _openEmailChange(context, security),
                  ),
                ],
              ),
              AppSection(
                title: 'الأمان'.tr,
                children: [
                  AppSettingsTile(
                    icon: Icons.lock_reset_rounded,
                    title: 'تغيير كلمة المرور'.tr,
                    subtitle: security.canChangePassword
                        ? null
                        : 'هذا الحساب لا يملك كلمة مرور محلية'.tr,
                    enabled: security.canChangePassword,
                    onTap: security.canChangePassword
                        ? () => AppNavigation.toNamed(Routes.CHANGE_PASSWORD)
                        : null,
                  ),
                ],
              ),
              AppSection(
                title: 'منطقة الخطر'.tr,
                subtitle: 'إجراءات نهائية لا يمكن التراجع عنها'.tr,
                children: [
                  AppSettingsTile(
                    icon: Icons.delete_forever_rounded,
                    title: 'حذف الحساب نهائيًا'.tr,
                    subtitle: 'حذف الحساب وكل البيانات المرتبطة به'.tr,
                    destructive: true,
                    onTap: () => AppNavigation.toNamed(Routes.DELETE_ACCOUNT),
                  ),
                ],
              ),
              AppButton(
                label: 'تسجيل الخروج'.tr,
                icon: Icons.logout_rounded,
                variant: AppButtonVariant.outline,
                expand: true,
                onPressed: () => _signOut(context, profile),
              ),
            ],
          );
        }),
      ),
    );
  }

  Future<void> _copy(BuildContext context, String uid) async {
    await Clipboard.setData(ClipboardData(text: uid));
    AppFeedback.show(
      title: 'تم النسخ'.tr,
      message: 'تم نسخ معرّف الحساب'.tr,
      type: AppNoticeType.success,
    );
  }

  Future<void> _resend(AccountSecurityController security) async {
    final ok = await security.resendVerification();
    AppFeedback.show(
      title: ok ? 'تم إرسال الرابط'.tr : 'تعذر الإرسال'.tr,
      message: ok
          ? 'افتح بريدك وأكّد العنوان لإكمال التوثيق.'.tr
          : security.lastError.value,
      type: ok ? AppNoticeType.success : AppNoticeType.error,
    );
  }

  Future<void> _refreshVerification(
    AccountSecurityController security,
    ProfileController profile,
  ) async {
    await security.refreshStatus();
    await profile.refreshAccount();
    final verified = security.emailVerified;
    AppFeedback.show(
      title: verified ? 'تم توثيق البريد'.tr : 'لم يُوثَّق البريد بعد'.tr,
      message: verified
          ? 'تم تحديث حالة التحقق بنجاح.'.tr
          : 'إذا أكدت البريد من الرسالة، جرّب التحديث مرة أخرى بعد لحظات.'.tr,
      type: verified ? AppNoticeType.success : AppNoticeType.info,
    );
  }

  Future<void> _openEmailChange(
    BuildContext context,
    AccountSecurityController security,
  ) async {
    await Get.bottomSheet<void>(
      const _ChangeEmailSheet(),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
    if (context.mounted) {
      AppFeedback.show(
        title: security.lastError.value.isEmpty
            ? 'تم إرسال رابط التأكيد'.tr
            : 'تعذر تغيير البريد'.tr,
        message: security.lastError.value.isEmpty
            ? 'افتح الرسالة المرسلة إلى العنوان الجديد لتأكيد التغيير.'.tr
            : security.lastError.value,
        type: security.lastError.value.isEmpty
            ? AppNoticeType.success
            : AppNoticeType.error,
      );
    }
  }

  Future<void> _signOut(BuildContext context, ProfileController profile) async {
    final confirmed = await Get.dialog<bool>(
          const _SignOutDialog(),
        ) ??
        false;
    if (!confirmed) return;
    await profile.signOut();
    if (context.mounted) Get.back<void>();
  }

  static String _formatDate(DateTime date) {
    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}/$month/$day';
  }
}

/// The e-mail change sheet. The address only changes after the user opens the
/// confirmation link, so the sheet is explicit about that and never claims the
/// change happened immediately.
class _ChangeEmailSheet extends StatefulWidget {
  const _ChangeEmailSheet();

  @override
  State<_ChangeEmailSheet> createState() => _ChangeEmailSheetState();
}

class _ChangeEmailSheetState extends State<_ChangeEmailSheet> {
  late final AccountSecurityController _security;
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _showPassword = false;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _security = Get.find<AccountSecurityController>();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: AppRadii.sheetTop,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: p.border,
                      borderRadius: AppRadii.pillAll,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'تغيير البريد الإلكتروني'.tr,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'أدخل العنوان الجديد وكلمة المرور. سيصلك رابط تأكيد، ولن يتغير البريد قبل فتحه.'.tr,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: p.textSecondary, height: 1.6),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _email,
                  enabled: !_sending,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(
                    labelText: 'البريد الإلكتروني الجديد'.tr,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _password,
                  enabled: !_sending,
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور الحالية'.tr,
                    suffixIcon: IconButton(
                      icon: Icon(_showPassword
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded),
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _error!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: p.error),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'إرسال رابط التأكيد'.tr,
                  icon: Icons.send_rounded,
                  expand: true,
                  loading: _sending,
                  onPressed: _sending ? null : _submit,
                ),
                const SizedBox(height: AppSpacing.xs),
                AppButton(
                  label: 'إلغاء'.tr,
                  variant: AppButtonVariant.ghost,
                  expand: true,
                  onPressed: _sending ? null : () => Get.back<void>(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (!GetUtils.isEmail(email)) {
      setState(() => _error = 'أدخل بريدًا إلكترونيًا صالحًا.'.tr);
      return;
    }
    if (password.isEmpty) {
      setState(() => _error = 'أدخل كلمة المرور الحالية.'.tr);
      return;
    }
    setState(() {
      _error = null;
      _sending = true;
    });
    final ok = await _security.requestEmailChange(
      newEmail: email,
      password: password,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) {
      Get.back<void>();
      return;
    }
    setState(() => _error = _security.lastError.value);
  }
}

/// Confirms signing out, since it clears the local library cache.
class _SignOutDialog extends StatelessWidget {
  const _SignOutDialog();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Dialog(
      backgroundColor: p.card,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.lgAll),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'تسجيل الخروج'.tr,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'سيتم مسح بيانات المكتبة والسجل المحفوظة على هذا الجهاز. هل تريد المتابعة؟'.tr,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(height: 1.6),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppButton(
                  label: 'إلغاء'.tr,
                  variant: AppButtonVariant.ghost,
                  compact: true,
                  onPressed: () => Get.back<bool>(result: false),
                ),
                const SizedBox(width: AppSpacing.xs),
                AppButton(
                  label: 'تسجيل الخروج'.tr,
                  variant: AppButtonVariant.danger,
                  compact: true,
                  onPressed: () => Get.back<bool>(result: true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
