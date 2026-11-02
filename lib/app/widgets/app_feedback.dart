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
      snackPosition: SnackPosition.TOP,
      backgroundColor: AppColors.card,
      colorText: AppColors.textPrimary,
      borderRadius: 14,
      margin: const EdgeInsets.fromLTRB(14, 52, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      duration: type == AppNoticeType.error
          ? const Duration(seconds: 4)
          : const Duration(milliseconds: 2800),
      animationDuration: const Duration(milliseconds: 220),
      forwardAnimationCurve: Curves.easeOutCubic,
      reverseAnimationCurve: Curves.easeInCubic,
      shouldIconPulse: false,
      icon: const MangaPlusLogo(size: 22),
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
          fontSize: 13,
        ),
      ),
      messageText: Text(
        message,
          maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 12,
          height: 1.25,
        ),
      ),
    );
  }
}
