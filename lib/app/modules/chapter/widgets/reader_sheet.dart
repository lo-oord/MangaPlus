import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/core/theme/design_tokens.dart';

/// Presents a reader surface on Flutter's own modal bottom sheet.
///
/// The reader previously used an overlay bottom sheet for the page navigator
/// and the chapter list; on device that could leave only the dimmed barrier
/// visible. This wrapper always gives the child a real, bounded surface with a
/// Material ancestor, so content cannot collapse into an empty grey area.
Future<T?> showReaderSheet<T>(
  BuildContext context, {
  required Widget child,
  double heightFactor = .84,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: .55),
    builder: (sheetContext) => Container(
      height: MediaQuery.sizeOf(sheetContext).height * heightFactor,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: const Border(
          top: BorderSide(color: Color(0x1affffff)),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Title row shared by the reader sheets. Keeps close affordance and a single
/// subtitle line so no sheet grows a second header.
class ReaderSheetHeader extends StatelessWidget {
  const ReaderSheetHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onClose,
  });

  final String title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  DefaultTextStyle.merge(
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    child: subtitle!,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
          IconButton(
            tooltip: 'إغلاق'.tr,
            onPressed: onClose ?? Get.back,
            icon: Icon(Icons.close_rounded, color: AppColors.icon),
          ),
        ],
      ),
    );
  }
}

/// Shown when a sheet has nothing to list or failed to prepare its data.
///
/// This replaces the previous silent return that could leave the user staring at
/// a dimmed reader with no explanation.
class ReaderSheetNotice extends StatelessWidget {
  const ReaderSheetNotice({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.loading = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              )
            else
              Icon(icon, size: 42, color: AppColors.icon),
            const SizedBox(height: AppSpacing.sm),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 5),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),
            ],
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: AppSpacing.md),
              TextButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
