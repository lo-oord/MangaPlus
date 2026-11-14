# MangaPlus — Phase 2 Design System & UI Unification Report

Scope: design tokens, theme architecture, shared components, settings, states,
dialogs/sheets, layout hygiene, RTL strategy. No reader-engine, navigation,
state-management or feature changes.

---

## A. Design system

**One palette, one source of truth.** `lib/app/core/theme/app_palette.dart`
defines `AppPalette`, a `ThemeExtension` with every semantic colour
(background, surface, surfaceVariant, surfaceElevated, card, searchBar, primary,
onPrimary, primaryContainer, onPrimaryContainer, secondary, accent, textPrimary,
textSecondary, textDisabled, icon, border, divider, success, warning, error,
onError, info, scrim, skeleton, brightness). Only two instances ship
(`AppPalette.light`, `AppPalette.dark`) and both themes are generated from them.
Widgets read `context.palette`.

**One theme builder.** `theme.dart` previously held two hand-written `ThemeData`
blocks (~1000 lines duplicated). It is now a single `_build(AppPalette)` used by
`AppTheme.lightTheme`, `AppTheme.darkTheme` and `AppTheme.themeFor(brightness)`,
so light and dark can no longer drift. It defines the full `ColorScheme`
(including `surfaceContainer*`, `outline*`, `inverse*`), typography, and the
component themes for app bar, cards, filled/elevated/outlined/text/icon buttons,
FAB, inputs, checkbox/radio/switch, slider, progress, divider, dialog, bottom
sheet, chip, tab bar, tooltip, popup menu, snack bar, list tile, navigation bars,
text selection, scrollbar and page transitions, plus system-bar overlay styling.

**Legacy colour facade.** `AppColors` no longer stores a second palette: every
getter delegates to the active `AppPalette`, so all 616 existing call sites stay
correct without a second definition. Status colours (`success`, `warning`,
`error`) remain `const` because they are used inside constant widget
expressions.

**Spacing / radii / sizes / durations.** `design_tokens.dart` provides
`AppSpacing` (4‑px grid, screen inset 16, section 24, card inset 16),
`AppRadii` (8/12/16/20/26/pill, sheet top), `AppSizes` (48 control height, 48
touch target, icon sizes, 60 app bar, 72 nav bar, 720 content max width) and
`AppDurations` (160/240/360 ms).

**Typography.** The old theme requested a `Poppins` family that the project does
not bundle (no font asset, no package), so text silently fell back to the
platform font while claiming otherwise. The phantom reference is removed and a
single scale is defined instead (display 32 → label 11, Arabic-friendly line
heights 1.3–1.6) on the platform font, which also guarantees Arabic shaping.

## B. Screens updated

- **Main shell** — navigation bar rebuilt from tokens (single shadow, pill
  radius, token heights), animated indicator kept, system status/navigation bar
  styles now follow the active palette.
- **Settings (Profile)** — fully rebuilt: account header, three grouped
  sections (preferences, library, notifications) plus About, one row component,
  consistent dividers, icon containers, switch/value/chevron endings.
- **Search** — rebuilt: pill search field, theme chips, standard result cards,
  semantic loading/empty/error states, token paddings, metadata pills.
- **Home** — source picker sheet is content-sized (was a fixed 72 % height that
  left empty space), states unified, light theme colours come from the palette.
- **Details / Bookmarks / Local library** — destructive dialogs moved to the
  shared dialog; chapter/selection cards inherit the theme card style.
- **Reading stats, Profile details** — dialogs and page padding standardised.
- The remaining screens (history, downloads, notifications, genre, auth, splash,
  reader overlays) now inherit the central palette and component themes; their
  layouts were not individually re-composed in this phase (see J).

## C. Reusable components

`app_buttons.dart` — `AppButton` (primary / secondary / outline / danger / ghost,
dense variant, icon, trailing icon, loading, expand) and `AppIconButton`.
`app_surfaces.dart` — `AppCard`, `AppSection`, `AppSettingsTile`, `AppPill`
(6 tones). `app_dialogs.dart` — `AppDialogs.show`, `AppDialogs.confirm`,
`AppDialogs.sheet` with shared shell (handle, header, radius, barrier, close
action). `brand_state.dart` — `BrandState.loading/.empty/.error` plus a new
`AppOfflineBanner`.

## D. Settings

