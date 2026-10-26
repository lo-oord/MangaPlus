import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/core/cache/manga_cover_cache_manager.dart';
import 'package:mangaplus/app/core/translations/content_localization.dart';
import 'package:mangaplus/app/data/services/bookmark_state_service.dart';
import 'package:mangaplus/app/widgets/brand_state.dart';
import 'package:mangaplus/app/widgets/manga_shimmer.dart';

class CustomCardNormal extends StatelessWidget {
  final String title;
  final String chapter;
  final String imageUrl;
  final String? type;
  final String releaseDate;
  final String rating;
  final String status;
  final String? comicId;
  final double width;

  const CustomCardNormal({
    super.key,
    required this.title,
    required this.chapter,
    required this.imageUrl,
    this.type,
    this.releaseDate = '',
    this.rating = '',
    this.status = '',
    this.comicId,
    this.width = 120,
  });

  String _relativeDate() {
    final parsed = DateTime.tryParse(releaseDate.trim());
    if (parsed == null) return '';
    final date = parsed.toLocal();
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.isNegative) return '';
    if (difference.inSeconds < 60) return 'منذ لحظات'.tr;
    if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      if (minutes == 1) return 'منذ دقيقة'.tr;
      return 'منذ @value دقائق'.trParams({'value': '$minutes'});
    }
    if (difference.inHours < 24) {
      final hours = difference.inHours;
      if (hours == 1) return 'منذ ساعة'.tr;
      if (hours == 2) return 'منذ ساعتين'.tr;
      return 'منذ @value ساعات'.trParams({'value': '$hours'});
    }
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    final calendarDays = today.difference(dateOnly).inDays;
    if (calendarDays == 0) return 'اليوم'.tr;
    if (calendarDays == 1) return 'أمس'.tr;
    if (calendarDays == 2) return 'أول أمس'.tr;
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final relativeDate = _relativeDate();
    final coverHeight = width * 1.25;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                cacheManager: MangaCoverCacheManager.instance,
                httpHeaders: _imageHeaders(imageUrl),
                width: width,
                height: coverHeight,
                memCacheWidth: (width * 3).round(),
                maxWidthDiskCache: 720,
                fit: BoxFit.cover,
                imageBuilder: (context, imageProvider) => Stack(
                  fit: StackFit.expand,
                  children: [
                    Image(
                      image: imageProvider,
                      width: width,
                      height: coverHeight,
                      fit: BoxFit.cover,
                    ),
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Material(
                        color: Colors.black.withValues(alpha: .62),
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: 'معاينة الغلاف'.tr,
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints.tightFor(
                            width: 34,
                            height: 34,
                          ),
                          padding: EdgeInsets.zero,
                          onPressed: () => _showCoverPreview(context, imageProvider),
                          icon: const Icon(
                            Icons.open_in_full_rounded,
                            size: 17,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                placeholder: (context, url) => MangaShimmer.fill(),
                errorWidget: (context, url, error) => Container(
                  width: width,
                  height: coverHeight,
                  color: AppColors.searchBar,
                  alignment: Alignment.center,
                  child: const MangaPlusLogo(size: 52),
                ),
              ),
            ),
            if (chapter.trim().isNotEmpty)
              Positioned(
                left: 8,
                bottom: 8,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 88),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.76),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'الفصل@value'.trParams({'value': chapter}),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            Obx(() {
              if (!BookmarkStateService.instance.contains(comicId)) {
                return const SizedBox.shrink();
              }
              return Positioned(
                top: 7,
                right: 7,
                child: Container(
                  width: 29,
                  height: 29,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.52),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.favorite_rounded, color: Color(0xffef5350), size: 17),
                ),
              );
            }),
          ],
        ),
        const SizedBox(height: 7),
        SizedBox(
          width: width,
          child: Text(
            title,
            maxLines: 1,
            textAlign: TextAlign.start,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (rating.trim().isNotEmpty || status.trim().isNotEmpty) ...[
          const SizedBox(height: 5),
          SizedBox(
            width: width,
            child: Row(
              children: [
                if (rating.trim().isNotEmpty) ...[
                  const Icon(Icons.star_rounded, size: 13, color: Color(0xfff2b94b)),
                  const SizedBox(width: 2),
                  Text(rating.trim(), style: TextStyle(color: AppColors.textPrimary, fontSize: 10, fontWeight: FontWeight.w800)),
                  if (status.trim().isNotEmpty) const SizedBox(width: 7),
                ],
                if (status.trim().isNotEmpty)
                  Expanded(
                    child: Text(
                      localizeContentStatus(status),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: _statusColor(status), fontSize: 9.5, fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (relativeDate.isNotEmpty) ...[
          const SizedBox(height: 3),
          SizedBox(
            width: width,
            child: Text(
              relativeDate,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
              ),
              ),
          ),
        ],
      ],
    );
  }

  void _showCoverPreview(
    BuildContext context,
    ImageProvider<Object> imageProvider,
  ) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'إغلاق معاينة الغلاف'.tr,
      barrierColor: Colors.black.withValues(alpha: .92),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, _, __) => SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Center(
                child: InteractiveViewer(
                  minScale: .8,
                  maxScale: 4,
                  child: Image(
                    image: imageProvider,
                    width: MediaQuery.sizeOf(dialogContext).width,
                    height: MediaQuery.sizeOf(dialogContext).height,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 4,
              left: 8,
              child: IconButton(
                tooltip: 'إغلاق'.tr,
                onPressed: () => Navigator.of(dialogContext).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: .96, end: 1).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      ),
    );
  }

  Color _statusColor(String value) {
    final statusText = localizeContentStatus(value).toLowerCase();
    if (statusText == 'مستمر'.tr.toLowerCase() || statusText == 'ongoing') return const Color(0xff43b581);
    if (statusText == 'متوقف مؤقتًا'.tr.toLowerCase() || statusText == 'paused' || statusText == 'hiatus') return const Color(0xffe5a947);
    return AppColors.textSecondary;
  }

  Map<String, String> _imageHeaders(String url) {
    final isKawaii = Uri.tryParse(url)?.host.toLowerCase() == 'manga-cdn.kawaii-anime.com';
    return {
      'Referer': isKawaii ? 'https://kawaiimanga.org/' : 'https://olympustaff.com/',
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/131 Mobile Safari/537.36',
    };
  }
}
