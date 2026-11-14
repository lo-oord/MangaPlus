# MangaPlus — Phase 1 Performance & Stability Report

Phase 1 of three. Scope: runtime performance, memory, rebuilds, image decoding,
reader/TTS responsiveness, persistence, background work, lifecycle. No visual,
theme, navigation or state-management redesign.

Environment used for validation: Flutter 3.27.1 / Dart 3.6.0 (the CI-pinned
SDK), Linux x64 VM, no JDK and no Android SDK. See **G. Build Status**.

---

## A. Completed fixes

| # | Problem (verified in source) | Fix |
|---|---|---|
| 1 | Reader pages decoded at a fixed screen width; a 1:15 webtoon strip therefore allocated ~86 MB per page | `readerPageDecodeSize()` sizes the decode box from the measured aspect ratio, a decoded-pixel budget (8 MP) and an absolute height ceiling (20 000 px); a still-unmeasured page gets a bounded probe height that self-heals when the 96 px probe arrives |
| 2 | `ReaderMangaPage` only passed `maxWidth` to the provider | Provider now forwards `maxHeight` to both `ResizeImage` and `CachedNetworkImageProvider` |
| 3 | Reader body `Obx` read `currentPage`, so every page turn rebuilt the whole page list | `_ensureScrollIndex` no longer reads `currentPage`; the anchor is derived from the live scroll offset instead |
| 4 | `_buildNovel` read speech state, so every spoken word rebuilt the paragraph list | Speech highlighting moved into a leaf `_NovelParagraph` widget with its own `Obx` |
| 5 | Speech following and auto-scroll ran as build side effects (every build queued a post-frame callback) | Moved to `ever()` workers created in `initState` and disposed with the state |
| 6 | `_paragraphKeys` kept a `GlobalKey` per visited paragraph forever, across chapters | Pruned to an anchor window (±80/+320) once the map grows past 400 entries; cleared in `dispose` |
| 7 | `syncPageController` post-frame callback re-queued on every paged-reader rebuild | Guarded so at most one sync is pending |
| 8 | `ChapterController get c => Get.find(...)` ran dozens of times per build/frame | Resolved once into a `late final` field |
| 9 | Reading position rewrote the entire `readerPositions` map on every page change | 700 ms trailing debounce, identical-write suppression, and a flush on `onClose` and on app lifecycle pause |
| 10 | In-chapter novel search scanned/lowercased a whole chapter on the UI isolate | Moved to `compute()`; results are dropped if a newer query started meanwhile |
| 11 | Only the Home tab was kept alive; the other three were disposed on every swipe | All four destinations wrapped in the existing `_KeepAlivePage` |
| 12 | `_ChapterList` re-filtered and re-sorted the catalogue on every reactive rebuild | Derived list memoized on chapters identity/length, filter, sort direction, query and the read/download/history revisions |
| 13 | Covers decoded at full resolution for 34–85 px thumbnails | Explicit `memCacheWidth` (plus `maxWidthDiskCache`) on detail, history, download, notifications and local-library covers |
| 14 | `imageCache` byte budget was the engine default (~100 items / 100 MB, size-driven) | Explicit 96 MB / 300 entries so a displayed reader page is not evicted by a screen of covers |
| 15 | Unused import warning in `reader_tools_sheet.dart` | Removed (analyzer 30 → 29 issues) |

## B. Files modified

- `lib/app/core/reader/reader_page_geometry.dart` — decode budget helper + constants.
- `lib/app/core/reader/reader_image_source.dart` — `maxHeight` plumbing.
- `lib/app/modules/chapter/widgets/reader_manga_page.dart` — `pageSize` input, decode box, provider args.
- `lib/app/modules/chapter/views/chapter_view.dart` — anchor without `currentPage`, leaf paragraph widget, workers for speech/auto-scroll, key pruning, single pending page sync, cached controller, `pageSize` passed to both readers.
- `lib/app/modules/chapter/controllers/chapter_controller.dart` — debounced position writes + flush, throttled search on `compute()`.
- `lib/app/modules/chapter/widgets/reader_tools_sheet.dart` — unused import removed.
- `lib/app/modules/main/views/main_view.dart` — keep-alive for Search, Bookmarks, Profile.
- `lib/app/modules/comic_detail/views/comic_detail_view.dart` — memoized chapter derivation, cover decode sizes.
- `lib/app/modules/{history,download,notifications,local_library}/views/*.dart` — cover decode sizes.
- `lib/main.dart` — explicit image cache budget.
- `test/reader_decode_size_test.dart` — 8 new regression tests.

## C. Memory improvements

- **Decode box, not a crop.** Long pages keep their aspect ratio: the helper
  computes `width = min(viewport·dpr·quality, nativeWidth, √(budget/aspect),
  ceiling/aspect)`. Ordinary pages keep exactly the previous width (1200 px at
  400 × dpr 3), so sharpness is unchanged; only strips whose bitmap would exceed
  the budget are downsampled, and they stay ≥ ~700 px wide at 1:15 (still above
  the native width of most strip sources).
- **No arbitrary maxHeight clamping of content.** The height ceiling is a
  safety bound (20 000 px) reached only beyond ~1:27 aspect ratios; nothing is
  cropped, `BoxFit` behaviour and offline file reading are untouched.
