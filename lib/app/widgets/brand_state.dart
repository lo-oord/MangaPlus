import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/constants/colors.dart';

const _mangaPlusLogoAsset = 'assets/images/mangaplus_logo.png';

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
          Padding(
            padding: EdgeInsets.all(size * 0.27),
            child: Image.asset(
              _mangaPlusLogoAsset,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.auto_stories_rounded,
                size: size * 0.34,
                color: AppColors.primary,
              ),
            ),
          ),
          if (value != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(value * 100).round()}%',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: size * 0.15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
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
      _mangaPlusLogoAsset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.auto_stories_rounded,
        size: size * 0.62,
        color: AppColors.primary,
      ),
    );
  }
}

class MangaPlusCoverState extends StatelessWidget {
  const MangaPlusCoverState({
    super.key,
    required this.message,
    this.progress,
    this.failed = false,
    this.markSize = 48,
  });

  final String message;
  final double? progress;
  final bool failed;
  final double markSize;

  @override
  Widget build(BuildContext context) {
    final mark = failed
        ? Stack(
            clipBehavior: Clip.none,
            children: [
              MangaPlusLogo(size: markSize),
              Positioned(
                right: -2,
                bottom: -2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Icon(
                    Icons.image_not_supported_rounded,
                    size: markSize * 0.34,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          )
        : MangaPlusLoader(size: markSize, progress: progress);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          mark,
          const SizedBox(height: 6),
          Text(
            message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: markSize * 0.2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class MangaPlusRetryTile extends StatelessWidget {
  const MangaPlusRetryTile({
    super.key,
    required this.title,
    required this.loading,
    required this.onRetry,
  });

  final String title;
  final bool loading;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: MangaPlusLoader(size: 42));
    return Container(
      decoration: BoxDecoration(
        color: AppColors.searchBar,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.7)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const MangaPlusLogo(size: 36),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextButton.icon(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 30),
              padding: const EdgeInsets.symmetric(horizontal: 2),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.refresh_rounded, size: 13),
            label: Text(
              'إعادة المحاولة'.tr,
              maxLines: 1,
              style: const TextStyle(fontSize: 9),
            ),
          ),
        ],
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
                    : Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          const MangaPlusLogo(size: 68),
                          if (icon != null)
                            Positioned(
                              right: -5,
                              bottom: -3,
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.divider),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x18000000),
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  icon,
                                  size: 15,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
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
