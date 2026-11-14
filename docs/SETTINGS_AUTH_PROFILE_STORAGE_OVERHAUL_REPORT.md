# MangaPlus — Settings, Auth, Profile, Onboarding, Downloads & Storage Report

Status labels used below:

- **Implemented + tested** — covered by the analyzer and automated tests.
- **Implemented, not device-verified** — builds and is exercised where possible, but needs a real
  Android device/plugin runtime.
- **Partial** — shipped in a limited form; the limit is stated.
- **Not implemented** — deliberately left out, with the reason.

Environment limits: no Android SDK/JDK, emulator or device is available here, so there is **no APK
build and no visual/runtime inspection** of these screens. Every number in section 15 is real
command output.

---

## 1. Initial project inspection

Inspected before changing anything:

- **Settings** — there was no settings module. The Settings tab *is* `ProfileView`
  (`lib/app/modules/profile/views/profile_view.dart`), a single long list mixing account,
  statistics, preferences, voice toggles, notifications, library links and About.
- **Settings state** — `ProfileController` owns language (`language`), theme (`themeMode`),
  notification toggles and account loading; reader preferences live in the chapter controller
  (`reader_mode`, `reader_direction`, `reader_fit`, `reader_continuous_navigation`, `novel_*`),
  with `_readerSettingKey` scoping novel keys.
- **Auth** — Firebase Auth through `AuthService`, `AuthController` with email sign-in, a
  three-step registration wizard, Google sign-in, guest mode, username availability, email
  verification cooldown, password reset by email, and a password change inside profile details.
  `AuthView` was one large form file with basic checks.
- **Profile** — `ProfileView` header + `ProfileDetailsView` (bio, account info, verification
  status, password change, favourites sync, sign-out) + `ReadingStatsPanel`.
- **Splash** — branded animation with a hard-coded `800 ms` timer that always went to `MAIN`;
  no first-launch detection anywhere.
- **Downloads** — `DownloadManagerService` (persistent task queue, two concurrent workers,
  pause/resume/cancel/retry, chapter-level progress, notifications) and a flat `DownloadView`
  list with a popup menu.
- **Storage** — `LocalLibraryController`/`LocalLibraryView` grouped downloaded chapters by comic
  with real file sizes, multi-select deletion, and relied on `downloadedChapters` storage.
- **Design system** — `AppSection`, `AppSettingsTile`, `AppCard`, `AppButton`, `AppDialogs`,
  `AppMotion`, `AppPalette`, `MangaPlusAppBar`, `ThemeAwareBuilder`, `BrandState`.
- **Dependencies** — Flutter 3.27 / Dart 3.6, GetX 4.6.6, Firebase suite, `flutter_downloader`,
  `permission_handler`, `image_picker`, `get_storage`, `shimmer`; no `package_info_plus`,
  `local_auth`, `flutter_secure_storage` or `disk_space`.

Reader code (`chapter_controller.dart`, `chapter_view.dart`, reader widgets) was **not modified**
in this task.

## 2. Existing functionality discovered

Theme switch (dark/light only), language switch (Arabic/English), three chapter-notification
toggles, account card (guest/signed-in/loading/offline cache), display-name and avatar editing,
bio editing, favourites cloud sync toggle, password change, sign-out, reading statistics,
bookmarks/history/downloads/storage shortcuts, About dialog with hard-coded version.

Authentication: email sign-in, registration wizard with username availability and suggestions,
Google sign-in/profile completion, guest mode, email verification screen with resend cooldown,
password-reset email, friendly Firebase errors, profile persistence cache.

Downloads: enqueue with duplicate prevention, persisted queue, pause/resume/cancel/retry,
completed/failed chapter tracking, persistent notifications with actions, two concurrent tasks.

Storage: per-comic grouping, file-size totals, multi-select delete, local-only comic detail entry.

## 3. Settings features added and repaired

- **Hub redesigned** into a control centre: account card, unverified-email banner, activity panel,
  and grouped sections — Appearance & Language, Reading, Library, About. Every row uses the shared
  tile/section system; no decorative rows were added.
- **System theme** (`ThemeMode.system`) supported end to end: preference mapping, profile
  controller, remote settings value, immediate `Get.changeThemeMode`, and legacy values still
  resolve to dark.
