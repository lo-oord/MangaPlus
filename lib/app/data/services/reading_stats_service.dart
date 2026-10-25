import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class ReadingSessionRef {
  const ReadingSessionRef({
    required this.ownerId,
    required this.sessionId,
    required this.comicId,
    required this.chapterId,
  });

  final String ownerId;
  final String sessionId;
  final String comicId;
  final String chapterId;
}

class ReadingStatsPreferences {
  const ReadingStatsPreferences({
    this.syncEnabled = false,
    this.dailyGoalMinutes = 30,
    this.weeklyGoalMinutes = 210,
    this.weeklyGoalChapters = 0,
    this.minimumActiveDayMinutes = 1,
    this.weeklySummaryEnabled = false,
  });

  final bool syncEnabled;
  final int dailyGoalMinutes;
  final int weeklyGoalMinutes;
  final int weeklyGoalChapters;
  final int minimumActiveDayMinutes;
  final bool weeklySummaryEnabled;

  factory ReadingStatsPreferences.fromMap(Map<String, dynamic> map) =>
      ReadingStatsPreferences(
        syncEnabled: map['syncEnabled'] == true,
        dailyGoalMinutes: _boundedInt(map['dailyGoalMinutes'], 30, 5, 720),
        weeklyGoalMinutes: _boundedInt(map['weeklyGoalMinutes'], 210, 30, 10080),
        weeklyGoalChapters: _boundedInt(map['weeklyGoalChapters'], 0, 0, 1000),
        minimumActiveDayMinutes: _boundedInt(map['minimumActiveDayMinutes'], 1, 1, 120),
        weeklySummaryEnabled: map['weeklySummaryEnabled'] == true,
      );

  Map<String, dynamic> toMap() => {
        'syncEnabled': syncEnabled,
        'dailyGoalMinutes': dailyGoalMinutes,
        'weeklyGoalMinutes': weeklyGoalMinutes,
        'weeklyGoalChapters': weeklyGoalChapters,
        'minimumActiveDayMinutes': minimumActiveDayMinutes,
        'weeklySummaryEnabled': weeklySummaryEnabled,
      };

  ReadingStatsPreferences copyWith({
    bool? syncEnabled,
    int? dailyGoalMinutes,
    int? weeklyGoalMinutes,
    int? weeklyGoalChapters,
    int? minimumActiveDayMinutes,
    bool? weeklySummaryEnabled,
  }) =>
      ReadingStatsPreferences(
        syncEnabled: syncEnabled ?? this.syncEnabled,
        dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
        weeklyGoalMinutes: weeklyGoalMinutes ?? this.weeklyGoalMinutes,
        weeklyGoalChapters: weeklyGoalChapters ?? this.weeklyGoalChapters,
        minimumActiveDayMinutes: minimumActiveDayMinutes ?? this.minimumActiveDayMinutes,
        weeklySummaryEnabled: weeklySummaryEnabled ?? this.weeklySummaryEnabled,
      );
}

int _boundedInt(dynamic value, int fallback, int minimum, int maximum) {
  final parsed = value is num ? value.round() : int.tryParse('$value');
  if (parsed == null) return fallback;
  return parsed.clamp(minimum, maximum).toInt();
}

/// Stores the source-of-truth sessions in the existing GetStorage box and
/// optionally mirrors completed sessions to the current user's private Firestore
/// subtree. No session is uploaded for an anonymous or signed-out user.
class ReadingStatsService extends GetxService {
  ReadingStatsService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GetStorage _storage = GetStorage();
  final RxInt revision = 0.obs;
  final math.Random _random = math.Random.secure();
  Future<void> _writeQueue = Future<void>.value();
  final Map<String, Future<void>> _syncs = <String, Future<void>>{};

  String get currentOwnerId {
    final user = _auth.currentUser;
    return user == null || user.isAnonymous ? 'guest' : user.uid;
  }
  bool get currentUserCanSync => _canSync(currentOwnerId);

  bool _canSync(String ownerId) {
    final user = _auth.currentUser;
    return user != null &&
        user.uid == ownerId &&
        !user.isAnonymous &&
        user.emailVerified;
  }

