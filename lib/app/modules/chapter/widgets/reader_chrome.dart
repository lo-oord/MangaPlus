import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/core/reader/reader_image_source.dart';
import 'package:mangaplus/app/modules/chapter/controllers/chapter_controller.dart';

/// How long the reader chrome stays visible after the last interaction.
const Duration kReaderChromeAutoHideDelay = Duration(milliseconds: 4200);

/// Owns the "hide the toolbars while reading" timer.
///
/// The timer lives outside the widget tree so it can be tested and cancelled
/// deterministically. Callers schedule it whenever chrome becomes visible or is
/// touched, pause it while a sheet is open, and dispose it with the view.
class ReaderChromeAutoHide {
  ReaderChromeAutoHide({
    required this.onHide,
    this.delay = kReaderChromeAutoHideDelay,
  });

  final VoidCallback onHide;
  final Duration delay;

  Timer? _timer;
  bool _paused = false;
  bool _disposed = false;

  bool get isPending => _timer?.isActive ?? false;
  bool get isPaused => _paused;

  /// Restarts the countdown. Ignored while paused or disposed.
  void schedule() {
    if (_disposed || _paused) return;
    _timer?.cancel();
    _timer = Timer(delay, () {
      _timer = null;
      if (!_disposed) onHide();
    });
  }

  /// Stops the countdown; used when chrome is hidden or a modal opens.
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// Prevents auto-hide while the reader is busy (chapter switch, sheet open).
  void pause() {
    _paused = true;
    cancel();
  }

  void resume() {
    _paused = false;
  }

  void dispose() {
    _disposed = true;
    cancel();
  }
}

/// Reader chrome palette, kept in one place so the two bars match.
class _ChromeColors {
  static const Color surface = Color(0xf2181b20);
  static const Color outline = Color(0x14ffffff);
}

/// Top bar: identity (cover, manga title, chapter), progress and quick actions.
class ReaderTopBar extends StatelessWidget {
  const ReaderTopBar({
    super.key,
    required this.comicTitle,
    required this.chapterTitle,
    required this.coverReference,
    required this.pageLabel,
    required this.progress,
    required this.onBack,
    required this.onBookmark,
    required this.onTools,
    this.onInteraction,
    this.hasBookmark = false,
  });

  final String comicTitle;
  final String chapterTitle;
  final String coverReference;
  final String pageLabel;
  final double progress;
  final VoidCallback onBack;
  final VoidCallback onBookmark;
  final VoidCallback onTools;
  final VoidCallback? onInteraction;
  final bool hasBookmark;