- **Appearance page** — light/dark/system selection with immediate feedback, Arabic/English
  selection, explanatory note for the system option.
- **Reading defaults page** — writes the same keys the reader reads (`reader_mode`,
  `reader_direction`, `reader_continuous_navigation`); the reader's per-chapter overrides are not
  overwritten. The hub row refreshes after the page closes.
- **Notifications page** — real OS permission status (`permission_handler`), request action,
  open-system-settings action, status refresh on app resume, and the existing favourite/manga/
  novel toggles. Download notifications are described honestly as belonging to the download
  manager and following the same OS permission.
- **About page** — version constant matching `pubspec.yaml` (`1.1.0`), real `showLicensePage`
  (GPL + Team X adapter license), and a confirmed "replay onboarding" action.
- **Persistence audit** — theme, language, notification toggles and reading defaults all persist
  and are re-read on startup; no setting has two independent copies. No fake "reset everything"
  or "clear history" control was added.

**Partial / not implemented:** no accent-colour picker (the design system has a single accent),
no interface font/density controls (no such capability exists), no notification sound selection
(the OS controls channel sound), no download-quality/location settings (the downloader has no such
knob), no Wi-Fi-only download setting (only chapter checks read `wifiOnly` today), and no
biometric lock.

## 4. Authentication changes

- **Implemented + tested:** a shared `AuthValidation` rule set used by the controller and covered
  by tests — email format, registration password (8+ chars, letter + digit), confirmation match,
  and a 0–2 strength score with labels.
- Registration step validation now reports specific messages from the same rules; sign-in only
  requires a non-empty password so legacy accounts with shorter passwords are not locked out.
- **Password strength bar** shown while creating a password (real value from the typed input).
- Duplicate-account and invalid-email Firebase errors now explain what to do instead of a generic
  failure; the existing neutral password-reset message (no account enumeration) is preserved.
- Email verification still requires Firebase's verified state — the button never fakes success.

**Partial:** the auth screens were not fully re-skinned; only validation/feedback changed. There is
no in-app new-password screen because the reset flow is the Firebase-hosted email link; deep-link
handling for that link is not implemented in this app. Terms acceptance, account deletion and
session-expiry UI are not implemented (no backend contract for deletion was found).

## 5. Profile changes

- Unverified-email banner in the hub with resend and refresh actions (uses Firebase
  `sendEmailVerification` and `reload`).
- Clearer account shortcuts: favourites, history, downloads, storage, and the detail screen with
  bio, account info, verification status, password change, favourites sync and sign-out.
- Guest/signed-in/loading/offline states remain the existing controller behaviour, including the
  local profile cache; the hub does not clear the card while offline.
- Reading statistics remain the real `ReadingStatsPanel` data.

**Not implemented:** username editing, account deletion, avatar cropping, and public profile
sharing. All would require backend changes or new dependencies and were not faked.

## 6. Splash and onboarding changes

- **Splash** keeps the existing brand animation but no longer uses a blind `800 ms` timer: it waits
  for a 650 ms minimum brand entrance and then routes from persisted state — onboarding on first
  launch, otherwise the shell. Firebase, storage and the download manager are already initialized
  before `runApp`, so there is no hidden initialization failure path to hang on.
- **Onboarding** is three short, visual steps:
  1. Welcome (logo + one action).
  2. Language (Arabic/English) and appearance (light/dark/system), applied immediately.
  3. Reading mode, direction, and an optional notification permission.
- Skip (confirmed) marks onboarding complete without writing reading defaults; finishing writes
  only the chosen defaults and the completion flag. Existing preferences are never erased.
- Completion is permanent across restarts and updates; it can be replayed from About.
- No forced account registration: guest access is unchanged.

## 7. Download manager changes

- Downloads screen now has real sections: **active** (downloading/paused), **queued**,
  **failed/cancelled**, **completed**, plus counts and per-section headers.
- Bulk **retry failed**, **clear completed records** (records only, files untouched) and
  **delete all completed files** (confirmed, active tasks untouched).
- Per-task **delete files** with confirmation; task details list each chapter with status and a
  delete control for chapters that are actually stored locally.
- Progress remains the manager's chapter-weighted value; no fabricated percentages. Errors show
  the task's real error message when present.
