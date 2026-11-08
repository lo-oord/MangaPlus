import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/widgets/mangaplus_app_bar.dart';
import 'package:mangaplus/app/widgets/theme_aware_builder.dart';

class HelpView extends StatelessWidget {
  const HelpView({super.key});

  @override
  Widget build(BuildContext context) => ThemeAwareBuilder(
        builder: (context) => Scaffold(
          backgroundColor: AppColors.background,
          appBar: MangaPlusAppBar(title: 'مركز المساعدة'.tr),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _card([
                _title('الأسئلة الشائعة'.tr),
                const SizedBox(height: 12),
                _faqItem(
                  'كيف讨论 المحفوظات؟'.tr,
                  'لحفظ العمل، افتح القائمة وأضف العمل إلى مفضلاتك. ستظهر محتوى العمل الذي أحضره التطبيق.'.tr,
                ),
                const Divider(height: 1, color: AppColors.divider),
                _faqItem(
                  'كيف跟踪 chapter إلى chapter?'.tr,
                  'استخدم زر الانتقال في القارئ للانتقال بين الفصول. يمكنك ضبط إعدادات القراءة في الإعدادات.'.tr,
                ),
              ]),
              const SizedBox(height: 22),
              _card([
                _title('استخدام التطبيق'.tr),
                const SizedBox(height: 12),
                _helpItem(
                  icon: Icons.book_rounded,
                  title: 'بدء القراءة'.tr,
                  description: 'ابحث عن عمل، افتحه، واختر فصلًا لبدء القراءة. يمكنك ضبط إعدادات القارئ حسب ذوقك.'.tr,
                ),
                const Divider(height: 1, color: AppColors.divider),
                _helpItem(
                  icon: Icons.favorite_rounded,
                  title: 'المفضلات'.tr,
                  description: 'أضف الأ_WORK إلى مفضلاتك للوصول السريع إليها والحصول على إشعارات عند توفر فصول جديدة.'.tr,
                ),
              ]),
              const SizedBox(height: 22),
              _card([
                _title('المساعدة والدعم'.tr),
                const SizedBox(height: 12),
                _helpItem(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'الإبلاغ عن مشكلة'.tr,
                  description: 'في حال وجود أي مشكلة، يمكنك الإبلاغ عنها عبر إرسال الملاحظات من داخل التطبيق.'.tr,
                ),
                const Divider(height: 1, color: AppColors.divider),
                _helpItem(
                  icon: Icons.lightbulb_outline_rounded,
                  title: 'الاقتراحات'.tr,
                  description: 'نرحب بجميع الاقتراحات والتعليقات لتحسين تجربة التطبيق.'.tr,
                ),
              ]),
              const SizedBox(height: 22),
              _card([
                _title('تواصل معنا'.tr),
                const SizedBox(height: 12),
                _helpItem(
                  icon: Icons.email_outlined,
                  title: 'تواصل عبر البريد الإلكتروني'.tr,
                  description: 'يمكنك التواصل معنا عبر البريد الإلكتروني المتاح في التطبيق أو عبر الموقع الرسمي إذا كان متاحًا.'.tr,
                ),
              ]),
            ],
          ),
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

  Widget _faqItem(String question, String answer) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            answer,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      );

  Widget _helpItem({
    required IconData icon,
    required String title,
    required String description,
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
          description,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      );
}
