import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/cache/manga_cover_cache_manager.dart';
import 'package:mangaplus/app/core/theme/app_palette.dart';
import 'package:mangaplus/app/core/theme/design_tokens.dart';
import 'package:mangaplus/app/core/translations/content_localization.dart';
import 'package:mangaplus/app/data/models/comic.dart';
import 'package:mangaplus/app/data/services/bookmark_state_service.dart';
import 'package:mangaplus/app/data/sources/source_brand.dart';
import 'package:mangaplus/app/data/sources/source_values.dart';
import 'package:mangaplus/app/modules/search/controllers/search_controller.dart'
    as search_controller;
import 'package:mangaplus/app/routes/app_pages.dart';
import 'package:mangaplus/app/widgets/app_surfaces.dart';
import 'package:mangaplus/app/widgets/brand_state.dart';
import 'package:mangaplus/app/widgets/mangaplus_app_bar.dart';
import 'package:mangaplus/app/widgets/theme_aware_builder.dart';

class SearchView extends GetView<search_controller.SearchController> {
  const SearchView({super.key});

  @override
  Widget build(BuildContext context) {
    return ThemeAwareBuilder(
      builder: (context) => Scaffold(
        backgroundColor: context.palette.background,
        appBar: MangaPlusAppBar(title: 'بحث'.tr),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.xs,
                AppSpacing.screen,
                AppSpacing.sm,
              ),
              child: _searchField(context),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                0,
                AppSpacing.screen,
                AppSpacing.xs,
              ),
              child: Obx(
                () => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChoice(context, 'all', 'الكل'.tr),
                      const SizedBox(width: AppSpacing.xs),
                      ...controller.availableTypes.map(
                        (type) => Padding(
                          padding: const EdgeInsetsDirectional.only(
                            end: AppSpacing.xs,
                          ),
                          child: _filterChoice(
                            context,
                            type,
                            localizeContentType(type),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(child: _results(context)),
          ],
        ),
      ),
    );
  }

  Widget _searchField(BuildContext context) {
    final p = context.palette;
    return TextField(
      controller: controller.textController,
      onChanged: controller.searchComics,
      onSubmitted: controller.searchComics,
      textInputAction: TextInputAction.search,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        hintText: 'ابحث عن المانجا'.tr,
        prefixIcon: Icon(Icons.search_rounded, color: p.icon),
        suffixIcon: Obx(
          () => controller.query.value.isNotEmpty
              ? IconButton(
                  tooltip: 'مسح البحث'.tr,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: controller.clearSearch,
                )
              : const SizedBox.shrink(),
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadii.pillAll,
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.pillAll,
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.pillAll,
          borderSide: BorderSide(color: p.primary, width: 1.5),
        ),
      ),
    );
  }

  Widget _results(BuildContext context) {
    return Obx(() {
      if (controller.query.value.isEmpty) {
        if (controller.isLoadingSuggestions.value &&
            controller.suggestions.isEmpty) {
          return BrandState.loading(title: 'جارٍ تحميل المحتوى'.tr);
        }
        if (controller.suggestions.isEmpty) {
          return BrandState.error(
            title: 'لا توجد اقتراحات'.tr,
            actionLabel: 'إعادة المحاولة'.tr,
            onAction: controller.loadSuggestions,
          );
        }
        if (controller.visibleSuggestions.isEmpty) {
          return BrandState.empty(
            title: 'لا توجد اقتراحات لهذا التصنيف'.tr,
            icon: Icons.filter_alt_off_rounded,
          );
        }
        return _comicList(
          context,
          title: 'اقتراحات'.tr,
          items: controller.visibleSuggestions,
        );
      }
      if (controller.isLoading.value && controller.comicsList.isEmpty) {
        return BrandState.loading(title: 'جارٍ البحث'.tr);
      }
      if (controller.hasError.value) {
        return BrandState.error(
          title: 'تعذر تحميل نتائج البحث'.tr,
          description: 'تحقق من اتصالك بالإنترنت ثم حاول مجدداً.'.tr,
          onAction: () => controller.searchComics(controller.query.value),
        );
      }
      if (controller.comicsList.isEmpty) {
        return BrandState.empty(
          title: 'لم يتم العثور على نتائج'.tr,
          description: 'جرّب كلمات أخرى أو غيّر التصنيف.'.tr,
          icon: Icons.search_off_rounded,
        );
      }
      return _comicList(
        context,
        title: 'النتائج'.tr,
        items: controller.comicsList,
        isLoadingMore: controller.isLoading.value,
      );
    });
  }

  Widget _filterChoice(BuildContext context, String value, String label) {
    final selected = controller.typeFilter.value == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => controller.setTypeFilter(value),
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: selected
                ? context.palette.primary
                : context.palette.textSecondary,
            fontWeight: FontWeight.w700,
          ),
    );
  }

  Widget _comicList(
    BuildContext context, {
    required String title,
    required List<ComicsList> items,
    bool isLoadingMore = false,
  }) {
    final text = Theme.of(context).textTheme;
    return ListView.separated(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.xxs,
        AppSpacing.screen,
        AppSpacing.lg,
      ),
      itemCount: items.length + 1 + (isLoadingMore ? 1 : 0),
      separatorBuilder: (_, index) =>
          SizedBox(height: index == 0 ? AppSpacing.xs : AppSpacing.xs + 2),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
            child: Row(
              children: [
                Expanded(
                  child: Text(title, style: text.titleMedium),
                ),
                AppPill(
                  label: '${items.length}',
                  tone: AppPillTone.primary,
                ),
              ],
            ),
          );
        }
        if (index == items.length + 1) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Center(child: MangaPlusLoader(size: 42)),
          );
        }
        return _SearchComicTile(comic: items[index - 1]);
      },
    );
  }
}

