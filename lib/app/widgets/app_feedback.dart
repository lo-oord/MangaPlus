import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/widgets/brand_state.dart';

enum AppNoticeType { info, success, error }

class AppFeedback {
  const AppFeedback._();

  static void show({
    required String title,
    required String message,
    AppNoticeType type = AppNoticeType.info,
  }) {
    Get.closeCurrentSnackbar();
    Get.snackbar(
      '',
      '',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.card.withValues(alpha: 0.9),
      colorText: AppColors.textPrimary,
      borderRadius: 15,
      margin: const EdgeInsets.fromLTRB(28, 8, 28, 74),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      maxWidth: 390,
      duration: type == AppNoticeType.error
          ? const Duration(seconds: 4)
          : const Duration(milliseconds: 2800),
      animationDuration: const Duration(milliseconds: 260),
      forwardAnimationCurve: Curves.easeOutCubic,
      reverseAnimationCurve: Curves.easeInCubic,
      shouldIconPulse: false,
      titleText: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MangaPlusLogo(size: 24),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message.trim().isEmpty ? title : message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: type == AppNoticeType.error
                    ? AppColors.error
                    : type == AppNoticeType.success
                        ? AppColors.success
                        : AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
      messageText: message.trim().isEmpty || message.trim() == title
          ? const SizedBox.shrink()
          : Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
    );
  }
}
