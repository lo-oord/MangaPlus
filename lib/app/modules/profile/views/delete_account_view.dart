import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/theme/app_palette.dart';
import 'package:mangaplus/app/core/theme/design_tokens.dart';
import 'package:mangaplus/app/modules/profile/controllers/account_security_controller.dart';
import 'package:mangaplus/app/routes/app_pages.dart';
import 'package:mangaplus/app/widgets/app_buttons.dart';
import 'package:mangaplus/app/widgets/app_dialogs.dart';
import 'package:mangaplus/app/widgets/app_feedback.dart';
import 'package:mangaplus/app/widgets/app_surfaces.dart';
import 'package:mangaplus/app/widgets/mangaplus_app_bar.dart';
import 'package:mangaplus/app/widgets/theme_aware_builder.dart';

/// Permanently deletes the signed-in account.
///
/// The screen explains exactly what is removed, requires the identity to be
/// confirmed again (Firebase refuses a delete on an old session), and asks the
/// user to type the confirmation phrase. Progress comes from the service itself,
/// so the button never reports success before every step finished.
class DeleteAccountView extends StatefulWidget {
  const DeleteAccountView({super.key});

  @override
  State<DeleteAccountView> createState() => _DeleteAccountViewState();
}

class _DeleteAccountViewState extends State<DeleteAccountView> {
  late final AccountSecurityController _controller;
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmation = TextEditingController();
  bool _showPassword = false;

  static const String _confirmationPhrase = 'حذف حسابي';

  @override
  void initState() {
    super.initState();
    _controller = Get.find<AccountSecurityController>();
    _confirmation.addListener(() => setState(() {}));
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  bool get _confirmationMatches =>
      _confirmation.text.trim() == _confirmationPhrase.tr;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return ThemeAwareBuilder(
      builder: (context) => Scaffold(
        backgroundColor: p.background,
        appBar: MangaPlusAppBar(title: 'حذف الحساب نهائيًا'.tr),
        body: Obx(() {
          final deleting = _controller.deleting.value;
          final useGoogle = !_controller.canChangePassword;
          return ListView(
            padding: AppSpacing.pageInsets,
            children: [
              AppCard(
                color: p.error.withValues(alpha: .08),
                borderColor: p.error.withValues(alpha: .35),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: p.error),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            'إجراء نهائي ولا يمكن التراجع عنه'.tr,
                            style: text.titleSmall?.copyWith(
                              color: p.error,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'سيتم حذف حسابك وكل بياناته من خوادمنا نهائيًا. لا يمكن استعادة الحساب أو المحتوى بعد الحذف.'.tr,
                      style: text.bodySmall?.copyWith(height: 1.6),
                    ),
                  ],
                ),
              ),
              if (_controller.hasPendingDeletion.value && !deleting)
                AppCard(
                  color: p.warning.withValues(alpha: .10),
                  borderColor: p.warning.withValues(alpha: .35),
                  child: Row(
                    children: [
                      Icon(Icons.sync_problem_rounded, color: p.warning),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          'بدأ حذف سابق ولم يكتمل. يمكنك إكماله الآن بأمان.'.tr,
                          style: text.bodySmall?.copyWith(height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              AppSection(
                title: 'ما الذي سيُحذف؟'.tr,
                children: [
                  for (final item in const [
                    'الملف الشخصي (الاسم، النبذة، الصورة)',
                    'المكتبة والمفضلة',
                    'سجل القراءة وتقدّم الفصول',
                    'القوائم المخصصة والإشعارات',
                    'إحصاءات القراءة',
                    'اسم المستخدم المحجوز',
                    'حساب الدخول (البريد وكلمة المرور)',
                    'التحميلات وذاكرة التخزين المؤقت على هذا الجهاز',
                  ])
                    AppSettingsTile(
                      icon: Icons.delete_outline_rounded,
                      title: item.tr,
                      enabled: false,
                    ),
                ],
              ),
              AppSection(
                title: 'تأكيد الهوية'.tr,
                subtitle: useGoogle
                    ? 'أكّد حسابك عبر Google للمتابعة'.tr
                    : 'أدخل كلمة المرور الحالية للمتابعة'.tr,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: useGoogle
                        ? Row(
                            children: [
                              Icon(Icons.g_mobiledata_rounded, color: p.primary),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Text(
                                  'تم إنشاء هذا الحساب عبر Google، وسيُطلب منك تأكيد الدخول.'.tr,
                                  style: text.bodySmall?.copyWith(height: 1.5),
                                ),
                              ),
                            ],
                          )
                        : TextField(
                            controller: _password,
                            obscureText: !_showPassword,
                            enabled: !deleting,
                            decoration: InputDecoration(
                              labelText: 'كلمة المرور الحالية'.tr,
                              suffixIcon: IconButton(
                                icon: Icon(_showPassword
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded),
                                onPressed: () => setState(
                                    () => _showPassword = !_showPassword),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
              AppSection(
                title: 'التأكيد النهائي'.tr,
                subtitle: 'اكتب «$_confirmationPhrase» بالضبط لتأكيد الحذف'.tr,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: TextField(
                      controller: _confirmation,
                      enabled: !deleting,
                      decoration: InputDecoration(
                        labelText: 'نص التأكيد'.tr,
                        hintText: _confirmationPhrase.tr,
                      ),
                    ),
                  ),
                ],
              ),
              if (deleting)
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              _controller.deletionStage.value.isEmpty
                                  ? 'جارٍ حذف الحساب…'.tr
                                  : _controller.deletionStage.value,
                              style: text.bodySmall?.copyWith(height: 1.5),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'لا تغلق التطبيق حتى تنتهي العملية.'.tr,
                        style: text.bodySmall?.copyWith(color: p.textSecondary),
                      ),
                    ],
                  ),
                ),
              if (_controller.lastError.value.isNotEmpty && !deleting)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    _controller.lastError.value,
                    style: text.bodySmall?.copyWith(color: p.error),
                  ),
                ),
              AppButton(
                label: 'حذف حسابي نهائيًا'.tr,
                icon: Icons.delete_forever_rounded,
                variant: AppButtonVariant.danger,
                expand: true,
                loading: deleting,
                onPressed: (deleting ||
                        !_confirmationMatches ||
                        (!useGoogle && _password.text.isEmpty))
                    ? null
                    : _confirmAndDelete,
              ),
            ],
          );
        }),
      ),
    );
  }

  Future<void> _confirmAndDelete() async {
    final useGoogle = !_controller.canChangePassword;
    final confirmed = await AppDialogs.confirm(
      title: 'تأكيد حذف الحساب'.tr,
      message: 'سيُحذف حسابك وكل بياناته نهائيًا ولا يمكن استعادته. هل أنت متأكد؟'.tr,
      confirmLabel: 'حذف نهائي'.tr,
      destructive: true,
    );
    if (!confirmed) return;
    final ok = await _controller.deleteAccount(
      password: _password.text,
      useGoogle: useGoogle,
    );
    if (!mounted) return;
    if (ok) {
      AppFeedback.show(
        title: 'تم حذف الحساب'.tr,
        message: 'حُذفت بياناتك وحسابك نهائيًا.'.tr,
        type: AppNoticeType.success,
      );
      Get.offAllNamed<void>(Routes.MAIN);
    }
  }
}
