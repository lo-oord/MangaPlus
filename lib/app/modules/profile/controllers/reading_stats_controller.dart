import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/data/models/reading_stats.dart';
import 'package:mangaplus/app/data/services/auth_service.dart';
import 'package:mangaplus/app/data/services/chapter_update_service.dart';
import 'package:mangaplus/app/data/services/reading_stats_service.dart';
import 'package:mangaplus/app/widgets/app_feedback.dart';

class ReadingAchievement {
  const ReadingAchievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.unlocked,
    this.unlockedAt,
  });

  final String id;
  final String title;
  final String description;
  final int icon;
  final bool unlocked;
  final DateTime? unlockedAt;

  bool get isNewThisWeek {
    final date = unlockedAt;
    if (!unlocked || date == null) return false;
    final local = date.toLocal();
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day - (now.weekday - DateTime.monday));
    final nextWeekStart = DateTime(weekStart.year, weekStart.month, weekStart.day + 7);
    return !local.isBefore(weekStart) && local.isBefore(nextWeekStart);
  }
}

class ReadingStatsController extends GetxController {
  ReadingStatsController({ReadingStatsService? service})
      : _service = service ?? Get.find<ReadingStatsService>();

  final ReadingStatsService _service;
  final sessions = <Map<String, dynamic>>[].obs;
  final preferences = const ReadingStatsPreferences().obs;
  final isLoading = true.obs;
  final isSyncing = false.obs;
  final typeFilter = 'all'.obs;
  final periodFilter = 'all'.obs;
  final selectedYear = DateTime.now().year.obs;
  final sortBy = 'time'.obs;
  final refreshRevision = 0.obs;
  StreamSubscription<User?>? _authSubscription;
  User? _previousAuthUser;
  Worker? _serviceRevisionWorker;
  int _loadGeneration = 0;
  String _ownerId = '';
  Map<String, String> _achievementUnlocks = <String, String>{};
  List<ReadingAchievement> _achievements = const [];
  ReadingStatsReport _allTimeReport = ReadingStatsAnalytics.build(
    const <Map<String, dynamic>>[],
    now: DateTime.now(),
  );
  ReadingStatsReport _report = ReadingStatsAnalytics.build(
    const <Map<String, dynamic>>[],
    now: DateTime.now(),
  );
  List<ReadingStatsWork> _visibleWorks = const [];

  ReadingStatsReport get report => _report;
  ReadingStatsReport get allTimeReport => _allTimeReport;
  List<ReadingStatsWork> get visibleWorks => _visibleWorks;
  List<ReadingAchievement> get achievements => _achievements;
  List<ReadingAchievement> get newAchievementsThisWeek =>
      _achievements.where((item) => item.isNewThisWeek).toList(growable: false);
  bool get canSync => _service.currentUserCanSync;
  String get ownerId => _ownerId;
  List<int> get availableYears {
    final firstYear = _allTimeReport.firstActivity?.year ?? DateTime.now().year;
    return [for (var year = DateTime.now().year; year >= firstYear; year--) year];
  }

  int get weeksMeetingGoal {
    final goal = preferences.value.weeklyGoalMinutes * 60;
    if (goal <= 0 || _allTimeReport.firstActivity == null) return 0;
    final weeklySeconds = _weeklySecondsByStart(_allTimeReport.dailySeconds);
    return weeklySeconds.values.where((seconds) => seconds >= goal).length;
  }

  int get trackedWeeks {
    final first = _allTimeReport.firstActivity;
    if (first == null) return 0;
    final now = DateTime.now();
    final currentWeek = _monday(DateTime(now.year, now.month, now.day));
    final firstWeek = _monday(DateTime(first.year, first.month, first.day));
    final elapsedCalendarDays = DateTime.utc(currentWeek.year, currentWeek.month, currentWeek.day)
        .difference(DateTime.utc(firstWeek.year, firstWeek.month, firstWeek.day))
        .inDays;
    return ((elapsedCalendarDays ~/ 7) + 1).clamp(1, 10000).toInt();
  }

  double get weeklyGoalAchievementPercent {
    if (trackedWeeks == 0) return 0;
    return (weeksMeetingGoal / trackedWeeks).clamp(0.0, 1.0).toDouble();
  }

