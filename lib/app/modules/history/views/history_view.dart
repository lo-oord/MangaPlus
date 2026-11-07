import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/cache/manga_cover_cache_manager.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/core/translations/content_localization.dart';
import 'package:mangaplus/app/data/models/history.dart';
import 'package:mangaplus/app/modules/history/controllers/history_controller.dart';
import 'package:mangaplus/app/routes/app_pages.dart';
import 'package:mangaplus/app/widgets/brand_state.dart';
import 'package:mangaplus/app/widgets/mangaplus_app_bar.dart';
import 'package:mangaplus/app/widgets/theme_aware_builder.dart';

class HistoryView extends GetView<HistoryController> {
  const HistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    return ThemeAwareBuilder(builder: (context) => Scaffold(
      backgroundColor: AppColors.background,
      appBar: MangaPlusAppBar(title: 'سجل القراءة'.tr),
      body: Obx(() {
        if (controller.isLoading.value) {
          return BrandState(title: 'جارٍ تحميل سجل القراءة'.tr, loading: true);
        }
        final histories = controller.histories;

        if (histories.isEmpty) {
          return _buildEmptyHistory();
        }

        return Obx(() {
          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 16),
            itemCount: histories.length,
            itemBuilder: (context, index) {
              return _buildHistoryItem(histories[index]);
            },
          );
        });
      }),
    ));
  }

  Widget _buildEmptyHistory() => BrandState(
        title: 'لا يوجد سجل قراءة بعد'.tr,
      );

  Widget _buildHistoryItem(HistoryItem history) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: AppColors.searchBar,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          Get.toNamed(Routes.COMIC_DETAIL, arguments: history.comicId);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Cover Image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: history.coverImage,
                  cacheManager: MangaCoverCacheManager.instance,
                  width: 85,
                  height: 114,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 80,
                    height: 100,
                    color: AppColors.background,
                    child: const Center(child: MangaPlusLogo(size: 48)),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 80,
                    height: 100,
                    color: AppColors.card,
                    child: const Center(child: MangaPlusLogo(size: 48)),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // History Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Comic Title
                    Text(
                      history.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    if (history.type.toLowerCase() != 'novel') ...[
                      Text(
                        localizeContentType(history.type),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],

                    // Last Read Time
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatTime(history.lastRead),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Chapter Button
                    SizedBox(
                      width: 110,
                      child: ElevatedButton(
                        onPressed: () {
                          Get.toNamed(
                            Routes.CHAPTER,
                            arguments: {
                              'comicId': history.comicId,
                              'comicTitle': history.title,
                              'coverImage': history.coverImage,
                              'comicType': history.type,
                              'chapterId': history.chapterId,
                              'chapterTitle': history.chapterTitle,
                            },
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                        child: Text(
                          history.chapterTitle
                              .replaceAll(RegExp(r'\s+'), ' ')
                              .trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
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
    );
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'منذ لحظات'.tr;
    } else if (difference.inMinutes < 60) {
      return _formatArabicDuration(
          difference.inMinutes, 'دقيقة'.tr, 'دقيقتين'.tr, 'دقائق'.tr);
    } else if (difference.inHours < 24) {
      return _formatArabicDuration(
          difference.inHours, 'ساعة'.tr, 'ساعتين'.tr, 'ساعات'.tr);
    } else if (difference.inDays < 7) {
      return _formatArabicDuration(
          difference.inDays, 'يوم'.tr, 'يومين'.tr, 'أيام'.tr);
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatArabicDuration(
      int value, String singular, String dual, String plural) {
    if (value == 2) {
      return 'منذ @duration'.trParams({'duration': dual});
    }
    if (value >= 3 && value <= 10) {
      return 'منذ @value @unit'.trParams({
        'value': '$value',
        'unit': plural,
      });
    }
    return 'منذ @value @unit'.trParams({
      'value': '$value',
      'unit': singular,
    });
  }
}
