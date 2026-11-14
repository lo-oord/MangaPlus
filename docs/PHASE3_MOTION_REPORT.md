# MangaPlus — Phase 3 Report: Navigation, Motion & Interaction

Scope: navigation transitions and safety, a centralized motion system, bottom navigation,
micro-interactions, details and reader feedback, overlay motion, loading transitions and
reusable interaction components. GetX remains the navigation framework; the reader engine,
Phase 1 performance work and the Phase 2 design system are preserved.

Verification environment: Flutter 3.27.1 / Dart 3.6.0 in the cloud workspace.
No Android SDK, JDK, emulator, device or desktop/web target is available here, so no APK was
built and nothing was visually or interactively inspected (see section L).

---

## A. Navigation Improvements

**Duplicate-tap protection — `lib/app/core/navigation/app_navigation.dart` (new)**

`AppNavigation.toNamed` wraps `Get.toNamed`, keeps `arguments`, `parameters`, the returned
`Future` and `preventDuplicates`, and refuses a push when:

- the target is already `Get.currentRoute`, or
- the same route was pushed less than `AppNavigation.duplicateWindow` (280 ms) ago.

Different routes are never blocked, so reader → detail → reader style flows are unaffected.
All 29 `Get.toNamed` call sites in 15 files now go through it (services, controllers and views).
Back navigation, history and deep-link argument passing are unchanged.

**Route transitions — `lib/app/routes/app_pages.dart`**

Transitions are chosen by relationship, not applied uniformly:

| Destination | Transition | Duration |
| --- | --- | --- |
| Comic detail, genre detail, history, downloads, local library, notifications, profile details, auth, genre | `rightToLeftWithFade` + `AppMotion.emphasized` | 260 ms |
| Reader (`CHAPTER`) | `fadeIn` | 150 ms |
| Splash | `fadeIn` | 320 ms |
| Main shell, search, profile, bookmarks (tab destinations opened directly) | `fadeIn` | 260 ms |

The reader keeps the shortest transition in the app so page images are never withheld for an
effect. Curves are the same emphasized cubic used by overlays.

## B. Animation System

**`lib/app/core/theme/app_motion.dart` (new)** is the single motion vocabulary:

- `instant` 90 ms — press release/feedback confirmation.
- `fast` 150 ms — chips, switches, icon swaps, sheet exit, reader fade.
- `normal` 220 ms — expansion and content switching.
- `chrome` 200 ms — reader toolbar slide.
- `slow` 320 ms — navigation-bar indicator and tab paging.
- `page` 260 ms — routes, dialogs, sheet entrance.
- `entrance` 320 ms — section entrance.
- Curves: `enter` (easeOutCubic), `exit` (easeInCubic), `standard` (easeInOutCubic),
  `emphasized` (Cubic(0.2, 0, 0, 1)).
- `reduceMotion(context)`, `effective(context, duration)`, `curve(context, curve)` and
  `scaleFor(context)` collapse motion to zero/linear/no-scale when
  `MediaQuery.disableAnimations` is set.
- `pressedScale` .97 and `entranceOffset` .04 are shared constants.

`AppDurations` (Phase 2) was removed rather than kept as a second timing source; every former
use in the navigation bar now reads `AppMotion`, so there is exactly one place that defines
how long anything takes.

The architecture continues to use only native primitives (`AnimatedContainer`,
`AnimatedOpacity`, `AnimatedScale`, `AnimatedSlide`, `AnimatedSwitcher`, `AnimatedSize`,
`AnimatedAlign`, `AnimatedRotation`, `AnimatedDefaultTextStyle`, `AnimationController`,
`FadeTransition`, `SlideTransition`, `ScaleTransition`); no animation package was added.

## C. Bottom Navigation

- Tab paging uses `AppMotion.slow` (320 ms, previously a hard-coded 420 ms) with
  `AppMotion.standard`, so switching feels responsive instead of sluggish.
- With reduced motion the page controller jumps immediately (`Duration.zero`).
- The existing indicator slide, icon cross-fade/scale and label colour/weight transition now
  read their durations and curves from `AppMotion` and collapse together with reduced motion.
- Selected state is still conveyed by icon fill, tint, indicator and label weight — motion is
  supplementary, not the only cue.
- Rapid taps remain safe: `changeIndex` keeps its request counter (latest tap wins, stale
  animations are ignored), and the paging controller is disposed in `onClose`.
- Tabs stay alive and keep their scroll state (Phase 1 keep-alive and `PageView` are untouched).

## D. Micro-Interactions

- **Buttons** — `AppButton` wraps its filled/outlined/ghost content in `PressableScale`
  (0.98) and only when enabled; tap handling is unchanged.
- **Reader chrome** — every reader toolbar control uses `PressableScale` (0.94) so it responds
  on touch-down; disabled controls do not scale.
- **Cards / chapter rows** — the selected chapter row animates its own background and border
  (`AnimatedContainer`, 150 ms). Selection still repaints only that row's `Obx`.
