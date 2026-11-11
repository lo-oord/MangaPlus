# MangaPlus source health audit

Last verified: 2026-11-06 (live network, Flutter 3.27.1 / Dart 3.6.0).

Update 2026-11-11: MangaTek and Mangasid were removed from the active app registry;
their rows below preserve the historical probe results only.

## How to reproduce

Hermetic registry contract (runs in CI with no network):

```bash
flutter test test/source_contract_test.dart
```

Live per-source probe (network required, kept out of `test/` so CI stays offline):

```bash
# all sources
flutter test test_live/source_live_probe_test.dart
# one source at a time
flutter test test_live/source_live_probe_test.dart --dart-define=SOURCE_ID=team_x_manga
```

Each probe checks, independently per source: latest feed, search, work details and
chapter list, reader payload (pages or novel text), and URL routing back to the
source. A failing source never blocks the others: the registry catches per-source
errors, and search returns whatever healthy sources produce.

## Results

| Source | id | Latest / search | Details + chapters | Reader | Status |
| --- | --- | --- | --- | --- | --- |
| Team X | `team_x_manga` | pass | pass | pages pass | Working |
| Manga Swat | `manga_swat` | pass | pass | pages pass | Working (one transient 500 observed, retried clean) |
| Manga Time | `mangatime` | pass | pass | pages pass | Working |
| Azora | `azora` | pass | pass | pages pass | Working (fixed: HTTP links were rejected by `handles`) |
| Manga Online | `manga_online` | pass | pass | pages pass | Fixed: moved from dead `onma.top` to `manonga.online`, chapter filter accepted only the old host |
| Lava Scans | `lava_scans` | pass | pass | pages pass | Working |
| Kawaii Manga | `kawaii_manga` | pass | pass | pages pass | Working |
| Kawaii Novels | `kawaii_novels` | pass | pass | text pass | Working |
| KolNovel | `kolnovel` | pass | pass | text pass | Working |
| SeaNovel | `seanovel` | pass | pass | text pass | Working |
| MKNOV | `mknov` | pass | pass | network/parse pass; native WOFF2 decode skipped in VM | Partially verified (Android-only decoder) |
| Cenele Manga | `cenele_manga` | pass | pass | text pass | Fixed: catalog pagination no longer aborts on a 404 page; reader selector updated for `story-fold` |
| Cenele Novels | `cenele_novels` | pass | pass | text pass | Fixed: same catalog + reader fixes |
| MangaTek | `mangatek` | pass (API) | pass (fixed runtime crash in genre parsing) | blocked: `mangatek.com` returns Cloudflare 403 to non-browser clients | Removed from app (historically partially working) |
| Mangasid | `mangasid` | blocked: Cloudflare "Just a moment" 403 | blocked | blocked | Removed from app (historically blocked upstream) |
| MangaDar | `mangadar` | blocked: Cloudflare 403 | blocked | blocked | Blocked upstream |
| ProComic | `procomic` | blocked: API now requires a Cloudflare Turnstile token | blocked | blocked | Blocked upstream |
| Hijala | `hijala` | blocked: Cloudflare 403 | blocked | blocked | Blocked upstream |
| Asgard Scans | `asgard` | unavailable: domain serves a "website stopped" page (404 on all routes) | unavailable | unavailable | Offline upstream |

MangaTek and Mangasid are no longer registered and cannot be resolved by URL.
Other blocked sources stay registered and fail in isolation, so the home feed,
search and reader keep working with the remaining sources.
