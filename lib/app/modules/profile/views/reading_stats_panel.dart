import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/data/models/reading_stats.dart';
import 'package:mangaplus/app/data/services/reading_stats_service.dart';
import 'package:mangaplus/app/modules/profile/controllers/reading_stats_controller.dart';
import 'package:mangaplus/app/routes/app_pages.dart';

class ReadingStatsPanel extends StatefulWidget {
  const ReadingStatsPanel({super.key});

  @override
  State<ReadingStatsPanel> createState() => _ReadingStatsPanelState();
}

class _ReadingStatsPanelState extends State<ReadingStatsPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ReadingStatsController>();
    return Obx(() {
      controller.refreshRevision.value;
      final report = controller.report;
      return Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.divider.withValues(alpha: .8)),
        ),
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 15, 16, 15),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.auto_graph_rounded, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'إحصاءات القراءة'.tr,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            report.totalSeconds == 0 && report.completedChapters == 0
                                ? 'ابدأ القراءة لبناء إحصاءاتك'.tr
                                : '${_duration(report.totalSeconds)} • ${report.completedChapters} ${'فصل مكتمل'.tr}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      color: AppColors.icon,
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 220),
              crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              firstChild: const SizedBox(width: double.infinity, height: 0),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                child: controller.isLoading.value
                    ? const Padding(
                        padding: EdgeInsets.all(22),
                        child: SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _dashboard(controller),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _dashboard(ReadingStatsController controller) {
    final report = controller.report;
    final all = controller.allTimeReport;
    final preferences = controller.preferences.value;
    final thisMonth = DateTime.now();
    final monthSummary = controller.summarizeRange(
      DateTime(thisMonth.year, thisMonth.month, 1),
      DateTime(thisMonth.year, thisMonth.month + 1, 1),
    );
    final previousMonthSummary = controller.summarizeRange(
      DateTime(thisMonth.year, thisMonth.month - 1, 1),
      DateTime(thisMonth.year, thisMonth.month, 1),
    );
    final thisYear = DateTime.now().year;
    final yearSummary = controller.summarizeRange(
      DateTime(thisYear, 1, 1),
      DateTime(thisYear + 1, 1, 1),
    );
    final previousYearSummary = controller.summarizeRange(
      DateTime(thisYear - 1, 1, 1),
      DateTime(thisYear, 1, 1),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'تُسجل الإحصاءات منذ تفعيلها على هذا الجهاز'.tr,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.35),
        ),
        const SizedBox(height: 11),
        _periodSelector(controller),
        const SizedBox(height: 11),
        LayoutBuilder(builder: (context, constraints) {
          final gap = 9.0;
          final width = (constraints.maxWidth - gap) / 2;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              _metric(width, Icons.menu_book_rounded, 'الفصول المكتملة'.tr, '${report.completedChapters}'),
              _metric(width, Icons.schedule_rounded, 'وقت القراءة'.tr, _duration(report.totalSeconds)),
              _metric(width, Icons.calendar_month_rounded, 'أيام النشاط'.tr, '${report.activeDays}'),
              _metric(width, Icons.local_fire_department_rounded, 'سلسلة الأيام'.tr, '${report.currentStreakDays} ${'يوم'.tr}'),
              _metric(width, Icons.military_tech_rounded, 'أطول سلسلة'.tr, '${report.longestStreakDays} ${'يوم'.tr}'),
              _metric(width, Icons.collections_bookmark_outlined, 'أعمال بدأت قراءتها'.tr, '${report.startedWorks}'),
              _metric(width, Icons.task_alt_rounded, 'الأعمال المكتملة'.tr, 'غير متاح'.tr),
              _metric(width, Icons.history_toggle_off_rounded, 'جلسات القراءة'.tr, '${report.sessionCount}'),
            ],
          );
        }),
        const SizedBox(height: 8),
        Text(
          'لا يعرض المشروع حاليًا عدد الفصول الكلي لكل عمل أو حالة إكمال موثوقة، لذلك لا يمكن حساب الأعمال المكتملة بدقة.'.tr,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 10, height: 1.4),
        ),
        const SizedBox(height: 14),
        _rangeChart(controller),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'ملخص هذا الأسبوع'.tr,
          trailing: Text(
            _comparison(all.currentWeekSeconds, all.previousWeekSeconds),
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${_duration(all.currentWeekSeconds)} • ${all.currentWeekChapters} ${'فصل مكتمل'.tr} • ${all.currentWeekActiveDays} ${'أيام نشطة'.tr}',
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 12),
              ),
              const SizedBox(height: 9),
              _weeklyBars(all.dailySeconds),
              const SizedBox(height: 9),
              Text(
                all.currentWeekTopWork == null
                    ? 'لا توجد قراءة هذا الأسبوع بعد'.tr
                    : '${'الأكثر قراءة هذا الأسبوع'.tr}: ${all.currentWeekTopWork!.title}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
              if (preferences.weeklyGoalMinutes > 0) ...[
                const SizedBox(height: 8),
                _goalLine(
                  'تحقيق الهدف الأسبوعي'.tr,
                  '${controller.weeksMeetingGoal} / ${controller.trackedWeeks} ${'أسابيع'.tr} • ${(controller.weeklyGoalAchievementPercent * 100).round()}%',
                  controller.weeklyGoalAchievementPercent,
                ),
              ],
              if (controller.newAchievementsThisWeek.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: controller.newAchievementsThisWeek
                      .map((item) => Chip(
                            avatar: Icon(Icons.auto_awesome, size: 14, color: AppColors.primary),
                            label: Text('${'إنجاز جديد'.tr}: ${item.title.tr}', style: const TextStyle(fontSize: 10)),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: AppColors.primary.withValues(alpha: .08),
                            side: BorderSide(color: AppColors.primary.withValues(alpha: .22)),
                          ))
                      .toList(growable: false),
                ),
              ] else ...[
                const SizedBox(height: 8),
                Text('لا توجد إنجازات جديدة هذا الأسبوع'.tr,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, constraints) {
          final gap = 9.0;
          final width = (constraints.maxWidth - gap) / 2;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              _metric(width, Icons.av_timer_rounded, 'متوسط الجلسة'.tr, _duration(report.averageSessionSeconds)),
              _metric(width, Icons.today_rounded, 'متوسط اليوم النشط'.tr, _duration(report.averageActiveDaySeconds)),
              _metric(width, Icons.hourglass_bottom_rounded, 'أطول جلسة'.tr, _duration(report.longestSessionSeconds)),
              _metric(width, Icons.date_range_rounded, 'متوسط أيام القراءة أسبوعيًا'.tr, report.averageActiveDaysPerWeek.toStringAsFixed(1)),
              _metric(width, Icons.event_available_rounded, 'أكثر أيام الأسبوع نشاطًا'.tr, _weekdayLabel(report.busiestWeekday)),
            ],
          );
        }),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'نشاط القراءة حسب وقت اليوم'.tr,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final entry in [
                ('morning', 'الصباح'.tr),
                ('afternoon', 'بعد الظهر'.tr),
                ('evening', 'المساء'.tr),
                ('night', 'الليل'.tr),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _goalLine(
                    entry.$2,
                    _duration(all.timeOfDaySeconds[entry.$1] ?? 0),
                    all.totalSeconds == 0
                        ? 0
                        : ((all.timeOfDaySeconds[entry.$1] ?? 0) / all.totalSeconds).clamp(0.0, 1.0).toDouble(),
                  ),
                ),
              Text('يُصنّف وقت القراءة بحسب وقت بداية الجلسة، وليس قياسًا للانتباه الفعلي.'.tr,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 9, height: 1.35)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _typeDistribution(all),
        const SizedBox(height: 12),
        _goalCard(controller, all, preferences),
        const SizedBox(height: 12),
        _annualCalendar(controller),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'ملخص الشهر الحالي'.tr,
          trailing: Text(_comparison(monthSummary.readingSeconds, previousMonthSummary.readingSeconds),
              style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w700)),
          child: _periodStatsLine(monthSummary, monthSummary.date, DateTime(monthSummary.date.year, monthSummary.date.month + 1, 1)),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'ملخص السنة الحالية'.tr,
          trailing: Text(_comparison(yearSummary.readingSeconds, previousYearSummary.readingSeconds),
              style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w700)),
          child: _periodStatsLine(yearSummary, DateTime(thisYear, 1, 1), DateTime(thisYear + 1, 1, 1)),
        ),
        const SizedBox(height: 12),
        _works(controller),
        const SizedBox(height: 12),
        _achievements(controller),
        const SizedBox(height: 12),
        _preferences(controller, preferences),
      ],
    );
  }

  Widget _periodSelector(ReadingStatsController controller) => Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          _periodChip(controller, 'today', 'اليوم'.tr),
          _periodChip(controller, 'week', 'هذا الأسبوع'.tr),
          _periodChip(controller, 'month', 'هذا الشهر'.tr),
          _periodChip(controller, 'last7', 'آخر 7 أيام'.tr),
          _periodChip(controller, 'last30', 'آخر 30 يومًا'.tr),
          _periodChip(controller, 'year', 'هذا العام'.tr),
          _periodChip(controller, 'all', 'كل الأوقات'.tr),
        ],
      );

  Widget _periodChip(ReadingStatsController controller, String value, String label) {
    final selected = controller.periodFilter.value == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 10, color: selected ? Colors.white : AppColors.textSecondary)),
      selected: selected,
      onSelected: (_) => controller.setPeriodFilter(value),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.background,
      side: BorderSide(color: selected ? AppColors.primary : AppColors.divider),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 3),
    );
  }

  Widget _metric(double width, IconData icon, String label, String value) => SizedBox(
        width: width,
        child: Container(
          constraints: const BoxConstraints(minHeight: 78),
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AppColors.divider.withValues(alpha: .65)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 19, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(label, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                    const SizedBox(height: 4),
                    Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _sectionCard({required String title, Widget? trailing, required Widget child}) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider.withValues(alpha: .65)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(child: Text(title, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13))),
              if (trailing != null) trailing,
            ]),
            const SizedBox(height: 11),
            child,
          ],
        ),
      );

  Widget _rangeChart(ReadingStatsController controller) {
    final now = DateTime.now();
    final selected = controller.periodFilter.value;
    final points = <_ChartPoint>[];
    if (['today', 'week', 'month', 'last7', 'last30'].contains(selected)) {
      final today = DateTime(now.year, now.month, now.day);
      late final DateTime first;
      late final int count;
      switch (selected) {
        case 'today':
          first = today;
          count = 1;
          break;
        case 'week':
          first = DateTime(today.year, today.month, today.day - (today.weekday - DateTime.monday));
          count = 7;
          break;
        case 'month':
          first = DateTime(today.year, today.month, 1);
          count = DateTime(today.year, today.month + 1, 0).day;
          break;
        case 'last7':
          first = DateTime(today.year, today.month, today.day - 6);
          count = 7;
          break;
        default:
          first = DateTime(today.year, today.month, today.day - 29);
          count = 30;
      }
      for (var index = 0; index < count; index++) {
        final day = DateTime(first.year, first.month, first.day + index);
        points.add(_ChartPoint(
          label: '${day.day}',
          start: day,
          end: day.add(const Duration(days: 1)),
          seconds: controller.report.dailySeconds[_dayKey(day)] ?? 0,
        ));
      }
    } else {
      final year = selected == 'year' ? now.year : controller.selectedYear.value;
      for (var month = 1; month <= 12; month++) {
        final start = DateTime(year, month, 1);
        final end = DateTime(year, month + 1, 1);
        var seconds = 0;
        for (final entry in controller.allTimeReport.dailySeconds.entries) {
          final day = DateTime.tryParse(entry.key);
          if (day != null && !day.isBefore(start) && day.isBefore(end)) seconds += entry.value;
        }
        points.add(_ChartPoint(label: '$month', start: start, end: end, seconds: seconds));
      }
    }
    final maximum = points.fold<int>(0, (value, item) => math.max(value, item.seconds).toInt());
    return _sectionCard(
      title: 'مخطط وقت القراءة'.tr,
      trailing: Text('اضغط على عمود للتفاصيل'.tr, style: TextStyle(color: AppColors.textSecondary, fontSize: 9)),
      child: SizedBox(
        height: 145,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: points.map((point) {
              final barHeight = maximum == 0 ? 5.0 : (5 + 67 * point.seconds / maximum).toDouble();
              return GestureDetector(
                onTap: () => _showRangeDetails(controller, point.start, point.end),
                child: Tooltip(
                  message: '${point.label}: ${_duration(point.seconds)}',
                  child: SizedBox(
                    width: selected == 'last30' ? 22 : 29,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(point.seconds == 0 ? '' : '${(point.seconds / 60).round()}',
                              maxLines: 1, style: TextStyle(color: AppColors.textSecondary, fontSize: 7)),
                          const SizedBox(height: 4),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            height: barHeight,
                            decoration: BoxDecoration(
                              color: point.seconds == 0 ? AppColors.divider : AppColors.primary.withValues(alpha: (.55 + .45 * point.seconds / math.max(1, maximum)).toDouble()),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(point.label, style: TextStyle(color: AppColors.textSecondary, fontSize: 8)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(growable: false),
          ),
        ),
      ),
    );
  }

  Widget _weeklyBars(Map<String, int> daySeconds) {
    final today = DateTime.now();
    final monday = DateTime(today.year, today.month, today.day - (today.weekday - DateTime.monday));
    final values = List.generate(7, (index) {
      final day = DateTime(monday.year, monday.month, monday.day + index);
      return (day, daySeconds[_dayKey(day)] ?? 0);
    });
    final maxSeconds = values.fold<int>(0, (max, item) => math.max(max, item.$2).toInt());
    const labels = ['إث', 'ث', 'أر', 'خ', 'ج', 'س', 'ح'];
    return SizedBox(
      height: 91,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (index) {
          final seconds = values[index].$2;
          final height = maxSeconds == 0 ? 5.0 : (5 + 40 * seconds / maxSeconds).toDouble();
          return Expanded(
            child: GestureDetector(
              onTap: () => _showRangeDetails(
                Get.find<ReadingStatsController>(),
                values[index].$1,
                values[index].$1.add(const Duration(days: 1)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(seconds == 0 ? '' : '${(seconds / 60).round()}', style: TextStyle(color: AppColors.textSecondary, fontSize: 8)),
                    const SizedBox(height: 3),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: height,
                      decoration: BoxDecoration(
                        color: seconds == 0 ? AppColors.divider : AppColors.primary.withValues(alpha: (.55 + .45 * seconds / math.max(1, maxSeconds)).toDouble()),
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(labels[index].tr, style: TextStyle(color: AppColors.textSecondary, fontSize: 9)),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _goalCard(
    ReadingStatsController controller,
    ReadingStatsReport report,
    ReadingStatsPreferences preferences,
  ) {
    final dailyMinutes = report.todaySeconds / 60;
    final todayProgress = (dailyMinutes / preferences.dailyGoalMinutes).clamp(0.0, 1.0).toDouble();
    final weekProgress = (report.currentWeekSeconds / 60 / preferences.weeklyGoalMinutes).clamp(0.0, 1.0).toDouble();
    final chapterProgress = preferences.weeklyGoalChapters <= 0
        ? 0.0
        : (report.currentWeekChapters / preferences.weeklyGoalChapters).clamp(0.0, 1.0).toDouble();
    return _sectionCard(
      title: 'أهداف القراءة'.tr,
      trailing: IconButton(
        tooltip: 'تعديل الأهداف'.tr,
        visualDensity: VisualDensity.compact,
        onPressed: () => _editGoals(controller, preferences),
        icon: Icon(Icons.edit_outlined, color: AppColors.icon, size: 18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _goalLine('الهدف اليومي'.tr, '${dailyMinutes.floor()} / ${preferences.dailyGoalMinutes} ${'دقيقة'.tr}', todayProgress),
          const SizedBox(height: 10),
          _goalLine('الهدف الأسبوعي'.tr, '${(report.currentWeekSeconds / 60).floor()} / ${preferences.weeklyGoalMinutes} ${'دقيقة'.tr}', weekProgress),
          const SizedBox(height: 10),
          preferences.weeklyGoalChapters <= 0
              ? Text('هدف الفصول الأسبوعي غير محدد'.tr, style: TextStyle(color: AppColors.textSecondary, fontSize: 10))
              : _goalLine('هدف الفصول الأسبوعي'.tr, '${report.currentWeekChapters} / ${preferences.weeklyGoalChapters} ${'فصل'.tr}', chapterProgress),
        ],
      ),
    );
  }

  Widget _goalLine(String label, String value, double progress) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(child: Text(label, style: TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w700))),
            Text(value, style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
          ]),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.divider,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ],
      );

  Widget _typeDistribution(ReadingStatsReport report) {
    final totals = <String, int>{};
    for (final work in report.works) {
      totals.update(work.type, (value) => value + work.readingSeconds,
          ifAbsent: () => work.readingSeconds);
    }
    final total = totals.values.fold<int>(0, (sum, value) => sum + value);
    final ordered = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return _sectionCard(
      title: 'توزيع وقت القراءة حسب نوع المحتوى'.tr,
      child: ordered.isEmpty
          ? Text('لا توجد بيانات كافية لهذا المخطط'.tr,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 10))
          : Column(
              children: ordered
                  .map((entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        child: _goalLine(
                          _typeLabel(entry.key),
                          _duration(entry.value),
                          total == 0 ? 0 : (entry.value / total).clamp(0.0, 1.0).toDouble(),
                        ),
                      ))
                  .toList(growable: false),
            ),
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'manga': return 'مانجا'.tr;
      case 'manhwa': return 'مانهوا'.tr;
      case 'manhua': return 'مانهوا صينية'.tr;
      case 'novel': return 'رواية'.tr;
      default: return 'أنواع أخرى'.tr;
    }
  }

  String _weekdayLabel(int? weekday) {
    switch (weekday) {
      case DateTime.monday: return 'الإثنين'.tr;
      case DateTime.tuesday: return 'الثلاثاء'.tr;
      case DateTime.wednesday: return 'الأربعاء'.tr;
      case DateTime.thursday: return 'الخميس'.tr;
      case DateTime.friday: return 'الجمعة'.tr;
      case DateTime.saturday: return 'السبت'.tr;
      case DateTime.sunday: return 'الأحد'.tr;
      default: return '—';
    }
  }

  Widget _annualCalendar(ReadingStatsController controller) {
    final year = controller.selectedYear.value;
    final first = DateTime(year, 1, 1);
    final trackingStart = controller.allTimeReport.firstActivity;
    final firstVisible = trackingStart == null
        ? DateTime.now()
        : DateTime(trackingStart.year, trackingStart.month, trackingStart.day);
    final currentDay = DateTime.now();
    final gridStart = DateTime(first.year, first.month, first.day - (first.weekday - DateTime.monday));
    final daysInYear = DateTime.utc(year + 1, 1, 1)
        .difference(DateTime.utc(gridStart.year, gridStart.month, gridStart.day))
        .inDays;
    final weeks = (daysInYear / 7).ceil();
    const weekdayLabels = ['إث', 'ث', 'أر', 'خ', 'ج', 'س', 'ح'];
    return _sectionCard(
      title: 'تقويم نشاط القراءة السنوي'.tr,
      trailing: DropdownButton<int>(
        value: controller.availableYears.contains(year) ? year : DateTime.now().year,
        isDense: true,
        underline: const SizedBox.shrink(),
        dropdownColor: AppColors.card,
        style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
        items: controller.availableYears.map((value) => DropdownMenuItem(value: value, child: Text('$value'))).toList(),
        onChanged: (value) { if (value != null) controller.setSelectedYear(value); },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (trackingStart == null)
            Text('سيبدأ التقويم بعد أول جلسة قراءة فعلية'.tr,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 10))
          else ...[
            Text('${'بدأ التسجيل في'.tr} ${_formatDate(firstVisible)}',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
            const SizedBox(height: 9),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 5, top: 1),
                    child: Column(
                      children: [
                        for (var day = 0; day < 7; day++)
                          SizedBox(
                            width: 18,
                            height: 15,
                            child: Center(child: Text(weekdayLabels[day].tr, style: TextStyle(color: AppColors.textSecondary, fontSize: 7))),
                          ),
                      ],
                    ),
                  ),
                  for (var week = 0; week < weeks; week++)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 3),
                      child: Column(
                        children: [
                          for (var dayIndex = 0; dayIndex < 7; dayIndex++)
                            _heatCell(
                              controller,
                              DateTime(gridStart.year, gridStart.month, gridStart.day + week * 7 + dayIndex),
                              year,
                              firstVisible,
                              currentDay,
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('أقل'.tr, style: TextStyle(color: AppColors.textSecondary, fontSize: 9)),
                const SizedBox(width: 5),
                for (final alpha in [0.0, .22, .42, .65, .92])
                  Container(
                    width: 11,
                    height: 11,
                    margin: const EdgeInsetsDirectional.only(end: 3),
                    decoration: BoxDecoration(
                      color: alpha == 0 ? AppColors.divider : AppColors.primary.withValues(alpha: alpha),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                Text('أكثر'.tr, style: TextStyle(color: AppColors.textSecondary, fontSize: 9)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _heatCell(
    ReadingStatsController controller,
    DateTime date,
    int year,
    DateTime firstVisible,
    DateTime today,
  ) {
    final visible = date.year == year && !date.isBefore(firstVisible) && !date.isAfter(DateTime(today.year, today.month, today.day));
    final seconds = visible ? controller.allTimeReport.dailySeconds[_dayKey(date)] ?? 0 : 0;
    final alpha = seconds == 0 ? 0.0 : (.18 + .76 * (seconds / 3600).clamp(0.0, 1.0)).toDouble();
    return SizedBox(
      width: 15,
      height: 15,
      child: Padding(
        padding: const EdgeInsets.all(1.5),
        child: Tooltip(
          message: visible ? '${_formatDate(date)} • ${_duration(seconds)}' : '',
          child: InkWell(
            borderRadius: BorderRadius.circular(3),
            onTap: visible
                ? () => _showRangeDetails(controller, date, date.add(const Duration(days: 1)))
                : null,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: !visible
                    ? AppColors.card
                    : seconds == 0
                        ? AppColors.divider.withValues(alpha: .55)
                        : AppColors.primary.withValues(alpha: alpha),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _periodStatsLine(ReadingDaySummary summary, DateTime start, DateTime end) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${_duration(summary.readingSeconds)} • ${summary.completedChapters} ${'فصل مكتمل'.tr} • ${summary.sessionCount} ${'جلسات'.tr}',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(summary.workTitles.isEmpty ? 'لا توجد قراءة مسجلة في هذه الفترة'.tr : '${'الأكثر قراءة'.tr}: ${summary.workTitles.take(3).join('، ')}',
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
          const SizedBox(height: 7),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: () => _showRangeDetails(Get.find<ReadingStatsController>(), start, end),
              icon: const Icon(Icons.open_in_new_rounded, size: 14),
              label: Text('تفاصيل الفترة'.tr, style: const TextStyle(fontSize: 10)),
            ),
          ),
        ],
      );

  Widget _works(ReadingStatsController controller) {
    final works = controller.visibleWorks;
    return _sectionCard(
      title: 'أكثر أعمالي قراءة'.tr,
      trailing: DropdownButton<String>(
        value: controller.sortBy.value,
        isDense: true,
        underline: const SizedBox.shrink(),
        style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
        dropdownColor: AppColors.card,
        onChanged: (value) { if (value != null) controller.setSortBy(value); },
        items: [
          DropdownMenuItem(value: 'time', child: Text('وقت القراءة'.tr)),
          DropdownMenuItem(value: 'chapters', child: Text('عدد الفصول'.tr)),
          DropdownMenuItem(value: 'last', child: Text('آخر نشاط'.tr)),
          DropdownMenuItem(value: 'first', child: Text('تاريخ البدء'.tr)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _filterChip(controller, 'all', 'الكل'.tr),
              _filterChip(controller, 'manga', 'مانجا'.tr),
              _filterChip(controller, 'manhwa', 'مانهوا'.tr),
              _filterChip(controller, 'manhua', 'مانهوا صينية'.tr),
              _filterChip(controller, 'novel', 'رواية'.tr),
            ],
          ),
          const SizedBox(height: 7),
          if (works.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text('ستظهر الأعمال بعد تسجيل جلسات قراءة فعلية'.tr,
                  textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            )
          else
            ...works.take(8).map((work) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: SizedBox(
                      width: 38,
                      height: 48,
                      child: work.coverImage.trim().isEmpty
                          ? ColoredBox(
                              color: AppColors.primary.withValues(alpha: .12),
                              child: Icon(Icons.menu_book_rounded, size: 18, color: AppColors.primary),
                            )
                          : Image.network(
                              work.coverImage,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => ColoredBox(
                                color: AppColors.primary.withValues(alpha: .12),
                                child: Icon(Icons.menu_book_rounded, size: 18, color: AppColors.primary),
                              ),
                            ),
                    ),
                  ),
                  title: Text(work.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    '${work.type.tr} • ${_duration(work.readingSeconds)} • ${work.completedChapters} ${'فصل مكتمل'.tr}\n${'أيام قراءة'.tr}: ${work.readingDays.length} • ${'آخر فصل'.tr}: ${work.lastChapterTitle.isEmpty ? 'غير متاح'.tr : work.lastChapterTitle}\n${'تاريخ البدء'.tr}: ${_formatDate(work.firstRead)} • ${'آخر نشاط'.tr}: ${_formatDate(work.lastRead)}',
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 9, height: 1.3),
                  ),
                  isThreeLine: true,
                  trailing: Icon(Icons.chevron_right_rounded, color: AppColors.icon, size: 18),
                  onTap: () => Get.toNamed(Routes.COMIC_DETAIL, arguments: work.comicId),
                )),
        ],
      ),
    );
  }

  Widget _filterChip(ReadingStatsController controller, String value, String label) {
    final selected = controller.typeFilter.value == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 10, color: selected ? Colors.white : AppColors.textSecondary)),
      selected: selected,
      onSelected: (_) => controller.setTypeFilter(value),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.card,
      side: BorderSide(color: selected ? AppColors.primary : AppColors.divider),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 3),
    );
  }

  Widget _achievements(ReadingStatsController controller) {
    final items = controller.achievements;
    return _sectionCard(
      title: 'الإنجازات'.tr,
      child: Column(
        children: items.map((achievement) => ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: Icon(
            IconData(achievement.icon, fontFamily: 'MaterialIcons'),
            color: achievement.unlocked ? AppColors.primary : AppColors.icon.withValues(alpha: .45),
            size: 21,
          ),
          title: Row(children: [
            Expanded(child: Text(achievement.title.tr, style: TextStyle(
              color: achievement.unlocked ? AppColors.textPrimary : AppColors.textSecondary,
              fontSize: 11,
              fontWeight: achievement.unlocked ? FontWeight.w800 : FontWeight.w600,
            ))),
            if (achievement.isNewThisWeek) Text('جديد'.tr, style: TextStyle(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.w800)),
          ]),
          subtitle: Text(achievement.description.tr, style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
          trailing: Icon(achievement.unlocked ? Icons.verified_rounded : Icons.lock_outline_rounded,
              size: 17, color: achievement.unlocked ? AppColors.primary : AppColors.icon.withValues(alpha: .5)),
        )).toList(growable: false),
      ),
    );
  }

  Widget _preferences(
    ReadingStatsController controller,
    ReadingStatsPreferences preferences,
  ) =>
      _sectionCard(
        title: 'الخصوصية والخيارات'.tr,
        child: Column(
          children: [
            SwitchListTile.adaptive(
              value: preferences.syncEnabled,
              onChanged: controller.canSync ? (value) => controller.setSyncEnabled(value) : null,
              contentPadding: EdgeInsets.zero,
              dense: true,
              secondary: Icon(Icons.cloud_sync_outlined, color: AppColors.icon),
              title: Text('مزامنة إحصاءات القراءة'.tr, style: TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w700)),
              subtitle: Text(
                controller.canSync
                    ? (preferences.syncEnabled ? 'تُزامن الجلسات الخاصة مع حسابك'.tr : 'تبقى الإحصاءات على هذا الجهاز'.tr)
                    : 'المزامنة متاحة للحسابات المسجلة والموثقة فقط'.tr,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
              ),
              activeColor: AppColors.primary,
            ),
            if (preferences.syncEnabled && controller.canSync)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: controller.isSyncing.value ? null : controller.syncNow,
                  icon: controller.isSyncing.value
                      ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                      : const Icon(Icons.sync_rounded, size: 16),
                  label: Text('مزامنة الآن'.tr, style: const TextStyle(fontSize: 11)),
                ),
              ),
            Divider(height: 1, color: AppColors.divider),
            SwitchListTile.adaptive(
              value: preferences.weeklySummaryEnabled,
              onChanged: (value) => controller.updatePreferences(
                preferences.copyWith(weeklySummaryEnabled: value),
              ),
              contentPadding: EdgeInsets.zero,
              dense: true,
              secondary: Icon(Icons.notifications_none_rounded, color: AppColors.icon),
              title: Text('ملخص قراءة أسبوعي'.tr, style: TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w700)),
              subtitle: Text('إشعار اختياري لتذكيرك بمراجعة ملخصك'.tr,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
              activeColor: AppColors.primary,
            ),
            Divider(height: 1, color: AppColors.divider),
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(Icons.delete_outline_rounded, color: AppColors.warning),
              title: Text('إعادة ضبط الإحصاءات'.tr, style: TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w700)),
              subtitle: Text('لا يمكن التراجع عن حذف سجل الإحصاءات'.tr, style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
              onTap: () => _confirmReset(controller, preferences),
            ),
          ],
        ),
      );

  Future<void> _editGoals(
    ReadingStatsController controller,
    ReadingStatsPreferences preferences,
  ) async {
    final daily = TextEditingController(text: '${preferences.dailyGoalMinutes}');
    final weekly = TextEditingController(text: '${preferences.weeklyGoalMinutes}');
    final chapters = TextEditingController(text: '${preferences.weeklyGoalChapters}');
    final activeDayMinimum = TextEditingController(text: '${preferences.minimumActiveDayMinutes}');
    final formKey = GlobalKey<FormState>();
    final confirmed = await Get.dialog<bool>(AlertDialog(
      backgroundColor: AppColors.card,
      title: Text('أهداف القراءة'.tr, style: TextStyle(color: AppColors.textPrimary)),
      content: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: daily, keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'الهدف اليومي بالدقائق'.tr),
                validator: (value) => _validGoal(value, 5, 720)),
              const SizedBox(height: 10),
              TextFormField(controller: weekly, keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'الهدف الأسبوعي بالدقائق'.tr),
                validator: (value) => _validGoal(value, 30, 10080)),
              const SizedBox(height: 10),
              TextFormField(controller: chapters, keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'هدف الفصول الأسبوعي (0 لإيقافه)'.tr),
                validator: (value) => _validGoal(value, 0, 1000)),
              const SizedBox(height: 10),
              TextFormField(controller: activeDayMinimum, keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'الحد الأدنى لليوم النشط بالدقائق'.tr,
                  helperText: 'يُستخدم هذا الحد لحساب أيام النشاط والسلاسل'.tr,
                ),
                validator: (value) => _validGoal(value, 1, 120)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: Text('إلغاء'.tr)),
        FilledButton(onPressed: () {
          if (formKey.currentState?.validate() == true) Get.back(result: true);
        }, child: Text('حفظ'.tr)),
      ],
    ));
    if (confirmed == true) {
      await controller.updatePreferences(preferences.copyWith(
        dailyGoalMinutes: int.parse(daily.text),
        weeklyGoalMinutes: int.parse(weekly.text),
        weeklyGoalChapters: int.parse(chapters.text),
        minimumActiveDayMinutes: int.parse(activeDayMinimum.text),
      ));
    }
    daily.dispose();
    weekly.dispose();
    chapters.dispose();
    activeDayMinimum.dispose();
  }

  String? _validGoal(String? value, int minimum, int maximum) {
    final parsed = int.tryParse(value ?? '');
    if (parsed == null || parsed < minimum || parsed > maximum) {
      return '${'أدخل رقمًا بين'.tr} $minimum ${'و'.tr} $maximum';
    }
    return null;
  }

  Future<void> _confirmReset(
    ReadingStatsController controller,
    ReadingStatsPreferences preferences,
  ) async {
    final cloudWillBeCleared = preferences.syncEnabled && controller.canSync;
    final confirmed = await Get.dialog<bool>(AlertDialog(
      backgroundColor: AppColors.card,
      title: Text('إعادة ضبط الإحصاءات؟'.tr, style: TextStyle(color: AppColors.textPrimary)),
      content: Text(
        cloudWillBeCleared
            ? 'سيُحذف سجل الإحصاءات من هذا الجهاز ومن حسابك السحابي نهائيًا. لن تُحذف المفضلة أو سجل القراءة المعتاد.'.tr
            : 'سيُحذف سجل الإحصاءات من هذا الجهاز فقط. إذا كانت هناك نسخة سحابية سابقة فلن تُحذف، وقد تعود عند تفعيل المزامنة لاحقًا. لن تُحذف المفضلة أو سجل القراءة المعتاد.'.tr,
        style: TextStyle(color: AppColors.textSecondary, height: 1.45),
      ),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: Text('إلغاء'.tr)),
        FilledButton.tonal(onPressed: () => Get.back(result: true), child: Text('حذف الإحصاءات'.tr)),
      ],
    ));
    if (confirmed == true) await controller.resetStatistics();
  }

  Future<void> _showRangeDetails(
    ReadingStatsController controller,
    DateTime start,
    DateTime end,
  ) async {
    final summary = controller.summarizeRange(start, end);
    final title = end.difference(start).inDays <= 1
        ? _formatDate(start)
        : '${_formatDate(start)} – ${_formatDate(end.subtract(const Duration(days: 1)))}';
    await Get.dialog<void>(AlertDialog(
      backgroundColor: AppColors.card,
      title: Text(title, style: TextStyle(color: AppColors.textPrimary, fontSize: 15)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _detailRow('وقت القراءة'.tr, _duration(summary.readingSeconds)),
          _detailRow('الفصول المكتملة'.tr, '${summary.completedChapters}'),
          _detailRow('جلسات القراءة'.tr, '${summary.sessionCount}'),
          const SizedBox(height: 6),
          Text(summary.workTitles.isEmpty ? 'لا توجد أعمال مسجلة'.tr : '${'الأعمال'.tr}: ${summary.workTitles.join('، ')}',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.4)),
        ],
      ),
      actions: [TextButton(onPressed: Get.back, child: Text('إغلاق'.tr))],
    ));
  }

  Widget _detailRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 11))),
          Text(value, style: TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w800)),
        ]),
      );

  String _comparison(int current, int previous) {
    if (previous <= 0) return current <= 0 ? '—' : 'بداية التتبع'.tr;
    final delta = ((current - previous) / previous * 100).round();
    return delta >= 0 ? '+$delta%' : '$delta%';
  }

  String _duration(int seconds) {
    final safe = seconds < 0 ? 0 : seconds;
    final hours = safe ~/ 3600;
    final minutes = (safe % 3600) ~/ 60;
    if (hours > 0) return '$hours ${'ساعة'.tr} ${minutes > 0 ? '$minutes ${'دقيقة'.tr}' : ''}'.trim();
    return '$minutes ${'دقيقة'.tr}';
  }

  String _formatDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  String _dayKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
}

class _ChartPoint {
  const _ChartPoint({required this.label, required this.start, required this.end, required this.seconds});

  final String label;
  final DateTime start;
  final DateTime end;
  final int seconds;
}
