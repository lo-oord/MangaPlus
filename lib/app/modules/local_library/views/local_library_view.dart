import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/modules/local_library/controllers/local_library_controller.dart';
import 'package:mangaplus/app/routes/app_pages.dart';
import 'package:mangaplus/app/widgets/brand_state.dart';

class LocalLibraryView extends GetView<LocalLibraryController> {
  const LocalLibraryView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Text('التخزين المحلي'.tr),
        actions: [
          Obx(() => IconButton(
                tooltip: controller.isSelectionMode.value
                    ? 'إلغاء التحديد'.tr
                    : 'تحديد'.tr,
                icon: Icon(controller.isSelectionMode.value
                    ? Icons.close_rounded
                    : Icons.checklist_rounded),
                onPressed: controller.clearSelection,
              )),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return BrandState(title: 'جارٍ تحميل التخزين المحلي'.tr, loading: true);
        }
        if (controller.groups.isEmpty) {
          return BrandState(
            title: 'لا توجد مانجا محفوظة محليًا'.tr,
            subtitle: 'نزّل فصولًا لتظهر هنا وتقرأها دون اتصال'.tr,
          );
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
              child: Row(
                children: [
                  Text('${controller.groups.length} ${'مانجا'.tr}',
                      style: TextStyle(color: AppColors.textSecondary)),
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
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: controller.groups.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, index) => _groupCard(controller.groups[index]),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _groupCard(LocalComicGroup group) {
    return GestureDetector(
      onLongPress: () => controller.toggleSelection(group.comicId),
      onTap: () {
        if (controller.isSelectionMode.value) {
          controller.toggleSelection(group.comicId);
          return;
        }
        Get.toNamed(Routes.COMIC_DETAIL, arguments: {
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
                ? AppColors.primary.withValues(alpha: 0.14)
                : AppColors.searchBar,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.divider,
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
                          ? Image.file(File(group.coverImage), fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const MangaPlusLogo(size: 42))
                          : Image.network(group.coverImage,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const MangaPlusLogo(size: 42)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text('${group.chapters.length} ${'فصل محفوظ'.tr}',
                        style: TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 5),
                    Text('${'المساحة المستخدمة'.tr}: ${group.sizeLabel}',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.chevron_left_rounded,
                color: selected ? AppColors.primary : AppColors.icon,
              ),
            ],
          ),
        );
      }),
    );
  }

  void _confirmDelete(BuildContext context) {
    Get.dialog(AlertDialog(
      title: Text('حذف الأعمال المحددة'.tr),
      content: Text('سيؤدي ذلك إلى حذف جميع الفصول المحلية لهذه الأعمال فقط.'.tr),
      actions: [
        TextButton(onPressed: Get.back, child: Text('إلغاء'.tr)),
        FilledButton(
          onPressed: () {
            Get.back();
            controller.deleteSelected();
          },
          child: Text('حذف'.tr),
        ),
      ],
    ));
  }
}
