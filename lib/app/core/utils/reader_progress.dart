import 'reader_stream_merge.dart';

/// Normalizes reader progress so sliders, bookmarks and chapter ranges share
/// the same inclusive/exclusive page semantics.
class ReaderProgress {
  const ReaderProgress._();

  static double scroll({required double offset, required double maxExtent}) {
    if (!offset.isFinite || !maxExtent.isFinite || maxExtent <= 0) return 0;
    return (offset / maxExtent).clamp(0.0, 1.0).toDouble();
  }

  static double page({
    required int pageIndex,
    required int pageCount,
    ReaderChapterPageRange? range,
    double fractionWithinPage = 1,
  }) {
    if (pageCount <= 0) return 0;
    final start = range?.startIndex ?? 0;
    final count = range?.pageCount ?? pageCount;
    if (count <= 0) return 0;
    final localIndex = (pageIndex - start).clamp(0, count - 1).toInt();
    final fraction = fractionWithinPage.clamp(0.0, 1.0).toDouble();
    return ((localIndex + fraction) / count).clamp(0.0, 1.0).toDouble();
  }

  static int pageAt({
    required double progress,
    required int pageCount,
    ReaderChapterPageRange? range,
  }) {
    if (pageCount <= 0) return 0;
    final start = range?.startIndex ?? 0;
    final count = range?.pageCount ?? pageCount;
    if (count <= 1) return start.clamp(0, pageCount - 1).toInt();
    final fraction = progress.isFinite
        ? progress.clamp(0.0, 1.0).toDouble()
        : 0.0;
    return (start + (fraction * (count - 1)).round())
        .clamp(0, pageCount - 1)
        .toInt();
  }
}
