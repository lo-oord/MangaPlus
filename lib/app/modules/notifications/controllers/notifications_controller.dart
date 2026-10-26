import 'package:get/get.dart';
import 'package:mangaplus/app/data/models/app_notification.dart';
import 'package:mangaplus/app/data/services/app_notification_service.dart';
import 'package:mangaplus/app/data/services/chapter_update_service.dart';
import 'package:mangaplus/app/routes/app_pages.dart';
import 'package:mangaplus/app/widgets/app_feedback.dart';

class NotificationsController extends GetxController {
  final AppNotificationService service = Get.find<AppNotificationService>();
  final ChapterUpdateService chapterService = Get.find<ChapterUpdateService>();
  final RxBool isLoading = true.obs;
  final RxBool isCheckingFavorites = false.obs;
  final RxBool backgroundEnabled = false.obs;
  final RxBool wifiOnly = false.obs;
  final RxInt frequencyHours = 12.obs;
  final RxBool batteryOptimizationActive = true.obs;
  final RxBool hasError = false.obs;
  final RxList<AppNotification> notifications = <AppNotification>[].obs;

  int get unreadCount => notifications.where((item) => !item.isRead).length;

  @override
  void onInit() {
    super.onInit();
    backgroundEnabled.value = chapterService.backgroundEnabled;
    wifiOnly.value = chapterService.wifiOnly;
    frequencyHours.value = chapterService.frequencyHours;
    _loadBatteryState();
    load();
  }

  Future<void> _loadBatteryState() async {
    batteryOptimizationActive.value = !(await chapterService.isBatteryOptimizationIgnored());
  }

  Future<void> setBackgroundEnabled(bool value) async {
    backgroundEnabled.value = value;
    await chapterService.setBackgroundEnabled(value);
    if (value && await chapterService.isBatteryOptimizationIgnored() == false) {
      await chapterService.requestBatteryOptimizationExemption();
    }
    await _loadBatteryState();
  }

  Future<void> setWifiOnly(bool value) async {
    wifiOnly.value = value;
    await chapterService.setWifiOnly(value);
  }

  Future<void> setFrequency(int value) async {
    frequencyHours.value = value;
    await chapterService.setFrequencyHours(value);
  }

  Future<void> requestBatteryExemption() async {
    await chapterService.requestBatteryOptimizationExemption();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await _loadBatteryState();
  }

  Future<void> load() async {
    isLoading.value = true;
    hasError.value = false;
    try {
      notifications.assignAll(await service.loadNotifications());
    } catch (_) {
      hasError.value = true;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> markRead(AppNotification notification) async {
    if (notification.isRead) return;
    await service.markRead(notification.id);
    final index = notifications.indexWhere((item) => item.id == notification.id);
    if (index >= 0) notifications[index] = notification.copyWith(isRead: true);
  }

  Future<void> markAllRead() async {
    for (final item in notifications.where((item) => !item.isRead).toList()) {
      await service.markRead(item.id);
    }
    notifications.assignAll(notifications.map((item) => item.copyWith(isRead: true)));
  }

  Future<void> openNotification(AppNotification notification) async {
    await markRead(notification);
    final comicId = '${notification.data['comicId'] ?? ''}'.trim();
    if (comicId.isNotEmpty) {
      await Get.toNamed(Routes.COMIC_DETAIL, arguments: comicId);
    }
  }

  Future<void> checkFavorites() async {
    if (isCheckingFavorites.value) return;
    isCheckingFavorites.value = true;
    try {
      final result = await chapterService.checkFavorites();
      await load();
      AppFeedback.show(
        title: 'اكتمل الفحص'.tr,
        message: result.updated == 0
            ? 'لم يتم العثور على فصول جديدة.'.tr
            : '${result.updated} ${'أعمال لديها تحديثات'.tr}',
        type: AppNoticeType.success,
      );
    } catch (_) {
      AppFeedback.show(
        title: 'تعذر الفحص'.tr,
        message: 'تحقق من اتصال الإنترنت ثم حاول مجددًا.'.tr,
        type: AppNoticeType.error,
      );
    } finally {
      isCheckingFavorites.value = false;
    }
  }
}
