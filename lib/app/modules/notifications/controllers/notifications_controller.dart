import 'package:get/get.dart';
import 'package:mangaplus/app/data/models/app_notification.dart';
import 'package:mangaplus/app/data/services/app_notification_service.dart';

class NotificationsController extends GetxController {
  final AppNotificationService service = Get.find<AppNotificationService>();
  final RxBool isLoading = true.obs;
  final RxBool hasError = false.obs;
  final RxList<AppNotification> notifications = <AppNotification>[].obs;

  int get unreadCount => notifications.where((item) => !item.isRead).length;

  @override
  void onInit() {
    super.onInit();
    load();
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
}
