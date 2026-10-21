import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/core/translations/content_localization.dart';
import 'package:mangaplus/app/data/models/bookmark.dart';
import 'package:mangaplus/app/modules/bookmark/controllers/bookmark_controller.dart';
import 'package:mangaplus/app/routes/app_pages.dart';
import 'package:mangaplus/app/widgets/brand_state.dart';

class BookmarkView extends GetView<BookmarkController> {
  const BookmarkView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('الإشارات المرجعية'.tr),
        centerTitle: true,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return BrandState(title: 'جارٍ تحميل المفضلة'.tr, loading: true);
        }
        final bookmarks = controller.bookmarks;

        if (bookmarks.isEmpty) {
          return _buildEmptyBookmark();
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 16),
          itemCount: bookmarks.length,
          itemBuilder: (context, index) {
            return _buildBookmarkItem(bookmarks[index]);
          },
        );
      }),
    );
  }

  Widget _buildEmptyBookmark() => BrandState(
        title: 'لا توجد إشارات مرجعية بعد'.tr,
      );

  Widget _buildBookmarkItem(BookmarkItem bookmark) {
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
          Get.toNamed(Routes.COMIC_DETAIL, arguments: bookmark.comicId);
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
                  imageUrl: bookmark.coverImage,
                  httpHeaders: const {
                    'Referer': 'https://olympustaff.com/',
                    'User-Agent':
                        'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/131 Mobile Safari/537.36',
                  },
                  width: 85,
                  height: 114,
                  memCacheWidth: 255,
                  maxWidthDiskCache: 720,
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

              // Bookmark Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Comic Title
                    Text(
                      bookmark.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Type
                    Text(
                      localizeContentType(bookmark.type),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Status or other comic information if needed
                    // You can add additional fields here as needed
                    // For example:
                    // Text(
                    //   bookmark.status ?? '',
                    //   style: TextStyle(
                    //     fontSize: 12,
                    //     color: AppColors.textSecondary,
                    //   ),
                    // ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
