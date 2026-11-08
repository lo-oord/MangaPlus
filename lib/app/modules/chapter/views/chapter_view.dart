import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/core/utils/reader_load_issue.dart';
import 'package:mangaplus/app/data/models/chapter.dart';
import 'package:mangaplus/app/data/sources/mangatek_overlay.dart';
import 'package:mangaplus/app/modules/chapter/controllers/chapter_controller.dart';
import 'package:mangaplus/app/widgets/app_feedback.dart';
import 'package:mangaplus/app/widgets/brand_state.dart';
import 'package:mangaplus/app/widgets/theme_aware_builder.dart';

class ChapterView extends StatefulWidget {
  const ChapterView({super.key});

  @override
  State<ChapterView> createState() => _ChapterViewState();
}

class _ChapterViewState extends State<ChapterView> {
  ChapterController get controller => Get.find<ChapterController>();

  final Map<String, GlobalKey> _pageKeys = <String, GlobalKey>{};
  int _lastFollowedSpeechParagraph = -1;
  bool _speechWasPlaying = false;
  final Set<String> _preloadedImages = <String>{};
  int _scrollAnchorPageIndex = 0;
  double _scrollAnchorTop = 0;
  double _scrollAnchorOffset = 0;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final images = controller.chapterData.value.chapter.images;
      if (images.isNotEmpty && !controller.isOffline.value) {
        _preloadImages(context, images);
        if (controller.continuousNavigation.value) {
          // Warm both boundaries as soon as chapter navigation is available.
          // This keeps continuous scroll from waiting at either chapter edge.
          _preloadAdjacentChapterImages(context);
          _preloadAdjacentChapterImages(context, previous: true);
        }
      }
    });

    return ThemeAwareBuilder(builder: (context) => Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          _buildContent(context),
          _buildPageLoadIndicator(context),
          _buildFloatingNavigation(),
        ],
      ),
    ));
  }

  Widget _buildContent(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value && !controller.hasReadableContent) {
        return BrandState(
          title: 'جارٍ تحميل الفصل'.tr,
          description: 'يتم تجهيز صفحات الفصل'.tr,
          loading: true,
        );
      }
      if (controller.hasError.value) {
        final issue = controller.loadIssue.value;
        return BrandState(
          title: (issue?.titleKey ?? 'تعذر تحميل الفصل').tr,
          description: (issue?.descriptionKey ?? 'تعذر تحميل المحتوى. حاول مجددًا.').tr,
          icon: issue?.icon ?? Icons.error_outline_rounded,
          actionLabel: 'إعادة المحاولة'.tr,
          onAction: () => controller.fetchChapter(controller.chapterId),
        );
      }
      final chapter = controller.chapterData.value.chapter;
      if (controller.isNovel) {
        if (chapter.content.trim().isEmpty) {
          return BrandState(
            title: 'لا يوجد محتوى نصي متاح'.tr,
            actionLabel: 'إعادة المحاولة'.tr,
            onAction: () => controller.fetchChapter(controller.chapterId),
          );
        }
        return _buildNovelContent(context, chapter);
      }
      if (chapter.images.isEmpty) {
        return BrandState(
          title: 'لا توجد صور متاحة'.tr,
          actionLabel: 'إعادة المحاولة'.tr,
          onAction: () => controller.fetchChapter(controller.chapterId),
        );
      }
      if (controller.readerMode.value == 'paged') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) controller.syncPageController();
        });
        return GestureDetector(
          onTapUp: (details) =>
              _handlePagedTap(context, details, chapter.images.length),
          behavior: HitTestBehavior.opaque,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: PageView.builder(
              controller: controller.pageController,
              reverse: controller.readingDirection.value == 'rtl',
              itemCount: chapter.images.length,
              onPageChanged: (index) {
                controller.onPageChanged(index);
                if (!controller.isOffline.value) {
                  _preloadImages(context, chapter.images, start: index + 1);
                  if (index >= chapter.images.length - 2) {
                    _preloadAdjacentChapterImages(context);
                  }
                  if (index <= 1) {
                    _preloadAdjacentChapterImages(context, previous: true);
                  }
                }
              },
              itemBuilder: (context, index) =>
                  _buildPagedImage(context, chapter.images[index], index),
            ),
          ),
        );
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) controller.syncScrollController();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateCurrentPage(context));
      final chapterBoundaries =
          controller.readerChapterPageRanges.skip(1).toList(growable: false);
      final imageOccurrences = <String, int>{};
      final pageKeys = chapter.images.map((image) {
        final occurrence = imageOccurrences.update(
          image,
          (count) => count + 1,
          ifAbsent: () => 0,
        );
        final identity = '$image\u0000$occurrence';
        return _pageKeys.putIfAbsent(identity, GlobalKey.new);
      }).toList(growable: false);
      final childIndexes = <Key, int>{};
      for (var pageIndex = 0; pageIndex < pageKeys.length; pageIndex++) {
        final precedingDividers = chapterBoundaries
            .where((range) => range.startIndex <= pageIndex)
            .length;
        childIndexes[pageKeys[pageIndex]] = pageIndex + precedingDividers;
      }
      return GestureDetector(
        onTap: controller.toggleNavigationVisibility,
        behavior: HitTestBehavior.opaque,
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollUpdateNotification ||
                notification is ScrollEndNotification) {
              if (notification is ScrollUpdateNotification) {
                _updateCurrentPage(context);
              }
              controller.handleScroll(
                notification.metrics,
                scrollDelta: notification is ScrollUpdateNotification
                    ? notification.scrollDelta
                    : null,
                userInitiated: notification is ScrollUpdateNotification &&
                    notification.dragDetails != null,
                settled: notification is ScrollEndNotification,
              );
              if (notification.metrics.extentAfter <=
                      notification.metrics.viewportDimension * 2 &&
                  !controller.isOffline.value) {
                _preloadAdjacentChapterImages(context);
              }
              if (notification.metrics.pixels <=
                      notification.metrics.viewportDimension * 2 &&
                  !controller.isOffline.value) {
                _preloadAdjacentChapterImages(context, previous: true);
              }
            }
            if (notification is OverscrollNotification) {
              controller.handleScroll(
                notification.metrics,
                scrollDelta: notification.overscroll < 0 ? -1.0 : 1.0,
              );
            }
            if (notification is ScrollEndNotification) {
              final notificationContext = notification.context;
              if (notificationContext != null) {
                _updateCurrentPage(notificationContext);
                if (!controller.isOffline.value) {
                  _preloadImages(
                    notificationContext,
                    chapter.images,
                    start: controller.currentPage.value + 1,
                  );
                }
              }
              controller.persistScrollOffset(notification.metrics.pixels);
            }
            return false;
          },
          child: ListView.builder(
            controller: controller.scrollController,
            cacheExtent: 1200,
            itemCount: chapter.images.length + chapterBoundaries.length,
            findChildIndexCallback: (key) => childIndexes[key],
            itemBuilder: (context, index) {
              var pageIndex = index;
              for (var boundaryIndex = 0;
                  boundaryIndex < chapterBoundaries.length;
                  boundaryIndex++) {
                final boundary = chapterBoundaries[boundaryIndex];
                final insertionIndex = boundary.startIndex + boundaryIndex;
                if (index == insertionIndex) {
                  return _buildChapterDivider(
                    title: controller.showChapterTitle.value
                        ? controller.chapterDividerTitle(boundary.chapterId)
                        : null,
                  );
                }
                if (index > insertionIndex) pageIndex--;
              }
              return KeyedSubtree(
                key: pageKeys[pageIndex],
                child: _buildImage(
                  context,
                  chapter.images[pageIndex],
                  pageIndex,
                ),
              );
            },
          ),
        ),
      );
    });
  }

  Widget _buildNovelContent(BuildContext context, DataChapter chapter) {
    return Obx(() {
      final background = _novelBackgroundColor(controller.novelBackground.value);
      final foreground = _novelTextColor(controller.novelBackground.value);
      final family = controller.novelFontFamily.value;
      final speechParagraph = controller.novelSpeechCurrentParagraph.value;
      final speechWord = controller.novelSpeechCurrentWord.value;
      final speechPlaying = controller.novelSpeechPlaying.value;
      final speechActive = speechPlaying || controller.novelSpeechPaused.value;
      return FutureBuilder<List<String>>(
        future: controller.paragraphsFor(chapter.content),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return ColoredBox(
              color: background,
              child: const Center(
                child: MangaPlusLoader(size: 54),
              ),
            );
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return BrandState(
              title: 'تعذر تحميل الفصل'.tr,
              actionLabel: 'إعادة المحاولة'.tr,
              onAction: () => controller.fetchChapter(controller.chapterId),
            );
          }

          final paragraphs = snapshot.data!;
          if (!speechActive) {
            _lastFollowedSpeechParagraph = -1;
            _speechWasPlaying = false;
          }
          final shouldFollowSpeech = speechActive &&
              speechParagraph >= 0 &&
              (speechParagraph != _lastFollowedSpeechParagraph ||
                  (speechPlaying && !_speechWasPlaying));
          _speechWasPlaying = speechPlaying;
          if (shouldFollowSpeech && speechParagraph < paragraphs.length) {
            _lastFollowedSpeechParagraph = speechParagraph;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted || !controller.scrollController.hasClients) return;
              final width = (MediaQuery.sizeOf(context).width - 48)
                  .clamp(160.0, 1200.0)
                  .toDouble();
              final charsPerLine = (width / (controller.novelFontSize.value * .55))
                  .floor().clamp(12, 160).toInt();
              var estimatedOffset = 0.0;
              for (var i = 0; i < speechParagraph; i++) {
                final lines = (paragraphs[i].length / charsPerLine)
                    .ceil()
                    .clamp(1, 10000)
                    .toInt();
                estimatedOffset += lines * controller.novelFontSize.value *
                    controller.novelLineHeight.value + controller.novelParagraphSpacing.value;
              }
              final position = controller.scrollController.position;
              final target = (estimatedOffset - position.viewportDimension * .28)
                  .clamp(0.0, position.maxScrollExtent).toDouble();
              controller.scrollController.animateTo(target,
                  duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
            });
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) controller.syncScrollController();
          });
          return ColoredBox(
            color: background,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (event) => controller.beginReaderPointer(
                event.position,
                event.timeStamp,
              ),
              onPointerMove: (event) =>
                  controller.updateReaderPointer(event.position),
              onPointerUp: (event) =>
                  controller.endReaderPointer(event.timeStamp),
              onPointerCancel: (_) => controller.cancelReaderPointer(),
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollUpdateNotification ||
                      notification is ScrollEndNotification) {
                    controller.updateNovelProgress(
                      notification.metrics.pixels,
                      notification.metrics.maxScrollExtent,
                    );
                    controller.handleScroll(
                      notification.metrics,
                      scrollDelta: notification is ScrollUpdateNotification
                          ? notification.scrollDelta
                          : null,
                      userInitiated:
                          notification is ScrollUpdateNotification &&
                              notification.dragDetails != null,
                      settled: notification is ScrollEndNotification,
                    );
                  }
                  if (notification is OverscrollNotification) {
                    controller.handleScroll(
                      notification.metrics,
                      scrollDelta: notification.overscroll < 0 ? -1.0 : 1.0,
                    );
                  }
                  if (notification is ScrollEndNotification) {
                    controller.persistScrollOffset(notification.metrics.pixels);
                  }
                  return false;
                },
                child: Directionality(
                  textDirection: controller.readingDirection.value == 'rtl'
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  child: SelectionArea(
                    child: ListView.builder(
                      controller: controller.scrollController,
                      padding: EdgeInsets.fromLTRB(
                        24,
                        MediaQuery.paddingOf(context).top + 28,
                        24,
                        MediaQuery.paddingOf(context).bottom + 110,
                      ),
                      itemCount: paragraphs.length,
                      itemBuilder: (context, index) {
                        final isCurrent = speechActive && index == speechParagraph;
                        final paragraph = paragraphs[index];
                        if (paragraph.startsWith(ChapterController.novelChapterDividerToken)) {
                          final title = ChapterController.titleFromNovelChapterDivider(paragraph);
                          return _buildChapterDivider(
                            title: controller.showChapterTitle.value ? title : null,
                          );
                        }
                        final wordStart = isCurrent && speechWord.isNotEmpty
                            ? paragraph.toLowerCase().indexOf(speechWord.toLowerCase())
                            : -1;
                        final wordEnd = wordStart < 0 ? -1 : wordStart + speechWord.length;
                        final baseStyle = TextStyle(
                          color: foreground,
                          fontSize: controller.novelFontSize.value,
                          fontFamily: family == 'default' ? null : family,
                          height: controller.novelLineHeight.value,
                          letterSpacing: 0.05,
                        );
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index == paragraphs.length - 1
                                ? 0
                                : controller.novelParagraphSpacing.value,
                          ),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? AppColors.primary.withValues(alpha: .14)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: isCurrent
                                  ? Border.all(color: AppColors.primary.withValues(alpha: .34))
                                  : null,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            child: Text.rich(
                              TextSpan(children: [
                                if (wordStart >= 0) ...[
                                  TextSpan(text: paragraph.substring(0, wordStart)),
                                  TextSpan(
                                    text: paragraph.substring(wordStart, wordEnd),
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      backgroundColor: AppColors.primary.withValues(alpha: .2),
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  TextSpan(text: paragraph.substring(wordEnd)),
                                ] else
                                  TextSpan(text: paragraph),
                              ]),
                              textAlign: controller.readingDirection.value == 'rtl'
                                  ? TextAlign.right
                                  : TextAlign.left,
                              style: baseStyle,
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
    });
  }

  Color _novelBackgroundColor(String value) {
    switch (value) {
      case 'light':
        return const Color(0xfffafafa);
      case 'sepia':
        return const Color(0xfff1e6d0);
      case 'dark':
        return const Color(0xff151515);
      case 'black':
        return Colors.black;
      default:
        return AppColors.background;
    }
  }

  Color _novelTextColor(String value) {
    switch (value) {
      case 'light':
        return const Color(0xff242424);
      case 'sepia':
        return const Color(0xff453b2d);
      case 'dark':
        return const Color(0xffe5e2dc);
      case 'black':
        return const Color(0xffeeeeee);
      default:
        return AppColors.textPrimary;
    }
  }

  void _handlePagedTap(
    BuildContext context,
    TapUpDetails details,
    int pageCount,
  ) {
    final width = MediaQuery.sizeOf(context).width;
    final x = details.localPosition.dx;
    final isLeftEdge = x <= width * 0.32;
    final isRightEdge = x >= width * 0.68;
    if (!isLeftEdge && !isRightEdge) {
      controller.toggleNavigationVisibility();
      return;
    }

    final isNextPage = controller.readingDirection.value == 'rtl'
        ? isRightEdge
        : isLeftEdge;
    final target = controller.currentPage.value + (isNextPage ? 1 : -1);
    if (target >= 0 && target < pageCount && controller.pageController.hasClients) {
      controller.pageController.animateToPage(
        target,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    } else if (isNextPage) {
      controller.navigateToChapter(
        controller.nextChapterId,
        joinContinuousStream: true,
      );
    } else {
      controller.navigateToChapter(
        controller.previousChapterId,
        reverse: true,
        joinContinuousStream: true,
      );
    }
  }

  void _updateCurrentPage(BuildContext context) {
    final screenCenter = MediaQuery.sizeOf(context).height / 2;
    var bestIndex = controller.currentPage.value;
    var bestDistance = double.infinity;
    var fractionWithinPage = 1.0;
    final images = controller.chapterData.value.chapter.images;
    final imageOccurrences = <String, int>{};
    final pageKeys = <GlobalKey>[];
    for (final image in images) {
      final occurrence = imageOccurrences.update(
        image,
        (count) => count + 1,
        ifAbsent: () => 0,
      );
      pageKeys.add(_pageKeys.putIfAbsent(
        '$image\u0000$occurrence',
        GlobalKey.new,
      ));
    }
    for (var index = 0; index < pageKeys.length; index++) {
      final renderObject = pageKeys[index].currentContext?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) continue;
      final top = renderObject.localToGlobal(Offset.zero).dy;
      final bottom = top + renderObject.size.height;
      if (top <= screenCenter && bottom >= screenCenter) {
        bestIndex = index;
        fractionWithinPage = renderObject.size.height <= 0
            ? 1
            : ((screenCenter - top) / renderObject.size.height)
                .clamp(0.0, 1.0)
                .toDouble();
        break;
      }
      final distance = screenCenter < top ? top - screenCenter : screenCenter - bottom;
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = index;
      }
    }
    if (bestIndex != controller.currentPage.value ||
        controller.readerMode.value == 'scroll') {
      controller.updateImageScrollProgress(bestIndex, fractionWithinPage);
    }
    _captureScrollAnchor(bestIndex, pageKeys);
  }

  void _captureScrollAnchor(int pageIndex, List<GlobalKey> pageKeys) {
    final scroll = controller.scrollController;
    if (controller.readerMode.value != 'scroll' ||
        !scroll.hasClients ||
        pageIndex < 0 ||
        pageIndex >= pageKeys.length) {
      return;
    }
    final renderObject =
        pageKeys[pageIndex].currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    _scrollAnchorPageIndex = pageIndex;
    _scrollAnchorTop = renderObject.localToGlobal(Offset.zero).dy;
    _scrollAnchorOffset = scroll.offset;
  }

  void _restoreScrollAnchorAfterImageLayout() {
    if (controller.readerMode.value != 'scroll') return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final scroll = controller.scrollController;
      if (!mounted || !scroll.hasClients) return;
      final images = controller.chapterData.value.chapter.images;
      final occurrences = <String, int>{};
      GlobalKey? anchorKey;
      for (var index = 0; index < images.length; index++) {
        final image = images[index];
        final occurrence = occurrences.update(
          image,
          (count) => count + 1,
          ifAbsent: () => 0,
        );
        final key = _pageKeys['$image\u0000$occurrence'];
        if (index == _scrollAnchorPageIndex) {
          anchorKey = key;
          break;
        }
      }
      final renderObject = anchorKey?.currentContext?.findRenderObject();
      if (renderObject is RenderBox && renderObject.hasSize) {
        final currentOffset = scroll.offset;
        final currentTop = renderObject.localToGlobal(Offset.zero).dy;
        final expectedTop =
            _scrollAnchorTop - (currentOffset - _scrollAnchorOffset);
        final correction = currentTop - expectedTop;
        if (correction.isFinite && correction.abs() > 1) {
          scroll.jumpTo(
            (currentOffset + correction)
                .clamp(0.0, scroll.position.maxScrollExtent)
                .toDouble(),
          );
        }
      }
      final currentKey = anchorKey;
      final currentBox = currentKey?.currentContext?.findRenderObject();
      if (currentBox is RenderBox && currentBox.hasSize) {
        _scrollAnchorTop = currentBox.localToGlobal(Offset.zero).dy;
        _scrollAnchorOffset = scroll.offset;
      }
    });
  }

  Widget _buildFloatingNavigation() {
    return Obx(() {
      final chapter = controller.chapterData.value.chapter;
      final progress = controller.readerProgress.value.clamp(0.0, 1.0).toDouble();
      final activeChapterId = controller.activeReaderChapterId;
      final activeChapter = controller.availableChapters.firstWhereOrNull(
        (item) => item.chapterId == activeChapterId || item.url == activeChapterId,
      );
      final title = activeChapter?.title.trim().isNotEmpty == true
          ? activeChapter!.title
          : chapter.title.isNotEmpty
              ? chapter.title
              : 'الفصل'.tr;
      final activeRange = controller.activeReaderPageRange;
      final pageCount = activeRange?.pageCount ?? chapter.images.length;
      final localPage = activeRange == null
          ? controller.currentPage.value
          : controller.currentPage.value - activeRange.startIndex;
      return Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        child: AnimatedSlide(
          offset: controller.showNavigation.value
              ? Offset.zero
              : const Offset(0, 1.35),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: IgnorePointer(
            ignoring: !controller.showNavigation.value,
            child: SafeArea(
              minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Container(
                constraints: const BoxConstraints(minHeight: 132),
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                decoration: BoxDecoration(
                  color: AppColors.card.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.divider),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          controller.isNovel || pageCount <= 0
                              ? '${(progress * 100).round()}%'
                              : '${(progress * 100).round()}%  •  ${localPage + 1}/$pageCount',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    _buildProgressSlider(progress),
                    Divider(height: 1, color: AppColors.divider),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 2,
                      runSpacing: 0,
                      children: _readerControlButtons(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildProgressSlider(double progress) {
    final bookmarks = controller.activeChapterBookmarks;
    return LayoutBuilder(
      builder: (context, constraints) {
        final rtl = Directionality.of(context) == TextDirection.rtl;
        return SizedBox(
          height: 46,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 6,
                  activeTrackColor: AppColors.primary,
                  inactiveTrackColor: AppColors.divider,
                  thumbColor: AppColors.primary,
                  overlayColor: AppColors.primary.withValues(alpha: 0.16),
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
                ),
                child: Slider(
                  value: progress,
                  min: 0,
                  max: 1,
                  label: '${(progress * 100).round()}%',
                  onChanged: controller.seekReaderProgress,
                  onChangeEnd: (_) => controller.persistReaderProgress(),
                ),
              ),
              for (final bookmark in bookmarks)
                if (bookmark['progress'] is num)
                  Positioned(
                    left: _bookmarkMarkLeft(
                      (bookmark['progress'] as num).toDouble(),
                      constraints.maxWidth,
                      rtl,
                    ),
                    child: GestureDetector(
                      onTap: () => controller.openReaderBookmark(bookmark),
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          color: const Color(0xff31c46c),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.card, width: 2),
                          boxShadow: const [
                            BoxShadow(color: Color(0x70000000), blurRadius: 3),
                          ],
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }

  double _bookmarkMarkLeft(double progress, double width, bool rtl) {
    final fraction = progress.isFinite
        ? progress.clamp(0.0, 1.0).toDouble()
        : 0.0;
    final alongTrack = rtl ? 1 - fraction : fraction;
    return (16 + alongTrack * (width - 32) - 6.5).toDouble();
  }

  List<Widget> _readerControlButtons() => [
        _readerIconButton(
          icon: Icons.settings_rounded,
          tooltip: 'إعدادات القارئ'.tr,
          onPressed: _openReaderSettings,
        ),
        _readerIconButton(
          icon: Icons.list_alt_rounded,
          tooltip: 'قائمة الفصول'.tr,
          onPressed: _openChapterList,
        ),
        _readerIconButton(
          icon: Icons.bookmarks_outlined,
          tooltip: 'العلامات المرجعية'.tr,
          onPressed: _openReaderBookmarks,
        ),
        if (controller.isNovel) ...[
          _readerIconButton(
            icon: controller.novelSpeechPlaying.value
                ? Icons.pause_rounded
                : controller.novelSpeechPaused.value
                    ? Icons.play_arrow_rounded
                    : Icons.volume_up_rounded,
            tooltip: controller.novelSpeechPlaying.value
                ? 'إيقاف مؤقت'.tr
                : controller.novelSpeechPaused.value
                    ? 'استئناف القراءة'.tr
                    : 'القراءة الصوتية'.tr,
            onPressed: () => controller.toggleNovelSpeech(),
          ),
          _readerIconButton(
            icon: Icons.chevron_left_rounded,
            tooltip: 'الفصل السابق'.tr,
            onPressed: controller.previousChapterId == null
                ? null
                : () => controller.navigateToChapter(
                      controller.previousChapterId,
                      reverse: true,
                      joinContinuousStream: true,
                    ),
          ),
          _readerIconButton(
            icon: Icons.chevron_right_rounded,
            tooltip: 'الفصل التالي'.tr,
            onPressed: controller.nextChapterId == null
                ? null
                : () => controller.navigateToChapter(
                      controller.nextChapterId,
                      joinContinuousStream: true,
                    ),
          ),
        ] else ...[
          _readerIconButton(
            icon: controller.readerMode.value == 'paged'
                ? Icons.view_stream_rounded
                : Icons.menu_book_rounded,
            tooltip: 'تبديل وضع القراءة'.tr,
            onPressed: () => controller.setReaderMode(
              controller.readerMode.value == 'paged' ? 'scroll' : 'paged',
            ),
          ),
          if (controller.readerMode.value == 'paged')
            _readerIconButton(
              icon: Icons.swap_horiz_rounded,
              tooltip: 'تبديل اتجاه القراءة'.tr,
              onPressed: () => controller.setReadingDirection(
                controller.readingDirection.value == 'rtl' ? 'ltr' : 'rtl',
              ),
            ),
        ],
      ];

  Widget _readerIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: 40,
      height: 40,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon),
        color: onPressed == null
            ? AppColors.icon.withValues(alpha: 0.35)
            : AppColors.primary,
        iconSize: 22,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 40, height: 40),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  BoxFit _imageFit(String value) {
    switch (value) {
      case 'height':
        return BoxFit.fitHeight;
      case 'natural':
        return BoxFit.none;
      case 'screen':
        return BoxFit.contain;
      default:
        return BoxFit.fitWidth;
    }
  }

  Widget _buildChapterDivider({String? title}) {
    final label = title?.trim() ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Divider(color: AppColors.divider, thickness: 1, height: 1),
          ),
          if (label.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                label,
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Expanded(
              child: Divider(color: AppColors.divider, thickness: 1, height: 1),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openReaderSettings() async {
    if (controller.isNovel) {
      await _openNovelReaderSettings();
      return;
    }
    await Get.bottomSheet(
      Obx(
        () => SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'إعدادات القارئ'.tr,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _readerSettingsSection(
                      'وضع القراءة'.tr, Icons.view_stream_rounded),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _readerModeChoice('scroll', 'التمرير المستمر'.tr),
                      _readerModeChoice('paged', 'صفحة بصفحة'.tr),
                    ],
                  ),
                  if (controller.readerMode.value == 'paged') ...[
                    const SizedBox(height: 12),
                    _readerSettingsSection(
                        'اتجاه القراءة'.tr, Icons.swap_horiz_rounded),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _directionChoice('rtl', 'من اليمين إلى اليسار'.tr),
                        _directionChoice('ltr', 'من اليسار إلى اليمين'.tr),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  _readerSettingsSection(
                      'ملاءمة الصور'.tr, Icons.aspect_ratio_rounded),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _fitChoice('screen', 'ملاءمة الشاشة'.tr),
                      _fitChoice('width', 'ملاءمة العرض'.tr),
                      _fitChoice('height', 'ملاءمة الارتفاع'.tr),
                      _fitChoice('natural', 'الحجم الطبيعي'.tr),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(color: AppColors.divider),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: controller.continuousNavigation.value,
                    onChanged: controller.setContinuousNavigation,
                    title: Text('الانتقال التلقائي بين الفصول'.tr,
                        style: TextStyle(color: AppColors.textPrimary)),
                    subtitle: Text('تحميل الفصل المجاور عند بلوغ نهاية الفصل'.tr,
                        style: TextStyle(color: AppColors.textSecondary)),
                    activeColor: AppColors.primary,
                  ),
                  if (controller.readerMode.value == 'scroll') ...[
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: controller.showChapterTitle.value,
                      onChanged: controller.setShowChapterTitle,
                      title: Text('إظهار اسم ورقم الفصل بين الفصول'.tr,
                          style: TextStyle(color: AppColors.textPrimary)),
                      subtitle: Text(
                          'يبقى الخط الفاصل ظاهراً عند إخفاء اسم الفصل'.tr,
                          style: TextStyle(color: AppColors.textSecondary)),
                      activeColor: AppColors.primary,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      isScrollControlled: true,
    );
  }

  Widget _fitChoice(String value, String label) {
    final selected = controller.readerFit.value == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => controller.setReaderFit(value),
      selectedColor: AppColors.primary.withValues(alpha: 0.22),
      labelStyle: TextStyle(
        color: selected ? AppColors.primary : AppColors.textSecondary,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _readerSettingsSection(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 17, color: AppColors.primary),
        const SizedBox(width: 7),
        Text(
          title,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _readerModeChoice(String value, String label) {
    final selected = controller.readerMode.value == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => controller.setReaderMode(value),
      selectedColor: AppColors.primary.withValues(alpha: 0.22),
      labelStyle: TextStyle(
        color: selected ? AppColors.primary : AppColors.textSecondary,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _directionChoice(String value, String label) {
    final selected = controller.readingDirection.value == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => controller.setReadingDirection(value),
      selectedColor: AppColors.primary.withValues(alpha: 0.22),
      labelStyle: TextStyle(
        color: selected ? AppColors.primary : AppColors.textSecondary,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Future<void> _openNovelReaderSettings() async {
    await Get.bottomSheet(
      Obx(() => SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.divider,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'إعدادات الرواية'.tr,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text('حجم الخط'.tr,
                        style: TextStyle(color: AppColors.textSecondary)),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => controller.setNovelFontSize(
                              controller.novelFontSize.value - 1),
                          icon: const Icon(Icons.remove_rounded),
                        ),
                        Expanded(
                          child: Slider(
                            value: controller.novelFontSize.value
                                .clamp(14.0, 30.0)
                                .toDouble(),
                            min: 14,
                            max: 30,
                            divisions: 16,
                            label: '${controller.novelFontSize.value.round()}',
                            onChanged: controller.setNovelFontSize,
                          ),
                        ),
                        IconButton(
                          onPressed: () => controller.setNovelFontSize(
                              controller.novelFontSize.value + 1),
                          icon: const Icon(Icons.add_rounded),
                        ),
                      ],
                    ),
                    Center(
                      child: Text(
                        'معاينة للنص'.tr,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: controller.novelFontSize.value,
                          fontFamily: controller.novelFontFamily.value == 'default'
                              ? null
                              : controller.novelFontFamily.value,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text('اتجاه النص'.tr,
                        style: TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 7,
                      children: [
                        _directionChoice('rtl', 'من اليمين إلى اليسار'.tr),
                        _directionChoice('ltr', 'من اليسار إلى اليمين'.tr),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text('تباعد الأسطر'.tr,
                        style: TextStyle(color: AppColors.textSecondary)),
                    Slider(
                      value: controller.novelLineHeight.value
                          .clamp(1.4, 2.3)
                          .toDouble(),
                      min: 1.4,
                      max: 2.3,
                      divisions: 9,
                      label: controller.novelLineHeight.value.toStringAsFixed(1),
                      onChanged: controller.setNovelLineHeight,
                    ),
                    const SizedBox(height: 8),
                    Text('تباعد الفقرات'.tr,
                        style: TextStyle(color: AppColors.textSecondary)),
                    Slider(
                      value: controller.novelParagraphSpacing.value
                          .clamp(8.0, 36.0)
                          .toDouble(),
                      min: 8,
                      max: 36,
                      divisions: 14,
                      label:
                          '${controller.novelParagraphSpacing.value.round()} px',
                      onChanged: controller.setNovelParagraphSpacing,
                    ),
                    const SizedBox(height: 8),
                    Text('نوع الخط'.tr,
                        style: TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 7,
                      children: [
                        _novelChoice('default', 'افتراضي'.tr),
                        _novelChoice('serif', 'نسخي'.tr),
                        _novelChoice('sans-serif', 'بسيط'.tr),
                        _novelChoice('monospace', 'أحادي المسافة'.tr),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('القراءة الصوتية'.tr,
                        style: TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 7),
                    Text('لغة القراءة الصوتية'.tr,
                        style: TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 7,
                      children: [
                        _speechLanguageChoice('ar-SA', 'العربية'.tr),
                        _speechLanguageChoice('en-US', 'الإنجليزية'.tr),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text('سرعة القراءة الصوتية'.tr,
                        style: TextStyle(color: AppColors.textSecondary)),
                    Slider(
                      value: controller.novelSpeechRate.value
                          .clamp(0.25, 0.75)
                          .toDouble(),
                      min: 0.25,
                      max: 0.75,
                      divisions: 10,
                      label:
                          controller.novelSpeechRate.value.toStringAsFixed(2),
                      onChanged: controller.setNovelSpeechRate,
                    ),
                    if (controller.novelSpeechPlaying.value ||
                        controller.novelSpeechPaused.value)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton.icon(
                          onPressed: () => controller.stopNovelSpeech(),
                          icon: const Icon(Icons.stop_rounded),
                          label: Text('إيقاف القراءة'.tr),
                        ),
                      ),
                    const SizedBox(height: 14),
                    Text('خلفية القراءة'.tr,
                        style: TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 7,
                      children: [
                        _novelChoice('app', 'حسب الثيم'.tr),
                        _novelChoice('light', 'فاتح'.tr),
                        _novelChoice('sepia', 'ورقي'.tr),
                        _novelChoice('dark', 'داكن'.tr),
                        _novelChoice('black', 'أسود خالص'.tr),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(color: AppColors.divider),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: controller.continuousNavigation.value,
                      onChanged: controller.setContinuousNavigation,
                      title: Text('الانتقال التلقائي بين الفصول'.tr,
                          style: TextStyle(color: AppColors.textPrimary)),
                      subtitle: Text(
                          'تحميل الفصل التالي عند بلوغ نهاية النص'.tr,
                          style: TextStyle(color: AppColors.textSecondary)),
                      activeColor: AppColors.primary,
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: controller.showChapterTitle.value,
                      onChanged: controller.setShowChapterTitle,
                      title: Text('إظهار اسم الفصل بين الفصول'.tr,
                          style: TextStyle(color: AppColors.textPrimary)),
                      subtitle: Text('يبقى الفاصل ظاهراً عند إخفاء الاسم'.tr,
                          style: TextStyle(color: AppColors.textSecondary)),
                      activeColor: AppColors.primary,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.menu_book_rounded,
                              color: AppColors.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'تُعرض فصول الرواية متصلة ويفصل بينها خط رفيع'.tr,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )),
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      isScrollControlled: true,
    );
  }

  Widget _novelChoice(String value, String label) {
    final selected = controller.novelFontFamily.value == value ||
        controller.novelBackground.value == value;
    final isFont = const {'default', 'serif', 'sans-serif', 'monospace'}
        .contains(value);
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => isFont
          ? controller.setNovelFontFamily(value)
          : controller.setNovelBackground(value),
      selectedColor: AppColors.primary.withValues(alpha: 0.22),
      labelStyle: TextStyle(
        color: selected ? AppColors.primary : AppColors.textSecondary,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _speechLanguageChoice(String value, String label) {
    final selected = controller.novelSpeechLanguage.value == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => controller.setNovelSpeechLanguage(value),
      selectedColor: AppColors.primary.withValues(alpha: 0.22),
      labelStyle: TextStyle(
        color: selected ? AppColors.primary : AppColors.textSecondary,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Future<void> _openReaderBookmarks() async {
    await Get.bottomSheet(
      Obx(() {
        final bookmarks = controller.readerBookmarks.toList(growable: false);
        return SafeArea(
          child: SizedBox(
            height: Get.height * 0.78,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'العلامات المرجعية'.tr,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text('${bookmarks.length}',
                          style: TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: () => controller.saveReaderBookmark(),
                      icon: const Icon(Icons.bookmark_add_outlined),
                      label: Text('حفظ موضع القراءة'.tr),
                    ),
                  ),
                ),
                Expanded(
                  child: bookmarks.isEmpty
                      ? Center(child: Text('لا توجد علامات مرجعية'.tr))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                          itemCount: bookmarks.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final item = bookmarks[index];
                            final progressValue = item['progress'];
                            final progress = progressValue is num
                                ? progressValue.toDouble()
                                : double.tryParse('$progressValue') ?? 0.0;
                            final createdAt = DateTime.tryParse(
                              '${item['createdAt'] ?? ''}',
                            );
                            final month =
                                createdAt?.month.toString().padLeft(2, '0') ?? '';
                            final day =
                                createdAt?.day.toString().padLeft(2, '0') ?? '';
                            final date = createdAt == null
                                ? ''
                                : '${createdAt.year}-$month-$day';
                            final progressLabel = '${(progress * 100).round()}%';
                            final bookmarkTitle =
                                '${item['chapterTitle'] ?? ''}'.trim();
                            final subtitle = date.isEmpty
                                ? progressLabel
                                : '$progressLabel • $date';
                            return ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              tileColor: AppColors.searchBar,
                              leading: Icon(Icons.bookmark_rounded,
                                  color: AppColors.primary),
                              title: Text(
                                bookmarkTitle.isEmpty
                                    ? 'الفصل'.tr
                                    : bookmarkTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: AppColors.textPrimary),
                              ),
                              subtitle: Text(
                                subtitle,
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                              trailing: IconButton(
                                tooltip: 'حذف'.tr,
                                onPressed: () => controller.removeReaderBookmark(
                                  '${item['id'] ?? ''}',
                                ),
                                icon: Icon(Icons.delete_outline_rounded,
                                    color: AppColors.icon),
                              ),
                              onTap: () {
                                Get.back();
                                controller.openReaderBookmark(item);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      }),
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      isScrollControlled: true,
    );
  }

  Future<void> _openChapterList() async {
    await controller.ensureChapterNavigation();
    final chapters = controller.availableChapters;
    if (chapters.isEmpty) {
      AppFeedback.show(
        title: 'قائمة الفصول'.tr,
        message: 'لا توجد قائمة فصول متاحة'.tr,
      );
      return;
    }
      await Get.bottomSheet(
      SafeArea(
        child: SizedBox(
          height: Get.height * 0.78,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('الفصول'.tr,
                          style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w800)),
                    ),
                    Text('${chapters.length}',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Expanded(
                child: Obx(() {
                  controller.chapterNavigationRevision.value;
                  controller.readerBookmarks.length;
                  return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                  itemCount: chapters.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final item = chapters[index];
                    final current = controller.isCurrentChapter(item);
                    final isRead = controller.isChapterRead(item.chapterId);
                    final bookmark = controller.bookmarkForChapter(item.chapterId);
                    return ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      tileColor: current
                          ? AppColors.primary.withValues(alpha: 0.14)
                          : AppColors.searchBar,
                      leading: Icon(
                        current
                            ? Icons.play_circle_filled_rounded
                            : Icons.menu_book_rounded,
                        color: current ? AppColors.primary : AppColors.icon,
                      ),
                      title: Text(item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: current
                                  ? FontWeight.w800
                                  : FontWeight.w600)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (bookmark != null)
                            IconButton(
                              tooltip: 'الانتقال إلى العلامة المرجعية'.tr,
                              visualDensity: VisualDensity.compact,
                              onPressed: () {
                                Get.back();
                                controller.openReaderBookmark(bookmark);
                              },
                              icon: const Icon(
                                Icons.bookmark_rounded,
                                color: Color(0xff31c46c),
                                size: 21,
                              ),
                            ),
                          if (isRead)
                            Text(
                              'مقروء'.tr,
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                      onTap: current
                          ? null
                          : () {
                              Get.back();
                              controller.navigateToChapter(item.chapterId);
                            },
                    );
                  },
                  );
                }),
              ),
            ],
          ),
        ),
      ),
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      isScrollControlled: true,
    );
  }

  bool _isLocalReaderPage(String imageReference) =>
      imageReference.startsWith('/');

  void _markPageLoadedAndPreservePosition(int index, String imageReference) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.markPageLoaded(index, pageReference: imageReference);
      _restoreScrollAnchorAfterImageLayout();
    });
  }

  Widget _buildPagedImage(
    BuildContext context,
    String imageUrl,
    int pageIndex,
  ) {
    return Obx(() {
      final isLocalPage = _isLocalReaderPage(imageUrl);
      if (isLocalPage) {
        WidgetsBinding.instance.addPostFrameCallback((_) =>
            controller.markPageLoaded(pageIndex, pageReference: imageUrl));
      }
      final selectedFit = controller.readerFit.value;
      final decodeWidth = selectedFit == 'natural'
          ? null
          : (MediaQuery.sizeOf(context).width *
                  MediaQuery.devicePixelRatioOf(context))
              .round();
      final fit = selectedFit == 'height'
          ? BoxFit.fitHeight
          : selectedFit == 'natural'
              ? BoxFit.none
              : BoxFit.contain;
      final Widget image = isLocalPage
          ? Image.file(
              File(imageUrl),
              width: double.infinity,
              height: double.infinity,
              cacheWidth: decodeWidth,
              fit: fit,
              filterQuality: FilterQuality.medium,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) {
                WidgetsBinding.instance.addPostFrameCallback((_) =>
                    controller.markPageFailed(pageIndex, pageReference: imageUrl));
                return const Center(child: MangaPlusLogo(size: 56));
              },
            )
          : CachedNetworkImage(
              key: ValueKey('$imageUrl#${controller.pageRetryToken(pageIndex)}'),
              imageUrl: imageUrl,
              httpHeaders: _imageHeaders(imageUrl),
              memCacheWidth: decodeWidth,
                imageBuilder: (context, imageProvider) {
                  WidgetsBinding.instance.addPostFrameCallback((_) =>
                      controller.markPageLoaded(pageIndex, pageReference: imageUrl));
                  return Image(
                    image: imageProvider,
                    width: double.infinity,
                    height: double.infinity,
                    fit: fit,
                    filterQuality: FilterQuality.medium,
                    gaplessPlayback: true,
                  );
                },
                progressIndicatorBuilder: (context, url, downloadProgress) =>
                    Center(
                  child: MangaPlusLoader(
                    size: 58,
                    progress: controller.isNovel ? null : downloadProgress.progress,
                  ),
                ),
                placeholder: (context, url) => const Center(
                  child: MangaPlusLoader(size: 54),
                ),
                errorWidget: (context, url, error) {
                  WidgetsBinding.instance.addPostFrameCallback((_) =>
                      controller.markPageFailed(pageIndex, pageReference: imageUrl));
                  final issue = ReaderLoadIssue.from(
                    error,
                    fallbackTitle: 'تعذر تحميل الصورة',
                  );
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const MangaPlusLogo(size: 56),
                      const SizedBox(height: 8),
                      Text(issue.titleKey.tr,
                          style: TextStyle(color: AppColors.textPrimary)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          issue.descriptionKey.tr,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => controller.retryPage(
                          pageIndex,
                          pageReference: imageUrl,
                        ),
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text('إعادة المحاولة'.tr),
                      ),
                    ],
                  );
                },
            );
      return ColoredBox(
        color: Colors.black,
        child: SizedBox.expand(
          child: MangaTekOverlay(imageUrl: imageUrl, child: image),
        ),
      );
    });
  }

  Widget _buildImage(
    BuildContext context,
    String imageUrl,
    int pageIndex,
  ) {
    return Container(
      width: double.infinity,
      color: Colors.black,
      child: Obx(
        () {
          final isLocalPage = _isLocalReaderPage(imageUrl);
          if (isLocalPage) {
            _markPageLoadedAndPreservePosition(pageIndex, imageUrl);
          }
          final selectedFit = controller.readerFit.value;
          final decodeWidth = selectedFit == 'natural'
              ? null
              : (MediaQuery.sizeOf(context).width *
                      MediaQuery.devicePixelRatioOf(context))
                  .round();
          final pageImage = isLocalPage
              ? Image.file(
                  File(imageUrl),
                  width: double.infinity,
                  cacheWidth: decodeWidth,
                  fit: _imageFit(controller.readerFit.value),
                  filterQuality: FilterQuality.medium,
                  alignment: Alignment.topCenter,
                  gaplessPlayback: true,
                errorBuilder: (context, error, stackTrace) {
                  WidgetsBinding.instance.addPostFrameCallback((_) =>
                      controller.markPageFailed(pageIndex, pageReference: imageUrl));
                  return const Center(child: MangaPlusLogo(size: 56));
                },
              )
              : CachedNetworkImage(
                key: ValueKey('$imageUrl#${controller.pageRetryToken(pageIndex)}'),
                imageUrl: imageUrl,
                httpHeaders: _imageHeaders(imageUrl),
                memCacheWidth: decodeWidth,
                imageBuilder: (context, imageProvider) {
                  _markPageLoadedAndPreservePosition(pageIndex, imageUrl);
                  return Image(
                    image: imageProvider,
                    width: double.infinity,
                    fit: _imageFit(controller.readerFit.value),
                    filterQuality: FilterQuality.medium,
                    gaplessPlayback: true,
                  );
                },
                progressIndicatorBuilder: (context, url, downloadProgress) =>
                    SizedBox(
                  width: double.infinity,
                  height: MediaQuery.sizeOf(context).height * 0.68,
                  child: Center(
                    child: MangaPlusLoader(
                      size: 58,
                      progress: controller.isNovel ? null : downloadProgress.progress,
                    ),
                  ),
                ),
                placeholder: (context, url) => SizedBox(
                  width: double.infinity,
                  height: MediaQuery.sizeOf(context).height * 0.68,
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      MangaPlusLoader(size: 54),
                    ],
                  ),
                ),
                errorWidget: (context, url, error) {
                  WidgetsBinding.instance.addPostFrameCallback((_) =>
                      controller.markPageFailed(pageIndex, pageReference: imageUrl));
                  final issue = ReaderLoadIssue.from(
                    error,
                    fallbackTitle: 'تعذر تحميل الصورة',
                  );
                  return SizedBox(
                    width: double.infinity,
                    height: MediaQuery.sizeOf(context).height * 0.68,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const MangaPlusLogo(size: 56),
                        const SizedBox(height: 10),
                        Text(
                          issue.titleKey.tr,
                          style: TextStyle(color: AppColors.textPrimary),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Text(
                            issue.descriptionKey.tr,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => controller.retryPage(
                            pageIndex,
                            pageReference: imageUrl,
                          ),
                          icon: const Icon(Icons.refresh_rounded),
                          label: Text('إعادة المحاولة'.tr),
                        ),
                      ],
                    ),
                  );
                },
              );
          return MangaTekOverlay(imageUrl: imageUrl, child: pageImage);
        },
      ),
    );
  }

  /// Small translucent chip with the real page-load ratio. It never takes taps
  /// away from the reader and hides itself once the chapter has finished
  /// loading (or shortly after, on a slow connection).
  Widget _buildPageLoadIndicator(BuildContext context) {
    return Obx(() {
      controller.pageLoadRevision.value;
      if (!controller.showPageLoadProgress.value) return const SizedBox.shrink();
      final progress = controller.pageLoadProgress;
      if (progress == null) return const SizedBox.shrink();
      final percent = (progress * 100).round().clamp(0, 100);
      return Positioned(
        top: MediaQuery.paddingOf(context).top + 10,
        left: 0,
        right: 0,
        child: IgnorePointer(
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0x94000000),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 1.8,
                      backgroundColor: const Color(0x33FFFFFF),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    '$percent%',
                    style: const TextStyle(
                      color: Color(0xE6FFFFFF),
                      fontSize: 11,
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

  Future<void> _preloadImages(
    BuildContext context,
    List<String> imageUrls, {
    int start = 0,
    int count = 3,
  }) async {
    if (!context.mounted) return;
    final urls = imageUrls
        .skip(start)
        .take(count)
        .where((url) => !_isLocalReaderPage(url))
        .where(_preloadedImages.add)
        .toList(growable: false);
    // Decode in small batches: a whole adjacent chapter can hold well over a
    // hundred pages, and warming them all at once spikes memory on low-end
    // devices. Batching keeps the boundary warm without the spike.
    const batchSize = 3;
    for (var offset = 0; offset < urls.length; offset += batchSize) {
      if (!context.mounted) return;
      final batch = urls.skip(offset).take(batchSize);
      await Future.wait(batch.map((url) async {
        try {
          await precacheImage(
            CachedNetworkImageProvider(
              url,
              headers: _imageHeaders(url),
            ),
            context,
          );
        } catch (error) {
          _preloadedImages.remove(url);
          debugPrint('Unable to preload page: $error');
        }
      }));
    }
  }

  void _preloadAdjacentChapterImages(
    BuildContext context, {
    bool previous = false,
  }) {
    final adjacentChapter = previous
        ? controller.previousChapterId
        : controller.nextChapterId;
    if (adjacentChapter == null) return;
    unawaited(controller.prefetchChapter(adjacentChapter).then((data) {
      if (!context.mounted || data == null || controller.isNovel) return;
      const start = 0;
      // Precache every page in the adjacent chapter. The chapter data itself
      // is already cached by ComicService, so crossing the boundary becomes
      // an in-memory list update instead of a network wait.
      final count = data.chapter.images.length;
      _preloadImages(
        context,
        data.chapter.images,
        start: start,
        count: count,
      );
    }));
  }

  Map<String, String> _imageHeaders(String imageUrl) {
    final uri = Uri.tryParse(imageUrl);
    final isMangaDar = uri?.host == 'storage.mangadar.com' ||
        uri?.host.endsWith('.storage.mangadar.com') == true ||
        uri?.host == 'mangadar.com';
    final host = uri?.host.toLowerCase() ?? '';
    final isProComic = host == 'procomic.pro' || host.endsWith('.procomic.pro');
    final isMangaSid = host == 'api.mangasid.com' || host.endsWith('.mangasidcdn.com');
    final isMangaTek = host == 'api.mangatek.com' || host.endsWith('.mangatek.com');
    return {
      'Referer': isProComic
          ? 'https://procomic.pro/'
          : isMangaSid
                  ? 'https://mangasid.com/'
                  : isMangaTek
                      ? 'https://mangatek.com/'
                      : isMangaDar
                          ? 'https://mangadar.com/'
                          : uri == null || uri.host.isEmpty
                              ? 'https://olympustaff.com/'
                              : '${uri.scheme}://${uri.host}/',
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/131 Mobile Safari/537.36',
    };
  }
}
