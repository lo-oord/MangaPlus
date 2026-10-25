import 'dart:math' as math;

class ReadingStatsWork {
  const ReadingStatsWork({
    required this.comicId,
    required this.title,
    required this.type,
    required this.coverImage,
    required this.readingSeconds,
    required this.completedChapterIds,
    required this.firstRead,
    required this.lastRead,
    required this.readingDays,
    required this.lastChapterTitle,
  });

  final String comicId;
  final String title;
  final String type;
  final String coverImage;
  final int readingSeconds;
  final Set<String> completedChapterIds;
  final DateTime firstRead;
  final DateTime lastRead;
  final Set<String> readingDays;
  final String lastChapterTitle;

  int get completedChapters => completedChapterIds.length;
}

class ReadingStatsReport {
  const ReadingStatsReport({
    required this.totalSeconds,
    required this.todaySeconds,
    required this.currentWeekSeconds,
    required this.previousWeekSeconds,
    required this.currentMonthSeconds,
    required this.previousMonthSeconds,
    required this.currentYearSeconds,
    required this.previousYearSeconds,
    required this.completedChapters,
    required this.activeDays,
    required this.currentWeekChapters,
    required this.previousWeekChapters,
    required this.currentWeekActiveDays,
    required this.sessionCount,
    required this.averageSessionSeconds,
    required this.averageActiveDaySeconds,
    required this.longestSessionSeconds,
    required this.currentStreakDays,
    required this.longestStreakDays,
    required this.averageActiveDaysPerWeek,
    required this.busiestWeekday,
    required this.timeOfDaySeconds,
    required this.dailySeconds,
    required this.monthlySeconds,
    required this.works,
    required this.currentWeekTopWork,
    required this.firstActivity,
  });

  final int totalSeconds;
  final int todaySeconds;
  final int currentWeekSeconds;
  final int previousWeekSeconds;
  final int currentMonthSeconds;
  final int previousMonthSeconds;
  final int currentYearSeconds;
  final int previousYearSeconds;
  final int completedChapters;
  final int activeDays;
  final int currentWeekChapters;
  final int previousWeekChapters;
  final int currentWeekActiveDays;
  final int sessionCount;
  final int averageSessionSeconds;
  final int averageActiveDaySeconds;
  final int longestSessionSeconds;
  final int currentStreakDays;
  final int longestStreakDays;
  final double averageActiveDaysPerWeek;
  final int? busiestWeekday;
  final Map<String, int> timeOfDaySeconds;
  final Map<String, int> dailySeconds;
  final Map<String, int> monthlySeconds;
  final List<ReadingStatsWork> works;
  final ReadingStatsWork? currentWeekTopWork;
  final DateTime? firstActivity;

  int get startedWorks => works.length;
}

class ReadingDaySummary {
  const ReadingDaySummary({
    required this.date,
    required this.readingSeconds,
    required this.completedChapters,
    required this.sessionCount,
    required this.workTitles,
  });

  final DateTime date;
  final int readingSeconds;
  final int completedChapters;
  final int sessionCount;
  final List<String> workTitles;
}

/// Aggregates only recorded sessions. Legacy history/readChapters records are
/// intentionally excluded because opening a chapter is not proof of reading.
class ReadingStatsAnalytics {
  const ReadingStatsAnalytics._();

