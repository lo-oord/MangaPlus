import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/theme/app_palette.dart';
import 'package:mangaplus/app/core/theme/design_tokens.dart';
import 'package:mangaplus/app/modules/profile/controllers/account_security_controller.dart';
import 'package:mangaplus/app/widgets/app_buttons.dart';
import 'package:mangaplus/app/widgets/app_feedback.dart';
import 'package:mangaplus/app/widgets/app_surfaces.dart';
import 'package:mangaplus/app/widgets/mangaplus_app_bar.dart';
import 'package:mangaplus/app/widgets/theme_aware_builder.dart';

/// Changes the password of a local (e-mail/password) account.
///
/// The current password is required by Firebase before a change, and is used
/// here to reauthenticate, so a hijacked session cannot silently rotate it.
class ChangePasswordView extends StatefulWidget {
  const ChangePasswordView({super.key});

  @override
  State<ChangePasswordView> createState() => _ChangePasswordViewState();
}

class _ChangePasswordViewState extends State<ChangePasswordView> {
  late final AccountSecurityController _controller;
  final TextEditingController _current = TextEditingController();
  final TextEditingController _next = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  bool _showCurrent = false;
  bool _showNext = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<AccountSecurityController>();
    _next.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ThemeAwareBuilder(
      builder: (context) => Scaffold(
        backgroundColor: p.background,
        appBar: MangaPlusAppBar(title: 'تغيير كلمة المرور'.tr),
        body: ListView(
          padding: AppSpacing.pageInsets,
          children: [
            if (!_controller.canChangePassword)
              AppCard(
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: p.info),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'تم إنشاء هذا الحساب عبر مزود خارجي ولا يملك كلمة مرور محلية.'.tr,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              AppSection(
                title: 'كلمة المرور'.tr,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _current,
                          obscureText: !_showCurrent,
                          enabled: !_saving,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'كلمة المرور الحالية'.tr,
                            suffixIcon: IconButton(
                              icon: Icon(_showCurrent
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded),
                              onPressed: () =>
                                  setState(() => _showCurrent = !_showCurrent),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextField(
                          controller: _next,
                          obscureText: !_showNext,
                          enabled: !_saving,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'كلمة المرور الجديدة'.tr,
                            suffixIcon: IconButton(
                              icon: Icon(_showNext
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded),
                              onPressed: () =>
                                  setState(() => _showNext = !_showNext),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        _strength(context),
                        const SizedBox(height: AppSpacing.sm),
                        TextField(
                          controller: _confirm,
                          obscureText: !_showNext,
                          enabled: !_saving,
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            labelText: 'تأكيد كلمة المرور الجديدة'.tr,
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
                      ],
                    ),
                  ),
                ],
              ),
              AppButton(
                label: 'تحديث كلمة المرور'.tr,
                icon: Icons.lock_reset_rounded,
                expand: true,
                loading: _saving,
                onPressed: _saving ? null : _submit,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _strength(BuildContext context) {
    final value = _next.text;
    if (value.isEmpty) return const SizedBox.shrink();
    var score = 0;
    if (value.length >= 8) score++;
    if (value.length >= 12) score++;
    if (RegExp(r'[A-Za-z]').hasMatch(value) && RegExp(r'\d').hasMatch(value)) {
      score++;
    }
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(value)) score++;
    final p = context.palette;
    final (label, color) = switch (score) {
      0 || 1 => ('ضعيفة'.tr, p.error),
      2 => ('متوسطة'.tr, p.warning),
      _ => ('قوية'.tr, p.success),
    };
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: AppRadii.pillAll,
            child: LinearProgressIndicator(
              value: (score / 4).clamp(0.15, 1.0),
              minHeight: 5,
              backgroundColor: p.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: color, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final current = _current.text;
    final next = _next.text;
    final confirm = _confirm.text;
    String? error;
    if (current.isEmpty) {
      error = 'أدخل كلمة المرور الحالية.'.tr;
    } else if (next.length < 8) {
      error = 'استخدم 8 أحرف على الأقل لكلمة المرور الجديدة.'.tr;
    } else if (next != confirm) {
      error = 'كلمتا المرور غير متطابقتين.'.tr;
    } else if (next == current) {
      error = 'اختر كلمة مرور مختلفة عن الحالية.'.tr;
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    final ok = await _controller.changePassword(
      currentPassword: current,
      newPassword: next,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      AppFeedback.show(
        title: 'تم تغيير كلمة المرور'.tr,
        message: 'تم تحديث كلمة مرور حسابك بنجاح'.tr,
        type: AppNoticeType.success,
      );
      Get.back<void>();
    } else {
      setState(() => _error = _controller.lastError.value);
    }
  }
}
