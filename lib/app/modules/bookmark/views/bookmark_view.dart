import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/core/translations/content_localization.dart';
import 'package:mangaplus/app/data/models/bookmark.dart';
import 'package:mangaplus/app/modules/bookmark/controllers/bookmark_controller.dart';
import 'package:mangaplus/app/routes/app_pages.dart';
import 'package:mangaplus/app/widgets/brand_state.dart';
import 'package:mangaplus/app/widgets/mangaplus_app_bar.dart';
import 'package:mangaplus/app/widgets/custom_card_normal.dart';
import 'package:mangaplus/app/widgets/theme_aware_builder.dart';

class BookmarkView extends GetView<BookmarkController> {
  const BookmarkView({super.key});

  @override
  Widget build(BuildContext context) {
    return ThemeAwareBuilder(
      builder: (context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: MangaPlusAppBar(
          title: 'الإشارات المرجعية'.tr,
          actions: [Obx(() {
            if (controller.selectedBookmarkIds.isNotEmpty) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'تحديد الكل'.tr,
                    onPressed: controller.selectAllVisible,
                    icon: const Icon(Icons.select_all_rounded),
                  ),
                  IconButton(
                    tooltip: 'حذف المحدد'.tr,
                    onPressed: _confirmDeleteSelected,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                  IconButton(
                    tooltip: 'إلغاء التحديد'.tr,
                    onPressed: controller.clearSelection,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              );
            }
            final selectedOrder = controller.sortOrder.value;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'استيراد المفضلة'.tr,
                  onPressed: _openImport,
                  icon: const Icon(Icons.add_rounded),
                ),
                PopupMenuButton<BookmarkSortOrder>(
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
                ),
              ],
            );
          })],
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

  Future<void> _openImport() async {
    final records = await controller.pickDropsauceBackup();
    if (records == null) return;
    Get.dialog(
      _DropsauceImportDialog(controller: controller),
      barrierDismissible: false,
    );
    await controller.importDropsauceFavorites(records);
  }