  @override
  Widget build(BuildContext context) {
    final percent = (progress.clamp(0.0, 1.0) * 100).round();
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: onInteraction == null ? null : (_) => onInteraction!(),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: .92),
              Colors.black.withValues(alpha: .55),
              Colors.transparent,
            ],
            stops: const [0, .72, 1],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 6, 22),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _ChromeIcon(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'رجوع',
                  onTap: onBack,
                ),
                const SizedBox(width: 2),
                _CoverThumb(reference: coverReference),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (comicTitle.trim().isNotEmpty)
                        Text(
                          comicTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                          ),
                        ),
                      Text(
                        chapterTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white
                              .withValues(alpha: comicTitle.isEmpty ? .92 : .62),
                          fontSize: comicTitle.isEmpty ? 13.5 : 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _InfoPill(label: pageLabel, icon: Icons.auto_stories),
                          const SizedBox(width: 6),
                          _InfoPill(label: '$percent%'),
                        ],
                      ),
                    ],
                  ),
                ),
                _ChromeIcon(
                  icon: hasBookmark
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_add_outlined,
                  tooltip: 'حفظ موضع القراءة',
                  onTap: onBookmark,
                  tint: hasBookmark ? AppColors.primary : null,
                ),
                _ChromeIcon(
                  icon: Icons.tune_rounded,
                  tooltip: 'أدوات القارئ',
                  onTap: onTools,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom bar: progress, page label and the five primary reading actions.
class ReaderBottomBar extends StatelessWidget {
  const ReaderBottomBar({
    super.key,
    required this.pageLabel,
    required this.progress,
    required this.onSeek,
    required this.onSeekEnd,
    required this.onPages,
    required this.onChapters,
    this.chapterTitle,
    this.onPreviousChapter,
    this.onNextChapter,
    this.onToggleMode,
    this.modeIcon = Icons.view_stream_rounded,
    this.modeTooltip = 'تبديل وضع القراءة',
    this.failedPages = 0,
    this.onRetryFailedPages,
    this.onInteraction,
  });

  final String pageLabel;
  final double progress;
  final ValueChanged<double> onSeek;
  final VoidCallback onSeekEnd;
  final VoidCallback onPages;
  final VoidCallback onChapters;
  final String? chapterTitle;
  final VoidCallback? onPreviousChapter;
  final VoidCallback? onNextChapter;
  final VoidCallback? onToggleMode;
  final IconData modeIcon;
  final String modeTooltip;
  final int failedPages;
  final VoidCallback? onRetryFailedPages;
  final VoidCallback? onInteraction;

  @override
  Widget build(BuildContext context) {
    final percent = (progress.clamp(0.0, 1.0) * 100).round();
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: onInteraction == null ? null : (_) => onInteraction!(),
      child: Container(
        decoration: const BoxDecoration(
          color: _ChromeColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: _ChromeColors.outline)),
          boxShadow: [
            BoxShadow(
              color: Color(0x59000000),
              blurRadius: 22,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(14, 6, 14, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      chapterTitle?.trim().isNotEmpty == true
                          ? chapterTitle!
                          : pageLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (failedPages > 0 && onRetryFailedPages != null)
                    TextButton.icon(
                      onPressed: onRetryFailedPages,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      icon: const Icon(Icons.error_outline_rounded, size: 15),
                      label: Text(
                        '$failedPages فشل',
                        style: const TextStyle(fontSize: 10.5),
                      ),
                    ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$pageLabel • $percent%',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .82),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 32,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2.5,
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: Colors.white.withValues(alpha: .14),
                    thumbColor: AppColors.primary,
                    overlayColor: AppColors.primary.withValues(alpha: .12),
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6.5),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 15),
                  ),
                  child: Slider(
                    value: progress.clamp(0.0, 1.0),
                    onChanged: onSeek,
                    onChangeStart: (_) => onInteraction?.call(),
                    onChangeEnd: (_) => onSeekEnd(),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ChromeIcon(
                    icon: Icons.grid_view_rounded,
                    tooltip: 'الصفحات',
                    onTap: onPages,
                  ),
                  _ChromeIcon(
                    icon: Icons.chevron_left_rounded,
                    tooltip: 'الفصل السابق',
                    onTap: onPreviousChapter,
                  ),
                  _ChromeIcon(
                    icon: modeIcon,
                    tooltip: modeTooltip,
                    onTap: onToggleMode,
                  ),
                  _ChromeIcon(
                    icon: Icons.chevron_right_rounded,
                    tooltip: 'الفصل التالي',
                    onTap: onNextChapter,
                  ),
                  _ChromeIcon(
                    icon: Icons.format_list_numbered_rounded,
                    tooltip: 'قائمة الفصول',
                    onTap: onChapters,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: Colors.white.withValues(alpha: .72)),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .86),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverThumb extends StatelessWidget {
  const _CoverThumb({required this.reference});

  final String reference;

  @override
  Widget build(BuildContext context) {
    final ref = reference.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 34,
        height: 46,
        child: ref.isEmpty
            ? const _CoverFallback()
            : Image(
                image: readerImageProvider(
                  ref,
                  headers: isLocalReaderImage(ref)
                      ? null
                      : readerImageHeaders(ref),
                  maxWidth: 140,
                ),
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => const _CoverFallback(),
                frameBuilder: (context, child, frame, sync) =>
                    frame != null || sync ? child : const _CoverFallback(),
              ),
      ),
    );
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white.withValues(alpha: .08),
      child: Icon(
        Icons.auto_stories_rounded,
        size: 17,
        color: Colors.white.withValues(alpha: .5),
      ),
    );
  }
}

class _ChromeIcon extends StatelessWidget {
  const _ChromeIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.tint,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon, size: 21),
      color: onTap == null
          ? Colors.white.withValues(alpha: .26)
          : tint ?? Colors.white.withValues(alpha: .9),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 42, height: 40),
      visualDensity: VisualDensity.compact,
    );
  }
}

