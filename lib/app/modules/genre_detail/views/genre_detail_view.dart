import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/modules/genre_detail/controllers/genre_detail_controller.dart';
import 'package:mangaplus/app/routes/app_pages.dart';
import 'package:mangaplus/app/widgets/brand_state.dart';
import 'package:mangaplus/app/widgets/theme_aware_builder.dart';
import 'package:mangaplus/app/widgets/custom_card_normal.dart';
import 'package:mangaplus/app/widgets/manga_shimmer.dart';
import 'package:mangaplus/app/widgets/staggered_entrance.dart';

class GenreDetailView extends GetView<GenreDetailController> {
  const GenreDetailView({super.key});

  Widget _buildLoadingSkeleton() {
    return MangaShimmer(
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        physics: const ClampingScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 10,
          mainAxisExtent: 236,
        ),
        itemCount: 9,
        itemBuilder: (context, index) => _buildCardSkeleton(context),
      ),
    );
  }

  Widget _buildCardSkeleton(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MangaShimmer.shape(
            width: constraints.maxWidth,
            height: 150,
            borderRadius: BorderRadius.circular(12),
          ),
          const SizedBox(height: 7),
          MangaShimmer.shape(
            width: constraints.maxWidth * 0.82,
            height: 12,
            radius: 5,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              MangaShimmer.shape(width: 34, height: 10, radius: 5),
              const SizedBox(width: 7),
              MangaShimmer.shape(
                width: constraints.maxWidth * 0.45,
                height: 10,
                radius: 5,
              ),
            ],
          ),
        ],
      ),
    );
  }

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
        if (controller.isLoading.value && controller.comicsList.isEmpty) {
          return _buildLoadingSkeleton();
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
          );
        }
        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.metrics.pixels >=
                    notification.metrics.maxScrollExtent * 0.8 &&
                controller.hasMoreData.value &&
                !controller.isLoadingMore.value) {
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
                (controller.isLoadingMore.value ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= controller.comicsList.length) {
                return MangaShimmer(
                  child: _buildCardSkeleton(context),
                );
              }
              final comic = controller.comicsList[index];
              return StaggeredEntrance(
                key: ValueKey('genre-${comic.comicId}'),
                index: index,
                child: GestureDetector(
                  onTap: () => Get.toNamed(
                    Routes.COMIC_DETAIL,
                    arguments: comic.comicId,
                  ),
                  child: CustomCardNormal(
                    key: ValueKey(comic.comicId),
                  title: comic.title,
                  chapter: comic.chapter,
                  imageUrl: comic.image,
                  type: comic.type,
                  rating: comic.rating,
                  status: comic.status ?? '',
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