- **Details page** — the primary action row, synopsis card and metadata grid enter with a short
  staggered fade/lift (0/60/120 ms), so important sections appear in reading order without
  delaying the first tap.
- **Bookmarks** — the existing immediate `Obx` icon/label swap was kept; no new screen refresh
  was introduced.
- **Settings** — switch rows keep the native platform switch animation; the reading-stats panel
  now uses the shared `AppExpandable` (height + chevron rotation, 220 ms).
- **Filters/chips** — chapter filter chips keep Material's animated selection; no layout shift
  was added.

## E. Reader Experience

- The toolbar show/hide transition is now driven by `AppMotion.chrome` (slide) and
  `AppMotion.fast` (fade), and collapses to an instant swap for reduced motion.
- Reader controls gained press feedback only; page display, paging, continuous scrolling,
  zoom/transformation, RTL/LTR direction and progress persistence were not touched.
- Page images are never wrapped in entrance animations: no fade or delay was added to the
  reader image pipeline, preserving Phase 1 decode budgets and cache behaviour.
- Previous/next chapter still loads pages in place (`navigateToChapter` /
  `joinContinuousStream: true`); no route is pushed, so chapter switching does not animate or
  rebuild the whole reader.
- Novel reader (TTS, text size, line height, theme) keeps its immediate settings; no animation
  was added to paragraph rendering or scrolling.

## F. Dialogs and Overlays

`AppDialogs.show`, `AppDialogs.confirm` and `AppDialogs.sheet` now use:

- dialogs: `transitionDuration: 260 ms`, `transitionCurve: AppMotion.emphasized`;
- bottom sheets: `enterBottomSheetDuration: 260 ms`, `exitBottomSheetDuration: 150 ms`;

both routed through `AppMotion.effective`, so reduced motion opens and closes instantly.
Barrier colour, dismissal gestures, keyboard/safe-area handling and controller lifecycles are
unchanged. Nine direct `Get.dialog` / `Get.bottomSheet` calls remain in feature files that build
bespoke sheet content (share sheet, reader tools, some confirmations); they keep GetX defaults
and are listed in section L.

## G. Reusable Components

**`lib/app/widgets/app_motion_widgets.dart` (new)**

- `PressableScale` — pointer-level press feedback using `Listener` with
  `HitTestBehavior.translucent`; it never enters the gesture arena, so wrapped buttons,
  `InkWell`s and `GestureDetector`s keep receiving taps. Collapses to scale 1 for reduced
  motion and for disabled controls.
- `AnimatedEntry` — one-shot fade + lift with optional delay; owns and disposes its
  `AnimationController`, cancels its delay `Timer` on dispose, and jumps to the end state when
  motion is reduced.
- `AnimatedContentSwitcher` — fade/light-scale cross-fade with a stack layout that avoids
  layout jumps between states.
- `AppExpandable` — the shared expand/collapse shell (Phase 2 tokens, `AppCard`, animated
  height, rotating chevron, `Semantics(expanded: ...)`); collapsed content is not built.

All four use `AppPalette`/`AppSpacing`/`AppRadii`/`AppSizes` and work in both themes.
`AppExpandable` is used by the profile reading-stats panel, `PressableScale` by `AppButton` and
the reader chrome, `AnimatedEntry` by `BrandState` and the details sections, and
`AnimatedContentSwitcher` is available for loading/content switches; it is covered by tests but
not yet adopted by a screen (see L).

## H. Dependencies

No package was added or removed.

- `flutter_animate` — not added: every effect implemented here is a property of an existing
  widget (`AnimatedScale`, `AnimatedSlide`, `AnimatedSwitcher`, `AnimatedSize`), so the package
  would add a dependency without removing code.
- `animations` — not added: its Material motion widgets would duplicate the project's own
  container/page transition configuration and its `PageTransitionSwitcher` is not needed while
  GetX owns routes.
- `rive` — not added: no vector/state-machine animation is required, and it would add a runtime
  and asset pipeline for decoration only.
- `lottie` — not added: no Lottie assets exist and the brand loader is a custom painter.

## I. Performance

- No `AnimationController` is created in a `build` method; the only controllers are inside
  `AnimatedEntry` state, created once, and disposed.
- `AnimatedEntry` cancels its pending delay `Timer` in `dispose`; a widget removed mid-animation
  cannot call `forward()` on a disposed controller.
- `PressableScale` uses `Listener` (no gesture recognizer, no arena contention) and rebuilds a
  single `AnimatedScale`; it does not wrap list rows.
- Chapter selection animates `AnimatedContainer` decoration only; the list still rebuilds per
  row via its existing `Obx`, and the derived chapter list cache from Phase 1 is untouched.
- No opacity animation is applied to large lists or full pages; entrances cover small sections
  (action row, synopsis, metadata, empty states).
- Image fade-ins reuse the cached image already used by the widgets; no extra decode, no second
  image widget, no `Hero` (duplicate-tag and overlay-memory risk in long cover lists).