/// Thumbnail page navigator.
///
/// Thumbnails decode at a small width instead of reusing full page bitmaps, so
/// opening the navigator cannot inflate the image cache or drop page quality.
Future<void> showReaderPageNavigator(
  BuildContext context,
  ChapterController controller, {
  required Future<void> Function(int page) onJumpToPage,
}) {
  final pages = controller.chapterData.value.chapter.images;
  if (pages.isEmpty) return Future<void>.value();
  return Get.bottomSheet(
    SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .82,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 10, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'الصفحات',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Obx(
                          () => Text(
                            '${controller.currentChapterTitle} • '
                            '${controller.currentPage.value + 1} / ${pages.length}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'إغلاق',
                    onPressed: Get.back,
                    icon: Icon(Icons.close_rounded, color: AppColors.icon),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Obx(
                () => GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: .62,
                  ),
                  itemCount: pages.length,
                  itemBuilder: (context, index) {
                    final current = index == controller.currentPage.value;
                    return _PageThumb(
                      reference: pages[index],
                      index: index,
                      current: current,
                      onTap: () {
                        Get.back();
                        onJumpToPage(index);
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    backgroundColor: AppColors.card,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
  );
}

class _PageThumb extends StatelessWidget {
  const _PageThumb({
    required this.reference,
    required this.index,
    required this.current,
    required this.onTap,
  });

  final String reference;
  final int index;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final local = isLocalReaderImage(reference);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: current ? AppColors.primary : AppColors.divider,
            width: current ? 2 : 1,
          ),
          color: AppColors.searchBar,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image(
              image: readerImageProvider(
                reference,
                headers: local ? null : readerImageHeaders(reference),
                maxWidth: 160,
              ),
              fit: BoxFit.cover,
              gaplessPlayback: true,
              filterQuality: FilterQuality.low,
              errorBuilder: (_, __, ___) => Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  size: 18,
                  color: AppColors.icon,
                ),
              ),
              frameBuilder: (context, child, frame, sync) => frame != null || sync
                  ? child
                  : ColoredBox(color: AppColors.searchBar),
            ),
            PositionedDirectional(
              bottom: 2,
              start: 2,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .62),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(color: Colors.white, fontSize: 9.5),
                ),
              ),
            ),
            if (current)
              PositionedDirectional(
                top: 3,
                end: 3,
                child: Icon(
                  Icons.play_circle_fill_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Chapter list sheet used by the reader chrome.
Future<void> showReaderChapterList(
  BuildContext context,
  ChapterController controller,
) async {
  await controller.ensureChapterNavigation();
  if (!context.mounted) return;
  final chapters = controller.availableChapters;
  if (chapters.isEmpty) return;
  await Get.bottomSheet(
    SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .8,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 10, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'الفصول',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${chapters.length}',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  IconButton(
                    tooltip: 'إغلاق',
                    onPressed: Get.back,
                    icon: Icon(Icons.close_rounded, color: AppColors.icon),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Obx(
                () => ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
                  itemCount: chapters.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final item = chapters[index];
                    final current = controller.isCurrentChapter(item);
                    final read = controller.isChapterRead(item.chapterId);
                    return ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      tileColor: current
                          ? AppColors.primary.withValues(alpha: .13)
                          : AppColors.searchBar,
                      leading: Icon(
                        current
                            ? Icons.play_circle_fill_rounded
                            : Icons.menu_book_rounded,
                        color: current ? AppColors.primary : AppColors.icon,
                        size: 21,
                      ),
                      title: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight:
                              current ? FontWeight.w800 : FontWeight.w500,
                        ),
                      ),
                      trailing: read
                          ? Text(
                              'مقروء',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : null,
                      onTap: current
                          ? null
                          : () {
                              Get.back();
                              controller.navigateToChapter(item.chapterId);
                            },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    backgroundColor: AppColors.card,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
  );
}
