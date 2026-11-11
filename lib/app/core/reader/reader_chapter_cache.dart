import 'dart:async';
import 'dart:collection';

import 'package:mangaplus/app/data/models/chapter.dart';

/// The lifecycle of a chapter inside the reader.
enum ReaderChapterStatus {
  /// No content yet; the chapter is being fetched.
  loading,

  /// Content came from the source and is complete.
  ready,

  /// Content came from the in-memory chapter cache.
  cached,

  /// Content came from the offline library and every page was verified.
  offline,

  /// The fetch failed. The reader may still show the previous chapter.
  failed,

  /// The source answered but had no readable content.
  unavailable,
}

class ReaderChapterSnapshot {
  const ReaderChapterSnapshot({
    required this.chapterId,
    required this.data,
    required this.status,
    this.error,
  });

  final String chapterId;
  final ChapterData data;
  final ReaderChapterStatus status;
  final Object? error;

  bool get isUsable =>
      data.chapter.images.isNotEmpty || data.chapter.content.trim().isNotEmpty;

  ReaderChapterSnapshot copyWith({
    ChapterData? data,
    ReaderChapterStatus? status,
    Object? error,
  }) =>
      ReaderChapterSnapshot(
        chapterId: chapterId,
        data: data ?? this.data,
        status: status ?? this.status,
        error: error ?? this.error,
      );
}

/// A small LRU of loaded chapters with in-flight request deduplication.
///
/// The important behaviour change is that prefetching a chapter *returns the
/// running future* instead of `null` when a prefetch is already in flight. The
/// previous reader treated that `null` as "nothing was loaded" and merged the
/// chapter that was already on screen, which duplicated pages and made
/// previous/next navigation jump.
class ReaderChapterCache {
  ReaderChapterCache({
    required this.loader,
    this.capacity = 4,
  }) : assert(capacity > 0);

  final Future<ReaderChapterSnapshot> Function(String chapterId) loader;
  final int capacity;

  final LinkedHashMap<String, ReaderChapterSnapshot> _entries =
      LinkedHashMap<String, ReaderChapterSnapshot>();
  final Map<String, Future<ReaderChapterSnapshot>> _inFlight =
      <String, Future<ReaderChapterSnapshot>>{};
  bool _disposed = false;

  int get length => _entries.length;

  List<String> get cachedChapterIds =>
      List<String>.unmodifiable(_entries.keys.toList(growable: false));

  ReaderChapterSnapshot? peek(String chapterId) => _entries[chapterId.trim()];

  bool isCached(String chapterId) => _entries.containsKey(chapterId.trim());

  bool isInFlight(String chapterId) => _inFlight.containsKey(chapterId.trim());

  Future<ReaderChapterSnapshot> load(
    String chapterId, {
    bool forceReload = false,
  }) {
    final key = chapterId.trim();
    if (key.isEmpty) {
      return Future<ReaderChapterSnapshot>.error(
        StateError('chapter reference is empty'),
      );
    }
    if (_disposed) {
      return Future<ReaderChapterSnapshot>.error(
        StateError('reader chapter cache was disposed'),
      );
    }
    if (!forceReload) {
      final cached = _entries.remove(key);
      if (cached != null) {
        // Re-insert to mark it as recently used.
        _entries[key] = cached;
        return Future<ReaderChapterSnapshot>.value(cached);
      }
      final running = _inFlight[key];
      if (running != null) return running;
    }
    late final Future<ReaderChapterSnapshot> request;
    request = loader(key).then((snapshot) {
      if (snapshot.isUsable && snapshot.status != ReaderChapterStatus.failed) {
        _store(key, snapshot);
      }
      return snapshot;
    }).whenComplete(() {
      if (identical(_inFlight[key], request)) _inFlight.remove(key);
    });
    _inFlight[key] = request;
    return request;
  }

  /// Loads [chapterId] without waiting: the future is returned so a later
  /// navigation can reuse it instead of starting a second request.
  Future<ReaderChapterSnapshot> prefetch(String chapterId) => load(chapterId);

  void evict(String chapterId) => _entries.remove(chapterId.trim());

  void clear() {
    _entries.clear();
    _inFlight.clear();
  }

  void dispose() {
    _disposed = true;
    clear();
  }

  void _store(String key, ReaderChapterSnapshot snapshot) {
    _entries.remove(key);
    _entries[key] = snapshot;
    while (_entries.length > capacity) {
      _entries.remove(_entries.keys.first);
    }
  }
}
