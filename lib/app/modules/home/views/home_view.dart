import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/modules/home/controllers/home_controller.dart';
import 'package:mangaplus/app/routes/app_pages.dart';
import 'package:mangaplus/app/widgets/custom_card_normal.dart';
import 'package:mangaplus/app/widgets/brand_state.dart';
import 'package:shimmer/shimmer.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Obx(() {
        if (controller.showGenrePage.value) return _buildInlineGenrePage();
        if (controller.isLoading.value) {
          return BrandState(
            title: 'جارٍ تحميل المحتوى'.tr,
            loading: true,
          );
        }
        final hasContent = controller.heroComics.isNotEmpty ||
            controller.comicData.value.comicsList.isNotEmpty;
        if (!hasContent) {
          return BrandState(
            title: 'تعذر تحميل المحتوى'.tr,
            actionLabel: 'إعادة المحاولة'.tr,
            onAction: controller.reload,
          );
        }
        return SingleChildScrollView(
          controller: controller.scrollController,
          child: Column(
            children: [
              _buildHeroImage(context),
              const SizedBox(height: 20),
              const KomikCardsSection(),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildInlineGenrePage() => SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'عودة'.tr,
                    onPressed: controller.closeGenre,
                    icon: Icon(Icons.arrow_back_rounded, color: AppColors.icon),
                  ),
                  Expanded(
                    child: Obx(
                      () => Text(
                        controller.selectedGenreName.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Obx(() {
                if (controller.isGenreLoading.value) {
                  return BrandState(
                    title: 'جارٍ تحميل التصنيف'.tr,
                    loading: true,
                  );
                }
                if (controller.genreHasError.value &&
                    controller.genreComics.isEmpty) {
                  return BrandState(
                    title: 'تعذر تحميل التصنيفات'.tr,
                    actionLabel: 'إعادة المحاولة'.tr,
                    onAction: () => controller.openGenre(
                      controller.selectedGenreFilter.value,
                      controller.selectedGenreName.value,
                    ),
                  );
                }
                if (controller.genreComics.isEmpty) {
                  return BrandState(
                    title: 'لا توجد قصص مصورة لهذا التصنيف'.tr,
                  );
                }
                return NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification.metrics.extentAfter < 500 &&
                        controller.genreHasMore.value &&
                        !controller.isGenreLoadingMore.value) {
                      controller.loadMoreGenre();
                    }
                    return false;
                  },
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    physics: const BouncingScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 10,
                      mainAxisExtent: 210,
                    ),
                    itemCount: controller.genreComics.length +
                        (controller.isGenreLoadingMore.value ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= controller.genreComics.length) {
                        return Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        );
                      }
                      final comic = controller.genreComics[index];
                      return GestureDetector(
                        onTap: () => Get.toNamed(
                          Routes.COMIC_DETAIL,
                          arguments: comic.comicId,
                        ),
                        child: CustomCardNormal(
                          title: comic.title,
                          chapter: comic.chapter,
                          imageUrl: comic.image,
                          type: comic.type,
                        ),
                      );
                    },
                  ),
                );
              }),
            ),
          ],
        ),
      );

  Widget _buildHeroImage(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value) {
        return BrandState(title: 'جارٍ تحميل المحتوى'.tr, loading: true);
      }
      if (controller.heroComics.isEmpty) return const SizedBox.shrink();
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 374,
            child: PageView.builder(
              controller: controller.pageController,
              itemCount: controller.heroComics.length,
              onPageChanged: (value) => controller.currentPage.value = value,
              itemBuilder: (context, index) {
                final comic = controller.heroComics[index];
                return ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(28),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 374,
                    child: Stack(
                    children: [
                      Positioned.fill(
                        child: CachedNetworkImage(
                          imageUrl: comic['image']!,
                          httpHeaders: const {
                            'Referer': 'https://olympustaff.com/',
                            'User-Agent':
                                'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/131 Mobile Safari/537.36',
                          },
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          placeholder: (context, url) => Container(
                            color: AppColors.searchBar,
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: AppColors.searchBar,
                            child: const Center(child: MangaPlusLogo(size: 68)),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.12),
                                Colors.transparent,
                                AppColors.background.withValues(alpha: 0.72),
                                AppColors.background,
                              ],
                              stops: const [0.0, 0.28, 0.72, 1.0],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 16,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.88),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'اختيار اليوم'.tr,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              if ((comic['subtitle'] ?? '').trim().isNotEmpty)
                                Text(
                                  comic['subtitle']!.tr.toUpperCase(),
                                  style: TextStyle(
                                    color: AppColors.textSecondary.withValues(alpha: 0.8),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              Text(
                                comic['title']!.tr,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: 184,
                                child: OutlinedButton(
                                  onPressed: () => Get.toNamed(
                                      Routes.COMIC_DETAIL,
                                      arguments: comic['comicId']),
                                  style: OutlinedButton.styleFrom(),
                                  child: Text(
                                    'اقرأ الآن'.tr,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 25),
          SmoothPageIndicator(
            controller: controller.pageController,
            count: controller.heroComics.length,
            effect: SlideEffect(
              spacing: 8.0,
              radius: 30,
              dotWidth: 6,
              dotHeight: 6,
              paintStyle: PaintingStyle.fill,
              strokeWidth: 1.5,
              dotColor: Colors.grey.shade800,
              activeDotColor: Colors.grey,
            ),
          ),
        ],
      );
    });
  }

  Widget _buildHeroImageSkeleton() {
    return Shimmer.fromColors(
      direction: ShimmerDirection.ltr,
      baseColor: AppColors.searchBar,
      highlightColor: AppColors.searchBar,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            height: 390,
            color: AppColors.searchBar,
          ),
          const SizedBox(height: 25),
          Container(
            height: 6,
            width: 100,
            color: AppColors.searchBar,
          ),
        ],
      ),
    );
  }
}

