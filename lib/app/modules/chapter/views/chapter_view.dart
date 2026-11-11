import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/core/reader/novel_reader_model.dart';
import 'package:mangaplus/app/core/reader/reader_page_geometry.dart';
import 'package:mangaplus/app/core/utils/bidi_text.dart';
import 'package:mangaplus/app/modules/chapter/controllers/chapter_controller.dart';
import 'package:mangaplus/app/modules/chapter/widgets/reader_manga_page.dart';
import 'package:mangaplus/app/modules/chapter/widgets/reader_tools_sheet.dart';
import 'package:mangaplus/app/widgets/brand_state.dart';
import 'package:mangaplus/app/widgets/theme_aware_builder.dart';

class ChapterView extends StatefulWidget {
  const ChapterView({super.key});

  @override
  State<ChapterView> createState() => _ChapterViewState();
}

class _ChapterViewState extends State<ChapterView>
    with TickerProviderStateMixin {
  ChapterController get c => Get.find<ChapterController>();

  ReaderPageScrollIndex _index = ReaderPageScrollIndex.empty;
  String _indexSignature = '';
  int _anchorPage = 0;
  double _anchorFraction = .5;
  bool _restoreScheduled = false;
  bool _initialScrollSynced = false;
  String? _indexedChapterId;
  int _lastWindowFirst = -1;
  int _lastWindowLast = -1;

  final Map<int, GlobalKey> _paragraphKeys = <int, GlobalKey>{};
  int _novelAnchor = 0;
  int _lastNovelRevision = -1;
  int _lastSpeechParagraph = -1;

  Ticker? _autoScrollTicker;
  Duration _lastTick = Duration.zero;

  @override
  void dispose() {
    _autoScrollTicker?.dispose();
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
      _anchorPage = c.currentPage.value.clamp(0, images.length - 1).toInt();
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
      c.onMangaWindowChanged(firstVisible: first, lastVisible: last);
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) c.syncPageController();
    });
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
            c.onPageChanged(page);
            c.onMangaWindowChanged(
              firstVisible: page,
              lastVisible: page + perSpread + 1,
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
        if (_lastNovelRevision != c.novelLayoutRevision.value) {
          _lastNovelRevision = c.novelLayoutRevision.value;
          _scheduleNovelAnchorRestore();
        }
        _syncAutoScroll(paragraphs.length);
        _followSpeech(paragraphs);
        final speechParagraph = c.novelSpeechCurrentParagraph.value;
        final speechActive =
            c.novelSpeechPlaying.value || c.novelSpeechPaused.value;
        final speechWord = c.novelSpeechCurrentWord.value;
        return ColoredBox(
          color: palette.background,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: c.toggleNavigationVisibility,
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.depth != 0) return false;
                final metrics = notification.metrics;
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
                      c.novelMargins.value,
                      MediaQuery.paddingOf(context).top + 68,
                      c.novelMargins.value,
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
                      final isSpeaking =
                          speechActive && index == speechParagraph;
                      return Padding(
                        key: _paragraphKeys.putIfAbsent(index, GlobalKey.new),
                        padding: EdgeInsets.only(
                          bottom: index == paragraphs.length - 1
                              ? 0
                              : c.novelParagraphSpacing.value,
                        ),
                        child: Text.rich(
                          TextSpan(
                            children: _novelSpans(
                              paragraph: paragraph,
                              notes: notes,
                              speechWord: isSpeaking ? speechWord : '',
                              speechColor: AppColors.primary,
                            ),
                          ),
                          textAlign: _novelTextAlign(direction),
                          style: TextStyle(
                            color: palette.text,
                            fontSize: c.novelFontSize.value,
                            fontFamily: c.novelFontFamily.value == 'default'
                                ? null
                                : c.novelFontFamily.value,
                            fontWeight: FontWeight.values[
                                ((c.novelFontWeight.value ~/ 100) - 3)
                                    .clamp(0, 5)
                                    .toInt()],
                            height: c.novelLineHeight.value,
                            letterSpacing: .05,
                          ),
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

  List<InlineSpan> _novelSpans({
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

  void _followSpeech(List<String> paragraphs) {
    final active = c.novelSpeechPlaying.value || c.novelSpeechPaused.value;
    final paragraph = c.novelSpeechCurrentParagraph.value;
    if (!active || paragraph < 0 || paragraph >= paragraphs.length) {
      _lastSpeechParagraph = -1;
      return;
    }
    if (paragraph == _lastSpeechParagraph) return;
    _lastSpeechParagraph = paragraph;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _jumpToParagraph(paragraph);
    });
  }

  void _syncAutoScroll(int paragraphCount) {
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

  // ---------------------------------------------------------------------
  // Reader chrome
  // ---------------------------------------------------------------------

  Widget _buildChrome(BuildContext context) {
    return Obx(() {
      final visible = c.showNavigation.value;
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
      return Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _chromeTransition(
              visible: visible,
              fromTop: true,
              child: _topBar(title, pageLabel),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _chromeTransition(
              visible: visible,
              fromTop: false,
              child: _bottomBar(progress, title, pageLabel),
            ),
          ),
        ],
      );
    });
  }

  Widget _chromeTransition({
    required bool visible,
    required bool fromTop,
    required Widget child,
  }) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : Offset(0, fromTop ? -1.1 : 1.1),
        duration: const Duration(milliseconds: 230),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: child,
        ),
      ),
    );
  }

  Widget _topBar(String title, String pageLabel) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: .86),
            Colors.black.withValues(alpha: .45),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 8, 18),
          child: Row(
            children: [
              _chromeIcon(
                Icons.arrow_back_rounded,
                'رجوع',
                () => Get.back(),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pageLabel,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .66),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _chromeIcon(
                c.readerFullscreen.value
                    ? Icons.fullscreen_exit_rounded
                    : Icons.fullscreen_rounded,
                'ملء الشاشة',
                () => c.setReaderFullscreen(!c.readerFullscreen.value),
              ),
              _chromeIcon(
                Icons.tune_rounded,
                'أدوات القارئ',
                () => _openTools(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomBar(double progress, String title, String pageLabel) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xff181b20).withValues(alpha: .97),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: .08)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .35),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(10, 8, 10, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 3,
                backgroundColor: Colors.white.withValues(alpha: .1),
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  pageLabel,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .62),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            SizedBox(
              height: 34,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  activeTrackColor: AppColors.primary,
                  inactiveTrackColor: Colors.white.withValues(alpha: .16),
                  thumbColor: AppColors.primary,
                  overlayColor: AppColors.primary.withValues(alpha: .12),
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 14),
                ),
                child: Slider(
                  value: progress,
                  onChanged: c.seekReaderProgress,
                  onChangeEnd: (_) => c.persistReaderProgress(),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _chromeIcon(
                  Icons.grid_view_rounded,
                  'الصفحات',
                  () => _openTools(context),
                ),
                _chromeIcon(
                  Icons.chevron_left_rounded,
                  'الفصل السابق',
                  c.previousChapterId == null
                      ? null
                      : () => c.navigateToChapter(
                            c.previousChapterId,
                            reverse: true,
                            joinContinuousStream: true,
                          ),
                ),
                _chromeIcon(
                  c.isNovel
                      ? Icons.format_list_bulleted_rounded
                      : (c.readerMode.value == 'paged'
                          ? Icons.view_stream_rounded
                          : Icons.menu_book_rounded),
                  c.isNovel ? 'أدوات' : 'تبديل وضع القراءة',
                  c.isNovel
                      ? () => _openTools(context)
                      : () => c.setReaderMode(
                            c.readerMode.value == 'paged' ? 'scroll' : 'paged',
                          ),
                ),
                _chromeIcon(
                  c.isNovel
                      ? (c.novelSpeechPlaying.value
                          ? Icons.pause_rounded
                          : Icons.volume_up_rounded)
                      : Icons.chevron_right_rounded,
                  c.isNovel ? 'القراءة الصوتية' : 'الفصل التالي',
                  c.isNovel
                      ? c.toggleNovelSpeech
                      : (c.nextChapterId == null
                          ? null
                          : () => c.navigateToChapter(
                                c.nextChapterId,
                                joinContinuousStream: true,
                              )),
                ),
                _chromeIcon(
                  c.isNovel
                      ? Icons.bookmarks_outlined
                      : Icons.format_list_numbered_rounded,
                  c.isNovel ? 'العلامات والملاحظات' : 'قائمة الفصول',
                  () => _openTools(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chromeIcon(IconData icon, String tooltip, VoidCallback? onTap) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon, size: 21),
      color: onTap == null
          ? Colors.white.withValues(alpha: .26)
          : Colors.white.withValues(alpha: .9),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 42, height: 38),
      visualDensity: VisualDensity.compact,
    );
  }

  Future<void> _openTools(BuildContext context) async {
    await openReaderTools(
      context,
      onJumpToPage: _jumpToPage,
      onJumpToParagraph: _jumpToParagraph,
      currentNovelParagraph: () => _novelAnchor,
    );
  }

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
                  SizedBox(
                    width: 11,
                    height: 11,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 1.6,
                      backgroundColor: Colors.white.withValues(alpha: .2),
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
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
