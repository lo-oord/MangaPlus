# MangaPlus — Manga Reader Redesign Report

Scope: the **manga** reader only (the novel reader was not redesigned), covering chrome,
reading modes, image rendering, preloading, gestures, chapter navigation, settings,
animations, error states, tests and build.

Verification environment: Flutter 3.27.1 / Dart 3.6.0 in the cloud workspace. No Android SDK,
JDK, emulator, device or desktop target exists here, so **no APK was built and nothing was
visually or interactively inspected**. Section 14 states exactly what was and was not measured.

---

## 1. Complete UI redesigns

- **New top bar** (`reader_chrome.dart`): back, rounded cover thumbnail (small decode, local or
  network with the existing headers), manga title from the reader arguments, chapter title,
  page pill and progress pill, bookmark-current-position action and the tools entry. It keeps a
  soft black-to-transparent gradient over the page instead of a solid block, so the artwork
  stays immersive.
- **New bottom bar**: drag handle, chapter/position row, a compact failed-pages chip with retry,
  a live page+percent pill, the progress slider with a larger touch target, and five evenly
  spaced actions (pages, previous chapter, mode toggle, next chapter, chapter list). Surface,
  radius, border and shadow now come from one `_ChromeColors` definition so both bars match.
- **Page canvas**: unchanged geometry engine; the redesign did not add padding, margins or
  overlays to the page list. The reader still shows exactly the extent reserved per page.
- **Loading placeholder**: the per-page `CircularProgressIndicator` was replaced by a static
  image skeleton. The load chip above the chrome remains the single progress indicator and now
  uses the design-system `MangaPlusLoader`, so no page in a scrolling list runs a repeating
  animation.
- **Safety**: both bars keep `SafeArea`, and the failed chip/slider do not cover the page
  content because they live inside the existing chrome transition.

## 2. New reader features

- **Chrome auto-hide** after 4.2 s of quiet reading, restarted on any interaction with the bars
  or the slider, paused while a sheet is open and while a chapter switch is running, and
  persisted as a setting.
- **Bookmark the current position** from the top bar (writes through the existing bookmark
  service and shows the existing feedback toast).
- **Direct thumbnail navigator** from the chrome: real page thumbnails at a 160 px decode
  budget, current page highlight, page numbers, tap-to-jump.
- **Direct chapter list** from the chrome, with current/read markers and in-reader navigation.
- **Retry failed pages** from the bottom bar, using the existing page-load tracker and retry
  path; the chip only appears when something actually failed.
- **Manga auto-scroll** with a speed slider (8–160 px/s), available in continuous/webtoon modes,
  cancelled immediately by a manual drag, and stopped automatically at the end of the chapter.
- **Webtoon preset** and **reading direction** toggles exposed in the tools sheet.

## 3. Improved reading modes

- **Vertical continuous** (existing `ListView` with `itemExtentBuilder`) is unchanged and still
  anchors the scroll position when pages above it get measured.
- **Horizontal paginated** (existing `PageView`, optional double page, RTL via `reverse: true`,
  three tap zones) is unchanged; the forward/back direction is now also reported to preloading.
- **Webtoon** is implemented as a preset over the same continuous list — full width, zero gap,
  single page, chapter dividers preserved — instead of a second rendering engine. The predicate
  `readerIsWebtoonPreset` lives in `core/reader/reader_reading_preset.dart` and is unit-tested.
- **Direction**: RTL/LTR now has a first-class setting in the reading tab. It already drove page
  order, tap zones and page indicators; preloading now follows the content index, not the visual
  direction, so RTL does not invert which pages are warmed.

## 4. Image rendering architecture changes

The engine was deliberately **not** replaced. `ReaderImagePipeline`, `ReaderChapterCache`,
`ReaderPageMetricsStore`, `readerPageDecodeSize`, the 8 MP decode budget, the 20 000 px height
cap, the 96 MB / 300-entry image cache and the offline library stay as they were.

Changes made:

- Reader page placeholder is static (one icon, no ticker per page).
- Thumbnails are separate image widgets decoding at 160 px width; they never reuse or evict the
  full-page bitmaps.
- Preload range calculation moved into a pure, tested helper (`reader_preload_window.dart`).
- No second image rendering system, no `extended_image`, no tiling layer.

## 5. Preloading and caching improvements

