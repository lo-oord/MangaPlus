/// The bounded page window the reader warms around the viewport.
///
/// Preloading is directional on purpose: while reading forward the reader needs
/// the next pages, and warming pages it just passed is wasted bandwidth. The
/// window is always clamped to the chapter and never exceeds the configured
/// preload distance on either side.
class ReaderPreloadWindow {
  const ReaderPreloadWindow(this.start, this.end);

  final int start;
  final int end;

  int get length => end - start + 1;

  @override
  String toString() => 'ReaderPreloadWindow($start..$end)';
}

const ReaderPreloadWindow emptyPreloadWindow = ReaderPreloadWindow(0, -1);

/// [direction] is positive when the reader is moving forward (increasing page
/// index, regardless of RTL/LTR), negative when moving backwards, and zero when
/// the direction is unknown (initial load, jump).
ReaderPreloadWindow readerPreloadWindow({
  required int firstVisible,
  required int lastVisible,
  required int total,
  required int distance,
  int direction = 0,
}) {
  if (total <= 0) return emptyPreloadWindow;
  final first = firstVisible.clamp(0, total - 1).toInt();
  final last = lastVisible.clamp(first, total - 1).toInt();
  final ahead = distance.clamp(1, 12).toInt();
  final start = direction < 0 ? first - ahead : first - 1;
  final end = direction > 0 ? last + ahead : last + 1;
  return ReaderPreloadWindow(
    start.clamp(0, total - 1).toInt(),
    end.clamp(0, total - 1).toInt(),
  );
}
