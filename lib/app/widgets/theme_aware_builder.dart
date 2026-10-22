import 'package:flutter/material.dart';
import 'package:mangaplus/app/core/constants/colors.dart';

/// Rebuilds a screen's widget configuration when the app theme changes while
/// keeping matching stateful descendants (such as scroll views) in place.
class ThemeAwareBuilder extends StatelessWidget {
  const ThemeAwareBuilder({super.key, required this.builder});

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: AppColors.themeRevision,
        builder: (context, _, __) => builder(context),
      );
}