- **Direction-aware preloading**: when the reader moves forward it warms one page behind and
  `preloadDistance` pages ahead; when it moves backwards it warms `preloadDistance` behind and
  one ahead; unknown direction (initial load, jump, chapter switch) keeps the symmetric window.
  The window is clamped to the chapter and the distance is clamped to 1–12.
- Existing guarantees are preserved: one request per URL, at most three loads in flight,
  visible-before-near-before-adjacent priority, bounded retries, cancellation of queued work far
  behind the reader, and adjacent-chapter prefetch near either end.
- No cache limit was changed and no measurement is claimed (see 14).

## 6. Zoom and gesture improvements

- Paginated pages keep `InteractiveViewer` with pinch zoom, double-tap zoom, pan-while-zoomed,
  the reset button and zoom reset when the page reference or retry token changes; animation
  controllers for zoom remain disposed with the page.
- Continuous/webtoon reading intentionally does **not** wrap pages in an `InteractiveViewer`:
  a pan recognizer inside the scrolling list would compete with vertical scrolling. Zoom stays a
  paginated feature, which is the behaviour that can be shipped without gesture conflicts.
- Auto-scroll listens to `ScrollStartNotification.dragDetails` and turns itself off, so manual
  panning/zooming never fights the ticker.

## 7. Chapter navigation improvements

- Previous/next chapter are directly reachable from the chrome, with the existing safeguards:
  position persisted before switching, stale requests cancelled by the controller, stale images
  not merged, duplicate requests guarded by `isNavigating`/navigation log, and chapter switches
  loading in place (no route push, no full reader rebuild).
- The chapter list sheet is now shared between the chrome and the tools sheet.
- Chrome auto-hide pauses during a chapter switch, so the bars cannot disappear while the new
  chapter is still being prepared.

## 8. Reader settings changes

Added and persisted through the existing GetStorage reader keys:

| Setting | Key | Applied |
| --- | --- | --- |
| Auto-hide chrome | `auto_hide_chrome` | immediately (timer consults it) |
| Manga auto-scroll | `manga_auto_scroll` | immediately (ticker worker) |
| Auto-scroll speed | `manga_auto_scroll_speed` | immediately |
| Reading direction | `direction` | immediately (existing setter) |
| Webtoon preset | mode/fit/gap/double-page keys | immediately |

The tools sheet now exposes: mode (continuous / paged / webtoon), direction, page fit, page gap,
double page, auto-scroll + speed, auto-hide, chapter title dividers, background, brightness,
fullscreen, keep-screen-on, orientation, image quality, preload distance, page-load status,
retry failed pages, image-memory clear, page thumbnails, page picker, chapter list, bookmarks,
and the existing novel-only sections. Technical values are labelled in user terms (no cache
sizes or decode budgets are exposed).

## 9. Animation implementation

- Chrome show/hide keeps the Phase 3 `AppMotion.chrome`/`fast` slide+fade and collapses to an
  instant swap under reduced motion.
- No animation is applied to page images, zoom transforms, scroll offsets or page order; page
  navigation stays immediate.
- The load chip, failed chip and thumbnail sheet use no repeating animations; the only repeating
  motion in this reader remains the novel TTS highlight, which is novel-only.
- Thumbnail sheet and chapter list use the same GetX sheet presentation as the rest of the app
  (default timing); they are not animated per tile.

## 10. Added and removed dependencies

**None.** Evaluated and rejected:

- `extended_image` / a second `cached_network_image` stack — would duplicate the existing
  pipeline, cache and decode budget.
- `scrollable_positioned_list` — the reader already knows every page extent
  (`ReaderPageScrollIndex`) and can jump by offset, which is what the page navigator uses.
- Tiling libraries — not needed for the current cap; Phase 1 already bounds decoded pixels by
  viewport and height instead of decoding full-resolution strips.
- `wakelock_plus` / `screen_brightness` — the project already has a platform channel for
  keep-screen-on and a brightness overlay; adding plugins would change native behaviour that
  cannot be validated without a device.
- `flutter_animate` / `animations` — Phase 3 already established the native animation system.

## 11. Files modified

New:

- `lib/app/modules/chapter/widgets/reader_chrome.dart` — top/bottom bars, auto-hide helper,
  thumbnail navigator, chapter list.
