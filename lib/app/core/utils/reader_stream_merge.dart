class ReaderChapterPageRange {
  final String chapterId;
  final int startIndex;
  final int pageCount;

  const ReaderChapterPageRange({
    required this.chapterId,
    required this.startIndex,
    required this.pageCount,
  });

  int get endIndex => startIndex + pageCount;

  bool contains(int pageIndex) =>
      pageIndex >= startIndex && pageIndex < endIndex;
}

class ReaderStreamMerge {
  final List<String> pages;
  final int currentPage;
  final List<ReaderChapterPageRange> chapterRanges;

  const ReaderStreamMerge({
    required this.pages,
    required this.currentPage,
    required this.chapterRanges,
  });
}

ReaderStreamMerge mergeReaderStreamPages({
  required List<String> currentPages,
  required List<String> adjacentPages,
  required List<ReaderChapterPageRange> currentRanges,
  required String adjacentChapterId,
  required int currentPage,
  required bool prepend,
  required bool pagedReader,
}) {
  final pages = prepend
      ? <String>[...adjacentPages, ...currentPages]
      : <String>[...currentPages, ...adjacentPages];
  final adjacentRange = ReaderChapterPageRange(
    chapterId: adjacentChapterId,
    startIndex: prepend ? 0 : currentPages.length,
    pageCount: adjacentPages.length,
  );
  final chapterRanges = prepend
      ? <ReaderChapterPageRange>[
          adjacentRange,
          ...currentRanges.map((range) => ReaderChapterPageRange(
                chapterId: range.chapterId,
                startIndex: range.startIndex + adjacentPages.length,
                pageCount: range.pageCount,
              )),
        ]
      : <ReaderChapterPageRange>[...currentRanges, adjacentRange];

  final nextPage = prepend
      ? (pagedReader
          ? adjacentPages.length - 1
          : currentPage + adjacentPages.length)
      : (pagedReader ? currentPages.length : currentPage);

  return ReaderStreamMerge(
    pages: List<String>.unmodifiable(pages),
    currentPage: pages.isEmpty ? 0 : nextPage.clamp(0, pages.length - 1).toInt(),
    chapterRanges: List<ReaderChapterPageRange>.unmodifiable(chapterRanges),
  );
}
