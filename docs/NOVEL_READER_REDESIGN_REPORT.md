# MangaPlus — Novel Reader Redesign Report

Status legend used throughout:

- **Implemented + tested** — covered by analyzer and automated tests.
- **Implemented, not device-verified** — code compiles and is exercised by tests where possible,
  but needs a real device/TTS engine.
- **Partial** — shipped in a limited form, with the limit stated.
- **Not implemented** — deliberately left out, with the reason.

No Android SDK, JDK, emulator or device exists in this workspace, so there was **no APK build and
no visual/runtime inspection**. All numbers in section 11 are real command output.

---

## 1. Existing architecture inspected

- `lib/app/modules/chapter/views/chapter_view.dart` — novel branch (`_buildNovel`),
  `_NovelParagraph`, anchor capture/restore, paragraph-key pruning, speech and auto-scroll
  workers, chrome.
- `lib/app/modules/chapter/controllers/chapter_controller.dart` — novel settings (font, spacing,
  margins, alignment, direction, themes), TTS session (`FlutterTts`), notes/highlights,
  `compute`-based search, bookmarks, progress persistence, scroll controller, auto-scroll.
- `lib/app/core/reader/novel_reader_model.dart` — paragraph splitting, chapter-divider tokens,
  `NovelSearchHit`, note model helpers.
- `lib/app/modules/chapter/widgets/reader_tools_sheet.dart` — the five-tab reader sheet with the
  novel appearance/more sections.
- `lib/app/modules/chapter/widgets/brand_state.dart`, `app_motion*`, `app_dialogs`,
  `app_feedback` — shared state, motion and feedback components.
- `test/novel_reader_model_test.dart` and the rest of the reader test suite.
- Persistence uses the existing GetStorage-backed keys (`novel_*`), not a new store.

Phase 1 optimisations found and preserved: isolated `_NovelParagraph` `Obx`, speech/auto-scroll
driven by workers instead of build, debounced progress writes, `compute()` search, paragraph key
pruning, cached chapter loading.

## 2. Features already present before this task

Continuous scrolling; five reading themes; font size, weight, family, line height, paragraph
spacing, margins, alignment and text direction; paragraph-level TTS with word highlighting and
auto-scroll to the spoken paragraph; play/pause/stop; TTS rate and language; bookmarks with
per-chapter positions; highlights/notes with quotes and colors; in-chapter search with results;
auto-scroll with speed; progress persistence and restore; chapter list and previous/next chapter;
offline chapters.

## 3. Features added

- **Sentence-level TTS units** with previous/next sentence and a live “sentence X of Y” counter.
- **Novel TTS panel** (`showNovelTtsPanel`): play/resume, pause, stop, previous/next sentence,
  current sentence text, speed slider, Arabic/English choice, paused/notice status and an honest
  note that available voices come from the device engine.
- **Dedicated novel top bar**: back, novel/chapter identity, position + percent pills, TTS
  quick toggle (play/pause state), bookmark position, tools.
- **Dedicated novel bottom bar**: drag handle, chapter/position row, progress slider, auto-scroll
  toggle, previous chapter, chapter list, reading settings, next chapter.
- **Chrome auto-hide for novels**, sharing the Phase 4 `ReaderChromeAutoHide` behaviour
  (restart on interaction, paused while sheets are open and during chapter switches).
- **Letter spacing** and **reading text width** settings, persisted and applied immediately.
- **System text scaling** is respected by novel text on top of the manual size setting.
- **Manual drag stops novel auto-scroll**, so the reader always keeps control.
- **Centered reading measure** on wide screens via a tested padding helper.

## 4. Features improved

- TTS now speaks sentences instead of 2500-character blocks, so pausing/resuming restarts a much
  smaller unit and “next/previous” is meaningful.
- TTS state is visible in the chrome (playing/paused icon) and in the panel instead of being
  buried in the tools sheet.
