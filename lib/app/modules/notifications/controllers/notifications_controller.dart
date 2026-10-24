import 'package:get/get.dart';
import 'package:mangaplus/app/data/models/app_notification.dart';
import 'package:mangaplus/app/data/services/app_notification_service.dart';
import 'package:mangaplus/app/data/services/chapter_update_service.dart';
import 'package:mangaplus/app/widgets/app_feedback.dart';

class NotificationsController extends GetxController {
  final AppNotificationService service = Get.find<AppNotificationService>();
  final ChapterUpdateService chapterService = Get.find<ChapterUpdateService>();
  final RxBool isLoading = true.obs;
  final RxBool isCheckingFavorites = false.obs;
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