  static ReadingStatsReport build(
    Iterable<Map<String, dynamic>> rawSessions, {
    required DateTime now,
    String typeFilter = 'all',
    int activeDayThresholdSeconds = 60,
  }) {
    final activeThreshold = activeDayThresholdSeconds.clamp(1, 86400).toInt();
    final sessions = rawSessions
        .where((session) =>
            typeFilter == 'all' ||
            normalizeType('${session['type'] ?? ''}') == normalizeType(typeFilter))
        .toList(growable: false);

    final dailySeconds = <String, int>{};
    final monthlySeconds = <String, int>{};
    final workData = <String, _WorkAccumulator>{};
    final allCompleted = <String>{};
    final weekCompleted = <String>{};
    final previousWeekCompleted = <String>{};
    final weekWorkSeconds = <String, int>{};
    final weekdaySeconds = <int, int>{};
    final timeOfDaySeconds = <String, int>{
      'morning': 0,
      'afternoon': 0,
      'evening': 0,
      'night': 0,
    };
    var totalSeconds = 0;
    var currentWeekSeconds = 0;
    var previousWeekSeconds = 0;
    var currentWeekActiveDays = 0;
    var sessionCount = 0;
    var longestSessionSeconds = 0;
    DateTime? firstActivity;

    final today = DateTime(now.year, now.month, now.day);
    final weekStart = DateTime(today.year, today.month, today.day - (today.weekday - DateTime.monday));
    final previousWeekStart = DateTime(weekStart.year, weekStart.month, weekStart.day - 7);
    final nextWeekStart = DateTime(weekStart.year, weekStart.month, weekStart.day + 7);
    final monthStart = DateTime(now.year, now.month, 1);
    final nextMonthStart = DateTime(now.year, now.month + 1, 1);
    final previousMonthStart = DateTime(now.year, now.month - 1, 1);
    final yearStart = DateTime(now.year, 1, 1);
    final nextYearStart = DateTime(now.year + 1, 1, 1);
    final previousYearStart = DateTime(now.year - 1, 1, 1);

    for (final session in sessions) {
      final seconds = _intValue(session['durationSeconds']).clamp(0, 86400).toInt();
      final chapterWasCompleted = session['chapterCompleted'] == true;
      if (seconds <= 0 && !chapterWasCompleted) continue;
      final comicId = '${session['comicId'] ?? ''}'.trim();
      final chapterId = '${session['chapterId'] ?? ''}'.trim();
      if (comicId.isEmpty) continue;
      final startedAt = _date(session['startedAt']) ?? _date(session['startedAtUtc']);
      final endedAt = _date(session['endedAt']) ?? startedAt;
      if (startedAt == null || endedAt == null) continue;
      final localStart = startedAt.toLocal();
      final localEnd = endedAt.toLocal();
      firstActivity = firstActivity == null || localStart.isBefore(firstActivity)
          ? localStart
          : firstActivity;
      sessionCount++;
      if (seconds > longestSessionSeconds) longestSessionSeconds = seconds;
      if (seconds > 0) {
        final bucket = _timeBucket(localStart.hour);
        timeOfDaySeconds[bucket] = (timeOfDaySeconds[bucket] ?? 0) + seconds;
      }

      final type = normalizeType('${session['type'] ?? ''}');
      final workKey = '${session['sourceId'] ?? ''}::$comicId';
      final accumulator = workData.putIfAbsent(
        workKey,
        () => _WorkAccumulator(
          comicId: comicId,
          title: '${session['title'] ?? ''}'.trim().isEmpty
              ? 'عمل محفوظ سابقًا'
              : '${session['title']}',
          type: type,
          coverImage: '${session['coverImage'] ?? ''}'.trim(),
          firstRead: localStart,
          lastRead: localEnd,
          lastChapterTitle: '${session['chapterTitle'] ?? ''}'.trim(),
        ),
      );
      accumulator.seconds += seconds;
      if (localStart.isBefore(accumulator.firstRead)) accumulator.firstRead = localStart;
      if (localEnd.isAfter(accumulator.lastRead)) {
        accumulator.lastRead = localEnd;
        final chapterTitle = '${session['chapterTitle'] ?? ''}'.trim();
        if (chapterTitle.isNotEmpty) accumulator.lastChapterTitle = chapterTitle;
      }
      if (accumulator.title == 'عمل محفوظ سابقًا' &&
          '${session['title'] ?? ''}'.trim().isNotEmpty) {
        accumulator.title = '${session['title']}';
      }
      final coverImage = '${session['coverImage'] ?? ''}'.trim();
      if (accumulator.coverImage.isEmpty && coverImage.isNotEmpty) {
        accumulator.coverImage = coverImage;
      }

      final dayMap = session['dailySeconds'];
      final sessionDays = <String, int>{};
      if (dayMap is Map) {
        for (final entry in dayMap.entries) {
          final key = '${entry.key}';
          final value = _intValue(entry.value).clamp(0, 86400).toInt();
          if (_parseDay(key) != null && value > 0) sessionDays[key] = value;
        }
      }
      if (sessionDays.isEmpty && seconds > 0) {
        final key = _dayKey(localStart);
        sessionDays[key] = seconds;
      }
      for (final entry in sessionDays.entries) {
        final day = _parseDay(entry.key);
        if (day == null) continue;
        dailySeconds.update(entry.key, (value) => value + entry.value,
            ifAbsent: () => entry.value);
        accumulator.dailySeconds.update(entry.key, (value) => value + entry.value,
            ifAbsent: () => entry.value);
        weekdaySeconds.update(day.weekday, (value) => value + entry.value,
            ifAbsent: () => entry.value);
        if (!day.isBefore(monthStart) && day.isBefore(nextMonthStart)) {
          monthlySeconds.update(entry.key, (value) => value + entry.value,
              ifAbsent: () => entry.value);
        }
        if (!day.isBefore(weekStart) && day.isBefore(nextWeekStart)) {
          currentWeekSeconds += entry.value;
          weekWorkSeconds.update(workKey, (value) => value + entry.value,
              ifAbsent: () => entry.value);
        } else if (!day.isBefore(previousWeekStart) && day.isBefore(weekStart)) {
          previousWeekSeconds += entry.value;
        }
      }
      totalSeconds += seconds;

      if (chapterWasCompleted && chapterId.isNotEmpty) {
        final chapterKey = '$workKey::$chapterId';
        accumulator.completedChapterIds.add(chapterId);
        allCompleted.add(chapterKey);
        final completedDay = '${session['chapterCompletedDay'] ?? ''}';
        final completedAt = _parseDay(completedDay) ?? localEnd;
        final normalizedDay = DateTime(completedAt.year, completedAt.month, completedAt.day);
        if (!normalizedDay.isBefore(weekStart) && normalizedDay.isBefore(nextWeekStart)) {
          weekCompleted.add(chapterKey);
        } else if (!normalizedDay.isBefore(previousWeekStart) &&
            normalizedDay.isBefore(weekStart)) {
          previousWeekCompleted.add(chapterKey);
        }
      }
    }

    final activeEntries = dailySeconds.entries.where((entry) => entry.value >= activeThreshold).toList(growable: false);
    final activeDays = activeEntries.length;
    final activeTimeSeconds = activeEntries.fold<int>(0, (sum, entry) => sum + entry.value);
    final currentWeekActiveDates = dailySeconds.entries.where((entry) {
      final day = _parseDay(entry.key);
      return entry.value >= activeThreshold && day != null &&
          !day.isBefore(weekStart) && day.isBefore(nextWeekStart);
    }).length;
    var todaySeconds = 0;
    var currentMonthSeconds = 0;
    var previousMonthSeconds = 0;
    var currentYearSeconds = 0;
    var previousYearSeconds = 0;
    for (final entry in dailySeconds.entries) {
      final day = _parseDay(entry.key);
      if (day == null) continue;
      if (_dayKey(day) == _dayKey(today)) todaySeconds += entry.value;
      if (!day.isBefore(monthStart) && day.isBefore(nextMonthStart)) {
        currentMonthSeconds += entry.value;
      } else if (!day.isBefore(previousMonthStart) && day.isBefore(monthStart)) {
        previousMonthSeconds += entry.value;
      }
      if (!day.isBefore(yearStart) && day.isBefore(nextYearStart)) {
        currentYearSeconds += entry.value;
      } else if (!day.isBefore(previousYearStart) && day.isBefore(yearStart)) {
        previousYearSeconds += entry.value;
      }
    }

    currentWeekActiveDays = currentWeekActiveDates;
    final works = workData.values
        .map((work) => work.toWork(activeThreshold))
        .toList()
      ..sort((a, b) => b.readingSeconds.compareTo(a.readingSeconds));
    ReadingStatsWork? topWork;
    if (weekWorkSeconds.isNotEmpty) {
      final topKey = weekWorkSeconds.entries.reduce(
        (a, b) => a.value >= b.value ? a : b,
      ).key;
      topWork = workData[topKey]?.toWork(activeThreshold);
    }
    final busiestWeekday = weekdaySeconds.isEmpty
        ? null
        : weekdaySeconds.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    final firstLocalDay = firstActivity == null
        ? today
        : DateTime(firstActivity.year, firstActivity.month, firstActivity.day);
    final elapsedDays = math.max(
      1,
      DateTime.utc(today.year, today.month, today.day)
              .difference(DateTime.utc(firstLocalDay.year, firstLocalDay.month, firstLocalDay.day))
              .inDays +
          1,
    );
    final weeksTracked = math.max(1, (elapsedDays / 7).ceil());

    return ReadingStatsReport(
      totalSeconds: totalSeconds,
      todaySeconds: todaySeconds,
      currentWeekSeconds: currentWeekSeconds,
      previousWeekSeconds: previousWeekSeconds,
      currentMonthSeconds: currentMonthSeconds,
      previousMonthSeconds: previousMonthSeconds,
      currentYearSeconds: currentYearSeconds,
      previousYearSeconds: previousYearSeconds,
      completedChapters: allCompleted.length,
      activeDays: activeDays,
      currentWeekChapters: weekCompleted.length,
      previousWeekChapters: previousWeekCompleted.length,
      currentWeekActiveDays: currentWeekActiveDays,
      sessionCount: sessionCount,
      averageSessionSeconds: sessionCount == 0 ? 0 : (totalSeconds / sessionCount).round(),
      averageActiveDaySeconds: activeDays == 0 ? 0 : (activeTimeSeconds / activeDays).round(),
      longestSessionSeconds: longestSessionSeconds,
      currentStreakDays: _currentStreak(dailySeconds, today, activeThreshold),
      longestStreakDays: _longestStreak(dailySeconds, activeThreshold),
      averageActiveDaysPerWeek: activeDays / weeksTracked,
      busiestWeekday: busiestWeekday,
      timeOfDaySeconds: Map.unmodifiable(timeOfDaySeconds),
      dailySeconds: Map.unmodifiable(dailySeconds),
      monthlySeconds: Map.unmodifiable(monthlySeconds),
      works: List.unmodifiable(works),
      currentWeekTopWork: topWork,
      firstActivity: firstActivity,
    );
  }

