import 'package:flutter/material.dart';
import 'package:mangaplus/app/core/theme/app_palette.dart';
import 'package:mangaplus/app/core/theme/design_tokens.dart';
import 'package:mangaplus/app/widgets/app_motion_widgets.dart';

/// The visual weight of an action in MangaPlus.
enum AppButtonVariant {
  /// The single main action of a screen.
  primary,

  /// A supportive action next to a primary one.
  secondary,

  /// A neutral action that must not compete with content.
  outline,

  /// A destructive action (delete, sign out).
  danger,

  /// A low-emphasis inline action.
  ghost,
}

/// One button implementation for the whole app.
///
/// Height, radius, padding, typography, disabled styling and the loading state
/// are decided here, so a primary action looks identical on every screen.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.trailingIcon,
    this.variant = AppButtonVariant.primary,
    this.loading = false,
    this.expand = false,
    this.compact = false,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailingIcon;
  final AppButtonVariant variant;
  final bool loading;
  final bool expand;
  final bool compact;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final height =
        compact ? AppSizes.compactControlHeight : AppSizes.controlHeight;
    final effectiveOnPressed = loading ? null : onPressed;

    final (Color background, Color foreground, Color? border) =
        switch (variant) {
      AppButtonVariant.primary => (p.primary, p.onPrimary, null),
      AppButtonVariant.secondary => (
          p.primaryContainer,
          p.onPrimaryContainer,
          null
        ),
      AppButtonVariant.outline => (Colors.transparent, p.textPrimary, p.border),
      AppButtonVariant.danger => (p.error, p.onError, null),
      AppButtonVariant.ghost => (Colors.transparent, p.primary, null),
    };

    final foregroundStyle = TextStyle(
      fontSize: compact ? 12.5 : 14,
      fontWeight: FontWeight.w700,
      height: 1.2,
      color: onPressed == null && !loading ? p.textDisabled : foreground,
    );
    final iconColor = foregroundStyle.color!;
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox.square(
            dimension: compact ? 14 : 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(iconColor),
            ),
          )
        else if (icon != null)
          Icon(icon, size: compact ? AppSizes.iconSm : 18, color: iconColor),
        if (loading || icon != null) const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: foregroundStyle,
          ),
        ),
        if (trailingIcon != null) ...const [
          SizedBox(width: AppSpacing.xs),
        ],
        if (trailingIcon != null)
          Icon(trailingIcon,
              size: compact ? AppSizes.iconSm : 18, color: iconColor),
      ],
    );

    final padding = EdgeInsets.symmetric(
      horizontal: compact ? AppSpacing.sm : AppSpacing.md,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: compact ? AppRadii.xsAll : AppRadii.smAll,
      side: border == null ? BorderSide.none : BorderSide(color: border),
    );
    final minimumSize = Size(64, height);

    final button = PressableScale(
      enabled: effectiveOnPressed != null,
      scale: .98,
      child: switch (variant) {
      AppButtonVariant.primary ||
      AppButtonVariant.secondary ||
      AppButtonVariant.danger =>
        FilledButton(
          onPressed: effectiveOnPressed,
          style: FilledButton.styleFrom(
            backgroundColor: background,
            foregroundColor: foreground,
            disabledBackgroundColor: background.withValues(alpha: .38),
            disabledForegroundColor: p.textDisabled,
            elevation: 0,
            minimumSize: minimumSize,
            padding: padding,
            shape: shape,
            textStyle: foregroundStyle,
          ),
          child: content,
        ),
      AppButtonVariant.outline => OutlinedButton(
          onPressed: effectiveOnPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: foreground,
            minimumSize: minimumSize,
            padding: padding,
            shape: shape,
            side: BorderSide(color: border ?? p.border),
            textStyle: foregroundStyle,
          ),
          child: content,
        ),
      AppButtonVariant.ghost => TextButton(
          onPressed: effectiveOnPressed,
          style: TextButton.styleFrom(
            foregroundColor: foreground,
            minimumSize: minimumSize,
            padding: padding,
            shape: shape,
            textStyle: foregroundStyle,
          ),
          child: content,
        ),
      },
    );

    return Semantics(
      button: true,
      enabled: effectiveOnPressed != null,
      label: semanticLabel ?? label,
      child: expand ? SizedBox(width: double.infinity, child: button) : button,
    );
  }
}

/// A square icon action with a touch target that never falls below 48 dp.
///
/// Used for app bar actions, card overlays and compact toolbars so icon buttons
/// share one size, radius and tint everywhere.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.selected = false,
    this.filled = false,
    this.color,
    this.size = AppSizes.iconMd,
    this.dense = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool selected;
  final bool filled;
  final Color? color;
  final double size;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tint = onPressed == null
        ? p.textDisabled
        : color ?? (selected || filled ? p.primary : p.icon);
    final background =
        filled ? p.primary.withValues(alpha: .12) : Colors.transparent;
    final button = IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: size),
      style: IconButton.styleFrom(
        foregroundColor: tint,
        backgroundColor: background,
        minimumSize: dense
            ? const Size(36, 36)
            : const Size(AppSizes.touchTarget, AppSizes.touchTarget),
        maximumSize: dense ? const Size(36, 36) : null,
        padding: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.pillAll),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
