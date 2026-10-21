import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:readmore/readmore.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/core/translations/content_localization.dart';
import 'package:mangaplus/app/data/models/comic_detail.dart';
import 'package:mangaplus/app/modules/comic_detail/controllers/comic_detail_controller.dart';
import 'package:mangaplus/app/modules/home/controllers/home_controller.dart';
import 'package:mangaplus/app/modules/main/controllers/main_controller.dart';
import 'package:mangaplus/app/routes/app_pages.dart';
import 'package:mangaplus/app/widgets/app_feedback.dart';
import 'package:mangaplus/app/widgets/brand_state.dart';

class ComicDetailView extends GetView<ComicDetailController> {
  const ComicDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Obx(() {
        if (controller.isLoading.value) {
          return Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: AppColors.primary,
              ),
            ),
          );
        }
        final comic = controller.comicDetailData.value.comicDetail;
        if (comic.title.isEmpty) {
          return BrandState(
            title: 'تفاصيل القصة غير متاحة'.tr,
            actionLabel: 'إعادة المحاولة'.tr,
            onAction: () => controller.fetchComicDetail('${Get.arguments ?? ''}'),
          );
        }
        return CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 400,
              backgroundColor: AppColors.background,
              foregroundColor: AppColors.textPrimary,
              actions: [
                IconButton(
                  tooltip: 'إضافة إلى الإشارات المرجعية'.tr,
                  onPressed: () => controller.toggleBookmark(comic),
                  icon: Obx(
                    () {
                      controller.bookmarkRevision.value;
                      return Icon(
                        controller.isBookmarked(comic.comicId)
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        color: AppColors.primary,
                      );
                    },
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (comic.coverImage.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: comic.coverImage,
                        httpHeaders: const {
                          'Referer': 'https://olympustaff.com/',
                          'User-Agent':
                              'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/131 Mobile Safari/537.36',
                        },
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: AppColors.card),
                        errorWidget: (_, __, ___) => const Center(
                          child: MangaPlusLogo(size: 100),
                        ),
                      )
                    else
                      const Center(child: MangaPlusLogo(size: 100)),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.08),
                            AppColors.background.withValues(alpha: 0.88),
                            AppColors.background,
                          ],
                          stops: const [0, 0.7, 1],
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              comic.title,
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                _InfoPill(
                                  icon: Icons.menu_book_rounded,
                                  text: '${comic.totalChapters} ${'الفصول'.tr}',
                                ),
                                if (comic.status.isNotEmpty)
                                  _InfoPill(
                                    icon: Icons.radio_button_checked_rounded,
                                    text: localizeContentStatus(comic.status),
                                  ),
                              ],
                            ),
                            if (comic.chapters.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 44,
                                child: FilledButton.icon(
                                  onPressed: () =>
                                      _openChapter(context, comic, comic.chapters.first),
                                  icon: const Icon(Icons.play_arrow_rounded),
                                  label: Text('قراءة الفصل الأخير'.tr),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (comic.genres.isNotEmpty) ...[
                      _SectionTitle('التصنيفات'.tr),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: comic.genres
                            .map((genre) => ActionChip(
                                  backgroundColor: AppColors.searchBar,
                                  side: BorderSide.none,
                                  label: Text(localizeContentGenre(genre)),
                                  onPressed: () => _openGenre(genre),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 18),
                    ],
                    _ChapterList(comic: comic, controller: controller),
                    const SizedBox(height: 22),
                    if (comic.synopsis.trim().isNotEmpty) ...[
                      _SectionTitle('القصة'.tr),
                      const SizedBox(height: 8),
                      ReadMoreText(
                        comic.synopsis,
                        trimLines: 4,
                        trimMode: TrimMode.Line,
                        trimCollapsedText: '... المزيد'.tr,
                        trimExpandedText: ' أقل'.tr,
                        moreStyle: TextStyle(color: AppColors.primary),
                        lessStyle: TextStyle(color: AppColors.primary),
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    _SectionTitle('معلومات المانجا'.tr),
                    const SizedBox(height: 8),
                    _MetadataCard(comic: comic),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _openChapter(
    BuildContext context,
    ComicDetail comic,
    Chapter chapter,
  ) async {
    await controller.addToHistory(comic, chapter.chapterId, chapter.title);
    if (!context.mounted) return;
    Get.toNamed(Routes.CHAPTER, arguments: {
      'chapterId': chapter.chapterId,
      'comicId': comic.comicId,
      'comicTitle': comic.title,
      'coverImage': comic.coverImage,
      'chapterTitle': chapter.title,
    });
  }

  void _openGenre(String genre) {
    if (Get.isRegistered<HomeController>() &&
        Get.isRegistered<MainController>()) {
      final home = Get.find<HomeController>();
      final selected = home.genreController.genreData.value.genres
          .firstWhereOrNull(
        (item) => item.name.toLowerCase() == genre.toLowerCase(),
      );
      home.openGenre(selected?.link ?? genre, localizeContentGenre(genre));
      Get.find<MainController>().changeIndex(0);
      Get.back();
      return;
    }
    Get.toNamed(Routes.GENRE_DETAIL, arguments: genre);
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Text(
        title,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 19,
          fontWeight: FontWeight.w800,
        ),
      );
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.card.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.primary),
            const SizedBox(width: 5),
            Text(
              text,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
}

class _MetadataCard extends StatelessWidget {
  const _MetadataCard({required this.comic});
  final ComicDetail comic;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('المؤلف'.tr, comic.author),
      ('سنة الإصدار'.tr, comic.releaseYear),
      ('الحالة'.tr, localizeContentStatus(comic.status)),
      ('النوع'.tr, localizeContentType(comic.type)),
      ('التقييم'.tr, comic.rating),
      ('آخر تحديث'.tr, comic.updatedOn),
    ].where((row) => row.$2.trim().isNotEmpty).toList();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: rows
            .map((row) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(row.$1,
                            style: TextStyle(color: AppColors.textSecondary)),
                      ),
                      Flexible(
                        child: Text(
                          row.$2,
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _ChapterList extends StatefulWidget {
  const _ChapterList({required this.comic, required this.controller});
  final ComicDetail comic;
  final ComicDetailController controller;

  @override
  State<_ChapterList> createState() => _ChapterListState();
}

class _ChapterListState extends State<_ChapterList> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chapters = widget.comic.chapters;
    return Obx(() {
      final visible = _searchController.text.trim().isEmpty
          ? chapters
          : widget.controller.filteredChapters.toList();
      final sorted = widget.controller.sortedChapters(visible);
      final selecting = widget.controller.isSelectionMode.value;
      final selectedCount = widget.controller.selectedChapterIds.length;
      final ascending = widget.controller.sortAscending.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _SectionTitle('الفصول'.tr)),
              Text(
                '${chapters.length}',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: ascending ? 'ترتيب تصاعدي'.tr : 'ترتيب تنازلي'.tr,
                onPressed: widget.controller.toggleSortOrder,
                icon: Icon(
                  ascending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  color: AppColors.primary,
                ),
              ),
              IconButton(
                tooltip: selecting ? 'إلغاء التحديد'.tr : 'تحديد الفصول'.tr,
                onPressed: widget.controller.toggleSelectionMode,
                icon: Icon(
                  selecting ? Icons.close_rounded : Icons.checklist_rounded,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          if (selecting || selectedCount > 0) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.divider),
              ),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    'تم تحديد @value فصل'.trParams({'value': '$selectedCount'}),
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => widget.controller.selectAllChapters(chapters),
                    icon: const Icon(Icons.select_all_rounded, size: 18),
                    label: Text('تحديد الكل'.tr),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: selectedCount == 0 ||
                            widget.controller.isBulkDownloading.value
                        ? null
                        : () => widget.controller.downloadSelectedChapters(widget.comic),
                    icon: widget.controller.isBulkDownloading.value
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_rounded, size: 18),
                    label: Text('تنزيل المحدد'.tr),
                  ),
                ],
              ),
            ),
          ],
          TextField(
            controller: _searchController,
            onChanged: widget.controller.filterChapters,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'ابحث عن فصل...'.tr,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'مسح'.tr,
                      onPressed: () {
                        _searchController.clear();
                        widget.controller.filterChapters('');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              fillColor: AppColors.searchBar,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (chapters.isEmpty)
            BrandState(title: 'لا توجد فصول متاحة'.tr)
          else if (sorted.isEmpty)
            BrandState(title: 'لا توجد نتائج'.tr)
          else
            ListView.separated(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sorted.length,
              separatorBuilder: (_, __) => const SizedBox(height: 7),
              itemBuilder: (context, index) => _buildChapterTile(context, sorted[index]),
            ),
        ],
      );
    });
  }

  Widget _buildChapterTile(BuildContext context, Chapter chapter) {
    final selected = widget.controller.selectedChapterIds.contains(chapter.chapterId);
    final downloaded = widget.controller.isChapterDownloaded(chapter.chapterId);
    final read = widget.controller.isChapterRead(chapter.chapterId);
    final progress = widget.controller.downloadingChapters[chapter.chapterId];
    final stateIcon = downloaded
        ? Icons.download_done_rounded
        : read
            ? Icons.visibility_rounded
            : Icons.fiber_new_rounded;
    final stateColor = downloaded
        ? const Color(0xff36a66a)
        : read
            ? AppColors.primary
            : const Color(0xffe09a34);
    final stateLabel = downloaded
        ? 'تم التنزيل'.tr
        : read
            ? 'مقروء'.tr
            : 'جديد'.tr;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: selected
          ? AppColors.primary.withValues(alpha: 0.13)
          : AppColors.searchBar,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: selected ? AppColors.primary.withValues(alpha: 0.55) : AppColors.divider,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsetsDirectional.fromSTEB(13, 4, 5, 4),
        onTap: () {
          if (widget.controller.isSelectionMode.value) {
            widget.controller.toggleChapterSelection(chapter);
          } else {
            _openChapter(context, chapter);
          }
        },
        onLongPress: () => widget.controller.toggleChapterSelection(chapter),
        leading: widget.controller.isSelectionMode.value
            ? Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected ? AppColors.primary : AppColors.icon,
                size: 26,
              )
            : Tooltip(
                message: stateLabel,
                child: CircleAvatar(
                  radius: 19,
                  backgroundColor: stateColor.withValues(alpha: 0.15),
                  child: Icon(stateIcon, size: 20, color: stateColor),
                ),
              ),
        title: Text(
          chapter.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        subtitle: chapter.releaseTime.isEmpty
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  chapter.releaseTime,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (progress != null)
              SizedBox(
                width: 38,
                height: 38,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 3,
                      color: AppColors.primary,
                      backgroundColor: AppColors.divider,
                    ),
                    Text(
                      '${(progress * 100).round()}%',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 9),
                    ),
                  ],
                ),
              )
            else
              IconButton(
                tooltip: downloaded ? 'تم التنزيل'.tr : 'تنزيل الفصل'.tr,
                onPressed: downloaded
                    ? null
                    : () {
                        widget.controller.downloadChapter(
                          chapter,
                          widget.comic.comicId,
                          widget.comic.title,
                          widget.comic.coverImage,
                        );
                      },
                icon: Icon(
                  downloaded ? Icons.download_done_rounded : Icons.download_rounded,
                  color: downloaded ? const Color(0xff36a66a) : AppColors.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openChapter(BuildContext context, Chapter chapter) async {
    await widget.controller.addToHistory(
      widget.comic,
      chapter.chapterId,
      chapter.title,
    );
    if (!mounted) return;
    Get.toNamed(Routes.CHAPTER, arguments: {
      'chapterId': chapter.chapterId,
      'comicId': widget.comic.comicId,
      'comicTitle': widget.comic.title,
      'coverImage': widget.comic.coverImage,
      'chapterTitle': chapter.title,
    });
  }
}
