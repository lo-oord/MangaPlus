import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/core/translations/content_localization.dart';
import 'package:mangaplus/app/data/services/bookmark_state_service.dart';
import 'package:mangaplus/app/widgets/brand_state.dart';

class CustomCardNormal extends StatelessWidget {
  final String title;
  final String chapter;
  final String imageUrl;
  final String? type;
  final String releaseDate;
  final String rating;
  final String status;
  final String? comicId;

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                httpHeaders: const {
                  'Referer': 'https://olympustaff.com/',
                  'User-Agent':
                      'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/131 Mobile Safari/537.36',
                },
                width: 120,
                height: 150,
                memCacheWidth: 360,
                maxWidthDiskCache: 720,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: 120,
                  height: 150,
                  color: AppColors.searchBar,
                  alignment: Alignment.center,
                  child: const MangaPlusLogo(size: 52),
                ),
                errorWidget: (context, url, error) => Container(
                  width: 120,
                  height: 150,
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
          width: 120,
          child: Text(
            title,
            maxLines: 2,
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
            width: 120,
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
            width: 120,
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

  Color _statusColor(String value) {
    final statusText = localizeContentStatus(value).toLowerCase();
    if (statusText == 'مستمر'.tr.toLowerCase() || statusText == 'ongoing') return const Color(0xff43b581);
    if (statusText == 'متوقف مؤقتًا'.tr.toLowerCase() || statusText == 'paused' || statusText == 'hiatus') return const Color(0xffe5a947);
    return AppColors.textSecondary;
  }
}
