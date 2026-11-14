import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/settings/reading_preferences.dart';
import 'package:mangaplus/app/core/theme/app_palette.dart';
import 'package:mangaplus/app/modules/profile/controllers/profile_controller.dart';
import 'package:mangaplus/app/core/theme/design_tokens.dart';
import 'package:mangaplus/app/widgets/app_feedback.dart';
import 'package:mangaplus/app/widgets/app_surfaces.dart';
import 'package:mangaplus/app/widgets/mangaplus_app_bar.dart';
import 'package:mangaplus/app/widgets/theme_aware_builder.dart';

/// The manga reader reads these keys during initialization, so a change here is
/// the default for the next chapter that is opened. Per-chapter overrides made
/// inside the reader keep working and are saved with the chapter position.
class SettingsReadingView extends StatefulWidget {
  const SettingsReadingView({super.key});

  @override
  State<SettingsReadingView> createState() => _SettingsReadingViewState();
}

class _SettingsReadingViewState extends State<SettingsReadingView> {
  late String _mode;
  late String _direction;
  late bool _continuous;

  @override
  void initState() {
    super.initState();
    _mode = ReadingPreferences.mode;
    _direction = ReadingPreferences.direction;
    _continuous = ReadingPreferences.continuousNavigation;
  }

  Future<void> _saveMode(String value) async {
    setState(() => _mode = value);
    await ReadingPreferences.saveMode(value);
    if (Get.isRegistered<ProfileController>()) {
      Get.find<ProfileController>().reloadReadingPreferences();
    }
    if (!mounted) return;
    AppFeedback.show(
      title: 'تم الحفظ'.tr,
      message: 'سيُستخدم «${ReadingPreferences.modeLabel(value)}» عند فتح فصل جديد.'.tr,
      type: AppNoticeType.success,
    );
  }

  Future<void> _saveDirection(String value) async {
    setState(() => _direction = value);
    await ReadingPreferences.saveDirection(value);
  }

  Future<void> _saveContinuous(bool value) async {
    setState(() => _continuous = value);
    await ReadingPreferences.saveContinuousNavigation(value);
  }

  @override
  Widget build(BuildContext context) => ThemeAwareBuilder(
        builder: (context) => Scaffold(
          backgroundColor: context.palette.background,
          appBar: MangaPlusAppBar(title: 'القراءة'.tr),
          body: ListView(
            padding: AppSpacing.pageInsets,
            children: [
              AppSection(
                title: 'وضع القراءة الافتراضي'.tr,
                children: [
                  AppSettingsTile(
                    icon: Icons.view_agenda_outlined,
                    title: 'تمرير متصل'.tr,
                    subtitle: 'الوضع المناسب للمانهوا والروايات.'.tr,
                    switchValue: _mode == 'scroll',
                    onSwitchChanged: (selected) {
                      if (selected) _saveMode('scroll');
                    },
                  ),
                  AppSettingsTile(
                    icon: Icons.auto_stories_outlined,
                    title: 'صفحات'.tr,
                    subtitle: 'صفحة واحدة في كل مرة.'.tr,
                    switchValue: _mode == 'paged',
                    onSwitchChanged: (selected) {
                      if (selected) _saveMode('paged');
                    },
                  ),
                ],
              ),
              AppSection(
                title: 'اتجاه القراءة'.tr,
                children: [
                  AppSettingsTile(
                    icon: Icons.format_textdirection_r_to_l,
                    title: 'يمين إلى يسار'.tr,
                    switchValue: _direction == 'rtl',
                    onSwitchChanged: (selected) {
                      if (selected) _saveDirection('rtl');
                    },
                  ),
                  AppSettingsTile(
                    icon: Icons.format_textdirection_l_to_r,
                    title: 'يسار إلى يمين'.tr,
                    switchValue: _direction == 'ltr',
                    onSwitchChanged: (selected) {
                      if (selected) _saveDirection('ltr');
                    },
                  ),
                ],
              ),
              AppSection(
                title: 'التنقل'.tr,
                children: [
                  AppSettingsTile(
                    icon: Icons.skip_next_rounded,
                    title: 'الانتقال للفصل التالي تلقائيًا'.tr,
                    subtitle: 'عند الوصول إلى نهاية الفصل في التمرير المتصل.'.tr,
                    switchValue: _continuous,
                    onSwitchChanged: _saveContinuous,
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: AppSpacing.xxs,
                  top: AppSpacing.xxs,
                ),
                child: Text(
                  'هذه القيم افتراضية للفصول الجديدة. أي تغيير تجريه داخل '
                  'القارئ يظل محفوظًا كما هو.'.tr,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.palette.textSecondary,
                        height: 1.5,
                      ),
                ),
              ),
            ],
          ),
        ),
      );
}