  static ReadingDaySummary summarizeDay(
    Iterable<Map<String, dynamic>> sessions,
    DateTime date,
  ) {
    final day = DateTime(date.year, date.month, date.day);
    final key = _dayKey(day);
    var seconds = 0;
    var completed = 0;
    var sessionCount = 0;
    final workTitles = <String>{};
    final completedKeys = <String>{};
    for (final session in sessions) {
      final duration = _intValue(session['dailySeconds'] is Map
          ? (session['dailySeconds'] as Map)[key]
          : 0);
      final started = _date(session['startedAt'])?.toLocal();
      final dailyRaw = session['dailySeconds'];
      final hasDayBreakdown = dailyRaw is Map && dailyRaw.isNotEmpty;
      final fallbackSeconds = !hasDayBreakdown && started != null && _dayKey(started) == key
          ? _intValue(session['durationSeconds'])
          : 0;
      final daySeconds = duration > 0 ? duration : fallbackSeconds;
      final completionDay = _parseDay('${session['chapterCompletedDay'] ?? ''}');
      final isCompleted = session['chapterCompleted'] == true &&
          (completionDay == null ? started != null && _dayKey(started) == key : _dayKey(completionDay) == key);
      if (daySeconds <= 0 && !isCompleted) continue;
      sessionCount++;
      seconds += daySeconds;
      if (isCompleted) {
        final identity = '${session['sourceId'] ?? ''}::${session['comicId'] ?? ''}::${session['chapterId'] ?? ''}';
        completedKeys.add(identity);
      }
      final title = '${session['title'] ?? ''}'.trim();
      if (title.isNotEmpty) workTitles.add(title);
    }
    completed = completedKeys.length;
    return ReadingDaySummary(
      date: day,
      readingSeconds: seconds,
      completedChapters: completed,
      sessionCount: sessionCount,
      workTitles: List.unmodifiable(workTitles),
    );
  }

