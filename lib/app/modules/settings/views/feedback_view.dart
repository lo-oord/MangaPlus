import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/widgets/mangaplus_app_bar.dart';
import 'package:mangaplus/app/widgets/theme_aware_builder.dart';

class FeedbackView extends StatefulWidget {
  const FeedbackView({super.key});

  @override
  State<FeedbackView> createState() => _FeedbackViewState();
}

class _FeedbackViewState extends State<FeedbackView> {
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ThemeAwareBuilder(
        builder: (context) => Scaffold(
          backgroundColor: AppColors.background,
          appBar: MangaPlusAppBar(title: 'إرسال ملاحظات'.tr),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _card([
                _title('راسلنا'.tr),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailCtrl,
                  decoration: InputDecoration(
                    labelText: 'البريد الإلكتروني (اختياري)'.tr,
                    hintText: 'مثال: you@example.com',
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _subjectCtrl,
                  decoration: InputDecoration(
                    labelText: 'العنوان'.tr,
                    hintText: 'كيف يمكننا المساعدة؟',
                  ),
                  maxLength: 60,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _messageCtrl,
                  decoration: InputDecoration(
                    labelText: 'رسالتك'.tr,
                    hintText: 'اكتب تفاصيل ملاحظتك هنا...',
                  ),
                  maxLines: 6,
                  maxLength: 600,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _sendFeedback,
                  icon: Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                  ),
                  label: Text('إرسال'.tr),
                ),
              ]),
              const SizedBox(height: 22),
              _card([
                _title('طرق التواصل الأخرى'.tr),
                const SizedBox(height: 12),
                _infoRow(
                  icon: Icons.mail_outline_rounded,
                  title: 'مراسلة عبر البريد الإلكتروني'.tr,
                  description:
                      'يمكنك مراسلتنا عبر البريد الإلكتروني لمقدمي التطبيق إذا كان متاحًا.'.tr,
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

  Widget _infoRow({
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

  Future<void> _sendFeedback() async {
    final subject = _subjectCtrl.text.trim();
    final message = _messageCtrl.text.trim();
    final email = _emailCtrl.text.trim();

    if (subject.isEmpty || message.isEmpty) {
      Get.snackbar(
        'يجب إرسال رسالة'.tr,
        'الرجاء كتابة عنوان وملاحظات قبل الإرسال'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    try {
      if (Platform.isAndroid || Platform.isIOS) {
        await FileUtil.openUrl('mailto:${email.isNotEmpty ? email : ''}?'
            'subject=${Uri.encodeComponent(subject)}'
            '&body=${Uri.encodeComponent(message)}');
        Get.snackbar(
          'تم إعداد المراسلة'.tr,
          'تطبيق البريد سيُفتح لمراسلتك'.tr,
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        Get.snackbar(
          'لا تدعم المنصة'.tr,
          'لا يمكن فتح تطبيق البريد تلقائيًا على هذه المنصة'.tr,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (_) {
      Get.snackbar(
        'فشل الإرسال'.tr,
        'تعذر فتح التطبيق المناسب للإرسال في الوقت الحالي'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}

class FileUtil {
  static Future<void> openUrl(String url) async {
    if (url.startsWith('mailto:')) {
      await Process.run('xdg-open', [url]);
    }
  }
}
