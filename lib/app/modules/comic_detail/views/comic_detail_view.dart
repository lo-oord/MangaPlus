import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:readmore/readmore.dart';
import 'package:mangaplus/app/core/cache/manga_cover_cache_manager.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/core/translations/content_localization.dart';
import 'package:mangaplus/app/data/models/comic_detail.dart';
import 'package:mangaplus/app/modules/comic_detail/controllers/comic_detail_controller.dart';
import 'package:mangaplus/app/modules/home/controllers/home_controller.dart';
import 'package:mangaplus/app/modules/main/controllers/main_controller.dart';
import 'package:mangaplus/app/routes/app_pages.dart';
import 'package:mangaplus/app/widgets/app_feedback.dart';
import 'package:mangaplus/app/widgets/brand_state.dart';
import 'package:mangaplus/app/widgets/theme_aware_builder.dart';

class ComicDetailView extends GetView<ComicDetailController> {
  const ComicDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return ThemeAwareBuilder(builder: (context) => Obx(() {
      final loading = controller.isLoading.value;
      final comic = controller.comicDetailData.value.comicDetail;
      if (loading) {
        return const Scaffold(
          body: Center(child: MangaPlusLoader(size: 68)),
        );
      }
      if (comic.title.isEmpty) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: BrandState(
            title: 'تفاصيل القصة غير متاحة'.tr,
            actionLabel: 'إعادة المحاولة'.tr,
            onAction: () => controller.fetchComicDetail('${Get.arguments ?? ''}'),
          ),
        );
      }
      return Scaffold(
        backgroundColor: AppColors.background,
        body: CustomScrollView(
          slivers: [
            _buildHero(context, comic),
            SliverToBoxAdapter(child: _buildBody(comic)),
            _ChapterList(comic: comic, controller: controller),
          ],
        ),
      );
    }));
  }

  Chapter? _targetChapter(ComicDetail comic) {
    controller.historyRevision.value;
    final history = controller.readingHistoryFor(comic.comicId);
    if (history != null) {
      final chapter = comic.chapters.firstWhereOrNull(
        (item) => item.chapterId == history.chapterId,
      );
      if (chapter != null) return chapter;
    }
    final oldestFirst = controller.sortedChapters(
      comic.chapters,
      ascending: true,
    );
    return oldestFirst.isEmpty ? null : oldestFirst.first;
  }

  Widget _readAction(BuildContext context, ComicDetail comic) => Obx(() {
        controller.historyRevision.value;
        final targetChapter = _targetChapter(comic);
        if (targetChapter == null) return const SizedBox.shrink();
        final history = controller.readingHistoryFor(comic.comicId);
        final hasHistory = history != null &&
            comic.chapters.any((chapter) => chapter.chapterId == history.chapterId);
        final label = hasHistory ? 'متابعة القراءة'.tr : 'ابدأ القراءة'.tr;
        return Padding(
          padding: const EdgeInsetsDirectional.only(start: 2, end: 4),
          child: Center(
            child: FilledButton.icon(
              onPressed: () => _openChapter(context, comic, targetChapter),
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: FilledButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: AppColors.primary,
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        );
      });

  Widget _buildHero(BuildContext context, ComicDetail comic) {
    final hasRating = comic.rating.trim().isNotEmpty && comic.rating != '0.0';

    return SliverAppBar(
      pinned: true,
      expandedHeight: 365,
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      leading: IconButton(
        tooltip: 'رجوع'.tr,
        onPressed: Get.back,
        icon: const BackButtonIcon(),
        style: IconButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          backgroundColor: AppColors.card.withValues(alpha: 0.92),
          shape: const CircleBorder(),
        ),
      ),
      actions: [
        _readAction(context, comic),
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
              color: AppColors.icon,
            ),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.card.withValues(alpha: 0.92),
              shape: const CircleBorder(),
            ),
          );
        }),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            _coverArtwork(
              comic.coverImage,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              logoSize: 76,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.34),
                    Colors.black.withValues(alpha: 0.24),
                    AppColors.background.withValues(alpha: 0.78),
                    AppColors.background,
                  ],
                  stops: const [0.0, 0.32, 0.76, 1.0],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      width: 96,
                      height: 142,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.65),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.32),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: _coverArtwork(
                          comic.coverImage,
                          fit: BoxFit.cover,
                          logoSize: 34,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            comic.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 23,
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
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 12,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 7,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (hasRating)
                                _InfoPill(
                                  icon: Icons.star_rounded,
                                  text: comic.rating,
                                ),
                              if (comic.status.trim().isNotEmpty)
                                _StatusBadge(status: comic.status),
                            ],
                          ),
                        ],
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

  Widget _coverArtwork(
    String imagePath, {
    required BoxFit fit,
    Alignment alignment = Alignment.center,
    double logoSize = 42,
  }) {
    final localFile = imagePath.startsWith('/') ? File(imagePath) : null;
    if (localFile != null && localFile.existsSync()) {
      return Image.file(
        localFile,
        fit: fit,
        alignment: alignment,
        errorBuilder: (_, __, ___) => Center(
          child: MangaPlusLogo(size: logoSize),
        ),
      );
    }
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: imagePath,
        cacheManager: MangaCoverCacheManager.instance,
        httpHeaders: const {
          'Referer': 'https://olympustaff.com/',
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/131 Mobile Safari/537.36',
        },
        fit: fit,
        alignment: alignment,
        placeholder: (_, __) => Container(color: AppColors.card),
        errorWidget: (_, __, ___) => Center(
          child: MangaPlusLogo(size: logoSize),
        ),
      );
    }
    return Container(
      color: AppColors.card,
      alignment: Alignment.center,
      child: MangaPlusLogo(size: logoSize),
    );
  }

  Widget _buildBody(ComicDetail comic) {
    final source = controller.comicDetailData.value.source.trim();
    final hasMetadata = [
      comic.author,
      comic.releaseYear,
      comic.type,
      comic.updatedOn,
      comic.totalChapters,
      source,
    ].any((value) =>
        value.trim().isNotEmpty && value != '0' && value != '0.0');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasMetadata) ...[
            _InfoCard(
              title: 'معلومات المانجا'.tr,
              icon: Icons.info_outline_rounded,
              child: _MetadataGrid(comic: comic, source: source),
            ),
            const SizedBox(height: 18),
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
          if (comic.genres.isNotEmpty) ...[
            _SectionHeading(
              icon: Icons.local_offer_outlined,
              title: 'التصنيفات'.tr,
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: comic.genres
                  .map(
                    (genre) => ActionChip(
                      label: Text(localizeContentGenre(genre)),
                      onPressed: () => _openGenre(genre),
                      backgroundColor: AppColors.searchBar,
                      side: BorderSide(
                        color: AppColors.divider.withValues(alpha: 0.7),
                      ),
                      labelStyle: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
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
      'comicType': comic.type,
      'chapterTitle': chapter.title,
      'chapterNavigation': comic.chapters
          .map((item) => {
                'chapterId': item.chapterId,
                'title': item.title,
                'url': item.link,
              })
          .toList(growable: false),
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

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: icon == Icons.star_rounded ? const Color(0xfff2b94b) : Colors.white70),
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

  Color _statusColor() {
    final value = localizeContentStatus(status).toLowerCase();
    if (value == 'مستمر'.tr.toLowerCase() || value == 'مكتمل'.tr.toLowerCase() || value == 'ongoing' || value == 'completed') {
      return AppColors.success;
    }
    if (value == 'متوقف مؤقتًا'.tr.toLowerCase() || value == 'hiatus' || value == 'paused') {
      return AppColors.warning;
    }
    return AppColors.icon;
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor();
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Text(
          localizeContentStatus(status),
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: AppColors.icon, size: 21),
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
  const _MetadataGrid({required this.comic, required this.source});
  final ComicDetail comic;
  final String source;

  @override
  Widget build(BuildContext context) {
    final values = <(IconData, String, String)>[
      (Icons.person_outline_rounded, 'المؤلف'.tr, comic.author),
      (Icons.calendar_today_outlined, 'سنة الإصدار'.tr, comic.releaseYear),
      (Icons.palette_outlined, 'النوع'.tr, localizeContentType(comic.type)),
      (Icons.update_rounded, 'آخر تحديث'.tr, comic.updatedOn),
      (Icons.public_rounded, 'المصدر'.tr, source),
      (Icons.format_list_numbered_rounded, 'عدد الفصول'.tr, comic.totalChapters),
    ].where((entry) =>
        entry.$3.trim().isNotEmpty && entry.$3 != '0.0' && entry.$3 != '0').toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth >= 320
            ? (constraints.maxWidth - 8) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: values
              .map(
                (entry) => SizedBox(
                  width: itemWidth,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.searchBar,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(entry.$1, color: AppColors.icon, size: 18),
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
      },
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
            Icon(icon, size: 14, color: icon == Icons.star_rounded ? const Color(0xfff2b94b) : AppColors.icon),
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
      widget.controller.downloadRevision.value;
      widget.controller.historyRevision.value;
      widget.controller.downloadingChapters.length;
      widget.controller.downloadTaskCount;
      final searched = _searchController.text.trim().isEmpty
          ? chapters
          : widget.controller.filteredChapters.toList();
      final filter = widget.controller.chapterFilter.value;
      final visible = searched.where((chapter) {
        switch (filter) {
          case 'unread':
            return !widget.controller.isChapterRead(chapter.chapterId);
          case 'read':
            return widget.controller.isChapterRead(chapter.chapterId);
          case 'downloaded':
            return widget.controller.isChapterDownloaded(chapter.chapterId);
          default:
            return true;
        }
      }).toList(growable: false);
      final sorted = widget.controller.sortedChapters(visible);
      final selecting = widget.controller.isSelectionMode.value;
      final selectedCount = widget.controller.selectedChapterIds.length;
      final ascending = widget.controller.sortAscending.value;
      return SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _SectionTitle('الفصول'.tr)),
                      Text(
                        '${sorted.length}/${chapters.length}',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton.icon(
                        onPressed: widget.controller.toggleSortOrder,
                        icon: Icon(
                          ascending
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                          size: 16,
                        ),
                        label: Text(
                          ascending ? 'الأقدم أولًا'.tr : 'الأحدث أولًا'.tr,
                          maxLines: 1,
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: BorderSide(color: AppColors.divider),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      if (widget.comic.type.toLowerCase() != 'novel')
                        IconButton(
                          tooltip: selecting ? 'إلغاء التحديد'.tr : 'تحديد الفصول'.tr,
                          onPressed: widget.controller.toggleSelectionMode,
                          icon: Icon(
                            selecting ? Icons.close_rounded : Icons.checklist_rounded,
                            color: selecting ? AppColors.primary : AppColors.icon,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  if (widget.comic.type.toLowerCase() != 'novel' &&
                      (selecting || selectedCount > 0)) ...[
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
                            onPressed: () =>
                                widget.controller.selectAllChapters(sorted),
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
                    onChanged: (value) {
                      setState(() {});
                      widget.controller.filterChapters(value);
                    },
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
                                setState(() {});
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
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _chapterFilterChip('all', 'الكل', Icons.apps_rounded),
                        const SizedBox(width: 7),
                        _chapterFilterChip(
                          'unread',
                          'غير مقروء',
                          Icons.radio_button_unchecked_rounded,
                        ),
                        const SizedBox(width: 7),
                        _chapterFilterChip(
                          'read',
                          'مقروء',
                          Icons.check_circle_outline_rounded,
                        ),
                        const SizedBox(width: 7),
                        _chapterFilterChip(
                          'downloaded',
                          'تم التنزيل',
                          Icons.download_done_rounded,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (sorted.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                child: BrandState(
                  title: chapters.isEmpty ? 'لا توجد فصول متاحة'.tr : 'لا توجد نتائج'.tr,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                    padding: EdgeInsets.only(bottom: index == sorted.length - 1 ? 0 : 7),
                    child: _buildChapterTile(context, sorted[index]),
                  ),
                  childCount: sorted.length,
                ),
              ),
            ),
        ],
      );
    });
  }

  Widget _chapterFilterChip(String value, String label, IconData icon) {
    final selected = widget.controller.chapterFilter.value == value;
    return ChoiceChip(
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => widget.controller.setChapterFilter(value),
      avatar: Icon(
        icon,
        size: 16,
        color: selected ? AppColors.primary : AppColors.icon,
      ),
      label: Text(label.tr),
      labelStyle: TextStyle(
        color: selected ? AppColors.primary : AppColors.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
      selectedColor: AppColors.primary.withValues(alpha: 0.13),
      backgroundColor: AppColors.card,
      side: BorderSide(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.45)
            : AppColors.divider,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _chapterStateChip(String label, IconData icon, Color color) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label.tr,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );

  Widget _buildChapterTile(BuildContext context, Chapter chapter) {
    final selected = widget.controller.selectedChapterIds.contains(chapter.chapterId);
    final downloaded = widget.controller.isChapterDownloaded(chapter.chapterId);
    final read = widget.controller.isChapterRead(chapter.chapterId);
    final progress = widget.controller.downloadingChapters[chapter.chapterId];
    final task = widget.controller.downloadTaskForChapter(chapter.chapterId);
    final taskStatus = task?.status.name;
    final failed = !downloaded &&
        (task?.failedChapterIds.contains(chapter.chapterId) ?? false);
    final paused = !downloaded && taskStatus == 'paused';
    final isCurrentTaskChapter = task?.currentChapterId == chapter.chapterId;
    final queued = !downloaded && !failed && !paused &&
        (taskStatus == 'queued' ||
            (taskStatus == 'downloading' && !isCurrentTaskChapter));
    final downloading = !downloaded && !failed && !paused && !queued &&
        (progress != null ||
            (taskStatus == 'downloading' && isCurrentTaskChapter));
    final readColor = read ? AppColors.success : AppColors.textSecondary;

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
        contentPadding: const EdgeInsetsDirectional.fromSTEB(14, 7, 8, 7),
        onTap: () {
          if (widget.controller.isSelectionMode.value) {
            widget.controller.toggleChapterSelection(chapter);
          } else {
            _openChapter(context, chapter);
          }
        },
        onLongPress: widget.comic.type.toLowerCase() == 'novel'
            ? null
            : () => widget.controller.toggleChapterSelection(chapter),
        leading: widget.controller.isSelectionMode.value
            ? Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected ? AppColors.primary : AppColors.icon,
                size: 26,
              )
            : null,
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
            runSpacing: 5,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _chapterStateChip(
                read ? 'مقروء' : 'غير مقروء',
                read ? Icons.check_circle_outline_rounded : Icons.circle_outlined,
                readColor,
              ),
              if (chapter.releaseTime.isNotEmpty)
                Text(
                  chapter.releaseTime,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              if (downloaded)
                _chapterStateChip(
                  'تم التنزيل',
                  Icons.download_done_rounded,
                  AppColors.success,
                )
              else if (failed)
                _chapterStateChip(
                  'فشل التنزيل',
                  Icons.error_outline_rounded,
                  AppColors.error,
                )
              else if (downloading)
                _chapterStateChip(
                  'جارٍ التنزيل',
                  Icons.downloading_rounded,
                  AppColors.primary,
                )
              else if (paused)
                _chapterStateChip(
                  'متوقف مؤقتًا',
                  Icons.pause_circle_outline_rounded,
                  AppColors.warning,
                )
              else if (queued)
                _chapterStateChip(
                  'قيد الانتظار',
                  Icons.schedule_rounded,
                  AppColors.textSecondary,
                ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (downloading)
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
                    if (progress != null)
                      Text(
                        '${(progress * 100).round()}%',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 9,
                        ),
                      ),
                  ],
                ),
              )
            else if (queued)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 12),
                child: Icon(Icons.schedule_rounded, color: AppColors.icon),
              )
            else if (paused)
              IconButton(
                tooltip: 'استئناف التنزيل'.tr,
                onPressed: () =>
                    widget.controller.resumeChapterDownload(chapter.chapterId),
                icon: Icon(Icons.play_circle_outline_rounded, color: AppColors.primary),
              )
            else if (failed)
              IconButton(
                tooltip: 'إعادة المحاولة'.tr,
                onPressed: () =>
                    widget.controller.retryChapterDownload(chapter.chapterId),
                icon: Icon(Icons.refresh_rounded, color: AppColors.error),
              )
            else if (downloaded)
              IconButton(
                tooltip: 'حذف الفصل المحلي'.tr,
                onPressed: () => _confirmDeleteChapter(chapter),
                icon: Icon(Icons.delete_outline_rounded, color: AppColors.error),
              )
            else if (widget.comic.type.toLowerCase() != 'novel')
              IconButton(
                tooltip: 'تنزيل الفصل'.tr,
                onPressed: () => widget.controller.downloadChapter(
                  chapter,
                  widget.comic.comicId,
                  widget.comic.title,
                  widget.comic.coverImage,
                ),
                icon: Icon(Icons.download_rounded, color: AppColors.primary),
              ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteChapter(Chapter chapter) {
    Get.defaultDialog(
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
      'comicType': widget.comic.type,
      'chapterTitle': chapter.title,
      'chapterNavigation': widget.comic.chapters
          .map((item) => {
                'chapterId': item.chapterId,
                'title': item.title,
                'url': item.link,
              })
          .toList(growable: false),
    });
  }
}