  Future<void> _confirmDeleteSelected() async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: Text('حذف المحدد'.tr),
        content: Text('هل تريد حذف الأعمال المحددة من المفضلة؟'.tr),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: Text('إلغاء'.tr)),
          FilledButton(onPressed: () => Get.back(result: true), child: Text('حذف'.tr)),
        ],
      ),
    );
    if (confirmed == true) await controller.deleteSelected();
  }

  Widget _buildBookmarkGrid(BuildContext context, List<BookmarkItem> bookmarks) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 800 ? 7 : (width >= 600 ? 5 : (width >= 390 ? 4 : 3));
    const crossAxisSpacing = 10.0;
    final cellWidth = (width - 28 - (columns - 1) * crossAxisSpacing) / columns;
    final cardWidth = cellWidth.clamp(92.0, 132.0).toDouble();
    final cardHeight = cardWidth * 1.25;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: 20,
        mainAxisExtent: cardHeight + 62,
      ),
      itemCount: bookmarks.length,
      itemBuilder: (context, index) {
        final bookmark = bookmarks[index];
        final rawRating = bookmark.rating.trim();
        final rating = rawRating.isEmpty || rawRating == '0.0' ? '—' : rawRating;
        final status = bookmark.status.trim().isEmpty
            ? 'غير معروف'.tr
            : localizeContentStatusOr(bookmark.status, 'غير معروف'.tr);
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: cardWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Obx(() {
                  final selected = controller.isSelected(bookmark.comicId);
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onLongPress: () => controller.toggleSelection(bookmark.comicId),
                    onTap: () {
                      if (controller.selectedBookmarkIds.isNotEmpty) {
                        controller.toggleSelection(bookmark.comicId);
                      } else {
                        Get.toNamed(Routes.COMIC_DETAIL, arguments: bookmark.comicId);
                      }
                    },
                    child: Stack(
                      children: [
                        CustomCardNormal(
                          comicId: bookmark.comicId,
                          title: bookmark.title,
                          chapter: '',
                          imageUrl: bookmark.coverImage,
                          type: bookmark.type,
                          rating: rating,
                          status: status,
                          width: cardWidth,
                        ),
                        if (selected)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.primary, width: 3),
                                  color: AppColors.primary.withValues(alpha: 0.12),
                                ),
                                child: const Align(
                                  alignment: Alignment.topRight,
                                  child: Padding(
                                    padding: EdgeInsets.all(7),
                                    child: Icon(Icons.check_circle_rounded, color: Colors.white, size: 23),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DropsauceImportDialog extends StatelessWidget {
  const _DropsauceImportDialog({required this.controller});

  final BookmarkController controller;

  @override
  Widget build(BuildContext context) => Obx(() {
        final total = controller.importTotal.value;
        final current = controller.importCurrentIndex.value;
        final completed = controller.importCompleted.value;
        final progress = total == 0 ? 0.0 : (current / total).clamp(0.0, 1.0).toDouble();
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 520, maxHeight: 650),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: AppColors.divider),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.file_download_done_rounded, color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'استيراد المفضلة',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      completed ? 'اكتمل استيراد النسخة الاحتياطية' : 'جارٍ إضافة الأعمال إلى المفضلة',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: completed ? 1 : progress,
                        minHeight: 8,
                        backgroundColor: AppColors.searchBar,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$current من $total',
                      textAlign: TextAlign.left,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                    if (total > 0) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(child: _ImportMetric(label: 'تمت إضافته', value: controller.importedTitles.length.toString(), color: const Color(0xff43b581))),
                          const SizedBox(width: 8),
                          Expanded(child: _ImportMetric(label: 'تمت مطابقة مصدره', value: controller.importResolvedCount.value.toString(), color: AppColors.primary)),
                          const SizedBox(width: 8),
                          Expanded(child: _ImportMetric(label: 'فشل', value: controller.importFailures.length.toString(), color: const Color(0xffe5a947))),
                        ],
                      ),
                    ],
                    if (!completed && controller.importCurrentTitle.value.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        decoration: BoxDecoration(
                          color: AppColors.searchBar,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Row(
                          children: [
                            const MangaPlusLoader(size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                controller.importCurrentTitle.value,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (controller.importedTitles.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('تمت إضافة الأعمال الأخيرة', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                      const SizedBox(height: 5),
                      ...controller.importedTitles.reversed.take(5).map(
                            (title) => Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Text(
                                '✓ $title',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: AppColors.textPrimary, fontSize: 11),
                              ),
                            ),
                          ),
                    ],
                    if (completed) ...[
                      const SizedBox(height: 16),
                      _ImportSummaryRow(
                        icon: Icons.check_circle_rounded,
                        color: const Color(0xff43b581),
                        label: 'تم استيراد ${controller.importedTitles.length} عمل',
                      ),
                      const SizedBox(height: 7),
                      _ImportSummaryRow(
                        icon: Icons.menu_book_rounded,
                        color: AppColors.primary,
                        label: 'مانجا: ${controller.importedMangaCount.value}',
                      ),
                      const SizedBox(height: 7),
                      _ImportSummaryRow(
                        icon: Icons.auto_stories_rounded,
                        color: AppColors.primary,
                        label: 'روايات: ${controller.importedNovelCount.value}',
                      ),
                      const SizedBox(height: 7),
                      _ImportSummaryRow(
                        icon: Icons.sync_rounded,
                        color: AppColors.primary,
                        label: 'تم العثور على مصدر بديل: ${controller.importResolvedCount.value}',
                      ),
                      const SizedBox(height: 7),
                      _ImportSummaryRow(
                        icon: Icons.error_outline_rounded,
                        color: controller.importFailures.isEmpty ? AppColors.textSecondary : const Color(0xffe5a947),
                        label: 'فشل الاستيراد: ${controller.importFailures.length}',
                      ),
                      if (controller.importFailures.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: controller.importFailures.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 5),
                            itemBuilder: (_, index) {
                              final failure = controller.importFailures[index];
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.searchBar,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.divider),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(failure.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 2),
                                    Text(failure.failureReason ?? 'تعذر تحديد السبب', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                    if (completed) ...[
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 46,
                        child: ElevatedButton(
                          onPressed: () => Get.back(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('إغلاق', style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      });
}

class _ImportSummaryRow extends StatelessWidget {
  const _ImportSummaryRow({required this.icon, required this.color, required this.label});

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      );
}

class _ImportMetric extends StatelessWidget {
  const _ImportMetric({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textSecondary, fontSize: 9, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}
