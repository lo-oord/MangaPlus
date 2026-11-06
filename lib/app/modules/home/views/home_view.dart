import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/cache/manga_cover_cache_manager.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/core/translations/content_localization.dart';
import 'package:mangaplus/app/data/models/comic.dart';
import 'package:mangaplus/app/modules/home/controllers/home_controller.dart';
import 'package:mangaplus/app/routes/app_pages.dart';
import 'package:mangaplus/app/widgets/custom_card_normal.dart';
import 'package:mangaplus/app/widgets/brand_state.dart';
import 'package:mangaplus/app/widgets/theme_aware_builder.dart';
import 'package:shimmer/shimmer.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return ThemeAwareBuilder(builder: (context) => Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Obx(() {
        final visible = controller.sourcePickerVisible.value;
        return AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0, 1.35),
          duration: const Duration(milliseconds: 340),
          curve: visible ? Curves.easeOutBack : Curves.easeInCubic,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: const Duration(milliseconds: 220),
            child: AnimatedScale(
              scale: visible ? 1 : 0.88,
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              child: IgnorePointer(
                ignoring: !visible,
                child: Tooltip(
                  message: 'اختيار مصدر المحتوى'.tr,
                  child: Material(
                    color: AppColors.primary,
                    elevation: 7,
                    shadowColor: AppColors.primary.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(22),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () => _showSourcePicker(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 9,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.travel_explore_rounded,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 7),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 120),
                              child: Text(
                                controller.selectedSourceName.tr,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
      body: NotificationListener<ScrollNotification>(
        onNotification: controller.handleHomeScroll,
        child: Obx(() {
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
            title: controller.homeLoadFailed.value
                ? 'تعذر تحميل المحتوى'.tr
                : 'لا توجد أعمال حديثة متاحة حالياً'.tr,
            description: controller.homeLoadFailed.value
                ? 'تحقق من اتصالك بالإنترنت ثم حاول مجدداً.'.tr
                : 'ستظهر الأعمال هنا عند توفر تحديثات جديدة.'.tr,
            icon: controller.homeLoadFailed.value
                ? Icons.cloud_off_rounded
                : Icons.auto_stories_rounded,
            actionLabel: 'إعادة المحاولة'.tr,
            onAction: controller.reload,
          );
        }
        return CustomScrollView(
          controller: controller.scrollController,
          slivers: [
            SliverToBoxAdapter(child: _buildHeroImage(context)),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            const KomikCardsSection(),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        );
        }),
      ),
    ));
  }

  void _showSourcePicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final sources = controller.availableSources;
        final height = MediaQuery.sizeOf(sheetContext).height * 0.72;
        return SafeArea(
          top: false,
          child: Container(
            height: height.clamp(360.0, 620.0).toDouble(),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: AppColors.divider.withValues(alpha: 0.7)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(Icons.travel_explore_rounded, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'مصدر العرض'.tr,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'اختر مصدراً لعرض أحدث المحتوى وتصنيفاته'.tr,
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: AppColors.divider.withValues(alpha: 0.7)),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                    itemCount: sources.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 5),
                    itemBuilder: (context, index) {
                      final isAll = index == 0;
                      final source = isAll ? null : sources[index - 1];
                      final id = isAll ? 'all' : source!.id;
                      final name = isAll ? 'كل المصادر'.tr : source!.name;
                      final kindLabel = source?.kind == 'novel'
                          ? 'روايات'.tr
                          : 'مانجا'.tr;
                      final selected = controller.selectedSourceId.value == id;
                      return Material(
                        color: selected
                            ? AppColors.primary.withValues(alpha: 0.10)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(17),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(17),
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            controller.selectSource(id);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? AppColors.primary.withValues(alpha: 0.16)
                                        : AppColors.searchBar,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    isAll ? Icons.auto_awesome_mosaic_rounded : Icons.menu_book_rounded,
                                    color: selected ? AppColors.primary : AppColors.icon,
                                    size: 21,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 14,
                                          fontWeight: selected
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                        ),
                                      ),
                                      if (!isAll)
                                        Text(
                                          kindLabel,
                                          style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (selected)
                                  Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
                        !controller.isGenreLoadingMore.value &&
                        !controller.genreLoadMoreError.value) {
                      controller.loadMoreGenre();
                    }
                    return false;
                  },
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    physics: const ClampingScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 10,
                      mainAxisExtent: 236,
                    ),
                    itemCount: controller.genreComics.length +
                        (controller.isGenreLoadingMore.value ||
                                controller.genreLoadMoreError.value
                            ? 1
                            : 0),
                    itemBuilder: (context, index) {
                      if (index >= controller.genreComics.length) {
                        return _InlinePaginationTile(
                          loading: controller.isGenreLoadingMore.value,
                          title: 'تعذر تحميل بقية أعمال التصنيف'.tr,
                          retry: controller.retryMoreGenre,
                        );
                      }
                      final comic = controller.genreComics[index];
                      return GestureDetector(
                        onTap: () => Get.toNamed(
                          Routes.COMIC_DETAIL,
                          arguments: comic.comicId,
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) => CustomCardNormal(
                            comicId: comic.comicId,
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
            height: 404,
            child: PageView.builder(
              controller: controller.pageController,
              allowImplicitScrolling: true,
              pageSnapping: true,
              physics: const PageScrollPhysics(),
              itemCount: controller.heroComics.length,
              onPageChanged: (value) => controller.currentPage.value = value,
              itemBuilder: (context, index) {
                final comic = controller.heroComics[index];
                return ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: SizedBox(
                    width: double.infinity,
                    height: 404,
                    child: Stack(
                    children: [
                      Positioned.fill(
                        child: CachedNetworkImage(
                          imageUrl: comic['image']!,
                          cacheManager: MangaCoverCacheManager.instance,
                          memCacheWidth: (MediaQuery.sizeOf(context).width *
                                  MediaQuery.devicePixelRatioOf(context))
                              .round(),
                          maxWidthDiskCache: (MediaQuery.sizeOf(context).width *
                                  MediaQuery.devicePixelRatioOf(context) *
                                  1.5)
                              .round(),
                          fadeInDuration: const Duration(milliseconds: 180),
                          httpHeaders: const {
                            'Referer': 'https://olympustaff.com/',
                            'User-Agent':
                                'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/131 Mobile Safari/537.36',
                          },
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          imageBuilder: (context, imageProvider) => Image(
                            image: imageProvider,
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                            filterQuality: FilterQuality.high,
                            gaplessPlayback: true,
                          ),
                          placeholder: (context, url) => Container(
                            color: AppColors.searchBar,
                            alignment: Alignment.center,
                            child: MangaPlusCoverState(
                              message: 'جارٍ تحميل الغلاف'.tr,
                              markSize: 68,
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: AppColors.searchBar,
                            alignment: Alignment.center,
                            child: MangaPlusCoverState(
                              message: 'تعذر تحميل الغلاف'.tr,
                              failed: true,
                              markSize: 68,
                            ),
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
                                Colors.black.withValues(alpha: 0.28),
                                Colors.black.withValues(alpha: 0.02),
                                Colors.black.withValues(alpha: 0.72),
                                Colors.black.withValues(alpha: 0.94),
                              ],
                              stops: const [0.0, 0.25, 0.66, 1.0],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 16,
                        right: 16,
                        child: _heroBadge(Icons.auto_awesome_rounded, 'اختيار اليوم'.tr),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 18,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'الفصل@value'.trParams({
                                  'value': (comic['subtitle'] ?? '').trim().isEmpty
                                      ? 'غير متاح'.tr
                                      : comic['subtitle']!,
                                }),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                comic['title']!.tr,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.start,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 25,
                                  height: 1.18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 7,
                                runSpacing: 7,
                                children: [
                                  _heroBadge(
                                    Icons.star_rounded,
                                    (comic['rating'] ?? '').trim().isEmpty
                                        ? 'غير متاح'.tr
                                        : comic['rating']!,
                                    accent: const Color(0xfff3c45c),
                                  ),
                                  _heroBadge(
                                    Icons.circle,
                                    (comic['status'] ?? '').trim().isEmpty
                                        ? 'غير متاح'.tr
                                        : localizeContentStatus(comic['status']!),
                                    dot: true,
                                  ),
                                  _heroBadge(
                                    Icons.update_rounded,
                                    (comic['releaseDate'] ?? '').trim().isEmpty
                                        ? 'غير متاح'.tr
                                        : comic['releaseDate']!.split('T').first,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: () => Get.toNamed(
                                      Routes.COMIC_DETAIL,
                                      arguments: comic['comicId']),
                                  icon: const Icon(Icons.menu_book_rounded, size: 18),
                                  label: Text('اقرأ الآن'.tr),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
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

  Widget _heroBadge(IconData icon, String text, {Color accent = Colors.white, bool dot = false}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: dot ? 8 : 14, color: accent),
            const SizedBox(width: 5),
            Text(text, style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      );

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
      if (controller.comicData.value.comicsList.isEmpty) {
        return SliverToBoxAdapter(
          child: SizedBox(
            height: 250,
            child: BrandState(
              title: 'لا توجد أعمال حديثة متاحة حالياً'.tr,
              description: 'ستظهر الأعمال هنا عند توفر تحديثات جديدة.'.tr,
              icon: Icons.auto_stories_rounded,
              actionLabel: 'تحديث'.tr,
              onAction: controller.reload,
            ),
          ),
        );
      }
      final comics = controller.comicData.value.comicsList;
      return SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle(context, 'اختيار التصنيف'.tr),
                  const SizedBox(height: 8),
                  _buildGenreChips(context),
                  const SizedBox(height: 12),
                  _buildSectionTitle(context, 'الأحدث'.tr),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, rowIndex) {
                  final firstIndex = rowIndex * 3;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var slot = 0; slot < 3; slot++) ...[
                          if (slot > 0) const SizedBox(width: 8),
                          Expanded(
                            child: firstIndex + slot < comics.length
                                ? _latestCard(comics[firstIndex + slot])
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ],
                    ),
                  );
                },
                childCount: (comics.length + 2) ~/ 3,
                addAutomaticKeepAlives: true,
              ),
            ),
          ),
          if (controller.isLoadingMore.value)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: MangaPlusLoader(size: 42)),
              ),
            ),
          if (controller.loadMoreError.value)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 240,
                child: BrandState(
                  title: 'تعذر تحميل المزيد من الأعمال'.tr,
                  description:
                      'تحقق من اتصالك ثم أعد المحاولة لمتابعة أحدث الفصول.'.tr,
                  icon: Icons.wifi_off_rounded,
                  actionLabel: 'إعادة المحاولة'.tr,
                  onAction: controller.retryNextPage,
                ),
              ),
            ),
        ],
      );
    });
  }

  Widget _latestCard(ComicsList comic) {
    return GestureDetector(
      key: ValueKey<String>('home-${comic.comicId}'),
      onTap: () => Get.toNamed(
        Routes.COMIC_DETAIL,
        arguments: comic.comicId,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => CustomCardNormal(
          comicId: comic.comicId,
          title: comic.title,
          chapter: comic.chapter,
          imageUrl: comic.image,
          type: comic.type,
          releaseDate: comic.latestChapterDate,
          rating: comic.rating,
          status: comic.status ?? '',
          width: constraints.maxWidth,
        ),
      ),
    );
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
            mainAxisExtent: 240,
          ),
          itemCount: terbaruComics.length,
          itemBuilder: (context, index) {
            final comic = terbaruComics[index];
            return GestureDetector(
              onTap: () {
                Get.toNamed(Routes.COMIC_DETAIL, arguments: comic.comicId);
              },
              child: CustomCardNormal(
                comicId: comic.comicId,
                title: comic.title,
                chapter: comic.chapter,
                imageUrl: comic.image,
                type: comic.type,
                releaseDate: comic.latestChapterDate,
                rating: comic.rating,
                status: comic.status ?? '',
              ),
            );
          },
        ),
        if (controller.isLoadingMore.value)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: SizedBox(
              width: 42,
              height: 42,
              child: const MangaPlusLoader(size: 42),
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
        physics: const ClampingScrollPhysics(),
        itemCount: genres.length,
        itemBuilder: (context, index) {
          final genre = genres[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              backgroundColor: AppColors.searchBar,
              side: BorderSide(color: AppColors.divider.withValues(alpha: 0.65)),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              label: Text(
                genre.name,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
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

class _InlinePaginationTile extends StatelessWidget {
  const _InlinePaginationTile({
    required this.loading,
    required this.title,
    required this.retry,
  });

  final bool loading;
  final String title;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: MangaPlusLoader(size: 42));
    return Container(
      decoration: BoxDecoration(
        color: AppColors.searchBar,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.7)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const MangaPlusLogo(size: 36),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextButton.icon(
            onPressed: retry,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 30),
              padding: const EdgeInsets.symmetric(horizontal: 2),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.refresh_rounded, size: 13),
            label: Text(
              'إعادة المحاولة'.tr,
              maxLines: 1,
              style: const TextStyle(fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }
}
