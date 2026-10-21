import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/modules/chapter/controllers/chapter_controller.dart';
import 'package:mangaplus/app/routes/app_pages.dart';
import 'package:mangaplus/app/widgets/brand_state.dart';

class ChapterView extends GetView<ChapterController> {
  const ChapterView({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final images = controller.chapterData.value.chapter.images;
      if (images.isNotEmpty && !controller.isOffline.value) {
        _preloadImages(context, images);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          _buildContent(),
          _buildFloatingNavigation(),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Obx(() {
      if (controller.isLoading.value) {
        return BrandState(title: 'جارٍ تحميل الفصل'.tr, loading: true);
      }
      if (controller.hasError.value) {
        return BrandState(
          title: 'تعذر تحميل الفصل'.tr,
          actionLabel: 'إعادة المحاولة'.tr,
          onAction: () => controller.fetchChapter(controller.chapterId),
        );
      }
      final chapter = controller.chapterData.value.chapter;
      if (chapter.images.isEmpty) {
        return BrandState(
          title: 'لا توجد صور متاحة'.tr,
          actionLabel: 'إعادة المحاولة'.tr,
          onAction: () => controller.fetchChapter(controller.chapterId),
        );
      }
      return GestureDetector(
        onTap: controller.toggleNavigationVisibility,
        behavior: HitTestBehavior.opaque,
        child: ListView.builder(
          cacheExtent: 1000,
          itemCount: chapter.images.length,
          itemBuilder: (context, index) => _buildImage(chapter.images[index]),
        ),
      );
    });
  }

  Widget _buildFloatingNavigation() {
    return Obx(() {
      if (!controller.showNavigation.value) return const SizedBox.shrink();
      final chapter = controller.chapterData.value.chapter;
      final canNavigate = !controller.isOffline.value;
      return Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        child: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Container(
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.card.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppColors.divider),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.24),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'الفصل السابق'.tr,
                  icon: const Icon(Icons.chevron_left, size: 30),
                  color: chapter.previousChapter.isNotEmpty && canNavigate
                      ? AppColors.primary
                      : AppColors.icon.withValues(alpha: 0.35),
                  onPressed: chapter.previousChapter.isEmpty || !canNavigate
                      ? null
                      : () => controller.navigateToChapter(chapter.previousChapter),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      chapter.title.isNotEmpty ? chapter.title : 'الفصل'.tr,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'الفصل التالي'.tr,
                  icon: const Icon(Icons.chevron_right, size: 30),
                  color: chapter.nextChapter != null && canNavigate
                      ? AppColors.primary
                      : AppColors.icon.withValues(alpha: 0.35),
                  onPressed: chapter.nextChapter == null || !canNavigate
                      ? null
                      : () => controller.navigateToChapter(chapter.nextChapter),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildImage(String imageUrl) {
    return Container(
      width: double.infinity,
      color: Colors.black,
      child: Obx(
        () => controller.isOffline.value
            ? Image.file(
                File(imageUrl),
                width: double.infinity,
                fit: BoxFit.fitWidth,
                filterQuality: FilterQuality.medium,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(Icons.broken_image_outlined, color: Colors.white70),
                ),
              )
            : CachedNetworkImage(
                imageUrl: imageUrl,
                httpHeaders: const {
                  'Referer': 'https://olympustaff.com/',
                  'User-Agent':
                      'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/131 Mobile Safari/537.36',
                },
                imageBuilder: (context, imageProvider) => Image(
                  image: imageProvider,
                  width: double.infinity,
                  fit: BoxFit.fitWidth,
                  filterQuality: FilterQuality.medium,
                  gaplessPlayback: true,
                ),
                placeholder: (context, url) => SizedBox(
                  width: double.infinity,
                  height: MediaQuery.sizeOf(context).height * 0.68,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const MangaPlusLogo(size: 48),
                      const SizedBox(height: 12),
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      ),
                    ],
                  ),
                ),
                errorWidget: (context, url, error) => SizedBox(
                  width: double.infinity,
                  height: MediaQuery.sizeOf(context).height * 0.68,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.broken_image_outlined,
                        size: 44,
                        color: Colors.white70,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'تعذر تحميل الصورة'.tr,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      TextButton.icon(
                        onPressed: () => controller.fetchChapter(controller.chapterId),
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text('إعادة المحاولة'.tr),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> _preloadImages(
    BuildContext context,
    List<String> imageUrls,
  ) async {
    for (final url in imageUrls.take(3)) {
      try {
        await precacheImage(
          CachedNetworkImageProvider(
            url,
            headers: const {
              'Referer': 'https://olympustaff.com/',
              'User-Agent':
                  'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/131 Mobile Safari/537.36',
            },
          ),
          context,
        );
      } catch (error) {
        debugPrint('Unable to preload Team X page: $error');
      }
    }
  }
}
