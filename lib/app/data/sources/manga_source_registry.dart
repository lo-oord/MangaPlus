import 'dart:async';
import 'manga_swat_source.dart';
import 'azora_source.dart';
import 'mangatime_source.dart';
import 'manga_online_source.dart';
import 'lava_scans_source.dart';
import 'mangatek_source.dart';
import 'manga_sid_source.dart';
import 'team_x_source.dart';
import 'mknov_source.dart';
import 'kawaii_manga_source.dart';
import 'kawaii_novels_source.dart';
import 'cenele_source.dart';
import 'mangadar_source.dart';
import 'kolnovel_source.dart';
import 'procomic_source.dart';
import 'hijala_source.dart';
import 'seanovel_source.dart';
import 'despair_source.dart';
import 'hizomanga_source.dart';
import 'mangatik_source.dart';
import 'search_relevance.dart';
import 'source_base.dart';

class MangaSourceRegistry {
  MangaSourceRegistry._();

  static final TeamXSource teamX = TeamXSource();
  static final MangaSwatSource mangaSwat = MangaSwatSource();
  static final AzoraSource azora = AzoraSource();
  static final MangaTimeSource mangaTime = MangaTimeSource();
  static final MangaOnlineSource mangaOnline = MangaOnlineSource();
  static final LavaScansSource lavaScans = LavaScansSource();
  static final MangaTekSource mangaTek = MangaTekSource();
  static final MangaSidSource mangaSid = MangaSidSource();
  static final MknovSource mknov = MknovSource();
  static final KawaiiMangaSource kawaiiManga = KawaiiMangaSource();
  static final KawaiiNovelsSource kawaiiNovels = KawaiiNovelsSource();
  static final CeneleNovelSource ceneleNovels = CeneleNovelSource();
  static final CeneleMangaSource ceneleManga = CeneleMangaSource();
  static final MangaDarSource mangaDar = MangaDarSource();
  static final KolNovelSource kolNovel = KolNovelSource();
  static final ProComicSource proComic = ProComicSource();
  static final HijalaSource hijala = HijalaSource();
  static final SeanovelSource seaNovel = SeanovelSource();
  static final DespairMangaSource despairManga = DespairMangaSource();
  static final DespairNovelsSource despairNovels = DespairNovelsSource();
  static final HizoMangaSource hizoManga = HizoMangaSource();
  static final MangaTikSource mangaTik = MangaTikSource();

  static List<ContentSource> get mangaSources => searchableSources
      .where((source) => source.kind == 'manga')
      .toList(growable: false);

  static ContentSource? byId(String id) {
    for (final source in searchableSources) {
      if (source.id == id) return source;
    }
    return null;
  }

  /// Team X is intentionally excluded from the multi-source home feed contract;
  /// the home screen calls it directly through [ComicService.fetchComics].
  static List<ContentSource> get searchableSources => [
        teamX,
        mangaSwat,
        azora,
        mangaTime,
        mangaOnline,
        lavaScans,
        mangaTek,
        mangaSid,
        mknov,
        kawaiiManga,
        kawaiiNovels,
        ceneleNovels,
        ceneleManga,
        mangaDar,
        kolNovel,
        proComic,
        hijala,
        seaNovel,
        despairManga,
        despairNovels,
        hizoManga,
        mangaTik,
      ];

  static ContentSource? forUrl(String url) {
    for (final source in searchableSources) {
      if (source.handles(url)) return source;
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>> search(
    String query, {
    void Function(List<Map<String, dynamic>> batch)? onBatch,
    Iterable<ContentSource>? sources,
    Duration progressiveDeadline = const Duration(seconds: 15),
  }) async {
    final batches = <Map<String, dynamic>>[];
    final sourcesToSearch = sources ?? searchableSources;
    final sourceRequests = Future.wait(sourcesToSearch.map((source) async {
      try {
        final result = await source.search(query).timeout(
              source.id == 'kawaii_novels'
                  ? const Duration(seconds: 90)
                  : source.id == 'mknov'
                  ? const Duration(seconds: 45)
                  : source.id == 'azora'
                  ? const Duration(seconds: 35)
                  : source.id == 'mangasid'
                  ? const Duration(seconds: 30)
                  : const Duration(seconds: 18),
            );
        final relevant = result.where(
          (item) => SearchRelevance.isRelevant(query, item),
        );
        final tagged = relevant.map((item) => {
              ...item,
              'source_id': item['source_id'] ?? source.id,
              'source': item['source'] ?? source.name,
            }).toList(growable: false);
        if (tagged.isNotEmpty) {
          batches.addAll(tagged);
          onBatch?.call(tagged);
        }
      } catch (_) {
        // A down source must never block the results of healthy sources.
      }
    }));
    if (onBatch == null) {
      await sourceRequests;
    } else {
      // Return the early snapshot for the UI, but do not cancel the other
      // source futures: their onBatch callbacks can still add late results.
      final deadline = Completer<void>();
      final timer = Timer(progressiveDeadline, () {
        if (!deadline.isCompleted) deadline.complete();
      });
      try {
        await Future.any<void>([
          sourceRequests.then<void>((_) {}),
          deadline.future,
        ]);
      } finally {
        timer.cancel();
      }
    }
    final seen = <String>{};
    return batches.where((item) {
      final key = '${item['source_id']}|${item['url']}';
      return seen.add(key);
    }).toList(growable: false);
  }
}
