import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
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
                  _buildPagedImage(chapter.images[index]),
            ),
          ),
        );
      }
      if (_pageKeys.length != chapter.images.length) {
        _pageKeys
          ..clear()
          ..addAll(List.generate(chapter.images.length, (_) => GlobalKey()));
      }
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
              child: _buildImage(chapter.images[index]),
            ),
          ),
        ),
      );
    });
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
      controller.onPageChanged(controller.currentPage.value);
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
                      onPressed: controller.canUseChapterList
                          ? _openChapterList
                          : () => AppFeedback.show(
                                title: 'قائمة الفصول'.tr,
                                message: 'لا توجد قائمة فصول متاحة'.tr,
                              ),
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
                              '${controller.currentPage.value + 1} / ${chapter.images.length}',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 5),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: chapter.images.isEmpty
                                    ? 0
                                    : (controller.currentPage.value + 1) /
                                        chapter.images.length,
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

  Future<void> _openChapterList() async {
    final chapters = controller.availableChapters;
    if (chapters.isEmpty) return;
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
                    final current = item.chapterId == controller.chapterId;
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

  Widget _buildPagedImage(String imageUrl) {
    return Obx(() {
      final selectedFit = controller.readerFit.value;
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

  Widget _buildImage(String imageUrl) {
    return Container(
      width: double.infinity,
      color: Colors.black,
      child: Obx(
        () => controller.isOffline.value
              ? Image.file(
                  File(imageUrl),
                  width: double.infinity,
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
              ),
      ),
    );
  }

  Future<void> _preloadImages(
    BuildContext context,
    List<String> imageUrls, {
    int start = 0,
    int count = 3,
  }) async {
    for (final url in imageUrls.skip(start).take(count)) {
      if (!_preloadedImages.add(url)) continue;
      try {
        await precacheImage(
          CachedNetworkImageProvider(
            url,
            headers: _imageHeaders(url),
          ),
          context,
        );
      } catch (error) {
        debugPrint('Unable to preload Team X page: $error');
      }
    }
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
