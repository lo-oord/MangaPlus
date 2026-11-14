import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/modules/auth/controllers/auth_controller.dart';
import 'package:mangaplus/app/widgets/brand_state.dart';
import 'package:mangaplus/app/widgets/mangaplus_app_bar.dart';
import 'package:mangaplus/app/widgets/theme_aware_builder.dart';

class AuthView extends GetView<AuthController> {
  const AuthView({super.key});

  @override
  Widget build(BuildContext context) {
    return ThemeAwareBuilder(builder: (context) => Scaffold(
      backgroundColor: AppColors.background,
      appBar: const MangaPlusAppBar(title: 'حساب MangaPlus'),
      body: SafeArea(
        child: Obx(() => controller.emailVerificationRequired.value ? _verificationView() : _formView()),
      ),
    ));
  }

  Widget _formView() => ListView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 36),
        children: [
          const Center(child: MangaPlusLogo(size: 82)),
          const SizedBox(height: 18),
          Obx(() => Text(
                controller.isCompletingGoogle.value ? 'أكمل ملفك الشخصي' : (controller.isRegister.value ? 'أنشئ حسابك' : 'مرحبًا بعودتك'),
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 25, fontWeight: FontWeight.w800),
              )),
          const SizedBox(height: 7),
          Obx(() => Text(
                controller.isCompletingGoogle.value ? 'بقيت معلومات بسيطة لبدء مزامنة قراءتك.' : (controller.isRegister.value ? 'زامن قراءتك ومفضلتك بين أجهزتك.' : 'سجّل الدخول لمتابعة قراءتك.'),
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              )),
          const SizedBox(height: 25),
          Obx(() => controller.isCompletingGoogle.value
              ? _googleCompletionFields()
              : Column(children: [
                  if (controller.isRegister.value) _registrationWizard() else _loginFields(),
                ])),
          const SizedBox(height: 12),
          Obx(() => controller.isRegister.value && !controller.isCompletingGoogle.value
              ? const SizedBox.shrink()
              : FilledButton(
                onPressed: controller.isBusy.value ? null : controller.submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: controller.isBusy.value
                    ? const MangaPlusLoader(
                        size: 21,
                        color: Colors.white,
                        trackColor: Colors.white24,
                      )
                    : Text(controller.isCompletingGoogle.value ? 'إكمال الملف' : (controller.isRegister.value ? 'إنشاء الحساب' : 'تسجيل الدخول'), style: const TextStyle(fontWeight: FontWeight.w700)),
              )),
          Obx(() => controller.isCompletingGoogle.value ? const SizedBox.shrink() : const SizedBox(height: 14)),
          Obx(() => controller.isCompletingGoogle.value ? const SizedBox.shrink() : _orDivider()),
          Obx(() => controller.isCompletingGoogle.value ? const SizedBox.shrink() : const SizedBox(height: 14)),
          Obx(() => controller.isCompletingGoogle.value ? const SizedBox.shrink() : ElevatedButton.icon(
                onPressed: controller.isBusy.value ? null : controller.signInGoogle,
                icon: const _GoogleMark(),
                label: const Text('المتابعة باستخدام Google', style: TextStyle(color: Color(0xff202124), fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xff202124),
                  disabledBackgroundColor: Colors.white70,
                  elevation: 1,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey.shade300)),
                ),
              )),
          Obx(() => controller.isCompletingGoogle.value ? const SizedBox.shrink() : const SizedBox(height: 9)),
          Obx(() => controller.isCompletingGoogle.value ? const SizedBox.shrink() : TextButton(onPressed: controller.isBusy.value ? null : controller.continueAsGuest, child: const Text('المتابعة كضيف'))),
          Obx(() => controller.isCompletingGoogle.value ? const SizedBox.shrink() : const SizedBox(height: 5)),
          Obx(() => controller.isCompletingGoogle.value ? const SizedBox.shrink() : TextButton(
                onPressed: controller.isBusy.value ? null : () => controller.setRegisterMode(!controller.isRegister.value),
                child: Text(controller.isRegister.value ? 'لديك حساب؟ سجّل الدخول' : 'ليس لديك حساب؟ أنشئ حسابًا'),
              )),
        ],
      );

  Widget _loginFields() => Column(
        children: [
          _field(controller.email, 'البريد الإلكتروني', Icons.email_outlined, keyboard: TextInputType.emailAddress),
          const SizedBox(height: 13),
          _passwordField(controller.password, 'كلمة المرور', controller.obscurePassword),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: _showResetPasswordDialog, child: const Text('نسيت كلمة المرور؟')),
          ),
        ],
      );

  Widget _registrationWizard() => Obx(() {
        final step = controller.registrationStep.value;
        final labels = ['بياناتك', 'الأمان', 'المعلومات'];
        return Column(
          children: [
            Row(
              children: List.generate(labels.length, (index) => Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  margin: EdgeInsetsDirectional.only(end: index == labels.length - 1 ? 0 : 6),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(color: index <= step ? AppColors.primary : AppColors.divider, borderRadius: BorderRadius.circular(9)),
                  child: Text(labels[index], textAlign: TextAlign.center, style: TextStyle(color: index <= step ? Colors.white : AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              )),
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: SlideTransition(position: Tween<Offset>(begin: const Offset(.08, 0), end: Offset.zero).animate(animation), child: child)),
              child: KeyedSubtree(key: ValueKey(step), child: _registrationStepFields(step)),
            ),
            const SizedBox(height: 16),
            Row(children: [
              if (step > 0) Expanded(child: OutlinedButton(onPressed: controller.previousRegistrationStep, child: const Text('السابق'))),
              if (step > 0) const SizedBox(width: 10),
              Expanded(child: FilledButton(onPressed: controller.isBusy.value ? null : (step == 2 ? controller.submit : controller.nextRegistrationStep), child: Text(step == 2 ? 'إنشاء الحساب' : 'التالي'))),
            ]),
          ],
        );
      });

  Widget _registrationStepFields(int step) => switch (step) {
        0 => Column(children: [_field(controller.displayName, 'الاسم الظاهر', Icons.badge_outlined), const SizedBox(height: 13), _usernameField()]),
        1 => Column(children: [_field(controller.email, 'البريد الإلكتروني', Icons.email_outlined, keyboard: TextInputType.emailAddress), const SizedBox(height: 13), _passwordField(controller.password, 'كلمة المرور', controller.obscurePassword), const SizedBox(height: 13), _passwordField(controller.confirmPassword, 'تأكيد كلمة المرور', controller.obscureConfirmPassword)]),
        _ => Column(children: [_countryField(), const SizedBox(height: 13), _genderField(), const SizedBox(height: 13), _birthDateField()]),
      };

  Widget _verificationView() => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mark_email_read_outlined, size: 70, color: AppColors.primary),
            const SizedBox(height: 20),
            Text('تحقق من بريدك الإلكتروني', style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text('افتح رسالة التحقق ثم اضغط «تحققت من بريدي». لا يكفي الضغط على الزر دون إتمام التحقق.', style: TextStyle(color: AppColors.textSecondary, height: 1.5), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton(onPressed: controller.isBusy.value ? null : controller.verifyEmail, child: const Text('تحققت من بريدي')),
            TextButton(onPressed: controller.verificationCooldown.value > 0 ? null : controller.resendVerification, child: Text(controller.verificationCooldown.value > 0 ? 'إعادة الإرسال بعد ${controller.verificationCooldown.value} ثانية' : 'إعادة إرسال رسالة التحقق')),
          ],
        ),
      );

  Widget _googleCompletionFields() => Column(
        children: [
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(15)),
            child: Row(children: [
              const _GoogleMark(),
              const SizedBox(width: 10),
              Expanded(child: Text('تم تسجيل الدخول بواسطة Google. أكمل البيانات التالية فقط.', style: TextStyle(color: AppColors.textSecondary, height: 1.35))),
            ]),
          ),
          const SizedBox(height: 16),
          _usernameField(),
          const SizedBox(height: 13),
          _countryField(),
          const SizedBox(height: 13),
          _genderField(),
          const SizedBox(height: 13),
          _birthDateField(),
          const SizedBox(height: 13),
        ],
      );

  Widget _field(TextEditingController textController, String label, IconData icon, {TextInputType? keyboard, ValueChanged<String>? onChanged}) => TextField(
        controller: textController,
        keyboardType: keyboard,
        onChanged: onChanged,
        textDirection: TextDirection.ltr,
        decoration: _decoration(label, icon),
      );

  Widget _usernameField() => Obx(() {
        final status = controller.usernameAvailability.value;
        final text = switch (status) {
          UsernameAvailability.checking => 'جارٍ فحص الاسم...',
          UsernameAvailability.available => 'متوفر',
          UsernameAvailability.taken => 'مأخوذ',
          UsernameAvailability.invalid => 'استخدم 3–24 حرفًا إنجليزيًا أو رقمًا أو _',
          UsernameAvailability.error => 'تعذر الفحص الآن، سيُعاد التحقق عند التسجيل',
          UsernameAvailability.idle => 'اكتب اسم المستخدم لفحص التوفر',
        };
        final color = status == UsernameAvailability.available ? Colors.green : status == UsernameAvailability.taken || status == UsernameAvailability.invalid ? Colors.red : AppColors.textSecondary;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _field(controller.username, 'اسم المستخدم (إنجليزي وأرقام و_)', Icons.alternate_email_rounded, onChanged: controller.usernameChanged),
          if (text.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 5, left: 12, right: 12), child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600))),
          if (controller.usernameSuggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('اقتراحات قريبة متاحة'.tr,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Wrap(
                spacing: 7,
                runSpacing: 7,
                children: controller.usernameSuggestions.map((suggestion) => ActionChip(
                  label: Text(suggestion),
                  labelStyle: const TextStyle(color: Color(0xff7E57C2), fontWeight: FontWeight.w700, fontSize: 12),
                  backgroundColor: const Color(0xff7E57C2).withValues(alpha: 0.12),
                  side: const BorderSide(color: Color(0xff7E57C2)),
                  onPressed: () => controller.selectUsername(suggestion),
                )).toList(),
              ),
            ),
          ],
        ]);
      });

  Widget _passwordField(TextEditingController textController, String label, RxBool obscure) => Obx(() => TextField(
        controller: textController,
        obscureText: obscure.value,
        textDirection: TextDirection.ltr,
        decoration: _decoration(label, Icons.lock_outline_rounded).copyWith(
          suffixIcon: IconButton(onPressed: obscure.toggle, icon: Icon(obscure.value ? Icons.visibility_outlined : Icons.visibility_off_outlined)),
        ),
      ));

  Widget _countryField() => DropdownButtonFormField<ArabCountry>(
        value: controller.selectedCountry.value,
        decoration: _decoration('الدولة', Icons.public_rounded),
        items: AuthController.countries.map((country) => DropdownMenuItem(value: country, child: Text(country.name))).toList(),
        onChanged: (value) => controller.selectedCountry.value = value,
      );

  Widget _genderField() => Obx(() => DropdownButtonFormField<String>(
        value: controller.selectedGender.value,
        decoration: _decoration('الجنس', Icons.wc_rounded),
        items: const [
          DropdownMenuItem(value: 'male', child: Text('♂️ ذكر')),
          DropdownMenuItem(value: 'female', child: Text('♀️ أنثى')),
        ],
        onChanged: (value) => controller.selectedGender.value = value,
      ));

  Widget _birthDateField() => InkWell(
        onTap: () async {
          final date = await showDatePicker(context: Get.context!, firstDate: DateTime(1900), lastDate: DateTime.now(), initialDate: DateTime(2000));
          if (date != null) controller.birthDate.value = date;
        },
        borderRadius: BorderRadius.circular(15),
        child: InputDecorator(
          decoration: _decoration('تاريخ الميلاد', Icons.cake_outlined),
          child: Text(controller.birthDate.value == null ? 'اختر تاريخ الميلاد' : '${controller.birthDate.value!.year}/${controller.birthDate.value!.month}/${controller.birthDate.value!.day}'),
        ),
      );

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: AppColors.card.withValues(alpha: 0.72),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: AppColors.divider)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: AppColors.divider)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
      );

  Widget _orDivider() => Row(children: [Expanded(child: Divider(color: AppColors.divider)), Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('أو', style: TextStyle(color: AppColors.textSecondary))), Expanded(child: Divider(color: AppColors.divider))]);

  Future<void> _showResetPasswordDialog() async {
    final emailController = TextEditingController(text: controller.email.text);
    var busy = false;
    await Get.dialog<void>(StatefulBuilder(builder: (context, setState) {
      return AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('استعادة كلمة المرور'),
        content: TextField(controller: emailController, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr, decoration: _decoration('البريد الإلكتروني', Icons.email_outlined)),
        actions: [
          TextButton(onPressed: busy ? null : () => Get.back(), child: const Text('إلغاء')),
          FilledButton(
            onPressed: busy ? null : () async {
              setState(() => busy = true);
              try {
                final error = await controller.resetPasswordForEmail(emailController.text);
                if (error != null) {
                  Get.snackbar('تعذر الإرسال', error, snackPosition: SnackPosition.BOTTOM);
                } else {
                  if (context.mounted) Navigator.of(context).pop();
                  Get.snackbar('تم إرسال الرسالة', 'تحقق من بريدك الإلكتروني لإعادة تعيين كلمة المرور.', snackPosition: SnackPosition.BOTTOM);
                }
              } finally {
                if (context.mounted) setState(() => busy = false);
              }
            },
            child: busy ? const MangaPlusLoader(size: 18) : const Text('إرسال'),
          ),
        ],
      );
    }));
    emailController.dispose();
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();
  @override
  Widget build(BuildContext context) => const SizedBox(width: 22, height: 22, child: CustomPaint(painter: _GoogleMarkPainter()));
}

class _GoogleMarkPainter extends CustomPainter {
  const _GoogleMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * .36;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const stroke = 3.7;
    const segments = <(Color, double, double)>[
      (Color(0xff4285F4), -0.20, 1.45),
      (Color(0xff34A853), 1.25, 1.00),
      (Color(0xffFBBC05), 2.25, 0.82),
      (Color(0xffEA4335), 3.07, 1.33),
    ];
    for (final segment in segments) {
      final paint = Paint()
        ..color = segment.$1
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, segment.$2, segment.$3, false, paint);
    }
    final barPaint = Paint()
      ..color = const Color(0xff4285F4)
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(center.dx, center.dy), Offset(size.width - 2, center.dy), barPaint);
  }

  @override
  bool shouldRepaint(covariant _GoogleMarkPainter oldDelegate) => false;
}