  String _sessionsKey(String ownerId) => 'reading_stats_sessions_v1_$ownerId';
  String _preferencesKey(String ownerId) => 'reading_stats_preferences_v1_$ownerId';
  String _achievementsKey(String ownerId) => 'reading_stats_achievements_v1_$ownerId';

  DocumentReference<Map<String, dynamic>> _statsDocument(String uid) => _firestore
      .collection('userProfiles')
      .doc(uid)
      .collection('private')
      .doc('readingStats');

  CollectionReference<Map<String, dynamic>> _sessionsCollection(String uid) =>
      _statsDocument(uid).collection('sessions');

  Future<ReadingSessionRef> beginSession({
    required String comicId,
    required String sourceId,
    required String title,
    String coverImage = '',
    required String type,
    required String chapterId,
    required String chapterTitle,
  }) async {
    final ownerId = currentOwnerId;
    await recoverInterruptedSessions(ownerId: ownerId, closeAllOpenSessions: true);
    final now = DateTime.now();
    final random = _random.nextInt(0x7fffffff).toRadixString(16);
    final sessionId = '${now.toUtc().microsecondsSinceEpoch}-$random';
    final ref = ReadingSessionRef(
      ownerId: ownerId,
      sessionId: sessionId,
      comicId: comicId.trim(),
      chapterId: chapterId.trim(),
    );
    final sessions = _readSessions(ownerId);
    sessions[sessionId] = {
      'sessionId': sessionId,
      'comicId': _boundedText(comicId, 2048),
      'sourceId': _boundedText(sourceId.toLowerCase(), 128),
      'title': _boundedText(title, 200),
      'coverImage': _safeCoverReference(coverImage),
      'type': _normalizeType(type),
      'chapterId': _boundedText(chapterId, 2048),
      'chapterTitle': _boundedText(chapterTitle, 250),
      'startedAt': now.toUtc().toIso8601String(),
      'endedAt': null,
      'durationSeconds': 0,
      'dailySeconds': <String, int>{},
      'progress': 0.0,
      'chapterCompleted': false,
      'chapterCompletedDay': null,
      'updatedAt': now.toUtc().toIso8601String(),
      'syncPending': true,
    };
    await _saveSessions(ownerId, sessions);
    return ref;
  }

  Future<void> addActiveSeconds(
    ReadingSessionRef ref,
    int seconds, {
    DateTime? localTime,
  }) async {
    if (seconds <= 0) return;
    final now = localTime ?? DateTime.now();
    final day = _dayKey(now);
    await _mutateSession(ref, (session) {
      if (session['endedAt'] != null) return;
      final daily = _map(session['dailySeconds']);
      daily[day] = (_boundedInt(daily[day], 0, 0, 86400) + seconds)
          .clamp(0, 86400)
          .toInt();
      session['dailySeconds'] = daily;
      session['durationSeconds'] =
          (_boundedInt(session['durationSeconds'], 0, 0, 86400) + seconds)
              .clamp(0, 86400)
              .toInt();
      session['updatedAt'] = DateTime.now().toUtc().toIso8601String();
      session['syncPending'] = true;
    });
  }

  Future<void> recordProgress(
    ReadingSessionRef ref,
    double progress, {
    bool chapterCompleted = false,
  }) async {
    final safeProgress = progress.isFinite ? progress.clamp(0.0, 1.0) : 0.0;
    await _mutateSession(ref, (session) {
      if (session['endedAt'] != null) return;
      final previous = session['progress'] is num
          ? (session['progress'] as num).toDouble()
          : 0.0;
      session['progress'] = math.max(previous, safeProgress);
      if (chapterCompleted && session['chapterCompleted'] != true) {
        session['chapterCompleted'] = true;
        session['chapterCompletedDay'] = _dayKey(DateTime.now());
      }
      session['updatedAt'] = DateTime.now().toUtc().toIso8601String();
      session['syncPending'] = true;
    });
  }