  static List<ReadingStatsWork> sortWorks(
    Iterable<ReadingStatsWork> works,
    String sortBy,
  ) {
    final result = works.toList();
    switch (sortBy) {
      case 'chapters':
        result.sort((a, b) => b.completedChapters.compareTo(a.completedChapters));
        break;
      case 'last':
        result.sort((a, b) => b.lastRead.compareTo(a.lastRead));
        break;
      case 'first':
        result.sort((a, b) => a.firstRead.compareTo(b.firstRead));
        break;
      default:
        result.sort((a, b) => b.readingSeconds.compareTo(a.readingSeconds));
    }
    return result;
  }

  static String normalizeType(String value) {
    if (value == 'all') return 'all';
    final normalized = value.trim().toLowerCase();
    if (normalized.contains('novel') || normalized.contains('روا')) return 'novel';
    if (normalized.contains('manhwa') || normalized.contains('مانهوا')) return 'manhwa';
    if (normalized.contains('manhua') || normalized.contains('chinese')) return 'manhua';
    if (normalized.contains('manga') || normalized.contains('مانجا')) return 'manga';
    return normalized.isEmpty ? 'other' : normalized;
  }

  static String _timeBucket(int hour) {
    if (hour >= 5 && hour < 12) return 'morning';
    if (hour >= 12 && hour < 18) return 'afternoon';
    if (hour >= 18 && hour < 22) return 'evening';
    return 'night';
  }

