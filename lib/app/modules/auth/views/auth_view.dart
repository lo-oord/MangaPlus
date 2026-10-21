import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/modules/auth/controllers/auth_controller.dart';
import 'package:mangaplus/app/widgets/brand_state.dart';

class AuthView extends GetView<AuthController> {
  const AuthView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('حساب MangaPlus'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
      ),
      body: SafeArea(
        child: Obx(() {
          if (controller.emailVerificationRequired.value) return _verificationView();
          return _formView();
        }),
      ),
    );
  }

  Widget _formView() => ListView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 32),
        children: [
          const Center(child: MangaPlusLogo(size: 86)),
          const SizedBox(height: 16),
          Text(
            controller.isRegister.value ? 'أنشئ حسابك' : 'مرحبًا بعودتك',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 25, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            controller.isRegister.value ? 'زامن قراءتك ومفضلتك بين أجهزتك.' : 'سجّل الدخول لمتابعة قراءتك.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          if (controller.isRegister.value) ...[
            _field(controller.displayName, 'الاسم الظاهر', Icons.badge_outlined),
            const SizedBox(height: 12),
            _usernameField(),
            const SizedBox(height: 12),
          ],
          _field(controller.email, 'البريد الإلكتروني', Icons.email_outlined, keyboard: TextInputType.emailAddress),
          const SizedBox(height: 12),
          _passwordField(controller.password, 'كلمة المرور', controller.obscurePassword),
          if (!controller.isRegister.value)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: controller.resetPassword, child: const Text('نسيت كلمة المرور؟')),
            ),
          if (controller.isRegister.value) ...[
            const SizedBox(height: 12),
            _passwordField(controller.confirmPassword, 'تأكيد كلمة المرور', controller.obscureConfirmPassword),
            const SizedBox(height: 12),
            _countryField(),
            const SizedBox(height: 12),
            _birthDateField(),
          ],
          const SizedBox(height: 22),
          FilledButton(
            onPressed: controller.isBusy.value ? null : controller.submit,
            child: controller.isBusy.value
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(controller.isRegister.value ? 'إنشاء الحساب' : 'تسجيل الدخول'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: controller.isBusy.value ? null : controller.signInGoogle,
            icon: const Icon(Icons.account_circle_outlined),
            label: const Text('المتابعة باستخدام Google'),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: controller.isBusy.value ? null : controller.continueAsGuest, child: const Text('المتابعة كضيف')),
          const SizedBox(height: 8),
          TextButton(
            onPressed: controller.isBusy.value ? null : () => controller.setRegisterMode(!controller.isRegister.value),
            child: Text(controller.isRegister.value ? 'لديك حساب؟ سجّل الدخول' : 'ليس لديك حساب؟ أنشئ حسابًا'),
          ),
        ],
      );

  Widget _verificationView() => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mark_email_read_outlined, size: 72, color: AppColors.primary),
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

  Widget _field(TextEditingController textController, String label, IconData icon, {TextInputType? keyboard}) => TextField(
        controller: textController,
        keyboardType: keyboard,
        textDirection: TextDirection.ltr,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      );

  Widget _usernameField() => Obx(() {
        final status = controller.usernameAvailability.value;
        final statusText = switch (status) {
          UsernameAvailability.checking => 'جارٍ فحص الاسم...',
          UsernameAvailability.available => 'متوفر',
          UsernameAvailability.taken => 'مأخوذ',
          UsernameAvailability.invalid => 'استخدم 3–24 حرفًا إنجليزيًا أو رقمًا أو _',
          UsernameAvailability.error => 'تعذر فحص الاسم',
          UsernameAvailability.idle => '',
        };
        final statusColor = status == UsernameAvailability.available
            ? Colors.green
            : status == UsernameAvailability.taken || status == UsernameAvailability.invalid
                ? Colors.red
                : AppColors.textSecondary;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _field(controller.username, 'اسم المستخدم (إنجليزي وأرقام و_)', Icons.alternate_email_rounded),
            if (statusText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 5, left: 12, right: 12),
                child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
          ],
        );
      });

  Widget _passwordField(TextEditingController textController, String label, RxBool obscure) => Obx(() => TextField(
        controller: textController,
        obscureText: obscure.value,
        textDirection: TextDirection.ltr,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.lock_outline_rounded),
          suffixIcon: IconButton(onPressed: obscure.toggle, icon: Icon(obscure.value ? Icons.visibility_outlined : Icons.visibility_off_outlined)),
        ),
      ));

  Widget _countryField() => DropdownButtonFormField<ArabCountry>(
        value: controller.selectedCountry.value,
        decoration: const InputDecoration(labelText: 'الدولة', prefixIcon: Icon(Icons.public_rounded)),
        items: AuthController.countries.map((country) => DropdownMenuItem(value: country, child: Text(country.name))).toList(),
        onChanged: (value) => controller.selectedCountry.value = value,
      );

  Widget _birthDateField() => InkWell(
        onTap: () async {
          final date = await showDatePicker(context: Get.context!, firstDate: DateTime(1900), lastDate: DateTime.now(), initialDate: DateTime(2000));
          if (date != null) controller.birthDate.value = date;
        },
        child: InputDecorator(
          decoration: const InputDecoration(labelText: 'تاريخ الميلاد', prefixIcon: Icon(Icons.cake_outlined)),
          child: Text(controller.birthDate.value == null ? 'اختر تاريخ الميلاد' : '${controller.birthDate.value!.year}/${controller.birthDate.value!.month}/${controller.birthDate.value!.day}'),
        ),
      );
}
