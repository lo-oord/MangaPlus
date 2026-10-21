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
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.card,
      colorText: AppColors.textPrimary,
      borderRadius: 18,
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      duration: type == AppNoticeType.error
          ? const Duration(seconds: 4)
          : const Duration(milliseconds: 2800),
      animationDuration: const Duration(milliseconds: 260),
      forwardAnimationCurve: Curves.easeOutCubic,
      reverseAnimationCurve: Curves.easeInCubic,
      shouldIconPulse: false,
      icon: const MangaPlusLogo(size: 28),
      titleText: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: type == AppNoticeType.error
              ? AppColors.error
              : type == AppNoticeType.success
                  ? AppColors.success
                  : AppColors.primary,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
      messageText: Text(
        message,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: AppColors.textPrimary, height: 1.35),
      ),
    );
  }
}
