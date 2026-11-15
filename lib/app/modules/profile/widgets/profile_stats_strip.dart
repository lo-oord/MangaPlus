import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/navigation/app_navigation.dart';
import 'package:mangaplus/app/core/theme/app_palette.dart';
import 'package:mangaplus/app/core/theme/design_tokens.dart';
import 'package:mangaplus/app/modules/profile/controllers/reading_stats_controller.dart';
import 'package:mangaplus/app/routes/app_pages.dart';
import 'package:mangaplus/app/widgets/app_buttons.dart';
import 'package:mangaplus/app/widgets/app_surfaces.dart';

/// A compact, honest summary of the reading statistics.
///
/// It reads the same aggregated report the full dashboard uses, so the numbers
/// always match the details screen instead of being derived a second time.
class ProfileStatsStrip extends StatelessWidget {
  const ProfileStatsStrip({super.key, required this.controller});

  final ReadingStatsController controller;

  @override
  Widget build(BuildContext context) => Obx(() {
        controller.refreshRevision.value;
        final report = controller.allTimeReport;
        final preferences = controller.preferences.value;
        final p = context.palette;
        final text = Theme.of(context).textTheme;

        if (controller.isLoading.value && report.sessionCount == 0) {
          return AppCard(
            child: Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'جارٍ تحميل إحصاءات القراءة…'.tr,
                    style: text.bodySmall,
                  ),
                ),
              ],
            ),
          );
        }

        final goalSeconds = preferences.weeklyGoalMinutes * 60;
        final progress = goalSeconds <= 0
            ? 0.0
            : (report.currentWeekSeconds / goalSeconds).clamp(0.0, 1.0);

        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_graph_rounded, size: AppSizes.icon, color: p.primary),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'إحصاءات القراءة'.tr,
                      style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  AppButton(
                    label: 'التفاصيل'.tr,
                    variant: AppButtonVariant.ghost,
                    compact: true,
                    onPressed: () => AppNavigation.toNamed(Routes.READING_STATS),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  _metric(
                    context,
                    icon: Icons.schedule_rounded,
                    label: 'وقت القراءة'.tr,
                    value: _duration(report.totalSeconds),
                  ),
                  _metric(
                    context,
                    icon: Icons.check_circle_outline_rounded,
                    label: 'فصل مكتمل'.tr,
                    value: '${report.completedChapters}',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  _metric(
                    context,
                    icon: Icons.local_fire_department_rounded,
                    label: 'أيام متتالية'.tr,
                    value: '${report.currentStreakDays}',
                  ),
                  _metric(
                    context,
                    icon: Icons.calendar_month_rounded,
                    label: 'أيام نشطة'.tr,
                    value: '${report.activeDays}',
                  ),
                ],
              ),
              if (goalSeconds > 0) ...[
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'الهدف الأسبوعي'.tr,
                        style: text.bodySmall?.copyWith(color: p.textSecondary),
                      ),
                    ),
                    Text(
                      '${(report.currentWeekSeconds / 60).floor()} / ${preferences.weeklyGoalMinutes} ${'دقيقة'.tr}',
                      style: text.bodySmall?.copyWith(color: p.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                ClipRRect(
                  borderRadius: AppRadii.pillAll,
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: p.surfaceVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(p.primary),
                  ),
                ),
              ],
              if (report.sessionCount == 0) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'ابدأ القراءة لبناء إحصاءاتك'.tr,
                  style: text.bodySmall?.copyWith(color: p.textSecondary),
                ),
              ],
            ],
          ),
        );
      });

  Widget _metric(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: p.primary.withValues(alpha: .10),
              borderRadius: AppRadii.smAll,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 17, color: p.primary),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(color: p.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _duration(int seconds) {
    final safe = seconds < 0 ? 0 : seconds;
    final hours = safe ~/ 3600;
    final minutes = (safe % 3600) ~/ 60;
    if (hours > 0) {
      return '$hours ${'ساعة'.tr} ${minutes > 0 ? '$minutes ${'دقيقة'.tr}' : ''}'.trim();
    }
    return '$minutes ${'دقيقة'.tr}';
  }
}
