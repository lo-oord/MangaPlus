import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/modules/genre_detail/controllers/genre_detail_controller.dart';
import 'package:mangaplus/app/routes/app_pages.dart';
import 'package:mangaplus/app/widgets/brand_state.dart';
import 'package:mangaplus/app/widgets/theme_aware_builder.dart';
import 'package:mangaplus/app/widgets/custom_card_normal.dart';

class GenreDetailView extends GetView<GenreDetailController> {
  const GenreDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return ThemeAwareBuilder(builder: (context) => Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Obx(() => Text(
              controller.genreTitle.value.isEmpty
                  ? 'التصنيف'.tr
                  : controller.genreTitle.value,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            )),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return BrandState(title: 'جارٍ تحميل التصنيف'.tr, loading: true);
        }
        if (controller.hasError.value && controller.comicsList.isEmpty) {
          return BrandState(
            title: 'تعذر تحميل قصص هذا التصنيف. تحقق من اتصال الإنترنت وحاول مجددًا.'.tr,
            actionLabel: 'إعادة المحاولة'.tr,
            onAction: controller.retry,
          );
        }
        if (controller.comicsList.isEmpty) {
          return BrandState(
            title: 'لا توجد قصص مصورة لهذا التصنيف'.tr,
            description: 'جرّب تحديث الصفحة أو اختر تصنيفاً آخر.'.tr,
            icon: Icons.auto_stories_rounded,
            actionLabel: 'إعادة المحاولة'.tr,
            onAction: controller.retry,
          );
        }
        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.metrics.pixels >=
                    notification.metrics.maxScrollExtent * 0.8 &&
                controller.hasMoreData.value &&
                !controller.isLoadingMore.value &&
                !controller.loadMoreError.value) {
              controller.fetchNextPage(controller.genreFilter.value);
            }
            return false;
          },
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            physics: const ClampingScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 10,
              mainAxisExtent: 236,
            ),
            itemCount: controller.comicsList.length +
                (controller.isLoadingMore.value ||
                        controller.loadMoreError.value
                    ? 1
                    : 0),
            itemBuilder: (context, index) {
              if (index >= controller.comicsList.length) {
                return MangaPlusRetryTile(
                  loading: controller.isLoadingMore.value,
                  title: 'تعذر تحميل بقية أعمال التصنيف'.tr,
                  onRetry: controller.retryNextPage,
                );
              }
              final comic = controller.comicsList[index];
              return GestureDetector(
                onTap: () => Get.toNamed(
                  Routes.COMIC_DETAIL,
                  arguments: comic.comicId,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) => CustomCardNormal(
                    title: comic.title,
                    chapter: comic.chapter,
                    imageUrl: comic.image,
                    type: comic.type,
                    rating: comic.rating,
                    status: comic.status ?? '',
                    width: constraints.maxWidth,
                  ),
                ),
              );
            },
          ),
        );
      }),
    ));
  }
}
