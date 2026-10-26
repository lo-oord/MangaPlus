import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/constants/colors.dart';

enum AppNoticeType { info, success, warning, error }

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
      snackStyle: SnackStyle.FLOATING,
      isDismissible: true,
      backgroundColor: AppColors.card,
      colorText: AppColors.textPrimary,
      borderRadius: 18,
      margin: const EdgeInsets.fromLTRB(14, 16, 14, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      duration: type == AppNoticeType.error
          ? const Duration(seconds: 4)
          : const Duration(milliseconds: 2800),
      animationDuration: const Duration(milliseconds: 260),
      forwardAnimationCurve: Curves.easeOutCubic,
      reverseAnimationCurve: Curves.easeInCubic,
      shouldIconPulse: false,
      icon: Icon(
        switch (type) {
          AppNoticeType.success => Icons.check_circle_rounded,
          AppNoticeType.warning => Icons.warning_amber_rounded,
          AppNoticeType.error => Icons.error_rounded,
          AppNoticeType.info => Icons.info_rounded,
        },
        size: 25,
        color: _noticeColor(type),
      ),
      titleText: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: _noticeColor(type),
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

  static Color _noticeColor(AppNoticeType type) => switch (type) {
        AppNoticeType.success => AppColors.success,
        AppNoticeType.warning => AppColors.warning,
        AppNoticeType.error => AppColors.error,
        AppNoticeType.info => AppColors.primary,
      };
}