- Reader chrome animates two small bars only; page images, scroll offsets and zoom transforms
  are never animated.
- Reduced motion removes work entirely: durations become zero, so no ticker keeps running.
- No benchmarks or frame timings were measured here (no device/emulator; see L); the statements
  above are structural, not profile numbers.

## J. Tests and Build

Commands run in the workspace with `flutter --no-pub`:

| Check | Result |
| --- | --- |
| `flutter analyze` | 29 issues, **0 errors, 0 warnings** (identical to the Phase 2 baseline: 23 `curly_braces_in_flow_control_structures`, 2 `deprecated_member_use`, 2 `use_build_context_synchronously`, 1 `unnecessary_import`, 1 `prefer_const_declarations`, 1 `prefer_const_constructors`) |
| `flutter test` | **277 tests passed** (264 existing Phase 1/2 tests + 13 new) |
| `flutter build bundle` | exit 0, assets generated in `build/flutter_assets` |

New tests (`test/motion_system_test.dart`) cover:

- `AppMotion` returns zero duration / scale 1 with `disableAnimations`, and the shared values
  otherwise;
- `AnimatedEntry` animates in, settles at full opacity, is already visible with reduced motion,
  and disposes safely while its delay is pending;
- `PressableScale` shrinks on pointer-down, restores on release, and does not swallow the
  wrapped control's tap;
- `AnimatedContentSwitcher` replaces the old child;
- `AppExpandable` keeps collapsed content unbuilt until tapped;
- `AppNavigation` blocks a repeated push inside 280 ms, allows it later, never blocks a
  different route, and honours `resetThrottle`.

Existing Phase 1 and Phase 2 tests were not modified or weakened.

## K. Files Modified

New:

- `lib/app/core/theme/app_motion.dart`
- `lib/app/core/navigation/app_navigation.dart`
- `lib/app/widgets/app_motion_widgets.dart`
- `test/motion_system_test.dart`
- `docs/PHASE3_MOTION_REPORT.md`

Modified:

- `lib/app/routes/app_pages.dart` — per-relationship transitions from `AppMotion`.
- `lib/app/modules/main/controllers/main_controller.dart` — tab paging duration/curve,
  reduced-motion jump, context read before `await`.
- `lib/app/modules/main/views/main_view.dart` — motion tokens for indicator, icon and label.
- `lib/app/modules/chapter/views/chapter_view.dart` — chrome timing from `AppMotion`,
  press feedback on reader controls.
- `lib/app/modules/comic_detail/views/comic_detail_view.dart` — staggered section entrance,
  animated chapter selection, image fade-in.
- `lib/app/modules/profile/views/reading_stats_panel.dart` — uses `AppExpandable`.
- `lib/app/widgets/app_buttons.dart` — `PressableScale` press feedback.
- `lib/app/widgets/app_dialogs.dart` — dialog/sheet durations and curve.
- `lib/app/widgets/brand_state.dart` — entrance animation for state widgets.
- `lib/app/core/theme/design_tokens.dart` — removed `AppDurations`.
- `lib/main.dart`, `lib/app/data/services/account_gate_service.dart`,
  `lib/app/data/services/notification_presentation.dart`,
  `lib/app/modules/notifications/controllers/notifications_controller.dart`,
  `lib/app/modules/profile/controllers/profile_controller.dart`,
  `lib/app/modules/{bookmark,genre,genre_detail,history,home,local_library,notifications,profile,search}/views/*.dart`
  — navigation through `AppNavigation`; cover fade-in where missing.

## L. Remaining Issues

1. **No visual or runtime verification.** No Android SDK/JDK, emulator, device, desktop or web
   target exists in this environment, so transitions, press feedback, reduced motion and the
   reader chrome were **not** observed running. They are covered by analyzer, widget tests and a
   successful asset build only.
2. **No APK.** `flutter build apk` cannot run (`No Android SDK found`); only
   `flutter build bundle` was executed.
3. **No profiling.** Frame times, memory and jank were not measured; the performance section
   describes structural safeguards, not numbers.
4. **Nine bespoke overlays** still call `Get.dialog` / `Get.bottomSheet` directly (share sheet,
   reader tools, chapter/track confirmations). They inherit GetX's default timing instead of
   `AppMotion`; converting them needs per-sheet API work and was left out of this phase.
5. **No `Hero` transitions.** Covers appear in several lists with non-unique identities and in
   long scrolling lists; a `Hero` tag collision or a full-screen overlay was judged riskier than
   the current cover fade. This is a deliberate decision, not an oversight.
6. **`AnimatedContentSwitcher` is tested but not yet used by a screen.** Loading → content still
   swaps at the page level in most modules; adopting it per module would require restructuring
   each `Obx` branch and is deferred.
7. **Reader settings sheet** keeps its existing styling and default GetX timing; only the reader
   chrome and controls were retimed.
8. **Unused packages** from earlier phases (11 packages with zero imports) were not removed, as
   removal still cannot be validated by an Android build here.
