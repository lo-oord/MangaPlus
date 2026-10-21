# Team X content source

MangaPlus uses Team X at `https://olympustaff.com` as its manga content provider. This is an HTML-backed source rather than a JSON API. Manga titles, search, latest updates, catalog genres, series details, and unlocked chapter pages are read directly from the website. Favorites, reading history, and downloaded pages remain local to the device.

## Integration behavior

- Search: `/search?keyword=...`.
- Latest titles: `/` with `?page=N` for later pages.
- Catalog and genre filters: `/series/` with `genre=<Arabic genre>` and optional `page=N`.
- Series details and chapters: `/series/<series-slug>`.
- Chapter images are read from the chapter page. Locked chapters are omitted; the reader does not attempt to purchase, bypass, or retrieve locked content.
- The app stores stable `teamx://` identifiers that wrap validated HTTPS URLs for `olympustaff.com` only.

## Live smoke check

On 2026-10-21, the source pages returned HTTP 200: [Team X home](https://olympustaff.com/), [series catalog](https://olympustaff.com/series/), and [search](https://olympustaff.com/search?keyword=Apocalypse%20Veteran). The search response contained a title card using the selector expected by the adapter. The catalog exposed 128 genre options and accepted `genre=أكشن` as a filter. The latest feed contained 40 title cards.

The public sample chapter [Fast Break, chapter 15](https://olympustaff.com/series/fast-break/15) returned 30 page-image elements. Its first page image responded with HTTP 200 and `image/png` when requested with the site as the referrer. This confirms that the page-image path used by the reader and download flow was reachable at the time of the check. The Team X website may change its HTML, so the scraper can require updates if its page structure changes.

## License and attribution

The Team X adapter is adapted from `IWatch-main/lib/sources/team_x_source.dart` and its helper files in the user-provided IWatch archive. The IWatch archive identifies itself as GNU GPL version 3. This repository therefore includes the full GPL-3.0 license, retains attribution in the adapted files, and exposes the license through the app's Licenses screen. The Team X integration and the related application changes are distributed under GPL-3.0.
