import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/core/utils/bidi_text.dart';

const _mangaPlusLogoAsset = 'assets/images/mangaplus_logo.png';

/// The single branded loading indicator used across MangaPlus.
///
/// The ring is drawn by hand (no stock progress spinner) around the official
/// app mark so every loading state shares the MangaPlus identity. Pass
/// [progress] for real, determinate work; leave it null for indeterminate
/// waits. The animation is paused when the platform asks for reduced motion.
class MangaPlusLoader extends StatefulWidget {
  const MangaPlusLoader({
    super.key,
    this.size = 68,
    this.progress,
    this.label,
    this.color,
    this.trackColor,
  });

  final double size;
  final double? progress;
  final String? label;
  final Color? color;
  final Color? trackColor;

  @override
  State<MangaPlusLoader> createState() => _MangaPlusLoaderState();
}

class _MangaPlusLoaderState extends State<MangaPlusLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  @override
  void initState() {
    super.initState();
    _controller.repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion && _controller.isAnimating) {
      _controller.stop();
    } else if (!reduceMotion && !_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.progress?.clamp(0.0, 1.0).toDouble();
    final size = widget.size;
    final color = widget.color ?? AppColors.primary;
    final track = widget.trackColor ?? AppColors.divider.withValues(alpha: 0.6);
    final strokeWidth = size < 32 ? 2.4 : (size < 48 ? 3.0 : 3.5);
    final mark = Padding(
      padding: EdgeInsets.all(size * (size < 40 ? 0.2 : 0.26)),
      child: Image.asset(
        _mangaPlusLogoAsset,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.auto_stories_rounded,
          size: size * 0.34,
          color: color,
        ),
      ),
    );

    final loader = SizedBox.square(
      dimension: size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final turns = _controller.value;
          final pulse = 1.0 + 0.045 * math.sin(turns * 2 * math.pi);
          return Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _LoaderRingPainter(
                    color: color,
                    trackColor: track,
                    progress: value,
                    rotation: turns * 2.0 * math.pi,
                    strokeWidth: strokeWidth,
                  ),
                ),
              ),
              Transform.scale(scale: pulse, child: child),
            ],
          );
        },
        child: mark,
      ),
    );

    // Below 44px the badge would be unreadable; the caller usually shows the
    // percentage next to the indicator anyway.
    final content = value == null || size < 44
        ? loader
        : Stack(
            alignment: Alignment.bottomCenter,
            children: [
              loader,
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(value * 100).round()}%',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: size * 0.15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          );

    final label = widget.label?.trim() ?? '';
    final semanticsLabel = label.isNotEmpty
        ? label
        : (value == null ? 'جارٍ التحميل' : 'اكتمل ${(value * 100).round()}%');
    return Semantics(
      label: semanticsLabel,
      container: true,
      child: label.isEmpty
          ? content
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                content,
                const SizedBox(height: 10),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  textDirection: bidiTextDirection(label),
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: size < 40 ? 10.5 : 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
    );
  }
}

class _LoaderRingPainter extends CustomPainter {
  const _LoaderRingPainter({
    required this.color,
    required this.trackColor,
    required this.progress,
    required this.rotation,
    required this.strokeWidth,
  });

  final Color color;
  final Color trackColor;
  final double? progress;
  final double rotation;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    if (radius <= 0) return;
    final bounds = Rect.fromCircle(center: center, radius: radius);
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    canvas.drawCircle(center, radius, trackPaint);

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [color.withValues(alpha: 0.12), color],
        transform: GradientRotation(rotation),
      ).createShader(bounds);

    if (progress != null) {
      canvas.drawArc(bounds, -math.pi / 2, 2 * math.pi * progress!, false, arcPaint);
    } else {
      // Two short arcs opposite each other read as motion without a stock
      // spinner and keep the logo unobstructed.
      canvas.drawArc(bounds, rotation, math.pi * 0.42, false, arcPaint);
      canvas.drawArc(bounds, rotation + math.pi, math.pi * 0.22, false, arcPaint);
    }
  }

  @override
  bool shouldRepaint(_LoaderRingPainter oldDelegate) =>
      oldDelegate.rotation != rotation ||
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.strokeWidth != strokeWidth;
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
            textDirection: bidiTextDirection(title),
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
                  textDirection: bidiTextDirection(title),
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
                    textDirection: bidiTextDirection(description),
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