  Future<void> finishSession(ReadingSessionRef? ref) async {
    if (ref == null) return;
    var shouldSync = false;
    await _writeLocal(() async {
      final sessions = _readSessions(ref.ownerId);
      final session = sessions[ref.sessionId];
      if (session == null || session['endedAt'] != null) return;
      final hasReading = _boundedInt(session['durationSeconds'], 0, 0, 86400) > 0 ||
          session['chapterCompleted'] == true;
      if (!hasReading) {
        sessions.remove(ref.sessionId);
        await _storage.write(_sessionsKey(ref.ownerId), sessions);
        revision.value++;
        return;
      }
      session['endedAt'] = DateTime.now().toUtc().toIso8601String();
      session['updatedAt'] = session['endedAt'];
      session['syncPending'] = true;
      await _storage.write(_sessionsKey(ref.ownerId), sessions);
      revision.value++;
      shouldSync = true;
    });
    final preferences = shouldSync ? await loadPreferences(ownerId: ref.ownerId) : null;
    if (preferences?.syncEnabled == true && _canSync(ref.ownerId)) {
      unawaited(syncOwner(ref.ownerId));
    }
  }

  Future<List<Map<String, dynamic>>> loadSessions({String? ownerId}) async {
    await _writeQueue;
    final sessions = _readSessions(ownerId ?? currentOwnerId);
    return sessions.values
        .map((value) => Map<String, dynamic>.from(value))
        .toList(growable: false);
  }

  Future<Map<String, String>> loadAchievementUnlocks({String? ownerId}) async {
    await _writeQueue;
    final raw = _storage.read(_achievementsKey(ownerId ?? currentOwnerId));
    if (raw is! Map) return <String, String>{};
    return raw.map((key, value) => MapEntry('$key', '$value'));
  }

  Future<void> saveAchievementUnlocks(
    Map<String, String> unlocks, {
    String? ownerId,
  }) =>
      _writeLocal(() async {
        await _storage.write(
          _achievementsKey(ownerId ?? currentOwnerId),
          Map<String, String>.from(unlocks),
        );
        revision.value++;
      });

  Future<void> recoverInterruptedSessions({
    String? ownerId,
    bool closeAllOpenSessions = false,
  }) async {
    final owner = ownerId ?? currentOwnerId;
    final staleBefore = DateTime.now().subtract(const Duration(minutes: 10));
    await _writeLocal(() async {
      final sessions = _readSessions(owner);
      var changed = false;
      for (final entry in sessions.entries.toList(growable: false)) {
        final session = entry.value as Map<String, dynamic>;
        if (session['endedAt'] != null) continue;
        final lastSaved = DateTime.tryParse(
              '${session['updatedAt'] ?? session['startedAt'] ?? ''}',
            )?.toLocal() ??
            DateTime.now();
        if (!closeAllOpenSessions && !lastSaved.isBefore(staleBefore)) continue;
        final hasReading = _boundedInt(session['durationSeconds'], 0, 0, 86400) > 0 ||
            session['chapterCompleted'] == true;
        if (!hasReading) {
          sessions.remove(entry.key);
          changed = true;
          continue;
        }
        final endedAt = lastSaved.toUtc().toIso8601String();
        session['endedAt'] = endedAt;
        session['updatedAt'] = endedAt;
        session['syncPending'] = true;
        changed = true;
      }
      if (changed) {
        await _storage.write(_sessionsKey(owner), sessions);
        revision.value++;
      }
    });
  }

  Future<ReadingStatsPreferences> loadPreferences({String? ownerId}) async {
    final owner = ownerId ?? currentOwnerId;
    final key = _preferencesKey(owner);
    final stored = _storage.read(key);
    if (stored is Map) {
      return ReadingStatsPreferences.fromMap(Map<String, dynamic>.from(stored));
    }
    if (_canSync(owner)) {
      try {
        final remote = await _statsDocument(owner).get();
        if (remote.exists) {
          final prefs = ReadingStatsPreferences.fromMap(remote.data() ?? {});
          await _storage.write(key, prefs.toMap());
          return prefs;
        }
      } catch (_) {
        // Offline users retain safe local defaults until the next refresh.
      }
    }
    return const ReadingStatsPreferences();
  }

