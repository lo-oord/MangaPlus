import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/cache/manga_cover_cache_manager.dart';
import 'package:mangaplus/app/core/navigation/app_navigation.dart';
import 'package:mangaplus/app/core/storage/storage_utils.dart';
import 'package:mangaplus/app/core/theme/app_motion.dart';
import 'package:mangaplus/app/core/theme/app_palette.dart';
import 'package:mangaplus/app/core/theme/design_tokens.dart';
import 'package:mangaplus/app/modules/local_library/controllers/local_library_controller.dart';
import 'package:mangaplus/app/routes/app_pages.dart';
import 'package:mangaplus/app/widgets/app_dialogs.dart';
import 'package:mangaplus/app/widgets/brand_state.dart';
import 'package:mangaplus/app/widgets/mangaplus_app_bar.dart';
import 'package:mangaplus/app/widgets/theme_aware_builder.dart';

class LocalLibraryView extends GetView<LocalLibraryController> {
  const LocalLibraryView({super.key});

  @override
  Widget build(BuildContext context) {
    return ThemeAwareBuilder(
      builder: (context) => Scaffold(
        backgroundColor: context.palette.background,
        appBar: MangaPlusAppBar(
          title: 'التخزين المحلي'.tr,
          actions: [
            IconButton(
              tooltip: 'تحديث'.tr,
              icon: const Icon(Icons.refresh_rounded),
              onPressed: controller.load,
            ),
            IconButton(
              tooltip: 'مسح ذاكرة الصور'.tr,
              icon: const Icon(Icons.cleaning_services_outlined),
              onPressed: () => _confirmClearCache(context),
            ),
            Obx(
              () => IconButton(
                tooltip: controller.isSelectionMode.value
                    ? 'إلغاء التحديد'.tr
                    : 'تحديد'.tr,
                icon: Icon(
                  controller.isSelectionMode.value
                      ? Icons.close_rounded
                      : Icons.checklist_rounded,
                ),
                onPressed: controller.clearSelection,
              ),
            ),
          ],
        ),
        body: Obx(() {
          if (controller.isLoading.value) {
            return BrandState(
              title: 'جارٍ تحميل التخزين المحلي'.tr,
              loading: true,
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _storageOverview(context),
              const SizedBox(height: 16),
              if (controller.groups.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xl),
                  child: BrandState(
                    title: 'لا توجد مانجا محفوظة محليًا'.tr,
                    description:
                        'نزّل فصولًا لتظهر هنا وتقرأها دون اتصال'.tr,
                  ),
                )
              else ...[
                Row(
                  children: [
                    Text(
                      '${controller.groups.length} ${'عمل'.tr} • '
                      '${controller.chapterCount.value} ${'فصل'.tr}',
                      style: TextStyle(color: context.palette.textSecondary),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: controller.selectedComicIds.isEmpty
                          ? null
                          : () => _confirmDelete(context),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: Text('حذف المحدد'.tr),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ...controller.groups.map(
                  (group) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _groupCard(context, group),
                  ),
                ),
              ],
            ],
          );
        }),
      ),
    );
  }

  /// All numbers here are measured: chapter files are summed with their real
  /// sizes and novel text is counted at 2 bytes per UTF-16 code unit. The image
  /// cache row is explicitly labelled as RAM because the cover cache package
  /// does not expose a disk-size API.
  Widget _storageOverview(BuildContext context) {
    final p = context.palette;
    final memoryCache = PaintingBinding.instance.imageCache.currentSizeBytes;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
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
              Icon(Icons.storage_rounded, color: p.primary),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'المساحة المستخدمة'.tr,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              Text(
                formatBytes(controller.totalBytes),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: p.primary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: AppRadii.pillAll,
            child: LinearProgressIndicator(
              value: controller.totalBytes == 0 ? 0 : 1,
              minHeight: 6,
              backgroundColor: p.divider,
              color: p.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _metric(context, 'مانجا', formatBytes(controller.mangaBytes.value)),
              _metric(context, 'روايات', formatBytes(controller.novelBytes.value)),
              _metric(context, 'ذاكرة الصور (RAM)', formatBytes(memoryCache)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'يحذف زر مسح ذاكرة الصور الصور المؤقتة فقط؛ الفصول المحمّلة '
            'تبقى كاملة وقابلة للقراءة دون اتصال.'.tr,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: p.textSecondary,
                  height: 1.45,
                ),
          ),
        ],
      ),
    );
  }

  Widget _metric(BuildContext context, String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: context.palette.surfaceVariant,
          borderRadius: AppRadii.pillAll,
        ),
        child: Text(
          '$label: $value',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.palette.textSecondary,
                fontWeight: FontWeight.w700,
              ),
        ),
      );

  Widget _groupCard(BuildContext context, LocalComicGroup group) {
    final p = context.palette;
    return GestureDetector(
      onLongPress: () => controller.toggleSelection(group.comicId),
      onTap: () {
        if (controller.isSelectionMode.value) {
          controller.toggleSelection(group.comicId);
          return;
        }
        AppNavigation.toNamed(Routes.COMIC_DETAIL, arguments: {
          'comicId': group.comicId,
          'localOnly': true,
          'comicTitle': group.title,
          'coverImage': group.coverImage,
        });
      },
      child: Obx(() {
        final selected = controller.selectedComicIds.contains(group.comicId);
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: selected
                ? p.primary.withValues(alpha: 0.14)
                : p.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? p.primary : p.border.withValues(alpha: .9),
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 76,
                  height: 96,
                  child: group.coverImage.isEmpty
                      ? const MangaPlusLogo(size: 42)
                      : group.coverImage.startsWith('/')
                          ? Image.file(
                              File(group.coverImage),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const MangaPlusLogo(size: 42),
                            )
                          : CachedNetworkImage(
                              imageUrl: group.coverImage,
                              cacheManager: MangaCoverCacheManager.instance,
                              fadeInDuration: AppMotion.page,
                              memCacheWidth: 228,
                              maxWidthDiskCache: 720,
                              fit: BoxFit.cover,
                              placeholder: (_, __) =>
                                  const MangaPlusLogo(size: 42),
                              errorWidget: (_, __, ___) =>
                                  const MangaPlusLogo(size: 42),
                            ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: p.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${group.chapters.length} ${'فصل محفوظ'.tr}',
                      style: TextStyle(color: p.textSecondary),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${'المساحة المستخدمة'.tr}: '
                      '${formatBytes(group.bytes)}',
                      style: TextStyle(
                        color: p.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.chevron_left_rounded,
                color: selected ? p.primary : p.icon,
              ),
            ],
          ),
        );
      }),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await AppDialogs.confirm(
      title: 'حذف الأعمال المحددة'.tr,
      message: 'سيؤدي ذلك إلى حذف جميع الفصول المحلية لهذه الأعمال فقط.'.tr,
      confirmLabel: 'حذف'.tr,
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!context.mounted || !confirmed) return;
    await controller.deleteSelected();
  }

  Future<void> _confirmClearCache(BuildContext context) async {
    final confirmed = await AppDialogs.confirm(
      title: 'مسح ذاكرة الصور'.tr,
      message: 'ستُحذف الصور المؤقتة والأغلفة المخزنة في الذاكرة والقرص. '
          'الفصول المحمّلة لن تُحذف.'.tr,
      confirmLabel: 'مسح'.tr,
      icon: Icons.cleaning_services_outlined,
    );
    if (confirmed == true) await controller.clearImageCaches();
  }
}