- `lib/app/core/reader/reader_reading_preset.dart` — webtoon preset predicate.
- `lib/app/core/reader/reader_preload_window.dart` — directional preload window.
- `test/reader_chrome_test.dart` — 11 tests.
- `test/reader_preload_window_test.dart` — 6 tests.
- `docs/PHASE4_READER_REDESIGN_REPORT.md`.

Modified:

- `lib/app/modules/chapter/views/chapter_view.dart` — new chrome, auto-hide wiring, manga
  auto-scroll ticker, scroll/page direction tracking, thumbnail/chapter/bookmark actions,
  paused auto-hide around sheets, design-system load chip.
- `lib/app/modules/chapter/controllers/chapter_controller.dart` — auto-hide and auto-scroll
  state + persistence, webtoon preset, directional `onMangaWindowChanged`.
- `lib/app/modules/chapter/widgets/reader_tools_sheet.dart` — webtoon chip, direction, auto-hide
  and auto-scroll settings; page grid and chapter list now delegate to the shared sheets.
- `lib/app/modules/chapter/widgets/reader_manga_page.dart` — static placeholder.

## 12. Tests executed

| Check | Result |
| --- | --- |
| `flutter analyze` | 28 issues, **0 errors, 0 warnings** (all pre-existing `info` lints; Phase 3 baseline was 29) |
| `flutter test` | **294 tests passed** (277 before this task + 17 new) |
| `flutter build bundle` | exit 0 |

New coverage:

- `ReaderChromeAutoHide`: fires once, cancel, pause/resume, dispose with a pending timer.
- `readerIsWebtoonPreset`: accepts only scroll + fit-width + zero-gap + single page for manga,
  rejects every other combination.
- `ReaderTopBar`: renders manga/chapter/page/percent and invokes back, bookmark and tools.
- `ReaderBottomBar`: page+percent label, pages/chapters/mode actions, slider seek and seek-end,
  disabled chapter buttons without a neighbour, failed-pages chip retry.
- `readerPreloadWindow`: forward/backward/symmetric windows, chapter clamping, empty chapter,
  distance clamping.

All pre-existing reader tests (`reader_decode_size`, `reader_image_pipeline`,
`reader_page_geometry`, `reader_chapter_cache`, `reader_offline_library`, `reader_progress`,
`reader_boundary_guard`, `novel_reader_model`, …) still pass unchanged.

## 13. Android build result

**Not run.** `flutter build apk` cannot run here: `[!] No Android SDK found`, and there is no
JDK, emulator or device. The only build performed was `flutter build bundle` (exit 0), which
compiles the Dart code and produces assets but does not validate the Android toolchain, the
platform channel (`setKeepScreenOn`), immersive mode or orientation locks on a real device.

## 14. Performance measurements

**None were taken.** Without a device or emulator, page display latency, scroll frame times,
memory growth and cache hit ratios cannot be measured honestly. What changed structurally:

- the scrolling list no longer runs a spinner per visible page;
- the preload window is directional and still bounded (1 behind + distance ahead), so moving
  forward does not spend bandwidth on pages already read;
- chapter prefetch near the end/start is unchanged and still de-duplicated;
- no new image providers, overlays, blur filters or per-page animations were introduced;
- page navigation in paged mode is still a direct `PageView` change; no animation was added to
  the image itself.

## 15. Remaining limitations

1. **No visual/runtime verification and no APK** (no Android toolchain or device here).
2. **No performance profiling**; the claims above are structural, not measured.
3. **Zoom is paginated only.** Continuous/webtoon zoom would need a gesture architecture that
   does not conflict with vertical scrolling; it was not implemented partially.
4. **No tiled/region decoding.** Very tall images are still handled by the Phase 1 decode
   budget plus the maximum extent; adding tiling without profiling on real devices was judged
   riskier than the current bounded decode.
5. **Brightness** is an in-reader dimming overlay, not system brightness; **keep-screen-on**
   uses the existing platform channel and was not tested on hardware.
6. **Auto-scroll** advances with `jumpTo` on every frame at the configured px/s (by design, to
   stay exact at any speed); it is not a spring physics simulation.
7. **Reader sheets** (tools, thumbnails, chapters) still use GetX's default sheet timing rather
   than `AppMotion`; Phase 3 left the same note for all bespoke sheets.
8. **Auto-next confirmation** was not added: the existing continuous navigation already loads
   the adjacent chapter in place, and adding a confirm dialog would interrupt long-strip reading.
9. The novel reader was intentionally left untouched.
