import 'dart:async';

/// Why an image is being requested. The reader always serves what the user is
/// looking at before warming anything else.
enum ReaderImagePriority {
  /// Pages currently on screen.
  visible(0),

  /// Pages immediately before/after the viewport.
  near(1),

  /// First pages of the adjacent chapter.
  adjacent(2),

  /// Low priority warm-up.
  background(3);

  const ReaderImagePriority(this.rank);

  final int rank;
}

class _PendingImageRequest {
  _PendingImageRequest({
    required this.url,
    required this.priority,
    required this.sequence,
  });

  final String url;
  ReaderImagePriority priority;
  final int sequence;
}

/// A small, bounded priority queue for warming page images.
///
/// It exists because calling `precacheImage` for every page of the chapter (and
/// then for the whole adjacent chapter) launched dozens of parallel decodes.
/// That is how a "smooth" reader ends up stuttering and how low-memory devices
/// end up killing the app.
///
/// Guarantees:
///  * one request per URL at a time (deduplication),
///  * at most [maxConcurrent] loads in flight,
///  * visible pages are served before prefetches,
///  * failures retry a bounded number of times with a delay,
///  * pending requests can be cancelled when the reader moves on,
///  * in-flight requests are never cancelled, because another widget may be
///    waiting for the same image.
class ReaderImagePipeline {
  ReaderImagePipeline({
    required this.loader,
    this.maxConcurrent = 3,
    this.maxAttempts = 3,
    this.retryDelay = const Duration(milliseconds: 450),
    this.completedCapacity = 900,
    this.onError,
  })  : assert(maxConcurrent > 0),
        assert(maxAttempts > 0);

  /// Resolves (and therefore caches) one image. Throw to trigger a retry.
  final Future<void> Function(String url) loader;
  final int maxConcurrent;
  final int maxAttempts;
  final Duration retryDelay;
  final int completedCapacity;
  final void Function(String url, Object error)? onError;

  final List<_PendingImageRequest> _pending = <_PendingImageRequest>[];
  final Set<String> _queued = <String>{};
  final Set<String> _active = <String>{};
  final Set<String> _completed = <String>{};
  final Set<String> _failed = <String>{};
  int _sequence = 0;
  bool _disposed = false;
  Completer<void>? _idle;

  int get pendingCount => _pending.length;
  int get activeCount => _active.length;
  bool isQueued(String url) => _queued.contains(url);
  bool isActive(String url) => _active.contains(url);
  bool isCompleted(String url) => _completed.contains(url);
  bool isFailed(String url) => _failed.contains(url);

  /// Starts warming [url] unless it is already queued, active or done.
  void request(String url,
      {ReaderImagePriority priority = ReaderImagePriority.near}) {
    final reference = url.trim();
    if (reference.isEmpty || _disposed) return;
    if (_completed.contains(reference) || _active.contains(reference)) return;
    if (_queued.contains(reference)) {
      final entry = _pending.firstWhere(
        (item) => item.url == reference,
        orElse: () => _PendingImageRequest(
          url: reference,
          priority: priority,
          sequence: _sequence++,
        ),
      );
      entry.priority = priority;
      _pending.sort(_compare);
      return;
    }
    _queued.add(reference);
    _failed.remove(reference);
    _pending.add(_PendingImageRequest(
      url: reference,
      priority: priority,
      sequence: _sequence++,
    ));
    _pump();
  }

  /// Raises the priority of a page that scrolled into view while queued.
  void prioritize(String url,
      {ReaderImagePriority priority = ReaderImagePriority.visible}) {
    final reference = url.trim();
    if (reference.isEmpty) return;
    for (final entry in _pending) {
      if (entry.url == reference) {
        entry.priority = priority;
        break;
      }
    }
    _pending.sort(_compare);
    _pump();
  }

  /// Drops a pending request. In-flight work is left alone on purpose.
  void cancel(String url) {
    final reference = url.trim();
    if (!_queued.remove(reference)) return;
    _pending.removeWhere((entry) => entry.url == reference);
    _notifyIdleIfNeeded();
  }

  void cancelWhere(bool Function(String url) test) {
    _pending.removeWhere((entry) {
      if (!test(entry.url)) return false;
      _queued.remove(entry.url);
      return true;
    });
    _notifyIdleIfNeeded();
  }

  void forget(String url) {
    _completed.remove(url.trim());
    _failed.remove(url.trim());
  }

  void clearCompleted() {
    _completed.clear();
    _failed.clear();
  }

  /// Completes when nothing is queued or running.
  Future<void> get whenIdle {
    if (_pending.isEmpty && _active.isEmpty) return Future<void>.value();
    return (_idle ??= Completer<void>()).future;
  }

  void dispose() {
    _disposed = true;
    _pending.clear();
    _queued.clear();
    _notifyIdleIfNeeded();
  }

  int _compare(_PendingImageRequest left, _PendingImageRequest right) {
    final byPriority = left.priority.rank.compareTo(right.priority.rank);
    if (byPriority != 0) return byPriority;
    return left.sequence.compareTo(right.sequence);
  }

  void _pump() {
    if (_disposed) return;
    while (_active.length < maxConcurrent && _pending.isNotEmpty) {
      _pending.sort(_compare);
      final next = _pending.removeAt(0);
      _queued.remove(next.url);
      if (_completed.contains(next.url)) continue;
      _active.add(next.url);
      unawaited(_run(next.url));
    }
    _notifyIdleIfNeeded();
  }

  Future<void> _run(String url) async {
    Object? lastError;
    try {
      for (var attempt = 1; attempt <= maxAttempts; attempt++) {
        if (_disposed) return;
        try {
          await loader(url);
          _completed.add(url);
          if (_completed.length > completedCapacity) {
            _completed.remove(_completed.first);
          }
          _failed.remove(url);
          return;
        } catch (error) {
          lastError = error;
          if (attempt >= maxAttempts) break;
          await Future<void>.delayed(retryDelay * attempt);
        }
      }
      _failed.add(url);
      onError?.call(url, lastError ?? StateError('image load failed'));
    } finally {
      _active.remove(url);
      if (!_disposed) _pump();
      _notifyIdleIfNeeded();
    }
  }

  void _notifyIdleIfNeeded() {
    if (_pending.isNotEmpty || _active.isNotEmpty) return;
    final idle = _idle;
    _idle = null;
    if (idle != null && !idle.isCompleted) idle.complete();
  }
}
