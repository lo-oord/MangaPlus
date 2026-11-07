import 'package:flutter/material.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/core/utils/bidi_text.dart';

/// Shared app bar so every secondary screen has the same height, back button,
/// title position and colours in both light and dark mode.
///
/// [centerTitle] defaults to true for short, static screen titles. Content
/// driven titles (a genre or a work name) should pass `centerTitle: false` so
/// a long name starts next to the back button and truncates cleanly.
class MangaPlusAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MangaPlusAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.actions,
    this.bottom,
    this.leading,
    this.centerTitle = true,
    this.automaticallyImplyLeading = true,
    this.toolbarHeight = 60,
  }) : assert(title != null || titleWidget != null);

  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final Widget? leading;
  final bool centerTitle;
  final bool automaticallyImplyLeading;
  final double toolbarHeight;

  @override
  Size get preferredSize =>
      Size.fromHeight(toolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = theme.appBarTheme.titleTextStyle;
    return AppBar(
      title: titleWidget ??
          Text(
            title ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: centerTitle ? TextAlign.center : TextAlign.start,
            textDirection:
                bidiTextDirection(title, fallback: TextDirection.rtl),
            style: (baseStyle ?? const TextStyle()).copyWith(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
      centerTitle: centerTitle,
      titleSpacing: centerTitle ? null : 2,
      toolbarHeight: toolbarHeight,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      iconTheme: IconThemeData(color: AppColors.textPrimary, size: 24),
      actionsIconTheme: IconThemeData(color: AppColors.icon, size: 23),
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      actions: actions == null
          ? null
          : [
              ...actions!,
              const SizedBox(width: 3),
            ],
      bottom: bottom,
    );
  }
}
