import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/cache/manga_cover_cache_manager.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/core/translations/content_localization.dart';
import 'package:mangaplus/app/data/models/comic.dart';
import 'package:mangaplus/app/data/services/bookmark_state_service.dart';
import 'package:mangaplus/app/modules/search/controllers/search_controller.dart'
    as search_controller;
import 'package:mangaplus/app/routes/app_pages.dart';
import 'package:mangaplus/app/widgets/brand_state.dart';
import 'package:mangaplus/app/widgets/theme_aware_builder.dart';

class SearchView extends GetView<search_controller.SearchController> {
  const SearchView({super.key});

  @override
  Widget build(BuildContext context) {
    return ThemeAwareBuilder(builder: (context) => Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Text('بحث'.tr),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: controller.textController,
              onChanged: controller.searchComics,
              onSubmitted: controller.searchComics,
              textInputAction: TextInputAction.search,
              style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'ابحث عن المانجا'.tr,
                hintStyle: TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.searchBar,
                prefixIcon: Icon(Icons.search_rounded, color: AppColors.icon),
                suffixIcon: Obx(
                  () => controller.query.value.isNotEmpty
                      ? IconButton(
                          tooltip: 'مسح البحث'.tr,
                          icon: Icon(Icons.close_rounded, color: AppColors.icon),
                          onPressed: controller.clearSearch,
                        )
                      : const SizedBox.shrink(),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: AppColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Obx(() => Wrap(
                  spacing: 8,
                  children: [
                    _filterChoice('all', 'الكل'.tr),
                    _filterChoice('manga', 'مانجا'.tr),
                    _filterChoice('novel', 'رواية'.tr),
                  ],
                )),
          ),
          Expanded(
            child: Obx(() {
              if (controller.query.value.isEmpty) {
                if (controller.isLoadingSuggestions.value &&
                    controller.suggestions.isEmpty) {
                  return BrandState(title: 'جارٍ تحميل المحتوى'.tr, loading: true);
                }
                if (controller.suggestions.isEmpty) {
                  return BrandState(
                    title: 'لا توجد اقتراحات'.tr,
                    actionLabel: 'إعادة المحاولة'.tr,
                    onAction: () {
                      controller.loadSuggestions();
                    },
                  );
                }
                if (controller.visibleSuggestions.isEmpty) {
                  return BrandState(
                    title: 'لا توجد اقتراحات لهذا التصنيف'.tr,
                  );
                }
                return _comicList(
                  title: 'اقتراحات'.tr,
                  items: controller.visibleSuggestions,
                );
              }
              if (controller.isLoading.value && controller.comicsList.isEmpty) {
                return BrandState(title: 'جارٍ البحث'.tr, loading: true);
              }
              if (controller.hasError.value) {
                return BrandState(
                  title: 'تعذر تحميل نتائج البحث'.tr,
                  actionLabel: 'إعادة المحاولة'.tr,
                  onAction: () => controller.searchComics(controller.query.value),
                );
              }
              if (controller.comicsList.isEmpty) {
                return BrandState(title: 'لم يتم العثور على نتائج'.tr);
              }
              return _comicList(
                title: 'النتائج'.tr,
                items: controller.comicsList,
                isLoadingMore: controller.isLoading.value,
              );
            }),
          ),
        ],
      ),
    ));
  }

  Widget _filterChoice(String value, String label) {
    final selected = controller.contentFilter.value == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => controller.setContentFilter(value),
      selectedColor: AppColors.primary.withValues(alpha: 0.18),
      side: BorderSide(
        color: selected ? AppColors.primary : AppColors.divider,
      ),
      labelStyle: TextStyle(
        color: selected ? AppColors.primary : AppColors.textSecondary,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _comicList({
    required String title,
    required List<ComicsList> items,
    bool isLoadingMore = false,
  }) {
    return ListView.separated(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 20),
      itemCount: items.length + 1 + (isLoadingMore ? 1 : 0),
      separatorBuilder: (_, index) => SizedBox(height: index == 0 ? 10 : 9),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${items.length}',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
        }
        if (index == items.length + 1) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(child: MangaPlusLoader(size: 42)),
          );
        }
        return _SearchComicTile(comic: items[index - 1]);
      },
    );
  }
}

class _SearchComicTile extends StatelessWidget {
  const _SearchComicTile({required this.comic});

  final ComicsList comic;

  @override
  Widget build(BuildContext context) {
    final isNovel = const {'novel', 'light novel', 'رواية'}
        .contains(comic.type.trim().toLowerCase());
    final genreText = comic.genres.isNotEmpty
        ? comic.genres.take(3).map(localizeContentGenre).join(' • ')
        : isNovel
            ? ''
            : localizeContentType(comic.type);
    final rawStatus = comic.status?.trim() ?? '';
    final statusText = rawStatus.isEmpty
        ? 'غير محدد'.tr
        : localizeContentStatus(rawStatus);
    final normalizedStatus = statusText.toLowerCase();
    final isOngoing = normalizedStatus == 'مستمر'.tr.toLowerCase() ||
        normalizedStatus == 'ongoing';
    final isCompleted = normalizedStatus == 'مكتمل'.tr.toLowerCase() ||
        normalizedStatus == 'completed';
    final statusIcon = isOngoing
        ? Icons.autorenew_rounded
        : isCompleted
            ? Icons.check_circle_rounded
            : Icons.pause_circle_filled_rounded;
    final statusColor = isOngoing
        ? const Color(0xff35a56a)
        : isCompleted
            ? AppColors.success
            : const Color(0xffd18b34);
    final countText = comic.totalChapters.trim().isEmpty
        ? 'غير محدد'.tr
        : 'عدد الفصول: @value'.trParams({'value': comic.totalChapters});
    final ratingText = comic.rating.trim().isEmpty ? '—' : comic.rating.trim();

    return Card(
      margin: EdgeInsets.zero,
      color: AppColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Get.toNamed(
          Routes.COMIC_DETAIL,
          arguments: comic.comicId,
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: CachedNetworkImage(
                      imageUrl: comic.image,
                      cacheManager: MangaCoverCacheManager.instance,
                      httpHeaders:
                          MangaCoverCacheManager.requestHeadersForWorkUrl(comic.comicId),
                      width: 76,
                      height: 104,
                      memCacheWidth: 228,
                      maxWidthDiskCache: 720,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        width: 76,
                        height: 104,
                        color: AppColors.searchBar,
                        alignment: Alignment.center,
                        child: const MangaPlusLogo(size: 30),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        width: 76,
                        height: 104,
                        color: AppColors.searchBar,
                        alignment: Alignment.center,
                        child: const MangaPlusLogo(size: 30),
                      ),
                    ),
                  ),
                  Obx(() {
                    if (!BookmarkStateService.instance.contains(comic.comicId)) return const SizedBox.shrink();
                    return Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), shape: BoxShape.circle, boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]),
                        child: const Icon(Icons.favorite_rounded, color: Colors.red, size: 17),
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comic.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    if (genreText.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        genreText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (comic.source.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        comic.source,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _SearchMetaPill(
                          icon: Icons.menu_book_rounded,
                          text: countText,
                          color: AppColors.icon,
                        ),
                        _SearchMetaPill(
                          icon: statusIcon,
                          text: statusText,
                          color: statusColor,
                        ),
                        _SearchMetaPill(
                          icon: Icons.star_rounded,
                          text: ratingText,
                          color: const Color(0xffe6a93d),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchMetaPill extends StatelessWidget {
  const _SearchMetaPill({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