  int get currentWeekSeconds => _allTimeReport.currentWeekSeconds;

  @override
  void onInit() {
    super.onInit();
    _serviceRevisionWorker = ever<int>(_service.revision, (_) {
      unawaited(_refreshSessions());
    });
    if (Get.isRegistered<AuthService>()) {
      final auth = Get.find<AuthService>();
      _previousAuthUser = auth.currentUser;
      _authSubscription = auth.authStateChanges.listen(_handleAuthChanged);
    }
    unawaited(_loadForCurrentOwner());
  }

  Future<void> _handleAuthChanged(User? user) async {
    final previous = _previousAuthUser;
    _previousAuthUser = user;
    if (previous != null &&
        previous.isAnonymous &&
        user != null &&
        !user.isAnonymous &&
        previous.uid == user.uid) {
      await _service.promoteGuestDataToAccount(user.uid);
    }
    await _loadForCurrentOwner();
  }

  Future<void> _loadForCurrentOwner() async {
    final generation = ++_loadGeneration;
    final owner = _service.currentOwnerId;
    _ownerId = owner;
    sessions.clear();
    isLoading(true);
    typeFilter('all');
    periodFilter('all');
    try {
      final loadedPreferences = await _service.loadPreferences(ownerId: owner);
      final unlocks = await _service.loadAchievementUnlocks(ownerId: owner);
      if (generation != _loadGeneration || owner != _service.currentOwnerId) return;
      preferences.value = loadedPreferences;
      _achievementUnlocks = unlocks;
      await _service.recoverInterruptedSessions(ownerId: owner);
      if (loadedPreferences.syncEnabled && _service.currentUserCanSync) {
        isSyncing(true);
        try {
          await _service.syncOwner(owner);
        } catch (_) {
          // The locally saved report remains available if the network is down.
        } finally {
          isSyncing(false);
        }
      }
      await _refreshSessions(generation: generation, owner: owner);
    } finally {
      if (generation == _loadGeneration) isLoading(false);
    }
  }

  Future<void> _refreshSessions({int? generation, String? owner}) async {
    final targetOwner = owner ?? _ownerId;
    if (targetOwner.isEmpty || targetOwner != _service.currentOwnerId) return;
    final targetGeneration = generation ?? _loadGeneration;
    final values = await _service.loadSessions(ownerId: targetOwner);
    if (targetGeneration != _loadGeneration || targetOwner != _service.currentOwnerId) return;
    sessions.assignAll(values);
    _recompute();
  }

  void setTypeFilter(String value) {
    if (!{'all', 'manga', 'manhwa', 'manhua', 'novel'}.contains(value)) return;
    typeFilter(value);
    _recompute();
  }

  void setPeriodFilter(String value) {
    if (!{'today', 'week', 'month', 'last7', 'last30', 'year', 'all'}.contains(value)) return;
    periodFilter(value);
    _recompute();
  }

  void setSelectedYear(int value) {
    if (!availableYears.contains(value)) return;
    selectedYear(value);
    refreshRevision.value++;
  }

  void setSortBy(String value) {
    if (!{'time', 'chapters', 'last', 'first'}.contains(value)) return;
    sortBy(value);
    _recompute();
  }

  ReadingDaySummary summarizeDay(DateTime day) =>
      ReadingStatsAnalytics.summarizeDay(_typeFilteredSessions(), day);

