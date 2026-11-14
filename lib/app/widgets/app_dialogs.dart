import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/theme/app_motion.dart';
import 'package:mangaplus/app/core/theme/app_palette.dart';
import 'package:mangaplus/app/core/theme/design_tokens.dart';
import 'package:mangaplus/app/widgets/app_buttons.dart';

/// One dialog and bottom-sheet implementation for the whole application.
///
/// Width, padding, radius, title hierarchy, action order, barrier colour and
/// dismissal behaviour live here instead of being re-decided at each call site.
class AppDialogs {
  const AppDialogs._();

  /// Shows a message dialog. [actions] are rendered end-aligned in the order
  /// given, so the affirmative action is always last.
  /// Overlay motion. Overlays follow the same page timing as routes so opening
  /// a confirm dialog from a pushed screen does not feel faster or slower than
  /// the push itself; reduced motion collapses it to an instant swap.
  static Duration _duration(Duration duration) {
    final context = Get.context;
    return context == null
        ? duration
        : AppMotion.effective(context, duration);
  }

  static Future<T?> show<T>({
    required String title,
    String? message,
    Widget? content,
    IconData? icon,
    List<Widget>? actions,
    bool dismissible = true,
    String? closeLabel,
  }) {
    return Get.dialog<T>(
      _DialogShell(
        title: title,
        message: message,
        content: content,
        icon: icon,
        actions: actions ??
            [
              AppButton(
                label: closeLabel ?? 'حسنًا'.tr,
                variant: AppButtonVariant.ghost,
                compact: true,
                onPressed: () => Get.back<T>(result: null),
              ),
            ],
      ),
      barrierDismissible: dismissible,
      barrierColor: Get.context?.palette.scrim,
      transitionDuration: _duration(AppMotion.page),
      transitionCurve: AppMotion.emphasized,
    );
  }

  /// A yes/no dialog. Resolves to false when dismissed.
  static Future<bool> confirm({
    required String title,
    String? message,
    required String confirmLabel,
    String? cancelLabel,
    bool destructive = false,
    IconData? icon,
  }) async {
    final result = await Get.dialog<bool>(
      _DialogShell(
        title: title,
        message: message,
        icon: icon ??
            (destructive
                ? Icons.warning_amber_rounded
                : Icons.help_outline_rounded),
        destructive: destructive,
        actions: [
          AppButton(
            label: cancelLabel ?? 'إلغاء'.tr,
            variant: AppButtonVariant.ghost,
            compact: true,
            onPressed: () => Get.back<bool>(result: false),
          ),
          AppButton(
            label: confirmLabel,
            variant: destructive
                ? AppButtonVariant.danger
                : AppButtonVariant.primary,
            compact: true,
            onPressed: () => Get.back<bool>(result: true),
          ),
        ],
      ),
      barrierDismissible: true,
      barrierColor: Get.context?.palette.scrim,
      transitionDuration: _duration(AppMotion.page),
      transitionCurve: AppMotion.emphasized,
    );
    return result ?? false;
  }

  /// Shows a bottom sheet with the shared handle, header and corner radius.
  ///
  /// The sheet sizes itself to its content and only scrolls once it reaches
  /// [heightFactor] of the screen, so short sheets never leave a large empty
  /// area at the bottom.
  static Future<T?> sheet<T>({
    required String title,
    String? subtitle,
    IconData? icon,
    required WidgetBuilder builder,
    bool dismissible = true,
    double heightFactor = .86,
  }) {
    return Get.bottomSheet<T>(
      _SheetShell(
        title: title,
        subtitle: subtitle,
        icon: icon,
        heightFactor: heightFactor,
        builder: builder,
      ),
      isScrollControlled: true,
      isDismissible: dismissible,
      enableDrag: dismissible,
      backgroundColor: Colors.transparent,
      barrierColor: Get.context?.palette.scrim,
      enterBottomSheetDuration: _duration(AppMotion.page),
      exitBottomSheetDuration: _duration(AppMotion.fast),
    );
  }
}

class _DialogShell extends StatelessWidget {
  const _DialogShell({
    required this.title,
    this.message,
    this.content,
    this.icon,
    this.destructive = false,
    required this.actions,
  });

  final String title;
  final String? message;
  final Widget? content;
  final IconData? icon;
  final bool destructive;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final accent = destructive ? p.error : p.primary;
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      title: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .12),
                borderRadius: AppRadii.smAll,
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 20, color: accent),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Text(
              title,
              style: text.titleLarge?.copyWith(
                color: p.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      content: content ??
          (message == null
              ? null
              : Text(
                  message!,
                  style: text.bodyMedium?.copyWith(
                    color: p.textSecondary,
                    height: 1.6,
                  ),
                )),
      actions: actions,
    );
  }
}

class _SheetShell extends StatelessWidget {
  const _SheetShell({
    required this.title,
    this.subtitle,
    this.icon,
    required this.heightFactor,
    required this.builder,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final double heightFactor;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final maxHeight = MediaQuery.sizeOf(context).height * heightFactor;
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: AppRadii.sheetTop,
        border: Border(top: BorderSide(color: p.border.withValues(alpha: .8))),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.xs),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: p.divider,
                borderRadius: AppRadii.pillAll,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: p.primary.withValues(alpha: .12),
                        borderRadius: AppRadii.smAll,
                      ),
                      alignment: Alignment.center,
                      child: Icon(icon, size: 21, color: p.primary),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleLarge?.copyWith(
                            color: p.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              subtitle!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodySmall?.copyWith(
                                color: p.textSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  AppIconButton(
                    icon: Icons.close_rounded,
                    tooltip: 'إغلاق'.tr,
                    size: AppSizes.icon,
                    onPressed: () => Get.back<void>(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: p.divider),
            Flexible(child: builder(context)),
          ],
        ),
      ),
    );
  }
}
