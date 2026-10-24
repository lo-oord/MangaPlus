import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/data/models/app_notification.dart';
import 'package:mangaplus/app/modules/notifications/controllers/notifications_controller.dart';
import 'package:mangaplus/app/widgets/brand_state.dart';
import 'package:mangaplus/app/widgets/theme_aware_builder.dart';

class NotificationsView extends GetView<NotificationsController> {
  const NotificationsView({super.key});

  @override
  Widget build(BuildContext context) => ThemeAwareBuilder(
        builder: (context) => Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text('الإشعارات'.tr),
            centerTitle: true,
            backgroundColor: AppColors.background,
            foregroundColor: AppColors.textPrimary,
            elevation: 0,
            actions: [
              Obx(() => controller.unreadCount == 0
                  ? const SizedBox.shrink()
                  : IconButton(
                      tooltip: 'تحديد الكل كمقروء'.tr,
                      onPressed: controller.markAllRead,
                      icon: Icon(Icons.done_all_rounded, color: AppColors.primary),
                    )),
            ],
          ),
          body: Obx(() {
            if (controller.isLoading.value) {
              return BrandState(title: 'جارٍ تحميل الإشعارات'.tr, loading: true);
            }
            if (controller.hasError.value) {
              return BrandState(
                title: 'تعذر تحميل الإشعارات'.tr,
                description: 'تحقق من اتصال الإنترنت ثم حاول مجددًا.'.tr,
                icon: Icons.notifications_off_outlined,
                actionLabel: 'إعادة المحاولة'.tr,
                onAction: controller.load,
              );
            }
            if (controller.notifications.isEmpty) return _emptyState();
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: controller.load,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                itemCount: controller.notifications.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  if (index == 0) return _introCard();
                  return _notificationCard(controller.notifications[index - 1]);
                },
              ),
            );
          }),
        ),
      );

  Widget _introCard() => Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.accent],
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.campaign_rounded, color: Colors.white, size: 27),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('مستجدات MangaPlus'.tr, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('ستظهر هنا أخبار التطبيق وإعلاناته المهمة'.tr, style: TextStyle(color: Colors.white.withValues(alpha: .86), height: 1.35, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _notificationCard(AppNotification item) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => controller.markRead(item),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: item.isRead ? AppColors.card : AppColors.primary.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: item.isRead ? AppColors.divider : AppColors.primary.withValues(alpha: .36)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .13), shape: BoxShape.circle),
              child: Icon(Icons.notifications_active_rounded, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textPrimary, fontWeight: item.isRead ? FontWeight.w600 : FontWeight.w800, fontSize: 14))),
                      if (!item.isRead) Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                    ],
                  ),
                  if (item.body.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(item.body, maxLines: 4, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textSecondary, height: 1.4, fontSize: 13)),
                  ],
                  const SizedBox(height: 9),
                  Text(_formatDate(item.createdAt), style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() => BrandState(
        title: 'لا توجد إشعارات بعد'.tr,
        description: 'ستصل إليك هنا أخبار التطبيق وإعلاناته المهمة.'.tr,
        icon: Icons.notifications_none_rounded,
      );

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();
    final difference = now.difference(local);
    if (difference.inMinutes < 1) return 'منذ لحظات'.tr;
    if (difference.inHours < 1) return '${difference.inMinutes} ${'دقيقة'.tr}';
    if (difference.inDays < 1) return '${difference.inHours} ${'ساعة'.tr}';
    if (difference.inDays < 7) return '${difference.inDays} ${'يوم'.tr}';
    return '${local.day}/${local.month}/${local.year}';
  }
}
