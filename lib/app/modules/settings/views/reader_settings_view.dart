import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/modules/settings/controllers/settings_controller.dart';
import 'package:mangaplus/app/modules/chapter/controllers/chapter_controller.dart';
import 'package:mangaplus/app/widgets/mangaplus_app_bar.dart';
import 'package:mangaplus/app/widgets/theme_aware_builder.dart';

class ReaderSettingsView extends GetView<SettingsController> {
  const ReaderSettingsView({super.key});

  ChapterController get _reader => Get.isRegistered<ChapterController>()
      ? Get.find<ChapterController>()
      : ChapterController();

  @override
  Widget build(BuildContext context) => ThemeAwareBuilder(
        builder: (context) => Scaffold(
          backgroundColor: AppColors.background,
          appBar: MangaPlusAppBar(title: 'إعدادات القارئ'.tr),
          body: Obx(() => ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  _card([
                    _title('وضع العرض'.tr),
                    const SizedBox(height: 12),
                    _readerOptionTile(
                      icon: Icons.view_carousel_rounded,
                      title: 'وضع الصفحات'.tr,
                      subtitle: 'عرض الصفحات واحدة تلو الأخرى'.tr,
                      value: _reader.readerMode.value == 'paged',
                      onChanged: (v) {
                        _reader.readerMode.value = v ? 'paged' : 'scroll';
                        _reader.pageController ??= null;
                        _reader.scrollController ??= null;
                      },
                    ),
                    const Divider(height: 1, color: AppColors.divider),
                    _readerOptionTile(
                      icon: Icons.dock_horizontal_rounded,
                      title: 'وضع التمرير'.tr,
                      subtitle: 'تمرير مستمر للマンغا والروايات'.tr,
                      value: _reader.readerMode.value == 'scroll',
                      onChanged: (v) {
                        _reader.readerMode.value = v ? 'scroll' : 'paged';
                        _reader.pageController ??= null;
                        _reader.scrollController ??= null;
                      },
                    ),
                  ]),
                  const SizedBox(height: 22),
                  _card([
                    _title('الاتجاه الافتراضي'.tr),
                    const SizedBox(height: 12),
                    _readerOptionTile(
                      icon: Icons.compare_arrows_rounded,
                      title: 'اتجاه القراءة'.tr,
                      subtitle: 'من اليمين إلى اليسار (RTL)'.tr,
                      value: _reader.readingDirection.value == 'rtl',
                      onChanged: (v) {
                        _reader.readingDirection.value = v ? 'rtl' : 'ltr';
                      },
                    ),
                  ]),
                  const SizedBox(height: 22),
                  _card([
                    _title('التصفح والانتقالات'.tr),
                    const SizedBox(height: 12),
                    _readerOptionTile(
                      icon: Icons.open_in_new_rounded,
                      title: 'الانتقال التلقائي للفصل التالي'.tr,
                      subtitle: 'الانتقال التلقائي عند نهاية الفصل'.tr,
                      value: _reader.continuousNavigation.value,
                      onChanged: (v) {
                        _reader.continuousNavigation.value = v;
                      },
                    ),
                    const Divider(height: 1, color: AppColors.divider),
                    _readerOptionTile(
                      icon: Icons.warning_rounded,
                      title: 'تأكيد الانتقال بين الفصول'.tr,
                      subtitle: 'طلب التأكيد قبل الانتقال'.tr,
                      value: _reader.showChapterTitle.value,
                      onChanged: (v) {
                        _reader.showChapterTitle.value = v;
                      },
                    ),
                  ]),
                  const SizedBox(height: 22),
                  _card([
                    _title('سلوك القارئ'.tr),
                    const SizedBox(height: 12),
                    _readerOptionTile(
                      icon: Icons.opacity_rounded,
                      title: 'وضع القراءة بملء الشاشة'.tr,
                      subtitle: 'تغيير حجم الصور لملء الشاشة'.tr,
                      value: _reader.readerFit.value == 'fill',
                      onChanged: (v) {
                        _reader.readerFit.value = v ? 'fill' : 'width';
                      },
                    ),
                  ]),
                  const SizedBox(height: 22),
                  _card([
                    _title('تخصيص الرواية'.tr),
                    const SizedBox(height: 12),
                    _readerOptionTile(
                      icon: Icons.text_fields,
                      title: 'حجم الخط الافتراضي للروايات'.tr,
                      subtitle: 'تحديد حجم النص الافتراضي'.tr,
                      value: false,
                      onChanged: (_) {},
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

  Widget _readerOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) =>
      SwitchListTile.adaptive(
        value: value,
        onChanged: onChanged,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        secondary: Icon(icon, color: AppColors.icon),
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
        activeColor: AppColors.primary,
      );
}
