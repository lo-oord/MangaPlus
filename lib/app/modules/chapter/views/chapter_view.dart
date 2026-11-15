import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/core/theme/app_motion.dart';
import 'package:mangaplus/app/core/reader/novel_reader_model.dart';
import 'package:mangaplus/app/core/reader/novel_typography.dart';
import 'package:mangaplus/app/core/reader/reader_page_geometry.dart';
import 'package:mangaplus/app/core/utils/bidi_text.dart';
import 'package:mangaplus/app/modules/chapter/controllers/chapter_controller.dart';
import 'package:mangaplus/app/modules/chapter/widgets/reader_chrome.dart';
import 'package:mangaplus/app/modules/chapter/widgets/reader_manga_page.dart';
import 'package:mangaplus/app/modules/chapter/widgets/reader_novel_chrome.dart';
import 'package:mangaplus/app/modules/chapter/widgets/reader_tools_sheet.dart';
import 'package:mangaplus/app/widgets/app_feedback.dart';
import 'package:mangaplus/app/widgets/brand_state.dart';
import 'package:mangaplus/app/widgets/theme_aware_builder.dart';

class ChapterView extends StatefulWidget {
  const ChapterView({super.key});

  @override
  State<ChapterView> createState() => _ChapterViewState();
}

class _ChapterViewState extends State<ChapterView>
    with TickerProviderStateMixin {
  // Resolved once. `Get.find` is a service-locator lookup and this accessor is
  // read dozens of times per build and per scroll notification.
  late final ChapterController c = Get.find<ChapterController>();

  ReaderPageScrollIndex _index = ReaderPageScrollIndex.empty;
  String _indexSignature = '';
  int _anchorPage = 0;
  double _anchorFraction = .5;
  bool _restoreScheduled = false;
  bool _initialScrollSynced = false;
  String? _indexedChapterId;
  int _lastWindowFirst = -1;
  int _lastWindowLast = -1;
  bool _pageSyncScheduled = false;
  double _lastScrollOffset = 0;
  int _lastPagedPage = 0;

  final Map<int, GlobalKey> _paragraphKeys = <int, GlobalKey>{};
  int _novelAnchor = 0;
  int _lastNovelRevision = -1;
  int _lastSpeechParagraph = -1;

  late final ReaderChromeAutoHide _chromeAutoHide =
      ReaderChromeAutoHide(onHide: _autoHideChrome);

  Offset? _novelPointerStart;
  DateTime? _novelPointerTime;

  /// SelectionArea wins the gesture arena for taps, so tapping the novel text
  /// never reached the chrome toggle. Raw pointer events still arrive here and
  /// a short, stationary tap is treated as a chrome toggle.
  void _onNovelPointerDown(PointerDownEvent event) {
    _novelPointerStart = event.position;
    _novelPointerTime = DateTime.now();
  }

  void _onNovelPointerUp(PointerUpEvent event) {
    final start = _novelPointerStart;
    final at = _novelPointerTime;
    _novelPointerStart = null;
    _novelPointerTime = null;
    if (start == null || at == null) return;
    if ((event.position - start).distance > 14) return;
    if (DateTime.now().difference(at) > const Duration(milliseconds: 350)) {
      return;
    }
    c.toggleNavigationVisibility();
    _noteChromeInteraction();
  }

  Ticker? _autoScrollTicker;
  Duration _lastTick = Duration.zero;
  Ticker? _mangaAutoScrollTicker;
  Duration _mangaTick = Duration.zero;
  Worker? _speechWorker;
  Worker? _autoScrollWorker;
  Worker? _chromeWorker;
  Worker? _chromeBusyWorker;
  Worker? _mangaAutoScrollWorker;
  Worker? _readerModeWorker;
  bool _keyPruneScheduled = false;

  @override
  void initState() {
    super.initState();
    // Speech and auto-scroll are side effects, not layout. Driving them from
    // workers keeps their state out of every build method, so a spoken word no
    // longer rebuilds the paragraph list.
    _speechWorker = ever<int>(
      c.novelSpeechCurrentParagraph,
      _onSpeechParagraphChanged,
    );
    _autoScrollWorker = ever<bool>(c.novelAutoScroll, (_) => _syncAutoScroll());
    // Auto-hide chrome: a quiet reader should not keep toolbars on screen, but
    // the countdown pauses for chapter switches and whenever a sheet is open.
    _chromeWorker = ever<bool>(c.showNavigation, _onChromeVisibilityChanged);
    _chromeBusyWorker = ever<bool>(c.isNavigating, (busy) {
      if (busy) {
        _chromeAutoHide.pause();
      } else {
        _chromeAutoHide.resume();
        if (c.showNavigation.value && c.readerAutoHideChrome.value) {
          _chromeAutoHide.schedule();
        }
      }
    });
    _mangaAutoScrollWorker = ever<bool>(
      c.mangaAutoScroll,
      (_) => _syncMangaAutoScroll(),
    );
    _readerModeWorker = ever<String>(
      c.readerMode,
      (_) => _syncMangaAutoScroll(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncAutoScroll();
        _syncMangaAutoScroll();
      }
    });
  }

  @override
  void dispose() {
    _speechWorker?.dispose();
    _autoScrollWorker?.dispose();
    _chromeWorker?.dispose();
    _chromeBusyWorker?.dispose();
    _mangaAutoScrollWorker?.dispose();
    _readerModeWorker?.dispose();
    _mangaAutoScrollTicker?.dispose();
    _chromeAutoHide.dispose();
    _autoScrollTicker?.dispose();
    _paragraphKeys.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ThemeAwareBuilder(
      builder: (context) => Scaffold(
        backgroundColor: _readerBackground(),
        body: Stack(
          children: [
            Positioned.fill(child: _buildBody(context)),
            _buildPageLoadChip(context),
            _buildBrightnessOverlay(),
            _buildChrome(context),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Content
  // ---------------------------------------------------------------------

  Widget _buildBody(BuildContext context) {
    return Obx(() {
      // Subscribe to every layout-affecting setting once. The page list itself
      // never depends on scroll progress, so it is not rebuilt while scrolling.
      final mode = c.readerMode.value;
      final fit = c.readerFit.value;
      final gap = c.readerPageGap.value;
      final metrics = c.pageMetricsRevision.value;
      final doublePage = c.readerDoublePage.value;
      final showTitle = c.showChapterTitle.value;
      final isNovel = c.isNovel;
      final offline = c.isOffline.value;
      c.novelLayoutRevision.value;

      if (c.isLoading.value && !c.hasReadableContent) {
        return BrandState(
          title: 'جارٍ تحميل الفصل'.tr,
          description: 'يتم تجهيز صفحات الفصل'.tr,
          loading: true,
        );
      }
      if (c.hasError.value) {
        final issue = c.loadIssue.value;
        return BrandState(
          title: (issue?.titleKey ?? 'تعذر تحميل الفصل').tr,
          description:
              (issue?.descriptionKey ?? 'تعذر تحميل المحتوى. حاول مجددًا.').tr,
          icon: issue?.icon ?? Icons.error_outline_rounded,
          actionLabel: 'إعادة المحاولة'.tr,
          onAction: () => c.fetchChapter(c.chapterId),
        );
      }
      final chapter = c.chapterData.value.chapter;
      if (isNovel) {
        if (chapter.content.trim().isEmpty) {
          return BrandState(
            title: 'لا يوجد محتوى نصي متاح'.tr,
            actionLabel: 'إعادة المحاولة'.tr,
            onAction: () => c.fetchChapter(c.chapterId),
          );
        }
        return _buildNovel(context, chapter);
      }
      if (chapter.images.isEmpty) {
        return BrandState(
          title: 'لا توجد صور متاحة'.tr,
          actionLabel: 'إعادة المحاولة'.tr,
          onAction: () => c.fetchChapter(c.chapterId),
        );
      }
      // Keep the unused reads referenced so the analyzer does not drop them;
      // the values above are genuine Obx dependencies.
      assert(mode.isNotEmpty &&
          fit.isNotEmpty &&
          gap >= 0 &&
          metrics >= 0 &&
          (doublePage || !doublePage) &&
          (showTitle || !showTitle) &&
          (offline || !offline));
      return mode == 'paged'
          ? _buildPaged(context, chapter.images)
          : _buildScroll(context, chapter.images);
    });
  }

  Widget _buildScroll(BuildContext context, List<String> images) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        _ensureScrollIndex(images, width, height);
        _syncInitialScroll();
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: c.toggleNavigationVisibility,
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScrollNotification,
            child: ListView.builder(
              controller: c.scrollController,
              // The list is given the exact extent of every page, measured or
              // reserved. This removes the guesswork that made the old list
              // shift while images finished decoding.
              itemExtentBuilder: (index, dimensions) =>
                  _index.startOf(index + 1) - _index.startOf(index),
              itemCount: images.length,
              cacheExtent: height * 1.5,
              physics: const ClampingScrollPhysics(),
              itemBuilder: (context, index) {
                final extent =
                    _index.startOf(index + 1) - _index.startOf(index);
                final isStart = c.isChapterStartPage(index);
                final dividerHeight = !isStart
                    ? 0.0
                    : c.showChapterTitle.value
                        ? 34.0
                        : 14.0;
                return ReaderMangaPage(
                  reference: images[index],
                  pageIndex: index,
                  extent: extent,
                  gap: c.readerPageGap.value,
                  fitValue: c.readerFit.value,
                  imageQuality: c.readerImageQuality.value,
                  retryToken: c.pageRetryToken(index),
                  viewportWidth: width,
                  viewportHeight: height,
                  pageSize: c.pageSizeAt(index),
                  chapterDividerHeight: dividerHeight,
                  chapterDividerTitle:
                      isStart ? c.chapterDividerTitleForPage(index) : null,
                  backgroundColor: _pageBackground(),
                  onLoaded: () => c.markPageLoaded(
                    index,
                    pageReference: images[index],
                  ),
                  onFailed: () => c.markPageFailed(
                    index,
                    pageReference: images[index],
                  ),
                  onRetry: () => c.retryPage(
                    index,
                    pageReference: images[index],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _ensureScrollIndex(
    List<String> images,
    double width,
    double height,
  ) {
    final signature = [
      c.chapterId,
      images.length,
      c.readerFit.value,
      c.readerPageGap.value,
      c.pageMetricsRevision.value,
      c.showChapterTitle.value,
      c.readerChapterPageRanges
          .map((range) => '${range.startIndex}:${range.chapterId}')
          .join(','),
      width.round(),
      height.round(),
    ].join('|');
    if (signature == _indexSignature) return;
    final extents = <double>[
      for (var index = 0; index < images.length; index++)
        c.mangaPageExtent(
          index,
          viewportWidth: width,
          viewportHeight: height,
        ),
    ];
    final firstBuildForChapter = _indexedChapterId != c.chapterId;
    _index = ReaderPageScrollIndex(extents);
    _indexSignature = signature;
    if (firstBuildForChapter) {
      _indexedChapterId = c.chapterId;
      _initialScrollSynced = false;
      // Do not read `currentPage` here. This runs inside the body's Obx, and
      // reading it would subscribe the entire page list to the page number, so
      // every page change would rebuild every visible page widget. The restored
      // position already lives in the scroll offset, so the anchor is derived
      // from that; it is refined again in the first post-frame sync.
      final scroll = c.scrollController;
      _anchorPage = scroll.hasClients
          ? _index
              .positionAt(
                scroll.offset,
                scroll.position.viewportDimension,
                fallbackIndex: _anchorPage,
              )
              .index
          : _anchorPage.clamp(0, images.length - 1).toInt();
      _anchorFraction = .5;
      _lastWindowFirst = -1;
      _lastWindowLast = -1;
    } else {
      _scheduleAnchorRestore(height);
    }
  }

  void _syncInitialScroll() {
    if (_initialScrollSynced) return;
    _initialScrollSynced = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      c.syncScrollController();
      final scroll = c.scrollController;
      if (!scroll.hasClients || _index.pageCount == 0) return;
      final position = _index.positionAt(
        scroll.offset,
        scroll.position.viewportDimension,
        fallbackIndex: _anchorPage,
      );
      _anchorPage = position.index;
      _anchorFraction = position.fractionWithinPage;
      c.onMangaWindowChanged(
        firstVisible: position.index,
        lastVisible: position.index,
      );
    });
  }

  /// Corrects the scroll offset by exactly the amount a newly measured page
  /// above the anchor changed the layout, without ever touching pages below it.
  void _scheduleAnchorRestore(double viewport) {
    if (_restoreScheduled) return;
    _restoreScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreScheduled = false;
      if (!mounted || _index.pageCount == 0) return;
      final scroll = c.scrollController;
      if (!scroll.hasClients) return;
      final start = _index.startOf(_anchorPage);
      final end = _index.startOf(_anchorPage + 1);
      final extent = end - start;
      final target = (start + _anchorFraction * extent - viewport / 2)
          .clamp(0.0, scroll.position.maxScrollExtent)
          .toDouble();
      if ((scroll.offset - target).abs() > 1) scroll.jumpTo(target);
    });
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    final metrics = notification.metrics;
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null &&
        c.mangaAutoScroll.value) {
      // A manual drag always wins over automatic scrolling.
      c.setMangaAutoScroll(false);
    }
    if (notification is ScrollUpdateNotification) {
      c.handleScroll(
        metrics,
        scrollDelta: notification.scrollDelta,
        userInitiated: notification.dragDetails != null,
      );
      _updateMangaPosition(metrics);
    } else if (notification is ScrollEndNotification) {
      c.handleScroll(metrics, settled: true);
      _updateMangaPosition(metrics, forceWindow: true);
      c.persistScrollOffset(metrics.pixels);
    } else if (notification is OverscrollNotification) {
      c.handleScroll(
        metrics,
        scrollDelta: notification.overscroll < 0 ? -1.0 : 1.0,
      );
    }
    return false;
  }

  void _updateMangaPosition(ScrollMetrics metrics, {bool forceWindow = false}) {
    if (_index.pageCount == 0) return;
    final delta = metrics.pixels - _lastScrollOffset;
    _lastScrollOffset = metrics.pixels;
    final direction = delta.abs() < .5 ? 0 : (delta > 0 ? 1 : -1);
    final position = _index.positionAt(
      metrics.pixels,
      metrics.viewportDimension,
      fallbackIndex: _anchorPage,
    );
    _anchorPage = position.index;
    _anchorFraction = position.fractionWithinPage;
    c.updateImageScrollProgress(position.index, position.fractionWithinPage);
    final first = _index
        .positionAt(metrics.pixels, 1, fallbackIndex: position.index)
        .index;
    final last = _index
        .positionAt(
          metrics.pixels + metrics.viewportDimension - 1,
          1,
          fallbackIndex: position.index,
        )
        .index;
    if (forceWindow || first != _lastWindowFirst || last != _lastWindowLast) {
      _lastWindowFirst = first;
      _lastWindowLast = last;
      c.onMangaWindowChanged(
        firstVisible: first,
        lastVisible: last,
        direction: direction,
      );
    }
  }

  int get _pagesPerSpread {
    if (!c.readerDoublePage.value) return 1;
    return MediaQuery.orientationOf(context) == Orientation.landscape ? 2 : 1;
  }

  Widget _buildPaged(BuildContext context, List<String> images) {
    final perSpread = _pagesPerSpread;
    final spreadCount = (images.length / perSpread).ceil();
    final rtl = c.readingDirection.value == 'rtl';
    // One pending callback is enough; without this guard every rebuild of the
    // paged reader queued another full page-controller sync.
    if (!_pageSyncScheduled) {
      _pageSyncScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pageSyncScheduled = false;
        if (mounted) c.syncPageController();
      });
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) => _handlePagedTap(details, images.length, perSpread),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: PageView.builder(
          controller: c.pageController,
          reverse: rtl,
          allowImplicitScrolling: true,
          itemCount: spreadCount,
          onPageChanged: (spread) {
            final page = spread * perSpread;
            final direction = page == _lastPagedPage
                ? 0
                : (page > _lastPagedPage ? 1 : -1);
            _lastPagedPage = page;
            c.onPageChanged(page);
            c.onMangaWindowChanged(
              firstVisible: page,
              lastVisible: page + perSpread + 1,
              direction: direction,
            );
          },
          itemBuilder: (context, spread) {
            final firstPage = spread * perSpread;
            final secondPage = perSpread > 1 && firstPage + 1 < images.length
                ? firstPage + 1
                : null;
            return LayoutBuilder(
              builder: (context, constraints) => Directionality(
                textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                child: Row(
                  children: [
                    Expanded(child: _pagedPage(context, images, firstPage)),
                    if (perSpread > 1)
                      Expanded(
                        child: secondPage == null
                            ? const SizedBox.shrink()
                            : _pagedPage(context, images, secondPage),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _pagedPage(BuildContext context, List<String> images, int index) {
    final size = MediaQuery.sizeOf(context);
    return ReaderMangaPage(
      reference: images[index],
      pageIndex: index,
      extent: size.height,
      gap: 0,
      fitValue: c.readerFit.value,
      imageQuality: c.readerImageQuality.value,
      retryToken: c.pageRetryToken(index),
      viewportWidth: size.width / _pagesPerSpread,
      viewportHeight: size.height,
      pageSize: c.pageSizeAt(index),
      zoomEnabled: true,
      backgroundColor: _pageBackground(),
      onLoaded: () => c.markPageLoaded(index, pageReference: images[index]),
      onFailed: () => c.markPageFailed(index, pageReference: images[index]),
      onRetry: () => c.retryPage(index, pageReference: images[index]),
    );
  }

  void _handlePagedTap(TapUpDetails details, int pageCount, int perSpread) {
    final width = MediaQuery.sizeOf(context).width;
    final x = details.localPosition.dx;
    if (x > width * .32 && x < width * .68) {
      c.toggleNavigationVisibility();
      return;
    }
    final rtl = c.readingDirection.value == 'rtl';
    final isNext = rtl ? x >= width * .68 : x <= width * .32;
    final spreadCount = (pageCount / perSpread).ceil();
    final currentSpread = (c.currentPage.value / perSpread).floor();
    if (isNext) {
      if (currentSpread + 1 < spreadCount) {
        c.pageController.nextPage(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        );
      } else {
        c.navigateToChapter(c.nextChapterId, joinContinuousStream: true);
      }
    } else {
      if (currentSpread > 0) {
        c.pageController.previousPage(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        );
      } else {
        c.navigateToChapter(
          c.previousChapterId,
          reverse: true,
          joinContinuousStream: true,
        );
      }
    }
  }

  // ---------------------------------------------------------------------
  // Novel reader
  // ---------------------------------------------------------------------

  Widget _buildNovel(BuildContext context, dynamic chapter) {
    return FutureBuilder<List<String>>(
      future: c.paragraphsFor(chapter.content as String),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return ColoredBox(
            color: _readerBackground(),
            child: const Center(
              child: SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return BrandState(
            title: 'تعذر تحميل الفصل'.tr,
            actionLabel: 'إعادة المحاولة'.tr,
            onAction: () => c.fetchChapter(c.chapterId),
          );
        }
        final paragraphs = snapshot.data!;
        final content = chapter.content as String;
        final direction = _novelDirection(content);
        final palette = _novelPalette();
        final horizontalPadding = novelReadingPadding(
          viewportWidth: MediaQuery.sizeOf(context).width,
          margins: c.novelMargins.value,
          maxWidth: c.novelContentWidth.value,
        );
        if (_lastNovelRevision != c.novelLayoutRevision.value) {
          _lastNovelRevision = c.novelLayoutRevision.value;
          _scheduleNovelAnchorRestore();
        }
        // Speech state is deliberately not read here: it changes on every
        // spoken word and would rebuild this whole paragraph list each time.
        // Each paragraph observes it in its own small widget instead.
        _scheduleKeyPrune();
        return ColoredBox(
          color: palette.background,
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: _onNovelPointerDown,
            onPointerUp: _onNovelPointerUp,
            onPointerCancel: (_) => _novelPointerStart = null,
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.depth != 0) return false;
                final metrics = notification.metrics;
                if (notification is ScrollStartNotification &&
                    notification.dragDetails != null &&
                    c.novelAutoScroll.value) {
                  // Touching the page always takes control from auto-scroll.
                  c.setNovelAutoScroll(false);
                }
                if (notification is ScrollUpdateNotification) {
                  c.updateNovelProgress(
                    metrics.pixels,
                    metrics.maxScrollExtent,
                  );
                  c.handleScroll(
                    metrics,
                    scrollDelta: notification.scrollDelta,
                    userInitiated: notification.dragDetails != null,
                  );
                } else if (notification is ScrollEndNotification) {
                  c.updateNovelProgress(
                    metrics.pixels,
                    metrics.maxScrollExtent,
                  );
                  c.handleScroll(metrics, settled: true);
                  c.persistScrollOffset(metrics.pixels);
                  _captureNovelAnchor();
                } else if (notification is OverscrollNotification) {
                  c.handleScroll(
                    metrics,
                    scrollDelta: notification.overscroll < 0 ? -1.0 : 1.0,
                  );
                }
                return false;
              },
              child: Directionality(
                textDirection: direction,
                child: SelectionArea(
                  child: ListView.builder(
                    controller: c.scrollController,
                    cacheExtent: 900,
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      MediaQuery.paddingOf(context).top + 68,
                      horizontalPadding,
                      MediaQuery.paddingOf(context).bottom + 120,
                    ),
                    itemCount: paragraphs.length,
                    itemBuilder: (context, index) {
                      final paragraph = paragraphs[index];
                      if (isNovelChapterDivider(paragraph)) {
                        return _novelDivider(
                          title: c.showChapterTitle.value
                              ? titleFromNovelChapterDivider(paragraph)
                              : '',
                          palette: palette,
                        );
                      }
                      final notes = c.notesForParagraph(index);
                      return _NovelParagraph(
                        key: _paragraphKeys.putIfAbsent(index, GlobalKey.new),
                        controller: c,
                        paragraphIndex: index,
                        paragraph: paragraph,
                        notes: notes,
                        textAlign: _novelTextAlign(direction),
                        bottomPadding: index == paragraphs.length - 1
                            ? 0
                            : c.novelParagraphSpacing.value,
                        style: TextStyle(
                          color: palette.text,
                          fontSize: MediaQuery.textScalerOf(context)
                              .scale(c.novelFontSize.value),
                          fontFamily: c.novelFontFamily.value == 'default'
                              ? null
                              : c.novelFontFamily.value,
                          fontWeight: FontWeight.values[
                              ((c.novelFontWeight.value ~/ 100) - 3)
                                  .clamp(0, 5)
                                  .toInt()],
                          height: c.novelLineHeight.value,
                          letterSpacing: c.novelLetterSpacing.value,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  TextDirection _novelDirection(String content) {
    switch (c.novelTextDirection.value) {
      case 'rtl':
        return TextDirection.rtl;
      case 'ltr':
        return TextDirection.ltr;
      default:
        return bidiTextDirection(content, fallback: TextDirection.rtl);
    }
  }

  TextAlign _novelTextAlign(TextDirection direction) {
    switch (c.novelTextAlign.value) {
      case 'justify':
        return TextAlign.justify;
      case 'start':
        return TextAlign.start;
      default:
        return TextAlign.start;
    }
  }

  Widget _novelDivider({
    required String title,
    required ({Color background, Color text}) palette,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: palette.text.withValues(alpha: .16),
              height: 1,
            ),
          ),
          if (title.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                title,
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          Expanded(
            child: Divider(
              color: palette.text.withValues(alpha: .16),
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  void _captureNovelAnchor() {
    if (!c.isNovel || !c.scrollController.hasClients) return;
    final scroll = c.scrollController;
    final viewportTop = scroll.offset + MediaQuery.paddingOf(context).top + 40;
    var bestIndex = _novelAnchor;
    var bestDistance = double.infinity;
    for (final entry in _paragraphKeys.entries) {
      final box = entry.value.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      final distance = (top - viewportTop).abs();
      if (top <= viewportTop + 40 && distance < bestDistance) {
        bestDistance = distance;
        bestIndex = entry.key;
      }
    }
    _novelAnchor = bestIndex;
  }

  void _scheduleNovelAnchorRestore() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _jumpToParagraph(_novelAnchor, animate: false);
    });
  }

  Future<void> _jumpToParagraph(int index, {bool animate = true}) async {
    if (!c.isNovel) return;
    final paragraphs =
        await c.paragraphsFor(c.chapterData.value.chapter.content);
    if (index < 0 || index >= paragraphs.length) return;
    final key = _paragraphKeys[index];
    final context = key?.currentContext;
    if (context != null) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final ctx = key?.currentContext;
        if (ctx == null) return;
        Scrollable.ensureVisible(
          ctx,
          alignment: .06,
          duration: animate ? const Duration(milliseconds: 260) : Duration.zero,
          curve: Curves.easeOutCubic,
        );
        _novelAnchor = index;
      });
      return;
    }
    final scroll = c.scrollController;
    if (!scroll.hasClients) return;
    final average = _averageParagraphExtent();
    final target = (index * average)
        .clamp(0.0, scroll.position.maxScrollExtent)
        .toDouble();
    scroll.jumpTo(target);
    // Let the list build the target area, then align precisely. A handful of
    // passes converge even for very long chapters.
    for (var attempt = 0; attempt < 6; attempt++) {
      await WidgetsBinding.instance.endOfFrame;
      final targetKey = _paragraphKeys[index];
      if (targetKey == null) continue;
      final targetContext = targetKey.currentContext;
      if (targetContext != null) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final ctx = targetKey.currentContext;
          if (ctx == null) return;
          Scrollable.ensureVisible(
            ctx,
            alignment: .06,
            duration: animate && attempt == 0
                ? const Duration(milliseconds: 220)
                : Duration.zero,
          );
          _novelAnchor = index;
        });
        return;
      }
      final position = scroll.position;
      final direction =
          index > _approximateParagraphAt(scroll.offset, average) ? 1 : -1;
      final next = (scroll.offset + direction * position.viewportDimension * .6)
          .clamp(0.0, position.maxScrollExtent)
          .toDouble();
      if ((next - scroll.offset).abs() < 1) break;
      scroll.jumpTo(next);
    }
    _novelAnchor = index;
  }

  double _averageParagraphExtent() {
    var total = 0.0;
    var count = 0;
    for (final entry in _paragraphKeys.entries) {
      final box = entry.value.currentContext?.findRenderObject();
      if (box is RenderBox && box.hasSize) {
        total += box.size.height + c.novelParagraphSpacing.value;
        count++;
      }
    }
    if (count == 0) {
      return c.novelFontSize.value * c.novelLineHeight.value * 4.2;
    }
    return total / count;
  }

  int _approximateParagraphAt(double offset, double average) =>
      average <= 0 ? 0 : (offset / average).floor();

  void _onSpeechParagraphChanged(int paragraph) {
    final active = c.novelSpeechPlaying.value || c.novelSpeechPaused.value;
    if (!active || paragraph < 0) {
      _lastSpeechParagraph = -1;
      return;
    }
    if (paragraph == _lastSpeechParagraph) return;
    _lastSpeechParagraph = paragraph;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // `_jumpToParagraph` bounds-checks against the real paragraph list.
      if (mounted && c.isNovel) _jumpToParagraph(paragraph);
    });
  }

  /// Drops paragraph keys far away from the reading position.
  ///
  /// A key is only needed to jump to a paragraph. Keeping one `GlobalKey` per
  /// visited paragraph of a long novel retains a global element registry entry
  /// for text the reader has already left behind.
  void _scheduleKeyPrune() {
    if (_keyPruneScheduled || _paragraphKeys.length <= 400) return;
    _keyPruneScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _keyPruneScheduled = false;
      if (!mounted) return;
      final low = _novelAnchor - 80;
      final high = _novelAnchor + 320;
      _paragraphKeys.removeWhere((index, _) => index < low || index > high);
    });
  }

  void _syncAutoScroll() {
    final enabled = c.novelAutoScroll.value;
    if (!enabled) {
      _autoScrollTicker?.stop();
      return;
    }
    _autoScrollTicker ??= createTicker((elapsed) {
      final scroll = c.scrollController;
      if (!scroll.hasClients) return;
      if (_lastTick == Duration.zero) {
        _lastTick = elapsed;
        return;
      }
      final dt =
          (elapsed - _lastTick).inMicroseconds / Duration.microsecondsPerSecond;
      _lastTick = elapsed;
      if (dt <= 0 || dt > .25) return;
      final max = scroll.position.maxScrollExtent;
      if (scroll.offset >= max - .5) {
        c.setNovelAutoScroll(false);
        return;
      }
      final target =
          (scroll.offset + c.novelAutoScrollSpeed.value * dt).clamp(0.0, max);
      scroll.jumpTo(target);
    });
    if (!_autoScrollTicker!.isActive) {
      _lastTick = Duration.zero;
      _autoScrollTicker!.start();
    }
  }

  /// Auto-scroll for manga and webtoon modes. It drives the existing scroll
  /// controller at a fixed pixels-per-second rate, so it never changes the page
  /// layout and stops the moment the reader touches the screen.
  void _syncMangaAutoScroll() {
    final enabled = c.mangaAutoScroll.value &&
        !c.isNovel &&
        c.readerMode.value != 'paged';
    if (!enabled) {
      _mangaAutoScrollTicker?.stop();
      _mangaTick = Duration.zero;
      return;
    }
    _mangaAutoScrollTicker ??= createTicker((elapsed) {
      final scroll = c.scrollController;
      if (!scroll.hasClients) return;
      if (_mangaTick == Duration.zero) {
        _mangaTick = elapsed;
        return;
      }
      final dt =
          (elapsed - _mangaTick).inMicroseconds / Duration.microsecondsPerSecond;
      _mangaTick = elapsed;
      if (dt <= 0 || dt > .25) return;
      final max = scroll.position.maxScrollExtent;
      if (scroll.offset >= max - .5) {
        unawaited(c.setMangaAutoScroll(false));
        return;
      }
      final target =
          (scroll.offset + c.mangaAutoScrollSpeed.value * dt).clamp(0.0, max);
      scroll.jumpTo(target);
    });
    if (!_mangaAutoScrollTicker!.isActive) {
      _mangaTick = Duration.zero;
      _mangaAutoScrollTicker!.start();
    }
  }

  // ---------------------------------------------------------------------
  // Reader chrome
  // ---------------------------------------------------------------------

  Widget _buildChrome(BuildContext context) {
    return Obx(() {
      final visible = c.showNavigation.value;
      c.pageLoadRevision.value;
      final progress = c.readerProgress.value.clamp(0.0, 1.0).toDouble();
      final range = c.activeReaderPageRange;
      final totalPages =
          range?.pageCount ?? c.chapterData.value.chapter.images.length;
      final localPage = range == null
          ? c.currentPage.value
          : c.currentPage.value - range.startIndex;
      final title = c.chapterDividerTitle(c.activeReaderChapterId);
      final pageLabel = c.isNovel || totalPages <= 0
          ? '${(progress * 100).round()}%'
          : '${localPage + 1} / $totalPages';
      final comicTitle = '${c.arguments['comicTitle'] ?? ''}'.trim();
      final coverReference = '${c.arguments['coverImage'] ?? ''}'.trim();
      final paged = c.readerMode.value == 'paged';
      if (c.isNovel) {
        return Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _chromeTransition(
                context: context,
                visible: visible,
                fromTop: true,
                child: NovelReaderTopBar(
                  comicTitle: comicTitle,
                  chapterTitle: title,
                  pageLabel: pageLabel,
                  progress: progress,
                  onBack: Get.back,
                  onBookmark: _bookmarkCurrentPosition,
                  onTools: () => _openTools(context),
                  onInteraction: _noteChromeInteraction,
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _chromeTransition(
                context: context,
                visible: visible,
                fromTop: false,
                child: NovelReaderBottomBar(
                  chapterTitle: title,
                  pageLabel: pageLabel,
                  progress: progress,
                  listening: c.novelSpeechPlaying.value,
                  onListen: () => _openNovelTtsPanel(context),
                  onSeek: c.seekReaderProgress,
                  onSeekEnd: c.persistReaderProgress,
                  onChapters: () => _openChapterList(context),
                  onSettings: () => _openTools(context),
                  onPreviousChapter: c.previousChapterId == null
                      ? null
                      : () => c.navigateToChapter(
                            c.previousChapterId,
                            reverse: true,
                            joinContinuousStream: true,
                          ),
                  onNextChapter: c.nextChapterId == null
                      ? null
                      : () => c.navigateToChapter(
                            c.nextChapterId,
                            joinContinuousStream: true,
                          ),
                  onInteraction: _noteChromeInteraction,
                ),
              ),
            ),
          ],
        );
      }
      return Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _chromeTransition(
              context: context,
              visible: visible,
              fromTop: true,
              child: ReaderTopBar(
                comicTitle: comicTitle,
                chapterTitle: title,
                coverReference: coverReference,
                pageLabel: pageLabel,
                progress: progress,
                hasBookmark: c.readerBookmarks.isNotEmpty,
                onBack: Get.back,
                onBookmark: _bookmarkCurrentPosition,
                onTools: () => _openTools(context),
                onInteraction: _noteChromeInteraction,
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _chromeTransition(
              context: context,
              visible: visible,
              fromTop: false,
              child: ReaderBottomBar(
                chapterTitle: title,
                pageLabel: pageLabel,
                progress: progress,
                failedPages: c.failedPageCount,
                onRetryFailedPages: _retryFailedPages,
                onSeek: c.seekReaderProgress,
                onSeekEnd: c.persistReaderProgress,
                onPages: () => _openPageNavigator(context),
                onChapters: () => _openChapterList(context),
                onPreviousChapter: c.previousChapterId == null
                    ? null
                    : () => c.navigateToChapter(
                          c.previousChapterId,
                          reverse: true,
                          joinContinuousStream: true,
                        ),
                onNextChapter: c.nextChapterId == null
                    ? null
                    : () => c.navigateToChapter(
                          c.nextChapterId,
                          joinContinuousStream: true,
                        ),
                onToggleMode: c.isNovel
                    ? null
                    : () => c.setReaderMode(paged ? 'scroll' : 'paged'),
                modeIcon: c.isNovel
                    ? Icons.format_list_bulleted_rounded
                    : (paged
                        ? Icons.view_stream_rounded
                        : Icons.menu_book_rounded),
                modeTooltip: c.isNovel ? 'أدوات الرواية' : 'تبديل وضع القراءة',
                onInteraction: _noteChromeInteraction,
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _chromeTransition({
    required BuildContext context,
    required bool visible,
    required bool fromTop,
    required Widget child,
  }) {
    // The chrome hides instantly for reduced motion: a reader must never wait
    // for an effect to reach the page again.
    final slide = AppMotion.effective(context, AppMotion.chrome);
    final fade = AppMotion.effective(context, AppMotion.fast);
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : Offset(0, fromTop ? -1.1 : 1.1),
        duration: slide,
        curve: AppMotion.enter,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: fade,
          child: child,
        ),
      ),
    );
  }

  void _onChromeVisibilityChanged(bool visible) {
    if (!visible) {
      _chromeAutoHide.cancel();
      return;
    }
    if (c.readerAutoHideChrome.value) _chromeAutoHide.schedule();
  }

  void _noteChromeInteraction() {
    if (c.showNavigation.value) _chromeAutoHide.schedule();
  }

  void _autoHideChrome() {
    if (!mounted || !c.readerAutoHideChrome.value) return;
    if (c.isNavigating.value) {
      _chromeAutoHide.schedule();
      return;
    }
    if (c.showNavigation.value) c.toggleNavigationVisibility();
  }

  Future<void> _bookmarkCurrentPosition() async {
    await c.saveReaderBookmark();
    AppFeedback.show(title: 'العلامات', message: 'تم حفظ موضع القراءة.');
    _noteChromeInteraction();
  }

  void _retryFailedPages() {
    final images = c.chapterData.value.chapter.images;
    for (var index = 0; index < images.length; index++) {
      if (c.isPageFailed(index)) {
        c.retryPage(index, pageReference: images[index]);
      }
    }
  }

  /// Runs [open] with the auto-hide countdown paused, then restarts it.
  Future<void> _withChromePaused(Future<void> Function() open) async {
    _chromeAutoHide.pause();
    try {
      await open();
    } finally {
      _chromeAutoHide.resume();
      _noteChromeInteraction();
    }
  }

  Future<void> _openTools(BuildContext context) => _withChromePaused(
        () => openReaderTools(
          context,
          onJumpToPage: _jumpToPage,
          onJumpToParagraph: _jumpToParagraph,
          currentNovelParagraph: () => _novelAnchor,
        ),
      );

  Future<void> _openPageNavigator(BuildContext context) => _withChromePaused(
        () => showReaderPageNavigator(context, c, onJumpToPage: _jumpToPage),
      );

  Future<void> _openChapterList(BuildContext context) =>
      _withChromePaused(() => showReaderChapterList(context, c));

  Future<void> _openNovelTtsPanel(BuildContext context) =>
      _withChromePaused(() => showNovelTtsPanel(context, c));

  Future<void> _jumpToPage(int page) async {
    final images = c.chapterData.value.chapter.images;
    if (images.isEmpty) return;
    final target = page.clamp(0, images.length - 1).toInt();
    if (c.readerMode.value == 'paged') {
      c.setCurrentPage(target);
      if (c.pageController.hasClients) {
        c.pageController.jumpToPage(target ~/ _pagesPerSpread);
      }
      return;
    }
    final scroll = c.scrollController;
    if (!scroll.hasClients || _index.pageCount != images.length) return;
    final offset = _index
        .startOf(target)
        .clamp(0.0, scroll.position.maxScrollExtent)
        .toDouble();
    scroll.jumpTo(offset);
    _anchorPage = target;
    _anchorFraction = 0;
    c.setCurrentPage(target);
    c.updateImageScrollProgress(target, 0);
    c.onMangaWindowChanged(firstVisible: target, lastVisible: target);
  }

  // ---------------------------------------------------------------------
  // Overlays and palette
  // ---------------------------------------------------------------------

  Widget _buildPageLoadChip(BuildContext context) {
    return Obx(() {
      c.pageLoadRevision.value;
      if (!c.showPageLoadProgress.value || c.isNovel) {
        return const SizedBox.shrink();
      }
      final progress = c.pageLoadProgress;
      if (progress == null) return const SizedBox.shrink();
      final percent = (progress * 100).round().clamp(0, 100);
      return Positioned(
        top: MediaQuery.paddingOf(context).top + 64,
        left: 0,
        right: 0,
        child: IgnorePointer(
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xa6000000),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MangaPlusLoader(size: 13, progress: progress),
                  const SizedBox(width: 6),
                  Text(
                    '$percent%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildBrightnessOverlay() {
    return Obx(() {
      final opacity = (1 - c.readerBrightness.value).clamp(0.0, .65);
      if (opacity <= .01) return const SizedBox.shrink();
      return Positioned.fill(
        child: IgnorePointer(
          child: ColoredBox(
            color: Colors.black.withValues(alpha: opacity),
          ),
        ),
      );
    });
  }

  Color _readerBackground() {
    if (c.isNovel) return _novelPalette().background;
    return _pageBackground();
  }

  Color _pageBackground() {
    switch (c.readerBackground.value) {
      case 'white':
        return const Color(0xfffafafa);
      case 'gray':
        return const Color(0xff2b2d31);
      case 'app':
        return AppColors.background;
      default:
        return Colors.black;
    }
  }

  ({Color background, Color text}) _novelPalette() {
    switch (c.novelBackground.value) {
      case 'light':
        return (
          background: const Color(0xfffafafa),
          text: const Color(0xff242424)
        );
      case 'sepia':
        return (
          background: const Color(0xfff1e6d0),
          text: const Color(0xff453b2d)
        );
      case 'dark':
        return (
          background: const Color(0xff151515),
          text: const Color(0xffe5e2dc)
        );
      case 'black':
        return (background: Colors.black, text: const Color(0xffeeeeee));
      default:
        return (background: AppColors.background, text: AppColors.textPrimary);
    }
  }
}

/// One paragraph of the novel reader.
///
/// The speech state is observed here, in its own `Obx`, instead of in the list
/// that builds the paragraphs. A spoken word therefore rebuilds a handful of
/// text widgets rather than the scrolling list and its whole item closure.
class _NovelParagraph extends StatelessWidget {
  const _NovelParagraph({
    super.key,
    required this.controller,
    required this.paragraphIndex,
    required this.paragraph,
    required this.notes,
    required this.style,
    required this.textAlign,
    required this.bottomPadding,
  });

  final ChapterController controller;
  final int paragraphIndex;
  final String paragraph;
  final List<NovelNote> notes;
  final TextStyle style;
  final TextAlign textAlign;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final speaking = controller.novelSpeechPlaying.value ||
          controller.novelSpeechPaused.value;
      final word = speaking &&
              controller.novelSpeechCurrentParagraph.value == paragraphIndex
          ? controller.novelSpeechCurrentWord.value
          : '';
      return Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: Text.rich(
          TextSpan(
            children: _novelParagraphSpans(
              paragraph: paragraph,
              notes: notes,
              speechWord: word,
              speechColor: AppColors.primary,
            ),
          ),
          textAlign: textAlign,
          style: style,
        ),
      );
    });
  }
}

/// Builds the inline spans of one paragraph: its note highlight (if any) and,
/// while it is being read aloud, the currently spoken word.
List<InlineSpan> _novelParagraphSpans({
  required String paragraph,
  required List<NovelNote> notes,
  required String speechWord,
  required Color speechColor,
}) {
  final ranges = <({int start, int end, Color color, bool speech})>[];
  for (final note in notes) {
    final range = note.resolveRange(paragraph);
    if (range.end <= range.start) continue;
    ranges.add((
      start: range.start,
      end: range.end,
      color: Color(novelNoteColorValue(note.color)),
      speech: false,
    ));
    break;
  }
  final word = speechWord.trim().toLowerCase();
  if (word.isNotEmpty) {
    final start = paragraph.toLowerCase().indexOf(word);
    if (start >= 0) {
      ranges.add((
        start: start,
        end: start + word.length,
        color: speechColor.withValues(alpha: .2),
        speech: true,
      ));
    }
  }
  if (ranges.isEmpty) return [TextSpan(text: paragraph)];
  ranges.sort((left, right) => left.start.compareTo(right.start));
  final spans = <InlineSpan>[];
  var cursor = 0;
  for (final range in ranges) {
    final start = range.start.clamp(cursor, paragraph.length);
    final end = range.end.clamp(start, paragraph.length);
    if (start > cursor) {
      spans.add(TextSpan(text: paragraph.substring(cursor, start)));
    }
    if (end > start) {
      spans.add(TextSpan(
        text: paragraph.substring(start, end),
        style: TextStyle(
          backgroundColor:
              range.speech ? range.color : range.color.withValues(alpha: .42),
          fontWeight: range.speech ? FontWeight.w900 : FontWeight.w600,
          color: range.speech ? speechColor : null,
        ),
      ));
    }
    cursor = end;
  }
  if (cursor < paragraph.length) {
    spans.add(TextSpan(text: paragraph.substring(cursor)));
  }
  return spans;
}
