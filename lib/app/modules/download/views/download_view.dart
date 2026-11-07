import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/cache/manga_cover_cache_manager.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/data/models/download_task.dart';
import 'package:mangaplus/app/modules/download/controllers/download_controller.dart';
import 'package:mangaplus/app/widgets/brand_state.dart';
import 'package:mangaplus/app/widgets/mangaplus_app_bar.dart';
import 'package:mangaplus/app/widgets/theme_aware_builder.dart';

class DownloadView extends GetView<DownloadController> {
  const DownloadView({super.key});

  @override
  Widget build(BuildContext context) {
    return ThemeAwareBuilder(builder: (context) => Scaffold(
      backgroundColor: AppColors.background,
      appBar: MangaPlusAppBar(title: 'التحميلات'.tr),
      body: Obx(() {
        final tasks = controller.manager.tasks;
        if (tasks.isEmpty) {
          return BrandState(
            title: 'لا توجد مهام تحميل'.tr,
            description: 'ستظهر هنا عمليات التحميل الجارية والمكتملة'.tr,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: tasks.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, index) => _taskCard(tasks[index]),
        );
      }),
    ));
  }

  Widget _taskCard(DownloadTask task) {
    final percent = (task.progress * 100).round();
    final active = task.status == DownloadTaskStatus.downloading;
    final paused = task.status == DownloadTaskStatus.paused;
    final failed = task.status == DownloadTaskStatus.failed ||
        task.status == DownloadTaskStatus.partiallyCompleted;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.searchBar,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 58,
                  height: 76,
                  child: task.coverImage.isEmpty
                      ? const MangaPlusLogo(size: 34)
                      : CachedNetworkImage(
                          imageUrl: task.coverImage,
                          cacheManager: MangaCoverCacheManager.instance,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              const MangaPlusLogo(size: 34),
                          errorWidget: (_, __, ___) =>
                              const MangaPlusLogo(size: 34),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task.comicTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 5),
                    Text(
                      task.totalChapters == 1
                          ? task.chapters.first['title'] ?? 'الفصل'.tr
                          : '${task.totalChapters} ${'فصول مطلوبة'.tr}',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Text('${_statusLabel(task.status)} • $percent%',
                        style: TextStyle(
                            color: _statusColor(task.status),
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, color: AppColors.icon),
                onSelected: (value) => _action(value, task),
                itemBuilder: (_) => [
                  if (active)
                    PopupMenuItem(value: 'pause', child: Text('إيقاف مؤقت'.tr)),
                  if (paused || task.status == DownloadTaskStatus.queued)
                    PopupMenuItem(value: 'resume', child: Text('استئناف'.tr)),
                  if (failed)
                    PopupMenuItem(value: 'retry', child: Text('إعادة المحاولة'.tr)),
                  PopupMenuItem(value: 'details', child: Text('تفاصيل المهمة'.tr)),
                  if (task.status != DownloadTaskStatus.completed &&
                      task.status != DownloadTaskStatus.cancelled)
                    PopupMenuItem(value: 'cancel', child: Text('إلغاء'.tr)),
                  PopupMenuItem(value: 'remove', child: Text('حذف السجل'.tr)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: task.status == DownloadTaskStatus.completed
                  ? 1
                  : task.progress,
              minHeight: 7,
              backgroundColor: AppColors.divider,
              color: _statusColor(task.status),
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Text('${task.completedCount}/${task.totalChapters} ${'مكتمل'.tr}',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              const Spacer(),
              if (task.failedChapterIds.isNotEmpty)
                Text('${task.failedChapterIds.length} ${'فشل'.tr}',
                    style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  void _action(String action, DownloadTask task) {
    switch (action) {
      case 'pause':
        controller.manager.pause(task.id);
        break;
      case 'resume':
        controller.manager.resume(task.id);
        break;
      case 'retry':
        controller.retryTask(task);
        break;
      case 'cancel':
        controller.manager.cancel(task.id);
        break;
      case 'remove':
        controller.deleteTask(task);
        break;
      case 'details':
        Get.bottomSheet(_details(task), backgroundColor: AppColors.card,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24))));
        break;
    }
  }

  Widget _details(DownloadTask task) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('تفاصيل المهمة'.tr, style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              ...task.chapters.map((chapter) {
                final id = chapter['id'];
                final done = task.completedChapterIds.contains(id);
                final failed = task.failedChapterIds.contains(id);
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(done ? Icons.check_circle_rounded : failed ? Icons.error_rounded : Icons.downloading_rounded,
                      color: done ? Colors.green : failed ? Colors.redAccent : AppColors.primary),
                  title: Text(chapter['title'] ?? 'الفصل'.tr, style: TextStyle(color: AppColors.textPrimary)),
                  subtitle: Text(done ? 'مكتمل'.tr : failed ? 'فشل'.tr : 'قيد الانتظار'.tr,
                      style: TextStyle(color: AppColors.textSecondary)),
                );
              }),
            ],
          ),
        ),
      );

  String _statusLabel(DownloadTaskStatus status) => {
        DownloadTaskStatus.queued: 'قيد الانتظار'.tr,
        DownloadTaskStatus.downloading: 'جارٍ التحميل'.tr,
        DownloadTaskStatus.paused: 'متوقف مؤقتًا'.tr,
        DownloadTaskStatus.completed: 'مكتمل'.tr,
        DownloadTaskStatus.partiallyCompleted: 'مكتمل جزئيًا'.tr,
        DownloadTaskStatus.failed: 'فشل'.tr,
        DownloadTaskStatus.cancelled: 'ملغى'.tr,
      }[status]!;

  Color _statusColor(DownloadTaskStatus status) => status == DownloadTaskStatus.failed
      ? Colors.redAccent
      : status == DownloadTaskStatus.partiallyCompleted
          ? Colors.orange
          : status == DownloadTaskStatus.completed
              ? Colors.green
              : AppColors.primary;
}