Every existing option is preserved: language, theme switch, notifications
(notifications screen, history, downloads, local storage), favourite / manga /
novel notification switches, account header with avatar change and display-name
edit, verified/official badges, About dialog. What changed is structure (grouped
sections with headings and subtitles), row geometry (36 px icon container, 12
padding, aligned trailing), destructive styling and dialog presentation. The
theme switch still calls `controller.changeTheme` and persists through the
existing `themeMode` storage key.

## E. States

- Loading: branded `MangaPlusLoader` only (no stock spinner) via
  `BrandState.loading`.
- Empty: `BrandState.empty` with icon, title, optional description and action.
- Error: `BrandState.error` always offers retry.
- Offline: `AppOfflineBanner` is inline and non-blocking, so cached/downloaded
  content stays reachable.

## F. Responsive / RTL

- The app keeps its **deliberate LTR shell** (documented in `main.dart` and
  `bidi_text.dart`): the paged reader, page order, sliders and progress bars are
  laid out LTR, while Arabic/mixed strings use `bidiTextDirection`. Flipping the
  shell would silently reverse reader paging — an unacceptable regression — so
  RTL is handled per string, and new components use `EdgeInsetsDirectional`.
- Components avoid fixed widths except bounded pills/values, use `Expanded`/
  `Flexible`, safe-area insets and 48 px touch targets.
- **Not visually verified**: no Android device/emulator or desktop target is
  available in this environment, so no screenshot review, no large-text (A11y
  scale) pass and no overflow sweep on real sizes was performed. Analyzer,
  widget tests and `flutter build bundle` are the only executed checks.

## G. Files

New: `core/theme/design_tokens.dart`, `core/theme/app_palette.dart`,
`widgets/app_buttons.dart`, `widgets/app_surfaces.dart`,
`widgets/app_dialogs.dart`, `test/design_system_test.dart`, this report.
Modified: `core/theme/theme.dart` (rewritten), `core/constants/colors.dart`,
`widgets/brand_state.dart`, `main.dart`, `modules/main/views/main_view.dart`,
`modules/profile/views/profile_view.dart`,
`modules/profile/views/profile_details_view.dart`,
`modules/profile/views/reading_stats_panel.dart`,
`modules/search/views/search_view.dart`, `modules/home/views/home_view.dart`,
`modules/bookmark/views/bookmark_view.dart`,
`modules/local_library/views/local_library_view.dart`,
`modules/comic_detail/views/comic_detail_view.dart`.

## H. Dependencies

None added, none removed. The new components are built from Flutter primitives
and the existing GetX layer.

## I. Tests and build

| Check | Result |
|---|---|
| `flutter analyze --no-pub` | 30 issues → after the last fix: **29 info-level, 0 errors, 0 warnings** (same count as the Phase 1 baseline) |
| `flutter test --no-pub` | **264 passed, 0 failed** (254 before this phase + 10 new design-system tests) |
| `flutter build bundle` | exit 0 |
| Android APK | **not built** — no JDK and no Android SDK: `[!] No Android SDK found` |

New tests cover: palette installed as theme extension, both themes generated
from it, palette `lerp`, shared button radius/height, `AppButton` action +
loading, `BrandState.loading` using the branded loader, `BrandState.empty`
retry, `AppSection` dividers, `AppSettingsTile` switch, `AppPill` overflow,
`AppCard` tap.

## J. Remaining issues

1. **No visual verification.** No emulator/device and no desktop/web target was
   validated, so colour contrast, exact spacing and dark/light screenshots were
   not inspected. Only automated checks ran.
2. **Screens that inherit but were not re-composed**: history, downloads,
   notifications, local library, genre, genre detail, auth, splash, and the
   reader chrome/settings sheets. They pick up the new palette, typography,
   inputs, chips, buttons, dialogs and states, but their internal layout was not
   rebuilt in this phase.
3. **Reader overlays** keep their dark, immersive chrome on purpose; they are
   not migrated to light-theme surfaces (that would hurt reading contrast).
4. **Details pages** still use their existing section stack; the shared
   `AppSection`/`AppCard` migration there is partial (chapter rows, selection bar
   and dialogs already match).
5. **Arabic/English layout validation** is limited to unit/widget tests and the
   documented bidi strategy; no RTL screenshot review was possible.
6. **System font instead of a bundled Arabic typeface.** Bundling an OFL Arabic
   font (e.g. IBM Plex Sans Arabic) would give a stronger identity; it was not
   added because no font asset/licence review exists in the repo and adding
   binary assets without visual verification was out of scope.
