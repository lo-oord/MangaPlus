import 'package:get/get.dart';
import 'package:mangaplus/app/data/models/app_notification.dart';
import 'package:mangaplus/app/data/services/app_notification_service.dart';
import 'package:mangaplus/app/routes/app_pages.dart';

class NotificationsController extends GetxController {
  final AppNotificationService service = Get.find<AppNotificationService>();
  final RxBool isLoading = true.obs;
  final RxBool hasError = false.obs;
  final RxList<AppNotification> notifications = <AppNotification>[].obs;

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

  Future<void> openNotification(AppNotification notification) async {
    await markRead(notification);

    final data = notification.data;
    final rawRoute = notification.route.trim();
    final uri = Uri.tryParse(rawRoute);
    var routePath = uri?.path ?? rawRoute;
    if (routePath.isNotEmpty && !routePath.startsWith('/')) {
      routePath = '/$routePath';
    }

    final query = uri?.queryParameters ?? const <String, String>{};
    final comicId = '${data['comicId'] ?? data['comic_id'] ?? data['mangaId'] ?? query['comicId'] ?? query['comic_id'] ?? query['id'] ?? ''}'.trim();

    if (routePath.isNotEmpty && AppPages.routes.any((page) => page.name == routePath)) {
      if (routePath == Routes.COMIC_DETAIL) {
        if (comicId.isEmpty) return;
        final arguments = data.isNotEmpty
            ? <String, dynamic>{...data, 'comicId': comicId}
            : comicId;
        await Get.toNamed(routePath, arguments: arguments);
        return;
      }
      final arguments = data.isNotEmpty
          ? data
          : query.isNotEmpty
              ? query
              : null;
      await Get.toNamed(routePath, arguments: arguments);
      return;
    }

    if (comicId.isNotEmpty) {
      await Get.toNamed(Routes.COMIC_DETAIL, arguments: comicId);
    }
  }
}
