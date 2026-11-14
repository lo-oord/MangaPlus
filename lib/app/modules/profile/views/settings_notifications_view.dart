import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/theme/app_palette.dart';
import 'package:mangaplus/app/core/theme/design_tokens.dart';
import 'package:mangaplus/app/modules/profile/controllers/profile_controller.dart';
import 'package:mangaplus/app/widgets/app_surfaces.dart';
import 'package:mangaplus/app/widgets/mangaplus_app_bar.dart';
import 'package:mangaplus/app/widgets/theme_aware_builder.dart';
import 'package:permission_handler/permission_handler.dart';

class SettingsNotificationsView extends StatefulWidget {
  const SettingsNotificationsView({super.key});

  @override
  State<SettingsNotificationsView> createState() =>
      _SettingsNotificationsViewState();
}

class _SettingsNotificationsViewState extends State<SettingsNotificationsView>
    with WidgetsBindingObserver {
  final ProfileController _controller = Get.find<ProfileController>();
  PermissionStatus? _permission;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refreshPermission());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refreshPermission());
  }

  Future<void> _refreshPermission() async {
    final status = await Permission.notification.status;
    if (mounted) setState(() => _permission = status);
  }

  Future<void> _requestPermission() async {
    final status = await Permission.notification.request();
    if (!mounted) return;
    setState(() => _permission = status);
    if (status.isPermanentlyDenied) {
      Get.snackbar(
        'الإذن مرفوض'.tr,
        'يمكنك تفعيل الإشعارات من إعدادات النظام.'.tr,
        snackPosition: SnackPosition.BOTTOM,
        mainButton: TextButton(
          onPressed: openAppSettings,
          child: Text('فتح الإعدادات'.tr),
        ),
      );
    }
  }

  String get _permissionLabel => switch (_permission) {
        PermissionStatus.granted => 'مسموح'.tr,
        PermissionStatus.denied => 'غير مسموح'.tr,
        PermissionStatus.permanentlyDenied => 'مرفوض من النظام'.tr,
        PermissionStatus.restricted => 'مقيّد من النظام'.tr,
        PermissionStatus.limited => 'محدود'.tr,
        PermissionStatus.provisional => 'مؤقت'.tr,
        _ => 'غير معروف'.tr,
      };

  @override
  Widget build(BuildContext context) => ThemeAwareBuilder(
        builder: (context) => Scaffold(
          backgroundColor: context.palette.background,
          appBar: MangaPlusAppBar(title: 'الإشعارات'.tr),
          body: Obx(
            () => ListView(
              padding: AppSpacing.pageInsets,
              children: [
                AppSection(
                  title: 'إذن النظام'.tr,
                  subtitle: 'لا يمكن إرسال أي تنبيه دون هذا الإذن.'.tr,
                  children: [
                    AppSettingsTile(
                      icon: _permission?.isGranted == true
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_off_outlined,
                      title: 'إشعارات النظام'.tr,
                      value: _permissionLabel,
                      onTap: _permission?.isGranted == true
                          ? openAppSettings
                          : _requestPermission,
                    ),
                    AppSettingsTile(
                      icon: Icons.settings_rounded,
                      title: 'إعدادات إشعارات النظام'.tr,
                      onTap: openAppSettings,
                    ),
                  ],
                ),
                AppSection(
                  title: 'أنواع التنبيهات'.tr,
                  subtitle: 'تنطبق على الفصول الجديدة للمفضلات.'.tr,
                  children: [
                    AppSettingsTile(
                      icon: Icons.favorite_border_rounded,
                      title: 'إشعارات المفضلات'.tr,
                      subtitle: 'فحص دوري للمفضلة وإشعار عند توفر فصل جديد.'.tr,
                      switchValue:
                          _controller.favoritesNotificationsEnabled.value,
                      onSwitchChanged: _controller.setFavoritesNotifications,
                    ),
                    AppSettingsTile(
                      icon: Icons.menu_book_rounded,
                      title: 'إشعارات المانجا'.tr,
                      switchValue: _controller.mangaNotificationsEnabled.value,
                      onSwitchChanged: _controller.setMangaNotifications,
                    ),
                    AppSettingsTile(
                      icon: Icons.auto_stories_rounded,
                      title: 'إشعارات الروايات'.tr,
                      switchValue: _controller.novelNotificationsEnabled.value,
                      onSwitchChanged: _controller.setNovelNotifications,
                    ),
                  ],
                ),
                AppSection(
                  title: 'تنزيلات'.tr,
                  children: [
                    AppSettingsTile(
                      icon: Icons.download_done_rounded,
                      title: 'إشعارات التحميل'.tr,
                      subtitle:
                          'تصدر عن مدير التحميلات نفسه، وتتبع إذن النظام أعلاه.'.tr,
                      onTap: () => Get.snackbar(
                        'إشعارات التحميل'.tr,
                        'يُظهر مدير التحميلات تقدم التنزيل واكتماله تلقائيًا '
                            'عند منح إذن النظام.'.tr,
                        snackPosition: SnackPosition.BOTTOM,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}
