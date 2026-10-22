import 'dart:io';
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
          return const Center(child: MangaPlusLoader(size: 68));
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
            _buildHero(context, comic),
            SliverToBoxAdapter(child: _buildBody(context, comic)),
          ],
        );
      }),
    );
  }

  Widget _buildHero(BuildContext context, ComicDetail comic) {
    final history = controller.readingHistoryFor(comic.comicId);
    final historyChapter = history == null
        ? null
        : comic.chapters.firstWhereOrNull(
            (chapter) => chapter.chapterId == history.chapterId,
          );
    final hasRating = comic.rating.trim().isNotEmpty && comic.rating != '0.0';

    return SliverAppBar(
      pinned: true,
      expandedHeight: 445,
      backgroundColor: AppColors.background,
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        Obx(() {
          controller.bookmarkRevision.value;
          final bookmarked = controller.isBookmarked(comic.comicId);
          return IconButton(
            tooltip: bookmarked
                ? 'إزالة الإشارة المرجعية'.tr
                : 'إضافة إلى الإشارات المرجعية'.tr,
            onPressed: () => controller.toggleBookmark(comic),
            icon: Icon(
              bookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: Colors.white,
            ),
          );
        }),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (comic.coverImage.isNotEmpty &&
                comic.coverImage.startsWith('/') &&
                File(comic.coverImage).existsSync())
              Image.file(
                File(comic.coverImage),
                fit: BoxFit.cover,
              )
            else if (comic.coverImage.startsWith('http://') ||
                comic.coverImage.startsWith('https://'))
              CachedNetworkImage(
                imageUrl: comic.coverImage,
                httpHeaders: const {
                  'Referer': 'https://olympustaff.com/',
                  'User-Agent':
                      'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/131 Mobile Safari/537.36',
                },
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                placeholder: (_, __) => Container(color: AppColors.card),
                errorWidget: (_, __, ___) => const Center(
                  child: MangaPlusLogo(size: 92),
                ),
              )
            else
              const Center(child: MangaPlusLogo(size: 92)),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.34),
                    Colors.black.withValues(alpha: 0.10),
                    AppColors.background.withValues(alpha: 0.78),
                    AppColors.background,
                  ],
                  stops: const [0.0, 0.27, 0.72, 1.0],
                ),
              ),
            ),
            Obx(() {
              controller.bookmarkRevision.value;
              if (!controller.isBookmarked(comic.comicId)) return const SizedBox.shrink();
              return Positioned(
                top: 116,
                right: 18,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    shape: BoxShape.circle,
                    boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 7)],
                  ),
                  child: const Icon(Icons.favorite_rounded, color: Colors.red, size: 25),
                ),
              );
            }),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _CoverThumbnail(imageUrl: comic.coverImage),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              comic.title,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                height: 1.12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (comic.nativeTitle.trim().isNotEmpty) ...[
                              const SizedBox(height: 5),
                              Text(
                                comic.nativeTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.72),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                _Metric(
                                  icon: Icons.menu_book_rounded,
                                  text: '${comic.totalChapters} ${'الفصول'.tr}',
                                ),
                                if (hasRating)
                                  _Metric(
                                    icon: Icons.star_rounded,
                                    text: comic.rating,
                                  ),
                                if (comic.type.trim().isNotEmpty)
                                  _Metric(
                                    icon: Icons.category_rounded,
                                    text: localizeContentType(comic.type),
                                  ),
                              ],
                            ),
                            if (comic.status.trim().isNotEmpty) ...[
                              const SizedBox(height: 10),
                              _StatusBadge(status: comic.status),
                            ],
                            if (controller.comicDetailData.value.source.trim().isNotEmpty) ...[
                              const SizedBox(height: 9),
                              _SourceBadge(
                                source: controller.comicDetailData.value.source,
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
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ComicDetail comic) {
    controller.bookmarkRevision.value;
    final history = controller.readingHistoryFor(comic.comicId);
    final historyChapter = history == null
        ? null
        : comic.chapters.firstWhereOrNull(
            (chapter) => chapter.chapterId == history.chapterId,
          );
    final targetChapter = historyChapter ??
        (comic.chapters.isEmpty ? null : comic.chapters.first);
    final hasHistory = historyChapter != null;
    final bookmarked = controller.isBookmarked(comic.comicId);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 6,
                child: FilledButton.icon(
                  onPressed: targetChapter == null
                      ? null
                      : () => _openChapter(context, comic, targetChapter),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    hasHistory ? 'متابعة القراءة'.tr : 'ابدأ القراءة'.tr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 4,
                child: OutlinedButton.icon(
                  onPressed: () => controller.toggleBookmark(comic),
                  icon: Icon(bookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded),
                  label: Text(
                    bookmarked ? 'إزالة من المفضلة'.tr : 'إضافة للمفضلة'.tr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (comic.genres.isNotEmpty) ...[
            _SectionHeading(icon: Icons.local_offer_outlined, title: 'التصنيفات'.tr),
            const SizedBox(height: 9),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: comic.genres
                  .map((genre) => ActionChip(
                        label: Text(localizeContentGenre(genre)),
                        onPressed: () => _openGenre(genre),
                        backgroundColor: AppColors.searchBar,
                        side: BorderSide(color: AppColors.divider.withValues(alpha: 0.7)),
                        labelStyle: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),
          ],
          if (comic.synopsis.trim().isNotEmpty) ...[
            _InfoCard(
              title: 'نبذة عن المانجا'.tr,
              icon: Icons.menu_book_rounded,
              child: ReadMoreText(
                comic.synopsis,
                trimLines: 4,
                trimMode: TrimMode.Line,
                trimCollapsedText: '... المزيد'.tr,
                trimExpandedText: ' أقل'.tr,
                moreStyle: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
                lessStyle: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
                style: TextStyle(color: AppColors.textSecondary, height: 1.65),
              ),
            ),
            const SizedBox(height: 18),
          ],
          _InfoCard(
            title: 'معلومات المانجا'.tr,
            icon: Icons.info_outline_rounded,
            child: _MetadataGrid(comic: comic),
          ),
          const SizedBox(height: 22),
          _ChapterList(comic: comic, controller: controller),
        ],
      ),
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

class _CoverThumbnail extends StatelessWidget {
  const _CoverThumbnail({required this.imageUrl});
  final String imageUrl;

  @override
  Widget build(BuildContext context) => Container(
        width: 112,
        height: 158,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: AppColors.primary, width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 12,
              offset: Offset(0, 5),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: imageUrl.isEmpty
            ? const Center(child: MangaPlusLogo(size: 52))
            : imageUrl.startsWith('/') && File(imageUrl).existsSync()
                ? Image.file(File(imageUrl), fit: BoxFit.cover)
            : imageUrl.startsWith('http://') || imageUrl.startsWith('https://')
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    httpHeaders: const {
                      'Referer': 'https://olympustaff.com/',
                      'User-Agent':
                          'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/131 Mobile Safari/537.36',
                    },
                    placeholder: (_, __) => Container(color: AppColors.card),
                    errorWidget: (_, __, ___) =>
                        const Center(child: MangaPlusLogo(size: 52)),
                  )
                : const Center(child: MangaPlusLogo(size: 52)),
      );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          localizeContentStatus(status),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 21),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.icon, required this.child});
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.divider.withValues(alpha: 0.78)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeading(icon: icon, title: title),
            const SizedBox(height: 11),
            child,
          ],
        ),
      );
}