class KomikCardsSection extends GetView<HomeController> {
  const KomikCardsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value) {
        return _buildLoadingSkeleton();
      }
      if (controller.comicData.value.comicsList.isEmpty) {
        return Center(
            child: Text('لا توجد قصص مصورة متاحة'.tr,
                style: TextStyle(color: AppColors.textPrimary)));
      }
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(context, "اختيار التصنيف".tr),
            const SizedBox(height: 8),
            _buildGenreChips(context),
            const SizedBox(height: 12),
            _buildSectionTitle(context, "الأحدث".tr),
            const SizedBox(height: 8),
            _buildTerbaruGrid(context),
            const SizedBox(height: 12),
          ],
        ),
      );
    });
  }

  Widget _buildLoadingSkeleton() {
    return Shimmer.fromColors(
      baseColor: AppColors.searchBar,
      highlightColor: AppColors.searchBar,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // History section skeleton
              Container(
                height: 140,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),

              // Popular section skeleton
              Container(
                height: 20,
                width: 150,
                color: AppColors.textPrimary,
                margin: const EdgeInsets.only(bottom: 8),
              ),
              const SizedBox(height: 8),

              SizedBox(
                height: 184,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 5,
                  itemBuilder: (context, index) {
                    return Container(
                      width: 120,
                      margin: const EdgeInsets.only(right: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 150,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 12,
                            width: 100,
                            color: AppColors.textPrimary,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: 10,
                            width: 60,
                            color: AppColors.textPrimary,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              // Genre chips skeleton
              Container(
                height: 20,
                width: 150,
                color: AppColors.textPrimary,
                margin: const EdgeInsets.only(bottom: 8),
              ),
              const SizedBox(height: 8),

              Container(
                height: 36,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 6,
                  itemBuilder: (context, index) {
                    return Container(
                      width: 80,
                      height: 36,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: AppColors.textPrimary,
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              // Latest section skeleton
              Container(
                height: 20,
                width: 150,
                color: AppColors.textPrimary,
                margin: const EdgeInsets.only(bottom: 8),
              ),
              const SizedBox(height: 8),

              GridView.builder(
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  mainAxisExtent: 200,
                ),
                itemCount: 12,
                itemBuilder: (context, index) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 144,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 12,
                        color: AppColors.textPrimary,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 10,
                        width: 60,
                        color: AppColors.textPrimary,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTerbaruGrid(BuildContext context) {
    final terbaruComics = controller.comicData.value.comicsList;
    return Column(
      children: [
        GridView.builder(
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.75,
            crossAxisSpacing: 8,
            mainAxisExtent: 216,
          ),
          itemCount: terbaruComics.length,
          itemBuilder: (context, index) {
            final comic = terbaruComics[index];
            return GestureDetector(
              onTap: () {
                Get.toNamed(Routes.COMIC_DETAIL, arguments: comic.comicId);
              },
              child: CustomCardNormal(
                title: comic.title,
                chapter: comic.chapter,
                imageUrl: comic.image,
                type: comic.type,
                releaseDate: comic.latestChapterDate,
              ),
            );
          },
        ),
        if (controller.isLoadingMore.value)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: AppColors.primary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGenreChips(BuildContext context) {
    final genres = controller.genreController.genreData.value.genres;

    return Container(
      height: 36,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: genres.length,
        itemBuilder: (context, index) {
          final genre = genres[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              backgroundColor: AppColors.searchBar,
              side: BorderSide.none,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              label: Text(
                genre.name,
                style: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.66),
                  fontSize: 12,
                ),
              ),
              onPressed: () => controller.openGenre(
                genre.link.isNotEmpty ? genre.link : genre.name,
                genre.name,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
