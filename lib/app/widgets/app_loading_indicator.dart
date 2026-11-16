import 'package:flutter/material.dart';

/// Unified loading spinner used across the app.
///
/// Keeps size, stroke, color, and animation consistent so loading states feel
/// intentional and professional everywhere.
class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({
    super.key,
    this.size = 24,
    this.strokeWidth = 2.5,
    this.color,
    this.semanticLabel,
  });

  /// Compact spinner for inline contexts such as buttons.
  const AppLoadingIndicator.compact({
    super.key,
    this.color,
    this.semanticLabel,
  })  : size = 16,
        strokeWidth = 2.2;

  /// Spinner sized for sheet/section loading states.
  const AppLoadingIndicator.medium({
    super.key,
    this.color,
    this.semanticLabel,
  })  : size = 28,
        strokeWidth = 2.6;

  /// The square dimension of the spinner.
  final double size;

  /// Thickness of the spinner track.
  final double strokeWidth;

  /// Spinner color. Defaults to the current color scheme primary.
  final Color? color;

  /// Optional accessibility label.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.primary;
    return Semantics(
      label: semanticLabel,
      child: SizedBox.square(
        dimension: size,
        child: CircularProgressIndicator(
          strokeWidth: strokeWidth,
          strokeCap: StrokeCap.round,
          valueColor: AlwaysStoppedAnimation<Color>(effectiveColor),
        ),
      ),
    );
  }
}
