import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/modules/settings/controllers/settings_controller.dart';
import 'package:mangaplus/app/routes/app_pages.dart';
import 'package:mangaplus/app/widgets/mangaplus_app_bar.dart';
import 'package:mangaplus/app/widgets/theme_aware_builder.dart';

class PrivacySecurityView extends GetView<SettingsController> {
  const PrivacySecurityView({super.key});

  @override
  Widget build(BuildContext context) => ThemeAwareBuilder(
        builder: (context) => Scaffold(
          backgroundColor: AppColors.background,
          appBar: MangaPlusAppBar(title: 'الخصوصية والأمان'.tr),
          body: Obx(() => ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  _card([
                    _title('إدارة الحساب'.tr),
                    const SizedBox(height: 12),
                    _navigationTile(
                      icon: Icons.person_rounded,
                      title: 'بيانات الحساب'.tr,
                      subtitle: 'الاسم، البريد، الصورة، وإعدادات الخصوصية'.tr,
                      onTap: () => Get.toNamed(Routes.PROFILE_DETAILS),
                    ),
                  ]),
                  const SizedBox(height: 22),
                  _card([
                    _title('الأمان والدخول'.tr),
                    const SizedBox(height: 12),
                    _navigationTile(
                      icon: Icons.lock_rounded,
                      title: 'كلمة المرور'.tr,
                      subtitle: 'تغيير كلمة المرور أو إعادة تعيينها'.tr,
                      onTap: () => Get.toNamed(Routes.AUTH),
                    ),
                    const Divider(height: 1, color: AppColors.divider),
                    _navigationTile(
                      icon: Icons.login_rounded,
                      title: 'طرق تسجيل الدخول'.tr,
                      subtitle: 'إدارة حسابات الدخول المتاحة'.tr,
                      onTap: () => Get.toNamed(Routes.AUTH),
                    ),
                  ]),
                  const SizedBox(height: 22),
                  _card([
                    _title('جلسة المستخدم'.tr),
                    const SizedBox(height: 12),
                    _navigationTile(
                      icon: Icons.exit_to_app_rounded,
                      title: 'تسجيل الخروج'.tr,
                      subtitle: 'نهاية الجلسة الحالية على هذا الجهاز'.tr,
                      onTap: () => _confirmSignOut(context),
                      isDestructive: true,
                    ),
                  ]),
                  const SizedBox(height: 22),
                  _card([
                    _title('الخصوصية والبيانات'.tr),
                    const SizedBox(height: 12),
                    _readonlyTile(
                      icon: Icons.privacy_tip_rounded,
                      title: 'معلومات الخصوصية'.tr,
                      subtitle: 'كيفية تخزين بياناتك ومزامنتها'.tr,
                      onTap: () => _showPrivacyInfo(context),
                    ),
                    const Divider(height: 1, color: AppColors.divider),
                    _navigationTile(
                      icon: Icons.description_outlined,
                      title: 'سياسة الخصوصية'.tr,
                      subtitle: 'شاهد سياسة الخصوصية الكاملة'.tr,
                      onTap: () => _showPrivacyPolicy(context),
                    ),
                    const Divider(height: 1, color: AppColors.divider),
                    _navigationTile(
                      icon: Icons.article_outlined,
                      title: 'شروط الاستخدام'.tr,
                      subtitle: 'أحكام واستخدام التطبيق'.tr,
                      onTap: () => _showTermsOfUse(context),
                    ),
                  ]),
                ],
              )),
        ),
      );

  Widget _card(List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.divider.withValues(alpha: .72)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      );

  Widget _title(String title) => Padding(
        padding: const EdgeInsetsDirectional.only(start: 4),
        child: Text(
          title,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  Widget _navigationTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    bool isDestructive = false,
  }) =>
      ListTile(
        leading: Icon(
          icon,
          color: isDestructive ? AppColors.error : AppColors.icon,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isDestructive ? AppColors.error : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: isDestructive ? AppColors.error : AppColors.icon,
        ),
        onTap: onTap,
      );

  Widget _readonlyTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) =>
      ListTile(
        leading: Icon(icon, color: AppColors.icon),
        title: Text(
          title,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        trailing:
            onTap != null ? Icon(Icons.chevron_right_rounded, color: AppColors.icon) : null,
        onTap: onTap,
      );

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        title: Text('تسجيل الخروج'.tr),
        content: Text(
          'ستخرج من حسابك الحالي. سيبقى سجل القراءة والمفضلات على هذا الجهاز ما لم تكن المزامنة مفعّلة.'.tr,
          textAlign: TextAlign.start,
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('إلغاء'.tr),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: Text('تسجيل الخروج'.tr),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
  }

  Future<void> _showPrivacyInfo(BuildContext context) async {
    await Get.dialog(
      AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        title: Text('معلومات الخصوصية'.tr),
        content: Text(
          'يتم تخزين بياناتك المحلية على هذا الجهاز، وتُستخدم ميزة المزامنة فقط إذا فعلت ذلك وفعّلت المزامنة مع حسابك. '
          'تُستخدم بيانات Firebase Auth و Firestore لخدمة المصادقة والمزامنة وفق سياسة الخصوصية. '
          'لا تظهر البيانات الشخصية دون إذنك.'.tr,
          textAlign: TextAlign.start,
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('فهمت'.tr),
          ),
        ],
      ),
    );
  }

  Future<void> _showPrivacyPolicy(BuildContext context) async {
    await Get.dialog(
      AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        title: Text('سياسة الخصوصية'.tr),
        content: Text(
          'سياسة الخصوصية متاحة للمستخدمين عبر رابط رسمي خارجي أو داخل التطبيق إذا كان متاحًا. '
          'يوفر التطبيق معلومات عامة حول كيفية جمع البيانات واستخدامها ومشاركتها وفق سياسة الخصوصية المعتمدة.'.tr,
          textAlign: TextAlign.start,
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('إغلاق'.tr),
          ),
        ],
      ),
    );
  }

  Future<void> _showTermsOfUse(BuildContext context) async {
    await Get.dialog(
      AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        title: Text('شروط الاستخدام'.tr),
        content: Text(
          'شروط استخدام التطبيق تشمل القواعد والأحكام التي تحكم استخدام MangaPlus. '
          'يمكن للمستخدمين مراجعة الشروط الكاملة عبر رابط رسمي خارجي أو داخل التطبيق إذا كان متاحًا.'.tr,
          textAlign: TextAlign.start,
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('إغلاق'.tr),
          ),
        ],
      ),
    );
  }
}
