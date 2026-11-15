import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/theme/app_palette.dart';
import 'package:mangaplus/app/core/theme/design_tokens.dart';
import 'package:mangaplus/app/modules/profile/views/reading_stats_panel.dart';
import 'package:mangaplus/app/widgets/mangaplus_app_bar.dart';
import 'package:mangaplus/app/widgets/theme_aware_builder.dart';

/// The full reading statistics dashboard, opened from the profile summary.
class ReadingStatsView extends StatelessWidget {
  const ReadingStatsView({super.key});

  @override
  Widget build(BuildContext context) => ThemeAwareBuilder(
        builder: (context) => Scaffold(
          backgroundColor: context.palette.background,
          appBar: MangaPlusAppBar(title: 'إحصاءات القراءة'.tr),
          body: ListView(
            padding: AppSpacing.pageInsets,
            children: const [
              ReadingStatsPanel(initiallyExpanded: true),
            ],
          ),
        ),
      );
}