  ReadingDaySummary summarizeRange(DateTime start, DateTime end) {
    final first = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);
    final activeSessions = <String>{};
    final completedChapters = <String>{};
    final workTitles = <String>{};
    var seconds = 0;
    for (final session in _typeFilteredSessions()) {
      final sessionId = '${session['sessionId'] ?? ''}';
      final daily = session['dailySeconds'];
      var sessionSeconds = 0;
      if (daily is Map) {
        for (final entry in daily.entries) {
          final date = DateTime.tryParse('${entry.key}');
          if (date == null || date.isBefore(first) || !date.isBefore(last)) continue;
          final value = entry.value is num ? (entry.value as num).toInt() : int.tryParse('${entry.value}') ?? 0;
          if (value > 0) sessionSeconds += value;
        }
      }
      if (daily is! Map || daily.isEmpty) {
        final started = DateTime.tryParse('${session['startedAt'] ?? ''}')?.toLocal();
        if (started != null && !started.isBefore(first) && started.isBefore(last)) {
          sessionSeconds = session['durationSeconds'] is num
              ? (session['durationSeconds'] as num).toInt().clamp(0, 86400).toInt()
              : 0;
        }
      }
      final completionDay = DateTime.tryParse('${session['chapterCompletedDay'] ?? ''}');
      final started = DateTime.tryParse('${session['startedAt'] ?? ''}')?.toLocal();
      final effectiveCompletionDay = completionDay ??
          (started == null ? null : DateTime(started.year, started.month, started.day));
      final completed = session['chapterCompleted'] == true &&
          effectiveCompletionDay != null &&
          !effectiveCompletionDay.isBefore(first) &&
          effectiveCompletionDay.isBefore(last);
      if (sessionSeconds <= 0 && !completed) continue;
      activeSessions.add(sessionId.isEmpty ? '${session.hashCode}' : sessionId);
      seconds += sessionSeconds;
      if (completed) {
        completedChapters.add(
          '${session['sourceId'] ?? ''}::${session['comicId'] ?? ''}::${session['chapterId'] ?? ''}',
        );
      }
      final title = '${session['title'] ?? ''}'.trim();
      if (title.isNotEmpty) workTitles.add(title);
    }
    return ReadingDaySummary(
      date: first,
      readingSeconds: seconds,
      completedChapters: completedChapters.length,
      sessionCount: activeSessions.length,
      workTitles: List.unmodifiable(workTitles),
    );
  }

  List<Map<String, dynamic>> _typeFilteredSessions() {
    if (typeFilter.value == 'all') return sessions.toList(growable: false);
    return sessions
        .where((session) =>
            ReadingStatsAnalytics.normalizeType('${session['type'] ?? ''}') ==
            typeFilter.value)
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _sessionsInRange(
    List<Map<String, dynamic>> source,
    DateTime now,
  ) {
    final range = _range(now);
    if (range == null) return source;
    final start = range.$1;
    final end = range.$2;
    final result = <Map<String, dynamic>>[];
    for (final session in source) {
      final copy = Map<String, dynamic>.from(session);
      final dailyRaw = session['dailySeconds'];
      final filteredDaily = <String, int>{};
      if (dailyRaw is Map) {
        for (final entry in dailyRaw.entries) {
          final day = DateTime.tryParse('${entry.key}');
          if (day == null || day.isBefore(start) || !day.isBefore(end)) continue;
          final seconds = entry.value is num ? (entry.value as num).toInt() : int.tryParse('${entry.value}') ?? 0;
          if (seconds > 0) filteredDaily['${entry.key}'] = seconds.clamp(0, 86400).toInt();
        }
      }
      var duration = filteredDaily.values.fold<int>(0, (sum, value) => sum + value);
      if (dailyRaw is! Map || dailyRaw.isEmpty) {
        final started = DateTime.tryParse('${session['startedAt'] ?? ''}')?.toLocal();
        if (started != null && !started.isBefore(start) && started.isBefore(end)) {
          duration = session['durationSeconds'] is num
              ? (session['durationSeconds'] as num).toInt().clamp(0, 86400).toInt()
              : 0;
          if (duration > 0) {
            final key = _dayKey(started);
            filteredDaily[key] = duration;
          }
        }
      }
      copy['durationSeconds'] = duration;
      copy['dailySeconds'] = filteredDaily;
      if (session['chapterCompleted'] == true) {
        final completionDay = DateTime.tryParse('${session['chapterCompletedDay'] ?? ''}');
        final started = DateTime.tryParse('${session['startedAt'] ?? ''}')?.toLocal();
        final effectiveDay = completionDay ?? (started == null ? null : DateTime(started.year, started.month, started.day));
        copy['chapterCompleted'] = effectiveDay != null &&
            !effectiveDay.isBefore(start) && effectiveDay.isBefore(end);
      }
      if (duration > 0 || copy['chapterCompleted'] == true) result.add(copy);
    }
    return result;
  }

  (DateTime, DateTime)? _range(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    switch (periodFilter.value) {
      case 'today':
        return (today, DateTime(today.year, today.month, today.day + 1));
      case 'last7':
        return (DateTime(today.year, today.month, today.day - 6), DateTime(today.year, today.month, today.day + 1));
      case 'last30':
        return (DateTime(today.year, today.month, today.day - 29), DateTime(today.year, today.month, today.day + 1));
      case 'week':
        final weekStart = _monday(today);
        return (weekStart, DateTime(weekStart.year, weekStart.month, weekStart.day + 7));
      case 'month':
        return (DateTime(today.year, today.month, 1), DateTime(today.year, today.month + 1, 1));
      case 'year':
        return (DateTime(today.year, 1, 1), DateTime(today.year + 1, 1, 1));
      default:
        return null;
    }
  }

  void _recompute() {
    final now = DateTime.now();
    final filtered = _typeFilteredSessions();
    final activeDayThresholdSeconds = preferences.value.minimumActiveDayMinutes * 60;
    _allTimeReport = ReadingStatsAnalytics.build(
      filtered,
      now: now,
      activeDayThresholdSeconds: activeDayThresholdSeconds,
    );
    _report = ReadingStatsAnalytics.build(
      _sessionsInRange(filtered, now),
      now: now,
      activeDayThresholdSeconds: activeDayThresholdSeconds,
    );
    _visibleWorks = ReadingStatsAnalytics.sortWorks(_report.works, sortBy.value);
    _refreshAchievementRecords(now);
    refreshRevision.value++;
  }

  void _refreshAchievementRecords(DateTime now) {
    final definitions = _achievementDefinitions(now);
    var changed = false;
    for (final item in definitions) {
      if (item.unlocked && !_achievementUnlocks.containsKey(item.id)) {
        _achievementUnlocks[item.id] = now.toUtc().toIso8601String();
        changed = true;
      }
    }
    if (changed) {
      unawaited(_service.saveAchievementUnlocks(_achievementUnlocks, ownerId: _ownerId));
    }
    _achievements = definitions.map((item) {
      final value = _achievementUnlocks[item.id];
      return ReadingAchievement(
        id: item.id,
        title: item.title,
        description: item.description,
        icon: item.icon,
        unlocked: value != null,
        unlockedAt: value == null ? null : DateTime.tryParse(value),
      );
    }).toList(growable: false);
  }

  List<ReadingAchievement> _achievementDefinitions(DateTime now) {
    final novelSessions = sessions.where((session) =>
        ReadingStatsAnalytics.normalizeType('${session['type'] ?? ''}') == 'novel');
    final novelChapters = ReadingStatsAnalytics.build(novelSessions, now: now).completedChapters;
    final nightSeconds = sessions.fold<int>(0, (sum, session) {
      final startedAt = DateTime.tryParse('${session['startedAt'] ?? ''}')?.toLocal();
      final seconds = session['durationSeconds'] is num
          ? (session['durationSeconds'] as num).toInt().clamp(0, 86400).toInt()
          : 0;
      return startedAt != null && (startedAt.hour >= 22 || startedAt.hour < 5)
          ? sum + seconds
          : sum;
    });
    final activeDates = _allTimeReport.dailySeconds.entries
        .where((entry) => entry.value >= preferences.value.minimumActiveDayMinutes * 60)
        .map((entry) => DateTime.tryParse(entry.key))
        .whereType<DateTime>()
        .toList()
      ..sort();
    final returnedAfterBreak = activeDates.asMap().entries.any((entry) {
      if (entry.key == 0) return false;
      final current = entry.value;
      final previous = activeDates[entry.key - 1];
      return DateTime.utc(current.year, current.month, current.day)
              .difference(DateTime.utc(previous.year, previous.month, previous.day))
              .inDays >=
          30;
    });
    final firstRead = _allTimeReport.firstActivity;
    final hadYear = firstRead != null &&
        !now.isBefore(DateTime(firstRead.year + 1, firstRead.month, firstRead.day));
    return [
      ReadingAchievement(id: 'chapters_10', title: 'القارئ المبتدئ', description: 'أكمل 10 فصول مقروءة', icon: 0xe8ef, unlocked: _allTimeReport.completedChapters >= 10),
      ReadingAchievement(id: 'chapters_500', title: 'جامع الفصول', description: 'أكمل 500 فصل مقروء', icon: 0xe8d2, unlocked: _allTimeReport.completedChapters >= 500),
      ReadingAchievement(id: 'streak_7', title: 'مواظب على القراءة', description: 'حافظ على سلسلة قراءة من 7 أيام', icon: 0xe1d7, unlocked: _allTimeReport.longestStreakDays >= 7),
      ReadingAchievement(id: 'novel_100', title: 'عاشق الروايات', description: 'أكمل 100 فصل من الروايات', icon: 0xe865, unlocked: novelChapters >= 100),
      ReadingAchievement(id: 'night_60', title: 'قارئ الليل', description: 'اقرأ 60 دقيقة في جلسات بدأت بين 10 مساءً و5 صباحًا', icon: 0xe3a6, unlocked: nightSeconds >= 60 * 60),
      ReadingAchievement(id: 'return_30', title: 'العودة الكبرى', description: 'عد إلى القراءة بعد انقطاع 30 يومًا', icon: 0xe5d5, unlocked: returnedAfterBreak),
      ReadingAchievement(id: 'year_1', title: 'سنة مع MangaPlus', description: 'مر عام على أول جلسة قراءة مسجلة', icon: 0xe8f4, unlocked: hadYear),
    ];
  }

  Map<DateTime, int> _weeklySecondsByStart(Map<String, int> days) {
    final result = <DateTime, int>{};
    for (final entry in days.entries) {
      final date = DateTime.tryParse(entry.key);
      if (date == null || entry.value <= 0) continue;
      final week = _monday(date);
      result.update(week, (value) => value + entry.value, ifAbsent: () => entry.value);
    }
    return result;
  }

  Future<void> updatePreferences(ReadingStatsPreferences value) async {
    final previous = preferences.value;
    if (previous.weeklySummaryEnabled != value.weeklySummaryEnabled &&
        Get.isRegistered<ChapterUpdateService>()) {
      final scheduled = await Get.find<ChapterUpdateService>()
          .setWeeklyReadingSummaryEnabled(
        value.weeklySummaryEnabled,
        languageCode: Get.locale?.languageCode == 'en' ? 'en_US' : 'ar_SA',
      );
      if (!scheduled) {
        AppFeedback.show(
          title: 'تعذر تفعيل الملخص الأسبوعي'.tr,
          message: 'اسمح بإشعارات التطبيق لتفعيل هذا الخيار'.tr,
          type: AppNoticeType.error,
        );
        return;
      }
    }
    preferences.value = value;
    await _service.savePreferences(value, ownerId: _ownerId);
    _recompute();
  }

  Future<void> setSyncEnabled(bool value) async {
    if (value && !_service.currentUserCanSync) return;
    await updatePreferences(preferences.value.copyWith(syncEnabled: value));
    if (value) await syncNow();
  }

  Future<void> syncNow() async {
    if (!_service.currentUserCanSync || !preferences.value.syncEnabled) return;
    isSyncing(true);
    try {
      await _service.syncOwner(_ownerId);
      await _refreshSessions();
    } catch (_) {
      AppFeedback.show(
        title: 'تعذر المزامنة'.tr,
        message: 'ستُحفظ الإحصاءات محليًا وتتم إعادة المحاولة لاحقًا'.tr,
        type: AppNoticeType.error,
      );
    } finally {
      isSyncing(false);
    }
  }

  Future<void> resetStatistics() async {
    final owner = _ownerId;
    final deleteCloud = preferences.value.syncEnabled && _service.currentUserCanSync;
    await _service.resetSessions(ownerId: owner, deleteCloudData: deleteCloud);
    sessions.clear();
    _achievementUnlocks.clear();
    _recompute();
  }

  static DateTime _monday(DateTime day) =>
      DateTime(day.year, day.month, day.day - (day.weekday - DateTime.monday));

  static String _dayKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  @override
  void onClose() {
    unawaited(_authSubscription?.cancel() ?? Future<void>.value());
    _serviceRevisionWorker?.dispose();
    super.onClose();
  }
}
