import 'package:flutter/material.dart';
import 'package:mangaplus/app/core/constants/colors.dart';

/// Rebuilds a screen's widget configuration when the app theme changes while
/// keeping matching stateful descendants (such as scroll views) in place.
///
/// Reading `Theme.of` here (instead of only listening to the explicit theme
/// revision) makes the subtree follow `ThemeMode.system` too: when the platform
/// brightness flips, Flutter rebuilds the inherited [Theme] and this builder
/// runs again. Before building the screen it syncs [AppColors] with the
/// brightness that was actually resolved, so the static palette facade and
/// `context.palette` can never disagree.
class ThemeAwareBuilder extends StatelessWidget {
  const ThemeAwareBuilder({super.key, required this.builder});

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: AppColors.themeRevision,
        builder: (context, _, __) {
          AppColors.syncBrightness(
            Theme.of(context).brightness == Brightness.dark,
          );
          return builder(context);
        },
      );
}