  Future<void> savePreferences(
    ReadingStatsPreferences preferences, {
    String? ownerId,
  }) async {
    final owner = ownerId ?? currentOwnerId;
    final safe = ReadingStatsPreferences.fromMap(preferences.toMap());
    await _storage.write(_preferencesKey(owner), safe.toMap());
    revision.value++;
    if (_canSync(owner)) {
      try {
        await _statsDocument(owner).set({
          ...safe.toMap(),
          'schemaVersion': 1,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {
        // Local preference is authoritative for this device; retry on next load.
      }
    }
    if (safe.syncEnabled && _canSync(owner)) {
      unawaited(syncOwner(owner));
    }
  }

  Future<void> syncOwner(String ownerId) {
    if (!_canSync(ownerId)) return Future<void>.value();
    final active = _syncs[ownerId];
    if (active != null) return active;
    final operation = _syncOwner(ownerId);
    _syncs[ownerId] = operation;
    return operation.whenComplete(() {
      if (identical(_syncs[ownerId], operation)) _syncs.remove(ownerId);
    });
  }

  Future<void> _syncOwner(String ownerId) async {
    final preferences = await loadPreferences(ownerId: ownerId);
    if (!preferences.syncEnabled || !_canSync(ownerId)) return;
    final remote = await _readRemoteSessions(ownerId);
    final local = _readSessions(ownerId);
    for (final entry in remote.entries) {
      final existing = local[entry.key];
      local[entry.key] = existing == null
          ? {...entry.value, 'syncPending': false}
          : _mergeSession(existing, entry.value);
    }
    if (_auth.currentUser?.uid != ownerId) return;
    await _saveSessions(ownerId, local);

    final pending = local.entries.where((entry) {
      final session = entry.value;
      return session['syncPending'] != false &&
          session['endedAt'] != null &&
          (_boundedInt(session['durationSeconds'], 0, 0, 86400) > 0 ||
              session['chapterCompleted'] == true);
    }).toList(growable: false);
    for (var offset = 0; offset < pending.length; offset += 400) {
      if (!_canSync(ownerId)) return;
      final chunk = pending.skip(offset).take(400).toList(growable: false);
      final batch = _firestore.batch();
      for (final entry in chunk) {
        batch.set(
          _sessionsCollection(ownerId).doc(entry.key),
          _toCloudMap(entry.value),
          SetOptions(merge: true),
        );
      }
      await batch.commit();
      for (final entry in chunk) {
        final current = local[entry.key];
        if (current != null) current['syncPending'] = false;
      }
      await _saveSessions(ownerId, local);
    }
  }

  Future<Map<String, Map<String, dynamic>>> _readRemoteSessions(String ownerId) async {
    final result = <String, Map<String, dynamic>>{};
    Query<Map<String, dynamic>> query = _sessionsCollection(ownerId)
        .orderBy(FieldPath.documentId)
        .limit(250);
    while (_canSync(ownerId)) {
      final snapshot = await query.get();
      if (snapshot.docs.isEmpty) break;
      for (final document in snapshot.docs) {
        result[document.id] = _fromCloudMap(document.id, document.data());
      }
      if (snapshot.docs.length < 250) break;
      query = _sessionsCollection(ownerId)
          .orderBy(FieldPath.documentId)
          .startAfterDocument(snapshot.docs.last)
          .limit(250);
    }
    return result;
  }

  Future<void> resetSessions({
    required String ownerId,
    required bool deleteCloudData,
  }) async {
    if (deleteCloudData && _canSync(ownerId)) {
      await _deleteRemoteSessions(ownerId);
    }
    await _writeLocal(() async {
      await _storage.write(_sessionsKey(ownerId), <String, dynamic>{});
      await _storage.write(_achievementsKey(ownerId), <String, String>{});
      revision.value++;
    });
  }

  /// Preserve device-local guest data only when Firebase upgrades the same
  /// anonymous UID. Signing in to another UID must never inherit guest history.
  Future<void> promoteGuestDataToAccount(String uid) async {
    if (!_canSync(uid)) return;
    await _writeLocal(() async {
      final guest = _readSessions('guest');
      if (guest.isNotEmpty) {
        final account = _readSessions(uid);
        for (final entry in guest.entries) {
          final existing = account[entry.key];
          account[entry.key] = existing == null
              ? Map<String, dynamic>.from(entry.value)
              : _mergeSession(existing, entry.value);
        }
        await _storage.write(_sessionsKey(uid), account);
        await _storage.write(_sessionsKey('guest'), <String, dynamic>{});
      }
      if (!_storage.hasData(_preferencesKey(uid)) &&
          _storage.hasData(_preferencesKey('guest'))) {
        final guestPreferences = _storage.read(_preferencesKey('guest'));
        if (guestPreferences is Map) {
          await _storage.write(_preferencesKey(uid), Map<String, dynamic>.from(guestPreferences));
        }
      }
      final guestAchievements = _storage.read(_achievementsKey('guest'));
      if (guestAchievements is Map) {
        final accountAchievements = _storage.read(_achievementsKey(uid));
        final mergedAchievements = <String, String>{
          if (accountAchievements is Map)
            ...accountAchievements.map((key, value) => MapEntry('$key', '$value')),
          ...guestAchievements.map((key, value) => MapEntry('$key', '$value')),
        };
        await _storage.write(_achievementsKey(uid), mergedAchievements);
        await _storage.write(_achievementsKey('guest'), <String, String>{});
      }
      revision.value++;
    });
  }

  Future<void> _deleteRemoteSessions(String ownerId) async {
    while (_canSync(ownerId)) {
      final snapshot = await _sessionsCollection(ownerId).limit(400).get();
      if (snapshot.docs.isEmpty) return;
      final batch = _firestore.batch();
      for (final document in snapshot.docs) {
        batch.delete(document.reference);
      }
      await batch.commit();
    }
  }

  Future<void> _mutateSession(
    ReadingSessionRef ref,
    void Function(Map<String, dynamic>) update,
  ) =>
      _writeLocal(() async {
        final sessions = _readSessions(ref.ownerId);
        final current = sessions[ref.sessionId];
        if (current == null) return;
        update(current);
        await _storage.write(_sessionsKey(ref.ownerId), sessions);
        revision.value++;
      });

  Future<void> _saveSessions(String ownerId, Map<String, dynamic> sessions) =>
      _writeLocal(() async {
        await _storage.write(_sessionsKey(ownerId), sessions);
        revision.value++;
      });

  Future<void> _writeLocal(Future<void> Function() operation) {
    final next = _writeQueue.then((_) => operation());
    _writeQueue = next.catchError((Object _) {});
    return next;
  }

  Map<String, dynamic> _readSessions(String ownerId) {
    final raw = _storage.read(_sessionsKey(ownerId));
    if (raw is! Map) return <String, dynamic>{};
    return raw.map((key, value) => MapEntry(
          '$key',
          value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{},
        ));
  }

  Map<String, dynamic> _mergeSession(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    final merged = <String, dynamic>{...remote, ...local};
    for (final key in ['comicId', 'sourceId', 'title', 'coverImage', 'chapterId', 'chapterTitle']) {
      if ('${merged[key] ?? ''}'.trim().isEmpty) merged[key] = remote[key] ?? local[key] ?? '';
    }
    final localSeconds = _boundedInt(local['durationSeconds'], 0, 0, 86400);
    final remoteSeconds = _boundedInt(remote['durationSeconds'], 0, 0, 86400);
    merged['durationSeconds'] = math.max(localSeconds, remoteSeconds);
    merged['dailySeconds'] = _mergeDailySeconds(
      _map(local['dailySeconds']),
      _map(remote['dailySeconds']),
    );
    merged['progress'] = math.max(
      local['progress'] is num ? (local['progress'] as num).toDouble() : 0.0,
      remote['progress'] is num ? (remote['progress'] as num).toDouble() : 0.0,
    );
    merged['chapterCompleted'] =
        local['chapterCompleted'] == true || remote['chapterCompleted'] == true;
    merged['chapterCompletedDay'] =
        local['chapterCompletedDay'] ?? remote['chapterCompletedDay'];
    merged['endedAt'] = local['endedAt'] ?? remote['endedAt'];
    merged['syncPending'] = local['syncPending'] == true;
    return merged;
  }

  Map<String, dynamic> _mergeDailySeconds(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    final result = <String, dynamic>{...remote};
    for (final entry in local.entries) {
      result[entry.key] = math.max(
        _boundedInt(entry.value, 0, 0, 86400),
        _boundedInt(result[entry.key], 0, 0, 86400),
      );
    }
    return result;
  }

  Map<String, dynamic> _toCloudMap(Map<String, dynamic> session) {
    DateTime parse(String key) =>
        DateTime.tryParse('${session[key] ?? ''}')?.toUtc() ?? DateTime.now().toUtc();
    return {
      'sessionId': '${session['sessionId'] ?? ''}',
      'comicId': _boundedText(session['comicId'], 2048),
      'sourceId': _boundedText(session['sourceId'], 128),
      'title': _boundedText(session['title'], 200),
      'coverImage': _safeCoverReference(session['coverImage']),
      'type': _normalizeType('${session['type'] ?? ''}'),
      'chapterId': _boundedText(session['chapterId'], 2048),
      'chapterTitle': _boundedText(session['chapterTitle'], 250),
      'startedAt': Timestamp.fromDate(parse('startedAt')),
      'endedAt': Timestamp.fromDate(parse('endedAt')),
      'durationSeconds': _boundedInt(session['durationSeconds'], 0, 0, 86400),
      'dailySeconds': _mergeDailySeconds(_map(session['dailySeconds']), const {}),
      'progress': session['progress'] is num
          ? (session['progress'] as num).toDouble().clamp(0.0, 1.0)
          : 0.0,
      'chapterCompleted': session['chapterCompleted'] == true,
      'chapterCompletedDay': session['chapterCompletedDay'],
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> _fromCloudMap(String id, Map<String, dynamic> data) {
    DateTime? date(dynamic value) {
      if (value is Timestamp) return value.toDate().toUtc();
      if (value is DateTime) return value.toUtc();
      return DateTime.tryParse('$value')?.toUtc();
    }

    final daily = _map(data['dailySeconds']).map((key, value) =>
        MapEntry(key, _boundedInt(value, 0, 0, 86400)));
    return {
      'sessionId': id,
      'comicId': '${data['comicId'] ?? ''}',
      'sourceId': '${data['sourceId'] ?? ''}',
      'title': '${data['title'] ?? 'عمل محفوظ سابقًا'}',
      'coverImage': _safeCoverReference(data['coverImage']),
      'type': _normalizeType('${data['type'] ?? 'other'}'),
      'chapterId': '${data['chapterId'] ?? ''}',
      'chapterTitle': '${data['chapterTitle'] ?? ''}',
      'startedAt': date(data['startedAt'])?.toIso8601String(),
      'endedAt': date(data['endedAt'])?.toIso8601String(),
      'durationSeconds': _boundedInt(data['durationSeconds'], 0, 0, 86400),
      'dailySeconds': daily,
      'progress': data['progress'] is num
          ? (data['progress'] as num).toDouble().clamp(0.0, 1.0)
          : 0.0,
      'chapterCompleted': data['chapterCompleted'] == true,
      'chapterCompletedDay': data['chapterCompletedDay'],
      'updatedAt': date(data['updatedAt'])?.toIso8601String(),
      'syncPending': false,
    };
  }

  String _safeCoverReference(dynamic value) {
    final text = _boundedText(value, 2048);
    final uri = Uri.tryParse(text);
    if (uri == null || uri.host.isEmpty || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return '';
    }
    return text;
  }

  Map<String, dynamic> _map(dynamic value) => value is Map
      ? value.map((key, item) => MapEntry('$key', item))
      : <String, dynamic>{};

  String _boundedText(dynamic value, int maximum) {
    final text = '${value ?? ''}'.trim();
    return text.length <= maximum ? text : text.substring(0, maximum);
  }

  String _normalizeType(String value) {
    final text = value.trim().toLowerCase();
    if (text.contains('novel') || text.contains('روا')) return 'novel';
    if (text.contains('manhwa') || text.contains('مانهوا')) return 'manhwa';
    if (text.contains('manhua') || text.contains('chinese')) return 'manhua';
    if (text.contains('manga') || text.contains('مانجا')) return 'manga';
    return 'other';
  }

  String _dayKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
