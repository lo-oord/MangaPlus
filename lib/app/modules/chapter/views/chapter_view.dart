import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/data/models/chapter.dart';
import 'package:mangaplus/app/modules/chapter/controllers/chapter_controller.dart';
import 'package:mangaplus/app/routes/app_pages.dart';
import 'package:mangaplus/app/widgets/app_feedback.dart';
import 'package:mangaplus/app/widgets/brand_state.dart';
import 'package:mangaplus/app/widgets/theme_aware_builder.dart';

class ChapterView extends GetView<ChapterController> {
  ChapterView({super.key});
  final List<GlobalKey> _pageKeys = <GlobalKey>[];
  final Set<String> _preloadedImages = <String>{};

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final images = controller.chapterData.value.chapter.images;
      if (images.isNotEmpty && !controller.isOffline.value) {
        _preloadImages(context, images);
      }
    });

    return ThemeAwareBuilder(builder: (context) => Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          _buildContent(context),
          _buildFloatingNavigation(),
        ],
      ),
    ));
  }

  Widget _buildContent(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value) {
        return BrandState(title: 'جارٍ تحميل الفصل'.tr, loading: true);
      }
      if (controller.hasError.value) {
        return BrandState(
          title: 'تعذر تحميل الفصل'.tr,
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
                }
              },
              itemBuilder: (context, index) =>
                  _buildPagedImage(context, chapter.images[index]),
            ),
          ),
        );
      }
      if (_pageKeys.length != chapter.images.length) {
        _pageKeys
          ..clear()
          ..addAll(List.generate(chapter.images.length, (_) => GlobalKey()));
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) controller.syncScrollController();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateCurrentPage(context));
      return GestureDetector(
        onTap: controller.toggleNavigationVisibility,
        behavior: HitTestBehavior.opaque,
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollUpdateNotification ||
                notification is ScrollEndNotification) {
              controller.handleScroll(notification.metrics);
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
            itemCount: chapter.images.length,
            itemBuilder: (context, index) => KeyedSubtree(
              key: _pageKeys[index],
              child: _buildImage(context, chapter.images[index]),
            ),
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
      return FutureBuilder<List<String>>(
        future: controller.paragraphsFor(chapter.content),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return ColoredBox(
              color: background,
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
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
                    controller.handleScroll(notification.metrics);
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
                      itemBuilder: (context, index) => Padding(
                        padding: EdgeInsets.only(
                          bottom: index == paragraphs.length - 1
                              ? 0
                              : controller.novelParagraphSpacing.value,
                        ),
                        child: Text(
                          paragraphs[index],
                          textAlign:
                              controller.readingDirection.value == 'rtl'
                                  ? TextAlign.right
                                  : TextAlign.left,
                          style: TextStyle(
                            color: foreground,
                            fontSize: controller.novelFontSize.value,
                            fontFamily: family == 'default' ? null : family,
                            height: controller.novelLineHeight.value,
                            letterSpacing: 0.05,
                          ),
                        ),
                      ),
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
      controller.navigateToChapter(controller.nextChapterId);
    } else {
      controller.navigateToChapter(controller.previousChapterId);
    }
  }

  void _updateCurrentPage(BuildContext context) {
    final screenCenter = MediaQuery.sizeOf(context).height / 2;
    var bestIndex = controller.currentPage.value;
    var bestDistance = double.infinity;
    for (var index = 0; index < _pageKeys.length; index++) {
      final renderObject = _pageKeys[index].currentContext?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) continue;
      final top = renderObject.localToGlobal(Offset.zero).dy;
      final bottom = top + renderObject.size.height;
      if (top <= screenCenter && bottom >= screenCenter) {
        bestIndex = index;
        break;
      }
      final distance = screenCenter < top ? top - screenCenter : screenCenter - bottom;
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = index;
      }
    }
    if (bestIndex != controller.currentPage.value) {
      controller.setCurrentPage(bestIndex);
    }
  }

  Widget _buildFloatingNavigation() {
    return Obx(() {
      final chapter = controller.chapterData.value.chapter;
      final progress = controller.isNovel
          ? controller.novelProgress.value
          : chapter.images.isEmpty
              ? 0.0
              : (controller.currentPage.value + 1) / chapter.images.length;
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
                constraints: const BoxConstraints(minHeight: 70),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                child: Row(
                  children: [
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
                    if (controller.isNovel)
                      _readerIconButton(
                        icon: Icons.bookmarks_outlined,
                        tooltip: 'العلامات المرجعية'.tr,
                        onPressed: _openNovelBookmarks,
                      ),
                    if (controller.isNovel)
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
                    Expanded(
                      child: GestureDetector(
                        onTap: _openChapterList,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              chapter.title.isNotEmpty
                                  ? chapter.title
                                  : 'الفصل'.tr,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              controller.isNovel
                                  ? '${(progress * 100).round()}%'
                                  : '${controller.currentPage.value + 1} / ${chapter.images.length}',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 5),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 2.5,
                                backgroundColor: AppColors.divider,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _readerIconButton(
                      icon: Icons.chevron_left_rounded,
                      tooltip: 'الفصل السابق'.tr,
                      onPressed: controller.previousChapterId != null
                          ? () => controller.navigateToChapter(controller.previousChapterId)
                          : null,
                    ),
                    _readerIconButton(
                      icon: Icons.chevron_right_rounded,
                      tooltip: 'الفصل التالي'.tr,
                      onPressed: controller.nextChapterId != null
                          ? () => controller.navigateToChapter(controller.nextChapterId)
                          : null,
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

  Widget _readerIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      color: onPressed == null
          ? AppColors.icon.withValues(alpha: 0.35)
          : AppColors.primary,
      iconSize: 22,
      visualDensity: VisualDensity.compact,
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
                  Text('وضع القراءة'.tr,
                      style: TextStyle(color: AppColors.textSecondary)),
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
                    Text('اتجاه القراءة'.tr,
                        style: TextStyle(color: AppColors.textSecondary)),
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
                  Text('ملاءمة الصور'.tr,
                      style: TextStyle(color: AppColors.textSecondary)),
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
                  const SizedBox(height: 10),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: controller.continuousNavigation.value,
                    onChanged: controller.setContinuousNavigation,
                    title: Text('التنقل المتصل بين الفصول'.tr,
                        style: TextStyle(color: AppColors.textPrimary)),
                    subtitle: Text('الانتقال التلقائي عند نهاية الفصل'.tr,
                        style: TextStyle(color: AppColors.textSecondary)),
                    activeColor: AppColors.primary,
                  ),
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
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: controller.continuousNavigation.value,
                      onChanged: controller.setContinuousNavigation,
                      title: Text('التنقل المتصل بين الفصول'.tr,
                          style: TextStyle(color: AppColors.textPrimary)),
                      subtitle: Text('الانتقال التلقائي عند نهاية الفصل'.tr,
                          style: TextStyle(color: AppColors.textSecondary)),
                      activeColor: AppColors.primary,
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

  Future<void> _openNovelBookmarks() async {
    await Get.bottomSheet(
      Obx(() {
        final bookmarks = controller.novelBookmarks.toList(growable: false);
        return SafeArea(
          child: SizedBox(
            height: Get.height * 0.68,
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
                      onPressed: () => controller.saveNovelBookmark(),
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
                                onPressed: () => controller.removeNovelBookmark(
                                  '${item['id'] ?? ''}',
                                ),
                                icon: Icon(Icons.delete_outline_rounded,
                                    color: AppColors.icon),
                              ),
                              onTap: () {
                                Get.back();
                                controller.openNovelBookmark(item);
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
          height: Get.height * 0.68,
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
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                  itemCount: chapters.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final item = chapters[index];
                    final current = controller.isCurrentChapter(item);
                    final isRead = controller.isChapterRead(item.chapterId);
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
                      trailing: isRead
                          ? Text(
                              'مقروء'.tr,
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
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

  Widget _buildPagedImage(BuildContext context, String imageUrl) {
    return Obx(() {
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
      final Widget image = controller.isOffline.value
          ? Image.file(
              File(imageUrl),
              width: double.infinity,
              height: double.infinity,
              cacheWidth: decodeWidth,
              fit: fit,
              filterQuality: FilterQuality.medium,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) => const Center(
                child: Icon(Icons.broken_image_outlined, color: Colors.white70),
              ),
            )
          : CachedNetworkImage(
              imageUrl: imageUrl,
              httpHeaders: _imageHeaders(imageUrl),
              memCacheWidth: decodeWidth,
              imageBuilder: (context, imageProvider) => Image(
                image: imageProvider,
                width: double.infinity,
                height: double.infinity,
                fit: fit,
                filterQuality: FilterQuality.medium,
                gaplessPlayback: true,
              ),
              placeholder: (context, url) => const Center(
                child: MangaPlusLoader(size: 54),
              ),
              errorWidget: (context, url, error) => Center(
                child: IconButton(
                  tooltip: 'إعادة المحاولة'.tr,
                  onPressed: () => controller.fetchChapter(controller.chapterId),
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                ),
              ),
            );
      return ColoredBox(
        color: Colors.black,
        child: SizedBox.expand(child: image),
      );
    });
  }

  Widget _buildImage(BuildContext context, String imageUrl) {
    return Container(
      width: double.infinity,
      color: Colors.black,
      child: Obx(
        () {
          final selectedFit = controller.readerFit.value;
          final decodeWidth = selectedFit == 'natural'
              ? null
              : (MediaQuery.sizeOf(context).width *
                      MediaQuery.devicePixelRatioOf(context))
                  .round();
          return controller.isOffline.value
              ? Image.file(
                  File(imageUrl),
                  width: double.infinity,
                  cacheWidth: decodeWidth,
                  fit: _imageFit(controller.readerFit.value),
                  filterQuality: FilterQuality.medium,
                  alignment: Alignment.topCenter,
                  gaplessPlayback: true,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(Icons.broken_image_outlined, color: Colors.white70),
                ),
              )
              : CachedNetworkImage(
                imageUrl: imageUrl,
                httpHeaders: _imageHeaders(imageUrl),
                memCacheWidth: decodeWidth,
                imageBuilder: (context, imageProvider) => Image(
                  image: imageProvider,
                  width: double.infinity,
                  fit: _imageFit(controller.readerFit.value),
                  filterQuality: FilterQuality.medium,
                  gaplessPlayback: true,
                ),
                placeholder: (context, url) => SizedBox(
                  width: double.infinity,
                  height: MediaQuery.sizeOf(context).height * 0.68,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const MangaPlusLoader(size: 54),
                    ],
                  ),
                ),
                errorWidget: (context, url, error) => SizedBox(
                  width: double.infinity,
                  height: MediaQuery.sizeOf(context).height * 0.68,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.broken_image_outlined,
                        size: 44,
                        color: Colors.white70,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'تعذر تحميل الصورة'.tr,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      TextButton.icon(
                        onPressed: () => controller.fetchChapter(controller.chapterId),
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text('إعادة المحاولة'.tr),
                      ),
                    ],
                  ),
                ),
              );
        },
      ),
    );
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
        .where(_preloadedImages.add)
        .toList(growable: false);
    await Future.wait(urls.map((url) async {
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
        debugPrint('Unable to preload Team X page: $error');
      }
    }));
  }

  Map<String, String> _imageHeaders(String imageUrl) {
    final uri = Uri.tryParse(imageUrl);
    final isMangaCloud = uri?.host == 'cdn.mangacloud.online' ||
        uri?.host.endsWith('.mangacloud.online') == true;
    return {
      'Referer': isMangaCloud
          ? 'https://mangacloud.online/'
          : uri == null || uri.host.isEmpty
          ? 'https://olympustaff.com/'
          : '${uri.scheme}://${uri.host}/',
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/131 Mobile Safari/537.36',
    };
  }
}