- **Unmeasured pages** decode with a height cap (8192 px equivalent) until the
  96 px probe reports the real ratio; the next decode uses the true aspect.
- **Image cache** now has an explicit byte/entry budget instead of relying on a
  size heuristic.
- **Key retention** is bounded instead of growing with every visited paragraph.
- **Covers** no longer hold full-resolution bitmaps for thumbnail slots.

## D. Rebuild improvements

- Page indicator/scroll-derived state no longer subscribes the manga page list
  to `currentPage`; a page turn now repaints the pages that changed.
- TTS word/paragraph state is observed only by the paragraph widget(s) on screen.
- Auto-scroll and speech following no longer run inside `build`.
- Chapter list derivations are reused across unrelated rebuilds (selection taps,
  download progress).
- `Get.find` is no longer performed per access in the reader.

## E. Reader improvements

- Continuous and paged modes both pass the measured page size to the decoder.
- Position persistence: coalesced writes, last-write-wins, flushed on close and
  on `inactive/paused/detached` — no page turn can lose progress.
- Novel search is responsive on very long chapters and cannot apply stale hits.
- Novel TTS highlighting, paragraph jumping, selection, text settings, auto
  scroll and chapter switching keep their previous behaviour.
- Reader page-controller sync is no longer queued once per rebuild.

## F. Tests

| Check | Command | Result |
|---|---|---|
| Static analysis | `flutter analyze --no-pub` | 29 issues, **0 errors**, 0 warnings (baseline: 30 issues, 1 warning) |
| Unit + widget tests | `flutter test --no-pub` | **254 passed, 0 failed** (baseline 246 + 8 new) |
| Kernel/assets build | `flutter build bundle` | exit 0, `build/flutter_assets` produced |

New tests (`test/reader_decode_size_test.dart`) cover: ordinary page unchanged,
quality scaling, tall-page pixel budget, extreme strip height ceiling,
unmeasured-page probe height, natural fit never upscaling, tiny viewport floor,
degenerate inputs.

Not executed: integration tests / on-device tests (no device or emulator).

## G. Build status

**Android APK/AAB: not built — blocked by the environment.** The VM has no JDK
and no Android SDK (`java` not found; no `ANDROID_HOME`), so Gradle cannot run.
The Dart/AOT frontend and asset pipeline were verified instead with
`flutter build bundle`, which succeeded. A release APK must be built on a
machine with the Android toolchain before shipping.

## H. Remaining problems

1. **Android build and profiling unverified.** No JDK/SDK/device here, so frame
   timings, memory curves and the packaged APK are unmeasured. All improvements
   above are source-verified and unit-tested, not profiled.
2. **Unused dependencies kept.** `crypto`, `cryptography`, `device_info_plus`,
   `dropdown_button2`, `firebase_analytics`, `firebase_storage`,
   `flutter_downloader`, `image`, `iconsax_flutter`, `permission_handler` and
   `shimmer` have zero imports in `lib/` and `test/`. They appear only in the
   generated `GeneratedPluginRegistrant.java` (regenerated on every build), and
   no hand-written manifest/Gradle/CI reference uses them. Removal was deferred
   because it changes `pubspec.lock` and the Gradle surface, and no Android build
   is available here to prove packaging is unaffected. Safe follow-up once a
   Linux/Windows machine with the Android SDK can build a release APK.
3. **Chapter snapshot load still does synchronous file existence checks** on the
   UI isolate (tens of small `existsSync` calls per open). Not converted to async
   because the helper's contract is used by the reader pipeline and the cost is
   small compared with JSON decode.
4. **Auto-scroll still ticks per frame while enabled.** It is now driven by a
   worker instead of `build`, but the per-frame offset math itself is unchanged;
   it was not simplified without frame timing data.
5. **Reader paragraph `ScrollController`, `PageController` and TTS engine** are
   owned by the controller and disposed there; their disposal was verified by
   inspection, not by a leak test.
6. **`docs/RELEASE_AUDIT.md` is stale** (claims 0 issues / 94 tests); not edited
   in this phase to avoid unrelated documentation churn.
7. **Four keep-alive tabs increase resident memory** while all have been opened;
   each already holds cached lists and cover thumbnails. If low-RAM devices
   regress, the natural follow-up is keeping only the last two visited tabs.

## I. Performance measurements

No before/after numbers are reported: this environment cannot run DevTools,
`flutter run --profile`, or on-device profiling, so any percentage would be
invented. What is verifiable without a device:

- Allocations avoided per page turn: the whole image list rebuild (previously
  every visible `ReaderMangaPage` + index recomputation) is now limited to the
  changing widgets.
- Allocations avoided per spoken word: one paragraph widget instead of the list.
- GetStorage writes per 10 rapid page turns: 10 full-map writes → 1.
- Chapter list filter+sort on an unrelated rebuild: O(n log n) → cached lookup.
- Thumbnail bitmaps: 34–85 px slots no longer decode full-resolution covers.

## J. Git status

13 modified files, 1 new test file; no dependency, asset, manifest or lockfile
changes; no generated or unrelated files touched.