class _SearchComicTile extends StatelessWidget {
  const _SearchComicTile({required this.comic});

  final ComicsList comic;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final isNovel = SourceValues.isNovelType(comic.type);
    final genreText = comic.genres.isNotEmpty
        ? comic.genres.take(3).map(localizeContentGenre).join(' • ')
        : isNovel
            ? ''
            : localizeContentType(comic.type);
    final rawStatus = comic.status?.trim() ?? '';
    final statusText = rawStatus.isEmpty
        ? 'غير معروف'.tr
        : localizeContentStatusOr(rawStatus, 'غير معروف'.tr);
    final isOngoing = rawStatus == SourceValues.statusOngoing;
    final isCompleted = rawStatus == SourceValues.statusCompleted;
    final statusIcon = isOngoing
        ? Icons.autorenew_rounded
        : isCompleted
            ? Icons.check_circle_rounded
            : Icons.pause_circle_filled_rounded;
    final statusTone = isOngoing
        ? AppPillTone.success
        : isCompleted
            ? AppPillTone.primary
            : AppPillTone.warning;
    final countText = comic.totalChapters.trim().isEmpty
        ? 'غير محدد'.tr
        : 'عدد الفصول: @value'.trParams({'value': comic.totalChapters});
    final ratingText = comic.rating.trim().isEmpty ? '—' : comic.rating.trim();

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xs + 2),
      onTap: () => Get.toNamed(
        Routes.COMIC_DETAIL,
        arguments: comic.comicId,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: AppRadii.smAll,
                child: CachedNetworkImage(
                  imageUrl: comic.image,
                  cacheManager: MangaCoverCacheManager.instance,
                  httpHeaders: MangaCoverCacheManager.requestHeadersForWorkUrl(
                    comic.comicId,
                  ),
                  width: 76,
                  height: 104,
                  memCacheWidth: 228,
                  maxWidthDiskCache: 720,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    width: 76,
                    height: 104,
                    color: p.surfaceVariant,
                    alignment: Alignment.center,
                    child: const MangaPlusLogo(size: 30),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    width: 76,
                    height: 104,
                    color: p.surfaceVariant,
                    alignment: Alignment.center,
                    child: const MangaPlusLogo(size: 30),
                  ),
                ),
              ),
              Obx(() {
                if (!BookmarkStateService.instance.contains(comic.comicId)) {
                  return const SizedBox.shrink();
                }
                return Positioned(
                  top: AppSpacing.xxs + 2,
                  right: AppSpacing.xxs + 2,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: p.scrim,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: Color(0xffef5350),
                      size: 14,
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comic.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                if (genreText.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xxs + 2),
                  Text(
                    genreText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall,
                  ),
                ],
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs - 2,
                  runSpacing: AppSpacing.xxs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    AppPill(
                      icon: Icons.category_outlined,
                      label: localizeContentType(comic.type),
                      tone: AppPillTone.primary,
                    ),
                    _SourceMetaBadge(comic: comic),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xxs + 2,
                  runSpacing: AppSpacing.xxs + 2,
                  children: [
                    AppPill(
                      icon: Icons.menu_book_rounded,
                      label: countText,
                    ),
                    AppPill(
                      icon: statusIcon,
                      label: statusText,
                      tone: statusTone,
                    ),
                    AppPill(
                      icon: Icons.star_rounded,
                      label: ratingText,
                      tone: AppPillTone.warning,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceMetaBadge extends StatelessWidget {
  const _SourceMetaBadge({required this.comic});

  final ComicsList comic;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      constraints: const BoxConstraints(maxWidth: 150),
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 4),
      decoration: BoxDecoration(
        color: p.surfaceVariant,
        borderRadius: AppRadii.xsAll,
      ),
      child: SourceBrandMark(
        source: comic.source,
        workUrl: comic.link,
        nameColor: p.textPrimary,
        fontSize: 10,
        iconSize: 13,
      ),
    );
  }
}
