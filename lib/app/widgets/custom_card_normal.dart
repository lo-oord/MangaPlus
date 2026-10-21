import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/core/translations/content_localization.dart';
import 'package:mangaplus/app/widgets/brand_state.dart';

class CustomCardNormal extends StatelessWidget {
  final String title;
  final String chapter;
  final String imageUrl;
  final String? type;

  const CustomCardNormal({
    super.key,
    required this.title,
    required this.chapter,
    required this.imageUrl,
    this.type,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                width: 120,
                height: 150,
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
            Positioned(
              left: 7,
              top: 7,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  chapter,
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
            if (type != null && type!.trim().isNotEmpty)
              Positioned(
                right: 7,
                top: 7,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.card.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    localizeContentType(type!),
                    maxLines: 1,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
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
      ],
    );
  }
}