  static int _currentStreak(Map<String, int> days, DateTime today, int threshold) {
    var date = DateTime(today.year, today.month, today.day);
    if ((days[_dayKey(date)] ?? 0) < threshold) {
      date = DateTime(date.year, date.month, date.day - 1);
    }
    var count = 0;
    while ((days[_dayKey(date)] ?? 0) >= threshold && count < 3660) {
      count++;
      date = DateTime(date.year, date.month, date.day - 1);
    }
    return count;
  }

  static int _longestStreak(Map<String, int> days, int threshold) {
    final active = days.entries
        .where((entry) => entry.value >= threshold)
        .map((entry) => _parseDay(entry.key))
        .whereType<DateTime>()
        .toList()
      ..sort();
    if (active.isEmpty) return 0;
    var longest = 1;
    var current = 1;
    for (var index = 1; index < active.length; index++) {
      final currentDay = DateTime.utc(
        active[index].year,
        active[index].month,
        active[index].day,
      );
      final previousDay = DateTime.utc(
        active[index - 1].year,
        active[index - 1].month,
        active[index - 1].day,
      );
      final difference = currentDay.difference(previousDay).inDays;
      if (difference == 1) {
        current++;
      } else if (difference > 1) {
        if (current > longest) longest = current;
        current = 1;
      }
    }
    return math.max(longest, current).toInt();
  }

  static String _dayKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  static DateTime? _parseDay(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) return null;
    final year = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final day = int.tryParse(match.group(3)!);
    if (year == null || month == null || day == null) return null;
    final parsed = DateTime(year, month, day);
    return parsed.year == year && parsed.month == month && parsed.day == day
        ? parsed
        : null;
  }

  static DateTime? _date(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value != null && value.runtimeType.toString() == 'Timestamp') {
      try {
        return (value as dynamic).toDate() as DateTime;
      } catch (_) {}
    }
    return null;
  }

  static int _intValue(dynamic value) =>
      value is num ? value.round() : int.tryParse('$value') ?? 0;
}

class _WorkAccumulator {
  _WorkAccumulator({
    required this.comicId,
    required this.title,
    required this.type,
    required this.coverImage,
    required this.firstRead,
    required this.lastRead,
    required this.lastChapterTitle,
  });

  final String comicId;
  String title;
  final String type;
  String coverImage;
  int seconds = 0;
  DateTime firstRead;
  DateTime lastRead;
  String lastChapterTitle;
  final Set<String> completedChapterIds = <String>{};
  final Map<String, int> dailySeconds = <String, int>{};

  ReadingStatsWork toWork(int activeDayThresholdSeconds) => ReadingStatsWork(
        comicId: comicId,
        title: title,
        type: type,
        coverImage: coverImage,
        readingSeconds: seconds,
        completedChapterIds: Set.unmodifiable(completedChapterIds),
        firstRead: firstRead,
        lastRead: lastRead,
        readingDays: Set.unmodifiable(dailySeconds.entries
            .where((entry) => entry.value >= activeDayThresholdSeconds)
            .map((entry) => entry.key)
            .toSet()),
        lastChapterTitle: lastChapterTitle,
      );
}
