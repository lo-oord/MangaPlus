import 'package:flutter/material.dart';
import 'package:mangaplus/app/core/constants/colors.dart';

class MangaPlusLoader extends StatelessWidget {
  const MangaPlusLoader({super.key, this.size = 68, this.progress});

  final double size;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final value = progress?.clamp(0.0, 1.0).toDouble();
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.square(
            dimension: size,
            child: CircularProgressIndicator(
              value: value,
              strokeWidth: size < 48 ? 3 : 3.5,
              strokeCap: StrokeCap.round,
              color: AppColors.primary,
              backgroundColor: AppColors.divider.withValues(alpha: 0.65),
            ),
          ),
          if (value == null)
            Icon(
              Icons.menu_book_rounded,
              size: size * 0.34,
              color: AppColors.primary.withValues(alpha: 0.9),
            )
          else
            Text(
              '${(value * 100).round()}%',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: size * 0.21,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
    );
  }
}

class MangaPlusLogo extends StatelessWidget {
  const MangaPlusLogo({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/mangaplus_logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.auto_stories_rounded,
        size: size * 0.62,
        color: AppColors.primary,
      ),
    );
  }
}

class BrandState extends StatelessWidget {
  const BrandState({
    super.key,
    required this.title,
    this.description,
    this.loading = false,
    this.icon,
    this.progress,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? description;
  final bool loading;
  final IconData? icon;
  final double? progress;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                loading
                    ? MangaPlusLoader(size: 68, progress: progress)
                    : icon == null
                        ? const MangaPlusLogo(size: 68)
                        : Icon(icon, size: 58, color: AppColors.primary),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    description!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 20),
                  FilledButton.tonal(
                    onPressed: onAction,
                    child: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