- Manager gained `removeCompletedTasks()`; it never deletes chapter files.

**Not changed / partial:** the two-worker concurrency is not configurable, there is no Wi-Fi-only
enforcement for downloads, and background process-termination recovery is whatever the existing
persisted queue already provides. Queue/file consistency is protected by only deleting files
through the library records.

## 8. Storage system changes

- Storage screen now starts with a **measured overview**: total downloaded bytes, manga vs novel
  bytes, chapter and work counts, and the decoded-image cache size explicitly labelled **(RAM)**.
- Manga bytes are summed from real files; novel bytes are text length × 2 (UTF-16), which is
  labelled as the storage representation rather than an on-disk file size.
- **Missing-file detection:** records whose image files no longer exist are dropped from the list
  and pruned from `downloadedChapters`, so totals and the offline library agree.
- **Cache cleanup** clears the Flutter image cache and the cover disk cache, with confirmation,
  and never touches downloaded chapters. Refresh action reloads measurements.
- Deletion remains per selected work, with confirmation, and a single ownership path for files.

**Partial / not implemented:** the cover cache package exposes no disk-size API, so disk cache size
is not displayed; free device space needs a platform/storage plugin and is not shown rather than
invented. Other cache directories (HTTP image cache beyond covers) are not separately reported.

## 9. Cross-system consistency improvements

- Clearing download **records** cannot remove offline files; clearing **files** is explicit and
  confirmed.
- Storage pruning removes only orphaned records, never files that still exist.
- Onboarding writes only its own keys; replay does not reset settings, downloads or account data.
- Downloads and storage read the same `downloadedChapters` structure; unverified/failed chapters
  are excluded from storage totals unless their files exist.
- Theme/language changes apply immediately and are persisted locally; remote sync remains
  best-effort and cannot overwrite a just-made local change within the same session (theme
  revision guard retained).

## 10. UI and animation improvements

- Settings hub and all new pages use shared sections/tiles/buttons, consistent icons, 36 px icon
  containers, inset dividers and one section rhythm.
- Sub-pages use the existing `rightToLeftWithFade` + `AppMotion.page` transition; onboarding uses
  page transitions and animated selection/dots; theme choices animate their check state.
- No new animation package; chrome avoids oversized cards, extra descriptions and repeated
  headings, and the long stats panel keeps its own scrolling layout.

## 11. New dependencies and reasons

**None.** The work uses the existing GetX, `get_storage`, `permission_handler`, Firebase,
`flutter_cache_manager` and the project design system.

## 12. Dependencies evaluated but rejected

- `flutter_animate` / `animations` / `lottie` — the native motion system already covers every
  transition used; new packages would add weight for no functional gain.
- `shimmer` — already a dependency; no new usage was needed.
- `package_info_plus` — a version constant matching `pubspec.yaml` is sufficient; adding a plugin
  just to read one string was not justified.
- `disk_space` — free-space numbers vary by platform/OEM; not displaying them is more honest than
  a plugin that may report misleading values.
- `local_auth` — biometric lock was not implemented, so the dependency was not added.
- `flutter_secure_storage` — no new sensitive value is stored locally; passwords/tokens remain in
  Firebase Auth. Adding storage for secrets that do not exist would be decorative.
- `cached_network_image`, `image_picker`, `firebase_auth` — already present and reused.

## 13. Files changed

New:

- `lib/app/core/settings/onboarding_service.dart`
- `lib/app/core/settings/reading_preferences.dart`
- `lib/app/core/auth/auth_validation.dart`
- `lib/app/core/storage/storage_utils.dart`
- `lib/app/modules/download/download_sections.dart`
- `lib/app/modules/onboarding/views/onboarding_view.dart`
- `lib/app/modules/profile/views/settings_appearance_view.dart`
- `lib/app/modules/profile/views/settings_reading_view.dart`
- `lib/app/modules/profile/views/settings_notifications_view.dart`
- `lib/app/modules/profile/views/settings_about_view.dart`
- `test/settings_platform_test.dart`
- `docs/SETTINGS_AUTH_PROFILE_STORAGE_OVERHAUL_REPORT.md`

Modified:

- `lib/app/core/theme/theme_mode_preference.dart` — system mode + legacy fallback.
- `lib/app/modules/profile/controllers/profile_controller.dart` — themeMode, setThemeMode,
  resolved brightness, reader-default snapshot, verification resend/refresh.