- The existing chapter-switch stop of TTS is preserved (speech is stopped before a new chapter's
  content is installed).
- Novel progress is reachable from the bottom bar slider (seek + persist), and the chapter list
  is one tap away.
- Bookmarking the current reading position is available without opening the sheet.
- Search results loading uses the design-system loader rather than a bare spinner.

## 5. UI redesign details

- Both novel bars use the same dark translucent surface language as the manga chrome but with
  novel-specific actions only — no page thumbnails or page-fit controls are shown for novels.
- The reading canvas keeps its existing geometry; only the horizontal padding now follows the
  user’s reading width and is centered on large screens. Top/bottom padding still clears the
  chrome.
- Paragraph rendering, divider rendering and note/speech span construction are unchanged, so
  Arabic shaping and note positioning remain exactly as before.
- Reduced motion: the bars use the Phase 3 `AppMotion` transitions, which collapse to instant
  when `MediaQuery.disableAnimations` is set.

## 6. TTS improvements

- **Implemented + tested**: sentence splitting (Arabic/English/mixed, punctuation kept,
  over-long sentences bounded by words), paragraph-index mapping that skips chapter dividers,
  next/previous sentence API, sentence counter and current-sentence state.
- **Implemented, not device-verified**: engine calls (`setLanguage`, `setSpeechRate`, `speak`,
  `pause`, `stop`), word highlighting via `setProgressHandler`, error feedback when the engine or
  language is unavailable, language resolution against `getLanguages`.
- **Not implemented**: background playback (the current engine/platform setup is not configured
  for it), explicit voice picker (only language selection is exposed; the system voice is used),
  sentence-level background highlight in the text (the current word is highlighted and the
  current sentence is shown in the panel).

## 7. Typography and Arabic support

- Existing font family/weight/size, line height, paragraph spacing, margins, alignment and
  direction controls are unchanged and now complemented by letter spacing and reading width.
- Arabic: the default font remains the system font, which guarantees Arabic shaping and
  fallback; no fonts are downloaded at runtime and no text is reordered. Mixed Arabic/English
  keeps bidi detection, and the text scale is applied through `TextScaler` so glyph shaping is
  untouched.
- **Not implemented**: first-line indentation (Flutter has no first-class first-line indent for
  a paragraph; the alternatives — injecting spaces or splitting paragraph spans — would distort
  selection and search offsets), and user-defined arbitrary colors (the five themes remain).

## 8. Performance improvements / preservation

- Sentence splitting runs once when the TTS session starts and lives outside the widget tree.
- The sentence label and current-sentence card are small `Obx` regions; a spoken word still
  rebuilds only the paragraph that owns it (Phase 1 design).
- No animation was added to paragraphs, text layout or scrolling; the only new animations are the
  chrome transitions (already reduced-motion aware).
- Search still runs in an isolate via `compute()`; results remain bounded.
- Auto-scroll still drives the existing scroll controller; it now also yields to manual drags.
- No `AnimationController`, `Ticker` or subscription was added without disposal in the view;
  novel TTS/chunk state is cleared on stop, chapter switch and close.

## 9. Dependencies added or rejected

**None added.**

- `flutter_animate` / `animations` — the project's native motion system (Phase 3) is sufficient.
- `scrollable_positioned_list` — paragraph keys plus `Scrollable.ensureVisible` already provide
  reliable jumps; the existing list already knows paragraph extents.
- `SelectableText` / custom context menu package — `SelectionArea` already provides selection and
  copy; a custom menu would need stable offsets that the current source model cannot guarantee.
- `TextPainter` pagination — no reliable, shaping-safe pagination could be built inside this
  architecture without risking broken Arabic line breaks; continuous scrolling was kept instead.
- A TTS package alternative — `flutter_tts` is already integrated and is the platform-supported
  engine, so replacing it would add risk without benefit.

## 10. Files changed

New:

