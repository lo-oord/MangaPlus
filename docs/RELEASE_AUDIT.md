# MangaPlus 1.1.0 release audit

Audit date: 2026-11-07 · Flutter 3.27.1 / Dart 3.6.0 · package `mangaplus` ·
application id `com.mangaplus.app`.

Update 2026-11-11: MangaTek and Mangasid were subsequently removed from the
active app registry; source counts below describe the original audit snapshot.

## Project Health

| Check | Result |
| --- | --- |
| `flutter analyze` | **0 issues** (was 73 at the start of the audit) |
| `flutter test` | **94 / 94 passing**, no network required |
| Line coverage (`flutter test --coverage`) | **15.6%** (2269 / 14572 lines) |
| `flutter build bundle` | **success**, 80 MB `build/flutter_assets` |
| `flutter build apk --debug` | **blocked in this environment**: no Android SDK / JDK |
| Secrets in the tree | none found; `google-services.json` and `firebase_options.dart` are the expected Firebase client config |
| Identity | name, package id, visual identity and bundled sources unchanged |

## Sources Audit

Full matrix and reproduction commands live in [SOURCE_AUDIT.md](SOURCE_AUDIT.md).
Verified live, independently, per source:

- **Working (13):** Team X, Manga Swat, Manga Time, Azora, Manga Online, Lava Scans,
  Kawaii Manga, Kawaii Novels, KolNovel, SeaNovel, Cenele Manga, Cenele Novels,
  and MangaTek's API feed/details.
- **Partially verified (2):** MKNOV (native WOFF2 font decode is Android-only),
  MangaTek (site reader returns Cloudflare 403 to non-browser clients).
- **Blocked upstream (4):** Mangasid, MangaDar, ProComic, Hijala
  (Cloudflare / Turnstile).
- **Offline upstream (1):** Asgard Scans (domain stopped serving the site).

MangaTek and Mangasid are no longer registered. The remaining blocked sources
still fail in isolation, so the feed, search and reader keep working.

## Features Audit

Working and untouched: home feed, latest updates, genres, search with
suggestions, work details and chapter list, manga reader (paged / continuous,
RTL and LTR directions, fit modes, chapter navigation, read-aloud), novel reader,
downloads with pause/resume and offline local library, bookmarks, reading history,
reading statistics, notifications, account (guest, email, Google) with profile
editing, cloud sync, backup import/export, light/dark theme and Arabic/English UI.

## UI/UX Audit

- One shared `MangaPlusAppBar` on all 11 secondary screens: same 60 px height,
  title size, back button, actions and theme colours.
- Content titles truncate with ellipsis instead of clipping; short titles stay
  centred, long titles start next to the back button.
- Arabic page titles, loaders and empty states use an RTL base direction inside
  the LTR application shell, so punctuation and mixed titles render correctly.
- Navigation is consistent: detail screens slide with a fade (280/240 ms), the
  reader opens on a 180 ms fade, tab switches keep their 420 ms eased motion and
  page loads keep the shared 260 ms fade.
- The LTR shell is intentional: the visual system (bottom navigation order, card
  layouts, paged reader) is built LTR. A full RTL flip would be a redesign and
  was not performed.
- Not visually verified: this environment has no emulator or device, so only
  static analysis, widget tests and a bundle build were possible.

## Loading UI Audit

- `MangaPlusLoader` is the only loading indicator: a hand-drawn sweeping ring
  around the official mark with a subtle pulse, optional label, determinate
  progress and reduced-motion support.
- All 6 stock `CircularProgressIndicator` usages were replaced. Real
  `LinearProgressIndicator` bars (download progress, backup import progress,
  reading goals) were deliberately kept because they show real progress.
- Determinate loaders run no ticker, so download lists with many small loaders
  stay static and cheap.

## Performance

- Adjacent-chapter image preloading now decodes in batches of three instead of
  warming a whole chapter at once, removing the memory spike on long chapters.
- Chapter reader keeps its existing dedupe set and prefetch cache; the reader,
  download and cache services were not redesigned.
- Cover images use `CachedNetworkImage`; 8 of 11 call sites pass explicit
  decode sizes.
- No profiling run was possible without a device. No speedup is claimed beyond
  the removed animation and decode work described above.

## Build & Tests

- `flutter analyze`: clean.
- `flutter test`: 94 passing (sources contract, services, reader logic, widget
  contracts, route registration, localization parity).
- `flutter test --coverage`: 15.6% line coverage; UI modules dominate the
  uncovered lines.
- `flutter build bundle`: success (Dart kernel + assets).
- Android APK/AAB: not built here because the sandbox has no JDK or Android SDK.
  This is an environment limitation, not a project failure; the CI workflow pins
  Flutter 3.27.1 and owns Android packaging.

## GitHub Delivery

- `7c45463` Phase 1: Core Audit, Bug Fixes & Sources Verification
- `45a2322` Phase 2: UI UX Improvements, Navigation & Animations
- Phase 3 commit follows this report; all three are pushed to `origin/main`
  without force and verified after a fresh fetch.

## Remaining Issues

1. MangaTek reader, Mangasid, MangaDar, ProComic and Hijala are blocked by the
   upstream Cloudflare/Turnstile protection; Asgard is offline. Fixing these
   needs browser-grade request handling or the sites coming back.
2. MKNOV reader needs the native WOFF2 decoder, so it can only be verified on an
   Android device.
3. Android packaging cannot be validated in this sandbox (no JDK/Android SDK).
4. 40 Arabic UI strings still have no English translation; the English UI falls
   back to Arabic for those. Arabic UI is unaffected.
5. Line coverage is 15.6%; the reader, download and sync flows are the largest
   untested areas.
6. No emulator/device visual pass was possible; spacing, RTL titles and the new
   loader should be eyeballed on a real phone before release.
