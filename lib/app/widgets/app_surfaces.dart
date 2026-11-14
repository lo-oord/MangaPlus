import 'package:flutter/material.dart';
import 'package:mangaplus/app/core/theme/app_palette.dart';
import 'package:mangaplus/app/core/theme/design_tokens.dart';

/// A flat, bordered container used for every card-like surface.
///
/// Cards are separated by a hairline border on the theme surface instead of
/// drop shadows, which keeps scrolling lists calm and avoids overdraw.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = AppSpacing.cardInsets,
    this.onTap,
    this.radius = AppRadii.md,
    this.color,
    this.borderColor,
    this.clip = true,
    this.height,
    this.width,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;
  final Color? color;
  final Color? borderColor;
  final bool clip;
  final double? height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final decoration = BoxDecoration(
      color: color ?? p.card,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? p.border.withValues(alpha: .9)),
    );
    final content = Padding(padding: padding, child: child);
    if (onTap == null) {
      return Container(
        height: height,
        width: width,
        decoration: decoration,
        clipBehavior: clip ? Clip.antiAlias : Clip.none,
        child: content,
      );
    }
    return Container(
      height: height,
      width: width,
      decoration: decoration,
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap, child: content),
      ),
    );
  }
}

/// A titled group of rows or widgets, matching the Settings screens.
///
/// Consecutive tiles are separated by a divider that is inset to align with the
/// tile text instead of the card edge, and the group is separated from the next
/// section by the shared section spacing.
class AppSection extends StatelessWidget {
  const AppSection({
    super.key,
    this.title,
    this.subtitle,
    this.action,
    required this.children,
    this.dividerIndent = AppSpacing.md,
    this.contentPadding,
  });

  final String? title;
  final String? subtitle;
  final Widget? action;
  final List<Widget> children;
  final double dividerIndent;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final rows = <Widget>[];
    for (var index = 0; index < children.length; index++) {
      if (index > 0) {
        rows.add(Divider(height: 1, indent: dividerIndent, color: p.divider));
      }
      rows.add(children[index]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: AppSpacing.xxs,
              bottom: AppSpacing.heading,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title!,
                        style: text.labelLarge?.copyWith(
                          color: p.textSecondary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .2,
                        ),
                      ),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            subtitle!,
                            style: text.bodySmall?.copyWith(
                              color: p.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (action != null) action!,
              ],
            ),
          ),
        Container(
          padding: contentPadding,
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: AppRadii.mdAll,
            border: Border.all(color: p.border.withValues(alpha: .9)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: rows,
          ),
        ),
        const SizedBox(height: AppSpacing.section),
      ],
    );
  }
}

/// One row inside an [AppSection].
///
/// The row owns its own tap target, leading icon container and trailing widget,
/// so switches, chevrons and value labels line up across every settings page.
class AppSettingsTile extends StatelessWidget {
  const AppSettingsTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.value,
    this.trailing,
    this.onTap,
    this.switchValue,
    this.onSwitchChanged,
    this.destructive = false,
    this.enabled = true,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool? switchValue;
  final ValueChanged<bool>? onSwitchChanged;
  final bool destructive;
  final bool enabled;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final tint = destructive ? p.error : p.primary;
    final titleColor = !enabled
        ? p.textDisabled
        : destructive
            ? p.error
            : p.textPrimary;

    Widget? leading;
    if (icon != null) {
      leading = Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: tint.withValues(alpha: .12),
          borderRadius: AppRadii.smAll,
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 19, color: destructive ? p.error : p.icon),
      );
    }

    Widget trailingWidget;
    if (trailing != null) {
      trailingWidget = trailing!;
    } else if (switchValue != null) {
      trailingWidget = Switch.adaptive(
        value: switchValue!,
        onChanged: enabled ? onSwitchChanged : null,
        activeColor: p.primary,
      );
    } else if (value != null || onTap != null) {
      trailingWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Text(
                value!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: text.bodySmall?.copyWith(color: p.textSecondary),
              ),
            ),
          if (onTap != null) ...[
            const SizedBox(width: AppSpacing.xxs),
            Icon(
              Icons.chevron_right_rounded,
              size: AppSizes.icon,
              color: p.icon,
            ),
          ],
        ],
      );
    } else {
      trailingWidget = const SizedBox.shrink();
    }

    final row = Padding(
      padding: padding,
      child: Row(
        children: [
          if (leading != null) ...[
            leading,
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: text.titleSmall?.copyWith(
                    color: titleColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: text.bodySmall?.copyWith(
                        color: enabled ? p.textSecondary : p.textDisabled,
                        height: 1.4,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          trailingWidget,
        ],
      ),
    );

    if (onTap == null) return row;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: AppRadii.mdAll,
      child: row,
    );
  }
}

/// Tonal meaning of an [AppPill].
enum AppPillTone { neutral, primary, success, warning, error, info }

/// A compact metadata badge (chapter count, status, rating, source).
class AppPill extends StatelessWidget {
  const AppPill({
    super.key,
    required this.label,
    this.icon,
    this.tone = AppPillTone.neutral,
    this.maxWidth,
  });

  final String label;
  final IconData? icon;
  final AppPillTone tone;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = switch (tone) {
      AppPillTone.neutral => p.textSecondary,
      AppPillTone.primary => p.primary,
      AppPillTone.success => p.success,
      AppPillTone.warning => p.warning,
      AppPillTone.error => p.error,
      AppPillTone.info => p.info,
    };
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth ?? 200),
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .11),
        borderRadius: AppRadii.xsAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: p.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
