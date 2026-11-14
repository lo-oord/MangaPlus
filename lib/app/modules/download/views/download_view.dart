import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/cache/manga_cover_cache_manager.dart';
import 'package:mangaplus/app/core/theme/app_motion.dart';
import 'package:mangaplus/app/core/theme/app_palette.dart';
import 'package:mangaplus/app/core/theme/design_tokens.dart';
import 'package:mangaplus/app/data/models/download_task.dart';
import 'package:mangaplus/app/modules/download/controllers/download_controller.dart';
import 'package:mangaplus/app/modules/download/download_sections.dart';
import 'package:mangaplus/app/widgets/app_dialogs.dart';
import 'package:mangaplus/app/widgets/brand_state.dart';
import 'package:mangaplus/app/widgets/mangaplus_app_bar.dart';
import 'package:mangaplus/app/widgets/theme_aware_builder.dart';

class DownloadView extends GetView<DownloadController> {
  const DownloadView({super.key});

  @override
  Widget build(BuildContext context) {
    return ThemeAwareBuilder(
      builder: (context) => Scaffold(
        backgroundColor: context.palette.background,
        appBar: MangaPlusAppBar(
          title: 'التحميلات'.tr,
          actions: [
            Obx(
              () => PopupMenuButton<String>(
                tooltip: 'خيارات التحميلات'.tr,
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (value) async {
                  if (value == 'clearRecords') {
                    await controller.clearCompletedRecords();
                  } else if (value == 'deleteFiles') {
                    final confirmed = await AppDialogs.confirm(
                      title: 'حذف ملفات التحميلات المكتملة'.tr,
                      message: 'ستُحذف كل الفصول المحمّلة المكتملة من التخزين '
                          'المحلي. تبقى سجلات المهام، ولن تتأثر أي مهمة نشطة.'.tr,
                      confirmLabel: 'حذف'.tr,
                      destructive: true,
                      icon: Icons.delete_sweep_outlined,
                    );
                    if (confirmed == true) {
                      await controller.deleteCompletedFiles();
                    }
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'clearRecords',
                    child: Text('مسح سجلات المكتملة'.tr),
                  ),
                  PopupMenuItem(
                    value: 'deleteFiles',
                    child: Text('حذف ملفات المكتملة'.tr),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: Obx(() {
          final sections = DownloadSections.from(controller.manager.tasks);
          if (sections.isEmpty) {
            return BrandState(
              title: 'لا توجد مهام تحميل'.tr,
              description: 'ستظهر هنا عمليات التحميل الجارية والمكتملة'.tr,
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _summary(context, sections),
              const SizedBox(height: 14),
              ..._section(
                context,
                title: 'قيد التنزيل'.tr,
                icon: Icons.downloading_rounded,
                tasks: sections.active,
              ),
              ..._section(
                context,
                title: 'قيد الانتظار'.tr,
                icon: Icons.schedule_rounded,
                tasks: sections.queued,
              ),
              ..._section(
                context,
                title: 'فاشلة أو ملغاة'.tr,
                icon: Icons.error_outline_rounded,
                tasks: sections.failed,
              ),
              ..._section(
                context,
                title: 'مكتملة'.tr,
                icon: Icons.check_circle_outline_rounded,
                tasks: sections.completed,
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _summary(BuildContext context, DownloadSections sections) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: AppRadii.mdAll,
        border: Border.all(color: p.border.withValues(alpha: .9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${sections.total} ${'مهمة في القائمة'.tr}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              if (sections.failed.isNotEmpty)
                TextButton(
                  onPressed: controller.retryFailedTasks,
                  child: Text('إعادة الفاشلة'.tr),
                ),
              if (sections.completed.isNotEmpty)
                TextButton(
                  onPressed: controller.clearCompletedRecords,
                  child: Text('مسح السجلات'.tr),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _chip(context, '${sections.active.length} ${'نشط'.tr}'),
              _chip(context, '${sections.queued.length} ${'انتظار'.tr}'),
              _chip(context, '${sections.failed.length} ${'فشل'.tr}'),
              _chip(context, '${sections.completed.length} ${'مكتمل'.tr}'),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'مسح السجلات لا يحذف أي ملف؛ استخدم «حذف الملفات» لحذف '
            'المحتوى من التخزين المحلي.'.tr,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: p.textSecondary,
                  height: 1.45,
                ),
          ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: context.palette.surfaceVariant,
          borderRadius: AppRadii.pillAll,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.palette.textSecondary,
                fontWeight: FontWeight.w700,
              ),
        ),
      );

  List<Widget> _section(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<DownloadTask> tasks,
  }) {
    if (tasks.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(4, 8, 4, 8),
        child: Row(
          children: [
            Icon(icon, size: 16, color: context.palette.icon),
            const SizedBox(width: 6),
            Text(
              title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: context.palette.textSecondary,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(width: 6),
            Text(
              '${tasks.length}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.palette.textDisabled,
                  ),
            ),
          ],
        ),
      ),
      ...tasks.map(
        (task) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _taskCard(context, task),
        ),
      ),
      const SizedBox(height: 4),
    ];
  }

  Widget _taskCard(BuildContext context, DownloadTask task) {
    final percent = (task.progress * 100).round();
    final active = task.status == DownloadTaskStatus.downloading;
    final paused = task.status == DownloadTaskStatus.paused;
    final failed = task.status == DownloadTaskStatus.failed ||
        task.status == DownloadTaskStatus.partiallyCompleted;
    final completed = task.status == DownloadTaskStatus.completed;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.palette.border.withValues(alpha: .9)),
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
                          fadeInDuration: AppMotion.page,
                          memCacheWidth: 174,
                          maxWidthDiskCache: 480,
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
                    Text(
                      task.comicTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.palette.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      task.totalChapters == 1
                          ? task.chapters.first['title'] ?? 'الفصل'.tr
                          : '${task.totalChapters} ${'فصول مطلوبة'.tr}',
                      style: TextStyle(color: context.palette.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_statusLabel(task.status)} • $percent%',
                      style: TextStyle(
                        color: _statusColor(context, task.status),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, color: context.palette.icon),
                onSelected: (value) => _action(context, value, task),
                itemBuilder: (_) => [
                  if (active)
                    PopupMenuItem(value: 'pause', child: Text('إيقاف مؤقت'.tr)),
                  if (paused || task.status == DownloadTaskStatus.queued)
                    PopupMenuItem(value: 'resume', child: Text('استئناف'.tr)),
                  if (failed)
                    PopupMenuItem(value: 'retry', child: Text('إعادة المحاولة'.tr)),
                  PopupMenuItem(value: 'details', child: Text('تفاصيل المهمة'.tr)),
                  if (completed)
                    PopupMenuItem(
                      value: 'deleteFiles',
                      child: Text('حذف الملفات'.tr),
                    ),
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
              value: completed ? 1 : task.progress,
              minHeight: 7,
              backgroundColor: context.palette.divider,
              color: _statusColor(context, task.status),
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Text(
                '${task.completedCount}/${task.totalChapters} ${'مكتمل'.tr}',
                style: TextStyle(
                  color: context.palette.textSecondary,
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              if (task.failedChapterIds.isNotEmpty)
                Text(
                  '${task.failedChapterIds.length} ${'فشل'.tr}',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                ),
            ],
          ),
          if (task.errorMessage != null && failed) ...[
            const SizedBox(height: 6),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                task.errorMessage!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.palette.textSecondary,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _action(
    BuildContext context,
    String action,
    DownloadTask task,
  ) async {
    switch (action) {
      case 'pause':
        await controller.manager.pause(task.id);
      case 'resume':
        await controller.manager.resume(task.id);
      case 'retry':
        await controller.retryTask(task);
      case 'cancel':
        await controller.manager.cancel(task.id);
      case 'remove':
        await controller.deleteTask(task);
      case 'deleteFiles':
        final confirmed = await AppDialogs.confirm(
          title: 'حذف الملفات'.tr,
          message: 'سيُحذف المحتوى المحمّل لهذه المهمة من التخزين المحلي. '
              'لن يتأثر أي عمل آخر.'.tr,
          confirmLabel: 'حذف'.tr,
          destructive: true,
          icon: Icons.delete_outline_rounded,
        );
        if (confirmed == true) await controller.deleteTaskFiles(task);
      case 'details':
        if (!context.mounted) return;
        Get.bottomSheet(
          _details(context, task),
          backgroundColor: context.palette.card,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
        );
    }
  }

  Widget _details(BuildContext context, DownloadTask task) {
    final downloaded = controller.downloadedChapters
        .where((chapter) => chapter.comicId == task.comicId)
        .toList();
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .72,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(18),
          children: [
            Text(
              'تفاصيل المهمة'.tr,
              style: TextStyle(
                color: context.palette.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _statusLabel(task.status),
              style: TextStyle(color: context.palette.textSecondary),
            ),
            const SizedBox(height: 10),
            ...task.chapters.map((chapter) {
              final id = chapter['id'];
              final done = task.completedChapterIds.contains(id);
              final failed = task.failedChapterIds.contains(id);
              final saved = downloaded.where((item) => item.chapterId == id);
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  done
                      ? Icons.check_circle_rounded
                      : failed
                          ? Icons.error_rounded
                          : Icons.downloading_rounded,
                  color: done
                      ? Colors.green
                      : failed
                          ? Colors.redAccent
                          : context.palette.primary,
                ),
                title: Text(
                  chapter['title'] ?? 'الفصل'.tr,
                  style: TextStyle(color: context.palette.textPrimary),
                ),
                subtitle: Text(
                  done
                      ? (saved.isEmpty ? 'مكتمل'.tr : 'محفوظ محليًا'.tr)
                      : failed
                          ? 'فشل'.tr
                          : 'قيد الانتظار'.tr,
                  style: TextStyle(color: context.palette.textSecondary),
                ),
                trailing: saved.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'حذف من التخزين'.tr,
                        icon: const Icon(Icons.delete_outline_rounded, size: 20),
                        onPressed: () async {
                          final confirmed = await AppDialogs.confirm(
                            title: 'حذف الفصل'.tr,
                            message: 'سيُحذف هذا الفصل من التخزين المحلي فقط.'.tr,
                            confirmLabel: 'حذف'.tr,
                            destructive: true,
                            icon: Icons.delete_outline_rounded,
                          );
                          if (confirmed == true) {
                            await controller.deleteChapter(saved.first);
                          }
                        },
                      ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _statusLabel(DownloadTaskStatus status) => {
        DownloadTaskStatus.queued: 'قيد الانتظار'.tr,
        DownloadTaskStatus.downloading: 'جارٍ التحميل'.tr,
        DownloadTaskStatus.paused: 'متوقف مؤقتًا'.tr,
        DownloadTaskStatus.completed: 'مكتمل'.tr,
        DownloadTaskStatus.partiallyCompleted: 'مكتمل جزئيًا'.tr,
        DownloadTaskStatus.failed: 'فشل'.tr,
        DownloadTaskStatus.cancelled: 'ملغى'.tr,
      }[status]!;

  Color _statusColor(BuildContext context, DownloadTaskStatus status) =>
      status == DownloadTaskStatus.failed
          ? Colors.redAccent
          : status == DownloadTaskStatus.partiallyCompleted
              ? Colors.orange
              : status == DownloadTaskStatus.completed
                  ? Colors.green
                  : context.palette.primary;
}
