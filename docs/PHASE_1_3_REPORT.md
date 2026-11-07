# MangaPlus: Phase 1–3 Delivery Report

Environment: Flutter 3.27.1 (the version pinned by CI), Dart from that SDK, no
Android SDK/JDK in the delivery VM.

## Verification summary

| Check | Result |
| --- | --- |
| `flutter analyze` | No issues found |
| `flutter test` | 150 tests passed |
| `flutter test --coverage` | 2,766 / 15,235 lines = 18.2% (whole `lib`, including UI) |
| Source contract tests | 19 registered sources, all resolve their own links |
| Live source probe (`test_live/`, not part of CI) | 69 passed, 1 skipped, 26 failed |
| `flutter build apk --debug` | Blocked: `No Android SDK found` (no JDK, no `sudo` to install one) |
| `flutter build apk --release` | Not attempted after the debug blocker |

The live probe is a network probe, separate from `test/`. Its failures are
source-side HTTP rejections, not Dart exceptions from the app model:

| Source | Live result |
| --- | --- |
| Team X, Manga Swat, Manga Time, Manga Online, Lava Scans, MKNOV, Kawaii Manga, Kawaii Novels, Cenele Manga, Cenele Novels, KolNovel, SeaNovel | latest/search/details/reader passed |
| MangaTek | feed/details passed, reader blocked (HTTP 403) |
| Mangasid | HTTP 403 on the page request; dependent probes cascade |
| MangaDar | HTTP 403 on the page request; dependent probes cascade |
| Hijala | HTTP 403 on the page request; dependent probes cascade |
| ProComic | HTTP 403 on the page request |
| Asgard Scans | HTTP 404 (site route unavailable) |

`LateInitializationError` entries in the probe are cascades: a test skips when
its feed fixture is missing, and later probes reuse that uninitialized local.
They are probe-harness behaviour, not app state leaks. No source was removed,
and no protection/Cloudflare rule was bypassed to force a pass.

## Phase 1: metadata and chapter selection

- `SourceValues` normalizes covers (`cover`, `cover_image`, `thumbnail`,
  `data-src`, `data-original`, `srcset`, relative/protocol-relative URLs,
  nested maps), status (English, Arabic, decorated), canonical content types,
  ratings, years, and unique chapter counts.
- `ComicService.mapComicItem` / `mapComicDetail` keep id, link and cover
  separate; `ComicDetail.mergedWith` never overwrites known values with empty
  ones; chapter lists are deduplicated by identity.
- Chapter selection root cause: the selected state lived in an `RxList` read by
  the counter and the sticky bar, while lazy `SliverList` rows were built
  outside an `Obx` and captured a stale snapshot. Tapping three rows updated
  the queue but only the first row painted its check.
- Fix: `ChapterSelection` (id-keyed store) plus `selectionRevision`, an `Obx`
  per row and a stable `ValueKey(comicId|chapterId)`. Counter, checkmarks,
  select-all and the download queue now read the same unique-id set. Empty
  ids are ignored; reordering and scrolling cannot move selection between rows.
- Tests: `chapter_selection_test.dart` covers 1, 3 and all chapters, deselect,
  clear, scrolling, rebuilds, reordering, duplicate ids across works, and
  counter/queue parity. `metadata_normalization_test.dart` and
  `metadata_regression_test.dart` cover metadata aliases and merge behaviour.

## Phase 2: reader

- `ChapterSequence` replaces title-number guessing. It deduplicates by id/url,
  detects oldest-first vs newest-first lists, steps exactly one source row, and
  uses source-declared neighbours only when the current chapter is not listed.
  Numbers are a last resort; Arabic-Indic digits, Arabic ordinals, decimals,
  `Special`/`Extra`, padded numbers and unnumbered lists are handled.
- Rapid taps remain guarded by `isNavigating`; failed transitions restore the
  previous chapter, page, images, offline flag and scroll offset.
- Page-load progress is real: `PageLoadTracker` counts successfully rendered
  pages over the known total. Failures are excluded until retried. The
  translucent chip never takes pointer input, appears for a new chapter,
  hides when complete or after a short delay, and shows no invented percentage
  when the page count is unknown.
- Failed pages now retry that page (new image key/token) instead of reloading
  the whole chapter; stale callbacks are ignored by comparing the page URL.
- Tests: `chapter_sequence_test.dart` (13), `page_load_tracker_test.dart` (8),
  plus the existing reader navigator, stream-merge and reader-preference tests.

## Phase 3: polish and limits

- Details page: small status pill (ongoing/completed/hiatus/cancelled colours,
  no misleading default), branded cover placeholder instead of a flat block.
  Layout, order and identity are unchanged; synopsis expansion and metadata
  were already present.
- Localization: `release_validation_test.dart` still asserts that every Arabic
  key has a non-blank English translation; no new raw keys were introduced.
- Loader: determinate progress needs no animation ticker and reduced motion is
  honoured (existing tests pass).
- Downloads rely on the Phase 1 unique-id selection; duplicate queueing is
  still rejected by the download manager.
- Not verified in this environment: APK debug/release builds, real-device
  rendering, and live source availability from a non-blocked network.
