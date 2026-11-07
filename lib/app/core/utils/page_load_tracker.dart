/// Tracks which pages of a chapter actually finished loading.
///
/// The percentage shown in the reader is `loaded / total`, never a scroll or
/// chapter-reading estimate. Failed pages stay failed until the reader retries
/// them, so a broken page cannot silently count as loaded.
class PageLoadTracker {
  PageLoadTracker([int total = 0]) : _total = total < 0 ? 0 : total;

  int _total;
  final Set<int> _loaded = <int>{};
  final Set<int> _failed = <int>{};

  int get total => _total;
  int get loadedCount => _loaded.length;
  int get failedCount => _failed.length;
  int get pendingCount {
    final pending = _total - _loaded.length - _failed.length;
    return pending < 0 ? 0 : pending;
  }

  bool get hasPages => _total > 0;
  bool get isComplete => _total > 0 && _loaded.length >= _total;
  double get progress =>
      _total == 0 ? 0 : (_loaded.length / _total).clamp(0.0, 1.0);

  bool isValid(int index) => index >= 0 && index < _total;
  bool isLoaded(int index) => _loaded.contains(index);
  bool isFailed(int index) => _failed.contains(index);

  void reset(int total) {
    _total = total < 0 ? 0 : total;
    _loaded.clear();
    _failed.clear();
  }

  void markLoaded(int index) {
    if (!isValid(index)) return;
    _failed.remove(index);
    _loaded.add(index);
  }

  void markFailed(int index) {
    if (!isValid(index) || _loaded.contains(index)) return;
    _failed.add(index);
  }

  void retry(int index) {
    if (!isValid(index)) return;
    _failed.remove(index);
  }

  /// Grows the page count without discarding pages already loaded. Used when a
  /// continuously scrolling reader appends a neighbouring chapter.
  void expandTo(int total) {
    final next = total < 0 ? 0 : total;
    if (next <= _total) {
      if (next < _total) reset(next);
      return;
    }
    _total = next;
  }

  /// Inserts [count] pages before the current pages, shifting loaded and failed
  /// indexes so progress keeps pointing at the same pages.
  void prepend(int count) {
    if (count <= 0) return;
    _total += count;
    _shift(_loaded, count);
    _shift(_failed, count);
  }

  static void _shift(Set<int> indexes, int count) {
    final shifted = indexes.map((index) => index + count).toList(growable: false);
    indexes
      ..clear()
      ..addAll(shifted);
  }
}