- `lib/app/core/reader/novel_speech.dart` — sentence/chunk splitting.
- `lib/app/core/reader/novel_typography.dart` — reading padding helper.
- `lib/app/modules/chapter/widgets/reader_novel_chrome.dart` — novel top/bottom bars and TTS panel.
- `test/novel_reader_test.dart` — 14 tests.
- `docs/NOVEL_READER_REDESIGN_REPORT.md`.

Modified:

- `lib/app/modules/chapter/controllers/chapter_controller.dart` — sentence TTS, next/previous
  sentence, sentence state, letter spacing and reading width settings/persistence.
- `lib/app/modules/chapter/views/chapter_view.dart` — novel chrome branch, TTS panel entry,
  reading-width padding, text scaling, letter spacing, manual-drag auto-scroll stop.
- `lib/app/modules/chapter/widgets/reader_tools_sheet.dart` — letter spacing/width sliders, TTS
  panel entry, design-system search loader.

The manga reader and other modules were not modified in this task.

## 11. Tests executed and results

| Check | Result |
| --- | --- |
| `flutter analyze` | 28 issues, **0 errors, 0 warnings** (all pre-existing infos) |
| `flutter test` | **308 passed** (294 before this task + 14 new) |
| `flutter build bundle` | exit 0 |

New tests (`test/novel_reader_test.dart`):

- `splitNovelSentences`: Arabic sentences with `.!?`, English/mixed text, paragraph without a
  terminator, over-long sentence bounds by words, empty input.
- `splitNovelSpeech`: skips chapter dividers, preserves paragraph indexes and sentence ordinals,
  empty content.
- `novelReadingPadding`: phone margins, centered measure on wide screens, minimum padding
  (including a 20 px viewport) and invalid width.
- `NovelReaderTopBar`: identity + progress pills, TTS state icon/tooltip, back/TTS/bookmark/tools
  callbacks.
- `NovelReaderBottomBar`: auto-scroll + chapters + settings callbacks, disabled previous chapter,
  running auto-scroll state.

Existing novel/reader tests (`novel_reader_model_test`, progress, bookmarks and the geometry
suites) still pass unchanged; no test was weakened or removed.

## 12. Build results

**No Android build.** This environment has no Android SDK/JDK and no emulator/device; running
`flutter build apk` fails for that reason. `flutter build bundle` (Dart compile + assets) exited 0,
which does not validate the Android toolchain, TTS engine, keep-screen-on channel or immersive UI
on hardware.

## 13. Known limitations

- **Implemented, not device-verified**: TTS playback, word highlighting, language resolution,
  keep-screen-awake and immersive UI behaviour.
- **No real-device performance measurement.** No frame timings or memory numbers are claimed.
- **No paginated novel mode.** Implementing it reliably needs shaping-safe line measurement and
  stable page boundaries; a character-count split was explicitly avoided.
- **TTS voice picker** is not exposed; only language, speed and the system default voice.
- **Background playback** is not implemented; leaving the app can interrupt speech.
- **Highlights/notes** are created from the tools dialog, not from a custom selection context
  menu; the same limits apply to “search selected text”.
- **First-line indent** and arbitrary custom colors are not available (see section 7).

## 14. Remaining issues

1. TTS panel behaviour is untested on a real engine: pause/resume, next/previous sentence across
   long chapters and error handling must be verified on Android.
2. The sentence unit is punctuation-based; rare texts without terminators become long chunks
   bounded at 600 characters, which is safe but less granular.
3. Notes are stored by chapter reference + paragraph index + quote; if a source rewrites a chapter
   heavily, a note may no longer align with the exact words (the quote is retained so the reader
   can still see what was annotated).
4. In-chapter search remains capped at 60 hits by design.
5. Chrome auto-hide for novels was wired through the same tested helper but not observed running.
6. The novel reader still uses the generic tools sheet for bookmarks/notes/search; a dedicated
   bottom “reading tools” surface is a possible follow-up, not a missing function.