class _MetadataGrid extends StatelessWidget {
  const _MetadataGrid({required this.comic});
  final ComicDetail comic;

  @override
  Widget build(BuildContext context) {
    final values = <(IconData, String, String)>[
      (Icons.person_outline_rounded, 'المؤلف'.tr, comic.author),
      (Icons.calendar_today_outlined, 'سنة الإصدار'.tr, comic.releaseYear),
      (Icons.palette_outlined, 'النوع'.tr, localizeContentType(comic.type)),
      (Icons.sync_rounded, 'الحالة'.tr, localizeContentStatus(comic.status)),
      (Icons.star_outline_rounded, 'التقييم'.tr, comic.rating),
      (Icons.update_rounded, 'آخر تحديث'.tr, comic.updatedOn),
    ].where((entry) => entry.$3.trim().isNotEmpty && entry.$3 != '0.0').toList();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values
          .map(
            (entry) => SizedBox(
              width: 150,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.searchBar,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(entry.$1, color: AppColors.primary, size: 18),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            entry.$3,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.source});

  final String source;

  String get logoUrl {
    final value = source.toLowerCase();
    if (value.contains('swat')) return 'https://appswat.com/favicon.ico';
    if (value.contains('azora')) return 'https://azorafly.com/favicon.ico';
    if (value.contains('time')) return 'https://mangatime.org/favicon.ico';
    if (value.contains('online')) return 'https://onma.top/favicon.ico';
    if (value.contains('lava')) return 'https://lavascans.com/favicon.ico';
    if (value.contains('mangatek')) return 'https://mangatek.com/favicon.ico';
    if (value.contains('mangacloud')) return 'https://mangacloud.online/favicon.ico';
    if (value.contains('team')) return 'https://olympustaff.com/favicon.ico';
    return 'https://mangaplus.com/favicon.ico';
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.34),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: CachedNetworkImage(
                imageUrl: logoUrl,
                width: 18,
                height: 18,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const Icon(
                  Icons.public_rounded,
                  size: 17,
                  color: Colors.white70,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              source,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
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
    final localOnly = widget.controller.comicDetailData.value.source == 'local';
    final read = widget.controller.isChapterRead(chapter.chapterId);
    final progress = widget.controller.downloadingChapters[chapter.chapterId];
    final downloading = progress != null;
    final stateIcon = downloading
        ? Icons.downloading_rounded
        : downloaded
        ? Icons.download_done_rounded
        : read
            ? Icons.visibility_rounded
            : Icons.fiber_new_rounded;
    final stateColor = downloading
        ? AppColors.primary
        : downloaded
        ? const Color(0xff36a66a)
        : read
            ? AppColors.primary
            : const Color(0xffe09a34);
    final stateLabel = downloading
        ? 'جارٍ التنزيل'.tr
        : downloaded
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
        contentPadding: const EdgeInsetsDirectional.fromSTEB(13, 6, 5, 6),
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
                  radius: 20,
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
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Wrap(
            spacing: 7,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: stateColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(stateIcon, size: 12, color: stateColor),
                    const SizedBox(width: 4),
                    Text(
                      stateLabel,
                      style: TextStyle(
                        color: stateColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (chapter.releaseTime.isNotEmpty)
                Text(
                  chapter.releaseTime,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
            ],
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
                tooltip: downloaded
                    ? (localOnly ? 'حذف الفصل المحلي'.tr : 'تم التنزيل'.tr)
                    : 'تنزيل الفصل'.tr,
                onPressed: downloaded && !localOnly
                    ? null
                    : downloaded && localOnly
                        ? () => Get.defaultDialog(
                              title: 'حذف الفصل المحلي'.tr,
                              content: Text('سيتم حذف ملفات هذا الفصل من الجهاز فقط.'.tr),
                              confirm: TextButton(
                                onPressed: () {
                                  Get.back();
                                  widget.controller.deleteDownloadedChapter(chapter.chapterId);
                                },
                                child: Text('حذف'.tr),
                              ),
                              cancel: TextButton(
                                onPressed: Get.back,
                                child: Text('إلغاء'.tr),
                              ),
                            )
                    : () {
                        widget.controller.downloadChapter(
                          chapter,
                          widget.comic.comicId,
                          widget.comic.title,
                          widget.comic.coverImage,
                        );
                      },
                icon: Icon(
                  downloaded && localOnly
                      ? Icons.delete_outline_rounded
                      : downloaded
                          ? Icons.download_done_rounded
                          : Icons.download_rounded,
                  color: downloaded && localOnly
                      ? Colors.redAccent
                      : downloaded
                          ? const Color(0xff36a66a)
                          : AppColors.primary,
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
