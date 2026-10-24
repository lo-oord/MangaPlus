import 'manga_swat_source.dart';
import 'azora_source.dart';
import 'mangatime_source.dart';
import 'manga_online_source.dart';
import 'lava_scans_source.dart';
import 'mangatek_source.dart';
import 'mangacloud_source.dart';
import 'team_x_source.dart';
import 'mknov_source.dart';
import 'kawaii_manga_source.dart';
import 'kawaii_novels_source.dart';
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
  static final MangaCloudSource mangaCloud = MangaCloudSource();
  static final MknovSource mknov = MknovSource();
  static final KawaiiMangaSource kawaiiManga = KawaiiMangaSource();
  static final KawaiiNovelsSource kawaiiNovels = KawaiiNovelsSource();

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
        mangaCloud,
        mknov,
        kawaiiManga,
        kawaiiNovels,
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
  }) async {
    final batches = <Map<String, dynamic>>[];
    await Future.wait(searchableSources.map((source) async {
      try {
        final result = await source.search(query).timeout(
              source.id == 'mknov' || source.id == 'kawaii_novels'
                  ? const Duration(seconds: 45)
                  : source.id == 'azora'
                  ? const Duration(seconds: 35)
                  : const Duration(seconds: 18),
            );
        final tagged = result.map((item) => {
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
    final seen = <String>{};
    return batches.where((item) {
      final key = '${item['source_id']}|${item['url']}';
      return seen.add(key);
    }).toList(growable: false);
  }
}