- `lib/app/modules/profile/views/profile_view.dart` — settings hub rewrite.
- `lib/app/modules/auth/controllers/auth_controller.dart` — shared validation + error messages.
- `lib/app/modules/auth/views/auth_view.dart` — password strength feedback.
- `lib/app/modules/download/views/download_view.dart` — sections, bulk actions, file deletion.
- `lib/app/modules/download/controllers/download_controller.dart` — verified deletion helpers.
- `lib/app/data/services/download_manager_service.dart` — completed-record removal only.
- `lib/app/modules/local_library/controllers/local_library_controller.dart` — measured totals,
  orphan pruning, cache clearing.
- `lib/app/modules/local_library/views/local_library_view.dart` — storage overview, refresh and
  cache actions.
- `lib/app/modules/splash/views/splash_view.dart` — state-driven first destination.
- `lib/app/routes/app_pages.dart`, `lib/app/routes/app_routes.dart` — onboarding route.
- `test/settings_platform_test.dart` + docs above.

## 14. Database / storage migrations

- No database schema or Firestore rules were changed.
- New local keys: `onboarding_completed`; new accepted value `system` for `themeMode` (unknown
  values still map to dark). Existing `language`, `themeMode`, notification keys and reader keys
  are untouched and were not renamed.
- `downloadedChapters` may be rewritten with orphaned records removed; this is a cleanup of
  records whose files no longer exist, not a format migration. No downloaded file is deleted by
  that cleanup.
- No account/session data is rewritten; Firebase Auth storage is untouched.

## 15. Tests executed and results

| Check | Result |
| --- | --- |
| `flutter analyze` | **28 issues, 0 errors, 0 warnings** (the same pre-existing infos as the baseline) |
| `flutter test` | **318 passed** (308 before this task + 10 new) |
| `flutter build bundle` | exit 0 |

New tests (`test/settings_platform_test.dart`):

- Theme mode mapping: legacy `null`/unknown → dark, full round-trip for light/dark/system.
- Reading defaults: normalization of unknown mode/direction, labels.
- Auth validation: email, password (length/letter/digit), confirmation, strength.
- Byte formatter: zero/negative, bytes, KB, MB without fake precision.
- Download sections: every task status lands in exactly one section; empty queue.

No test was skipped, weakened or removed to make this pass.

## 16. Build results

`flutter build bundle` succeeded. **No Android debug APK was built** because this environment has
no Android SDK/JDK/emulator; therefore notification permission prompts, Firebase Auth on device,
download notifications, cache clearing and the onboarding/splash transition were **not verified
on hardware**.

## 17. Known limitations

- Settings hub and sub-pages have not been visually inspected on a device.
- Auth is only partially redesigned: validation and feedback changed; the form layout is the
  existing one.
- Password reset uses Firebase's hosted email flow; there is no in-app reset form or deep link.
- No account deletion, username change, biometric lock, accent-colour picker, or download
  WiFi-only/quality settings.
- Download concurrency remains the manager's fixed two workers.
- Free device storage and cover-cache disk size are intentionally not shown.
- Notification permission denial on Android 13+ leaves the in-app toggles enabled while the OS
  blocks delivery; the status row explains the state but there is no automatic toggle-off.
- Sign-out keeps the existing behaviour of clearing local bookmarks/history/readChapters; this
  was not changed because it is existing account behaviour, and it is called out here.
- Reading defaults apply to new reader sessions; a chapter already open keeps its live value.
- Onboarding replay while the app is inside a tab route uses `offAllNamed`, which resets the main
  navigation stack; no user data is affected.

## 18. Remaining work

1. Device pass: Android 13+ notification permission, onboarding/splash transitions, auth
   sign-in/verification, cache-clear results and download deletion.
2. Decide and implement account deletion with a real backend contract, or state clearly in the
   app that it is unavailable.
3. Full visual redesign of the auth screens (shared inputs/buttons, consistent RTL layout) on top
   of the new validation.
4. Optional: configurable download concurrency and a real Wi-Fi-only enforcement path.
5. Optional: report actual cache disk usage if the cache package exposes a size API.
6. Optional: an in-app reset-password screen if Firebase action links are wired.
