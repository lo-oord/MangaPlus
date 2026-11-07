import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/data/models/app_notification.dart';
import 'package:mangaplus/app/modules/notifications/controllers/notifications_controller.dart';
import 'package:mangaplus/app/widgets/brand_state.dart';
import 'package:mangaplus/app/widgets/mangaplus_app_bar.dart';
import 'package:mangaplus/app/widgets/theme_aware_builder.dart';

class NotificationsView extends GetView<NotificationsController> {
  const NotificationsView({super.key});

  @override
  Widget build(BuildContext context) => ThemeAwareBuilder(
        builder: (context) => Scaffold(
          backgroundColor: AppColors.background,
          appBar: MangaPlusAppBar(title: 'الإشعارات'.tr),
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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                itemCount: controller.notifications.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) =>
                    _notificationCard(controller.notifications[index]),
              ),
            );
          }),
        ),
      );

  Widget _notificationCard(AppNotification item) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => controller.openNotification(item),
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
            ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: SizedBox(
                width: 48,
                height: 60,
                child: item.imageUrl.trim().isEmpty
                    ? Container(
                        color: AppColors.primary.withValues(alpha: .13),
                        child: Icon(Icons.notifications_active_rounded, color: AppColors.primary, size: 22),
                      )
                    : CachedNetworkImage(
                        imageUrl: item.imageUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          color: AppColors.primary.withValues(alpha: .13),
                          child: Icon(Icons.notifications_active_rounded, color: AppColors.primary, size: 22),
                        ),
                      ),
              ),
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
