/// The reading presets the manga reader exposes.
///
/// Webtoon is deliberately *not* a separate rendering engine: it is the
/// continuous scroll list with full-width pages, no gaps and no double spreads.
/// Keeping the rule in one pure function means the tools sheet, the reader and
/// the tests all agree on what "webtoon" means.
bool readerIsWebtoonPreset({
  required bool isNovel,
  required String mode,
  required String fit,
  required double gap,
  required bool doublePage,
}) =>
    !isNovel && mode == 'scroll' && fit == 'width' && gap <= .5 && !doublePage;
