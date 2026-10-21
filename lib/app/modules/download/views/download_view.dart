import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/modules/download/controllers/download_controller.dart';
import 'package:mangaplus/app/routes/app_pages.dart';
import 'package:mangaplus/app/widgets/brand_state.dart';

class DownloadView extends GetView<DownloadController> {
  const DownloadView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
          title: Text(
          'التنزيلات'.tr,
          style: TextStyle(
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return BrandState(title: 'جارٍ تحميل التنزيلات'.tr, loading: true);
        }
        if (controller.downloadedChapters.isEmpty) {
          return BrandState(
            title: 'لا توجد فصول منزّلة'.tr,
            description: 'نزّل الفصول من تفاصيل الكوميكس لقراءتها دون اتصال'.tr,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemCount: controller.downloadedChapters.length,
          itemBuilder: (context, index) {
            final chapter = controller.downloadedChapters[index];
            return Card(
              margin: EdgeInsets.zero,
              color: AppColors.searchBar,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 0),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    chapter.coverImage,
                    width: 45,
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const MangaPlusLogo(size: 32),
                  ),
                ),
                title: Text(
                  chapter.comicTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  chapter.chapterTitle.replaceAll(RegExp(r'\s+'), ' ').trim(),
                  style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.66)),
                ),
                trailing: IconButton(
                  icon: Icon(Icons.delete, color: AppColors.textSecondary.withValues(alpha: 0.66)),
                  onPressed: () {
                    Get.defaultDialog(
                      title: 'حذف الفصل'.tr,
                      content: Text(
                        'هل أنت متأكد من حذف الفصل @chapterTitle؟'.trParams(
                          {'chapterTitle': chapter.chapterTitle},
                        ),
                      ),
                      confirm: TextButton(
                        onPressed: () {
                          controller.deleteChapter(chapter);
                          Get.back();
                        },
                        child: Text('حذف'.tr),
                      ),
                      cancel: TextButton(
                        onPressed: () => Get.back(),
                        child: Text('إلغاء'.tr),
                      ),
                    );
                  },
                ),
                onTap: () {
                  Get.toNamed(Routes.CHAPTER, arguments: {
                    'chapterId': chapter.chapterId,
                    'comicId': chapter.comicId,
                    'comicTitle': chapter.comicTitle,
                  });
                },
              ),
            );
          },
        );
      }),
    );
  }
}
