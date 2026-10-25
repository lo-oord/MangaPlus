import 'package:flutter_test/flutter_test.dart';
import 'package:mangaplus/app/data/models/reading_stats.dart';

void main() {
  group('ReadingStatsAnalytics', () {
    test('deduplicates completed chapters by source and work identity', () {
      final day = DateTime(2025, 4, 7, 10);
      final key = _key(day);
      final report = ReadingStatsAnalytics.build(
        [
          _session(
            id: 's1',
            comicId: 'same-comic',
            sourceId: 'source-a',
            chapterId: 'chapter-1',
            type: 'manga',
            startedAt: day,
            seconds: 60,
            completed: true,
            dayKey: key,
          ),
          _session(
            id: 's2',
            comicId: 'same-comic',
            sourceId: 'source-a',
            chapterId: 'chapter-1',
            type: 'manga',
            startedAt: day.add(const Duration(minutes: 5)),
            seconds: 120,
            completed: true,
            dayKey: key,
          ),
          _session(
            id: 's3',
            comicId: 'same-comic',
            sourceId: 'source-b',
            chapterId: 'chapter-1',
            type: 'manhwa',
            startedAt: day.add(const Duration(minutes: 10)),
            seconds: 0,
            completed: true,
            dayKey: key,
          ),
        ],
        now: day,
      );

      expect(report.completedChapters, 2);
      expect(report.totalSeconds, 180);
      expect(report.sessionCount, 3);
      expect(report.activeDays, 1);
      expect(report.startedWorks, 2);
      expect(report.averageSessionSeconds, 60);
      expect(report.works.length, 2);
      expect(report.works.every((work) => work.comicId == 'same-comic'), isTrue);
    });

    test('computes daily, weekly, monthly, yearly and streak totals from local days', () {
      final firstDay = DateTime(2025, 5, 5, 9);
      final sessions = List.generate(3, (index) {
        final day = firstDay.add(Duration(days: index));
        return _session(
          id: 'streak-$index',
          comicId: 'series',
          sourceId: 'catalog.example',
          chapterId: 'chapter-$index',
          type: 'novel',
          startedAt: day,
          seconds: 600,
          completed: index != 2,
          dayKey: _key(day),
        );
      });
      final now = firstDay.add(const Duration(days: 2, hours: 10));
      final report = ReadingStatsAnalytics.build(sessions, now: now);

      expect(report.todaySeconds, 600);
      expect(report.currentWeekSeconds, 1800);
      expect(report.currentMonthSeconds, 1800);
      expect(report.currentYearSeconds, 1800);
      expect(report.currentWeekActiveDays, 3);
      expect(report.activeDays, 3);
      expect(report.currentStreakDays, 3);
      expect(report.longestStreakDays, 3);
      expect(report.averageActiveDaySeconds, 600);
      expect(report.longestSessionSeconds, 600);
      expect(report.timeOfDaySeconds['morning'], 1800);
    });

    test('does not invent activity when no qualifying session exists', () {
      final report = ReadingStatsAnalytics.build(
        [
          _session(
            id: 'empty',
            comicId: 'series',
            sourceId: 'catalog.example',
            chapterId: 'chapter-1',
            type: 'manga',
            startedAt: DateTime(2025, 1, 1),
            seconds: 0,
            completed: false,
            dayKey: '2025-01-01',
          ),
        ],
        now: DateTime(2025, 1, 2),
      );

      expect(report.totalSeconds, 0);
      expect(report.completedChapters, 0);
      expect(report.activeDays, 0);
      expect(report.sessionCount, 0);
      expect(report.firstActivity, isNull);
    });

    test('honors the configurable minimum for an active day', () {
      final day = DateTime(2025, 6, 2, 9);
      final session = _session(
        id: 'threshold',
        comicId: 'series',
        sourceId: 'catalog.example',
        chapterId: 'chapter-1',
        type: 'manga',
        startedAt: day,
        seconds: 90,
        completed: false,
        dayKey: _key(day),
      );

      final defaultReport = ReadingStatsAnalytics.build([session], now: day);
      final strictReport = ReadingStatsAnalytics.build(
        [session],
        now: day,
        activeDayThresholdSeconds: 120,
      );

      expect(defaultReport.activeDays, 1);
      expect(defaultReport.works.single.readingDays, contains(_key(day)));
      expect(strictReport.totalSeconds, 90);
      expect(strictReport.activeDays, 0);
      expect(strictReport.currentStreakDays, 0);
      expect(strictReport.works.single.readingDays, isEmpty);
    });

    test('filters content using known MangaPlus type categories', () {
      final day = DateTime(2025, 6, 10, 8);
      final sessions = [
        _session(id: 'manga', comicId: 'm', sourceId: 'a', chapterId: '1', type: 'manga', startedAt: day, seconds: 100, completed: true, dayKey: _key(day)),
        _session(id: 'novel', comicId: 'n', sourceId: 'b', chapterId: '1', type: 'novel', startedAt: day, seconds: 200, completed: true, dayKey: _key(day)),
      ];

      expect(ReadingStatsAnalytics.build(sessions, now: day, typeFilter: 'manga').totalSeconds, 100);
      expect(ReadingStatsAnalytics.build(sessions, now: day, typeFilter: 'novel').totalSeconds, 200);
    });
  });
}

String _key(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

Map<String, dynamic> _session({
  required String id,
  required String comicId,
  required String sourceId,
  required String chapterId,
  required String type,
  required DateTime startedAt,
  required int seconds,
  required bool completed,
  required String dayKey,
}) =>
    <String, dynamic>{
      'sessionId': id,
      'comicId': comicId,
      'sourceId': sourceId,
      'title': 'Series $comicId',
      'type': type,
      'chapterId': chapterId,
      'chapterTitle': 'Chapter $chapterId',
      'startedAt': startedAt.toIso8601String(),
      'endedAt': startedAt.add(Duration(seconds: seconds)).toIso8601String(),
      'durationSeconds': seconds,
      'dailySeconds': seconds == 0 ? <String, int>{} : <String, int>{dayKey: seconds},
      'progress': completed ? 1.0 : 0.5,
      'chapterCompleted': completed,
      'chapterCompletedDay': completed ? dayKey : null,
    };
