import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/data/models/bookmark.dart';
import 'package:mangaplus/app/modules/bookmark/controllers/bookmark_controller.dart';
import 'package:mangaplus/app/routes/app_pages.dart';
import 'package:mangaplus/app/widgets/brand_state.dart';
import 'package:mangaplus/app/widgets/custom_card_normal.dart';
import 'package:mangaplus/app/widgets/theme_aware_builder.dart';

class BookmarkView extends GetView<BookmarkController> {
  const BookmarkView({super.key});

  @override
  Widget build(BuildContext context) {
    return ThemeAwareBuilder(
      builder: (context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text('الإشارات المرجعية'.tr),
          centerTitle: true,
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          actions: [
            Obx(() {
              final selectedOrder = controller.sortOrder.value;
              return PopupMenuButton<BookmarkSortOrder>(
                initialValue: selectedOrder,
                tooltip: 'ترتيب'.tr,
                icon: Icon(Icons.sort_rounded, color: AppColors.textPrimary),
                onSelected: controller.setSortOrder,
                itemBuilder: (context) => [
                  PopupMenuItem(value: BookmarkSortOrder.newest, child: Text('الأحدث إضافة'.tr)),
                  PopupMenuItem(value: BookmarkSortOrder.oldest, child: Text('الأقدم إضافة'.tr)),
                  PopupMenuItem(value: BookmarkSortOrder.titleAscending, child: Text('الاسم: أ إلى ي'.tr)),
                  PopupMenuItem(value: BookmarkSortOrder.titleDescending, child: Text('الاسم: ي إلى أ'.tr)),
                  PopupMenuItem(value: BookmarkSortOrder.ratingHighest, child: Text('أعلى تقييم'.tr)),
                  PopupMenuItem(value: BookmarkSortOrder.ratingLowest, child: Text('أقل تقييم'.tr)),
                ],
              );
            }),
          ],
        ),
        body: Obx(() {
          if (controller.isLoading.value) {
            return BrandState(title: 'جارٍ تحميل المفضلة'.tr, loading: true);
          }
          if (controller.bookmarks.isEmpty) return _buildEmptyBookmark();
          final bookmarks = controller.visibleBookmarks;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  onChanged: controller.setSearchQuery,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'بحث في المفضلة'.tr,
                    prefixIcon: Icon(Icons.search_rounded, color: AppColors.icon),
                    filled: true,
                    fillColor: AppColors.searchBar,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: AppColors.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 42,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  children: [
                    _typeFilterChip(BookmarkTypeFilter.all, 'الكل'.tr),
                    const SizedBox(width: 8),
                    _typeFilterChip(BookmarkTypeFilter.manga, 'مانجا'.tr),
                    const SizedBox(width: 8),
                    _typeFilterChip(BookmarkTypeFilter.novel, 'روايات'.tr),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 9, 18, 2),
                child: Row(
                  children: [
                    Icon(Icons.favorite_rounded, size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      '${bookmarks.length}',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: bookmarks.isEmpty
                    ? BrandState(title: 'لا توجد نتائج'.tr)
                    : _buildBookmarkGrid(context, bookmarks),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _typeFilterChip(BookmarkTypeFilter value, String label) => Obx(() {
        final selected = controller.typeFilter.value == value;
        return ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => controller.setTypeFilter(value),
          showCheckmark: false,
          labelStyle: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          backgroundColor: AppColors.searchBar,
          selectedColor: AppColors.primary,
          side: BorderSide(color: selected ? AppColors.primary : AppColors.divider),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 10),
        );
      });

  Widget _buildEmptyBookmark() => BrandState(title: 'لا توجد إشارات مرجعية بعد'.tr);

  Widget _buildBookmarkGrid(BuildContext context, List<BookmarkItem> bookmarks) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 800 ? 6 : (width >= 600 ? 4 : (width >= 390 ? 3 : 2));
    const crossAxisSpacing = 16.0;
    final cellWidth = (width - 28 - (columns - 1) * crossAxisSpacing) / columns;
    final cardWidth = cellWidth.clamp(116.0, 160.0).toDouble();
    final cardHeight = cardWidth * 1.25;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: 20,
        mainAxisExtent: cardHeight + 92,
      ),
      itemCount: bookmarks.length,
      itemBuilder: (context, index) {
        final bookmark = bookmarks[index];
        final rawRating = bookmark.rating.trim();
        final rating = rawRating.isEmpty || rawRating == '0.0' ? '—' : rawRating;
        final status = bookmark.status.trim().isEmpty ? 'غير معروف'.tr : bookmark.status;
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: cardWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Get.toNamed(
                    Routes.COMIC_DETAIL,
                    arguments: bookmark.comicId,
                  ),
                  child: CustomCardNormal(
                    comicId: bookmark.comicId,
                    title: bookmark.title,
                    chapter: '',
                    imageUrl: bookmark.coverImage,
                    type: bookmark.type,
                    rating: rating,
                    status: status,
                    width: cardWidth,
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: IconButton(
                    tooltip: 'إزالة من المفضلة'.tr,
                    onPressed: () => controller.deleteBookmark(bookmark.comicId),
                    visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      backgroundColor: AppColors.card,
                      minimumSize: const Size(32, 32),
                      padding: EdgeInsets.zero,
                      side: BorderSide(color: AppColors.divider),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
