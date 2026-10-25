import 'package:get/get.dart';
import 'package:mangaplus/app/data/models/comic.dart';
import 'package:mangaplus/app/data/models/genre.dart';
import 'package:mangaplus/app/data/services/comic_service.dart';
import 'package:mangaplus/app/core/translations/content_localization.dart';
import 'package:mangaplus/app/data/sources/manga_source_registry.dart';
import 'package:mangaplus/app/data/sources/source_base.dart';
import 'package:mangaplus/app/data/sources/team_x_source.dart';

class GenreService extends GetxService {
  GenreService({TeamXSource? source}) : _source = source ?? TeamXSource();

  final TeamXSource _source;

  Future<GenreData> fetchGenres() async {
    final entriesRequest = _source.genres();
    final taggedSources = MangaSourceRegistry.searchableSources.where(
      (source) => const {
        'azora',
        'manga_swat',
        'mangatime',
        'manga_cloud',
        'kawaii_manga',
      }.contains(source.id),
    );
    final batchesRequest = Future.wait(taggedSources.map((source) async {
      try {
        return await source.latest(page: 1).timeout(const Duration(seconds: 10));
      } catch (_) {
        return <Map<String, dynamic>>[];
      }
    }));
    final entries = await entriesRequest;
    final names = <String, Genre>{};
    for (final entry in entries) {
      final name = '${entry['name'] ?? ''}'.trim();
      final value = '${entry['value'] ?? ''}'.trim();
      if (name.isNotEmpty && value.isNotEmpty) {
        names.putIfAbsent(_normalizeGenre(name), () => Genre(
          name: localizeContentGenre(name),
          seriesCount: 0,
          link: value,
        ));
      }
    }
    final batches = await batchesRequest;
    for (final batch in batches) {
      for (final item in batch) {
        final genres = item['genres'];
        if (genres is! List) continue;
        for (final value in genres) {
          final name = value is Map ? '${value['name'] ?? ''}'.trim() : '$value'.trim();
          if (name.isNotEmpty) {
            names.putIfAbsent(_normalizeGenre(name), () => Genre(
              name: localizeContentGenre(name),
              seriesCount: 0,
              link: name,
            ));
          }
        }
      }
    }
    return GenreData(
      genres: names.values.toList(growable: false),
      source: ComicService.sourceName,
    );
  }

  Future<ComicData> fetchGenreDetail(String genre, {int page = 1, String genreName = ''}) async {
    final normalizedGenre = _normalizeGenre(genreName.isEmpty ? genre : genreName);
    final sources = MangaSourceRegistry.searchableSources.where(
      (source) => source.id != _source.id && source.id != 'kawaii_novels',
    );
    final teamXRequest = _source
        .catalogPage(genre: genre, page: page)
        .timeout(const Duration(seconds: 15))
        .then<TeamXCatalogPage?>((value) => value)
        .catchError((_) => null);
    final fetched = await Future.wait(sources.map((source) async {
      try {
        final items = await source.catalog(page: page).timeout(const Duration(seconds: 12));
        return (source: source, items: items.take(30).toList());
      } catch (_) {
        return (source: source, items: <Map<String, dynamic>>[]);
      }
    }));
    final teamX = await teamXRequest;
    final teamXItems = teamX?.items ?? <Map<String, dynamic>>[];
    final teamXNextPage = teamX?.nextPage;
    final candidates = <(ContentSource, Map<String, dynamic>)>[];
    for (final batch in fetched) {
      var detailOnlyCount = 0;
      for (final item in batch.items) {
        final genres = item['genres'];
        if ((genres is! List || genres.isEmpty) && detailOnlyCount >= 8) continue;
        if (genres is! List || genres.isEmpty) detailOnlyCount++;
        candidates.add((batch.source, item));
      }
    }
    final matching = <Map<String, dynamic>>[];
    for (var start = 0; start < candidates.length; start += 12) {
      final end = start + 12 < candidates.length ? start + 12 : candidates.length;
      final enriched = await Future.wait(candidates.sublist(start, end).map((candidate) async {
        final source = candidate.$1;
        final item = candidate.$2;
        var result = item;
        var tags = item['genres'];
        if (tags is! List || tags.isEmpty) {
          try {
            result = {...item, ...await source.details('${item['url'] ?? ''}').timeout(const Duration(seconds: 10))};
            tags = result['genres'];
          } catch (_) {
            return null;
          }
        }
        if (tags is! List || !tags.any((tag) => _normalizeGenre(tag is Map ? '${tag['name'] ?? ''}' : '$tag') == normalizedGenre)) return null;
        return result;
      }));
      matching.addAll(enriched.whereType<Map<String, dynamic>>());
    }
    final itemsById = <String, Map<String, dynamic>>{};
    for (final item in [...teamXItems, ...matching]) {
      final id = '${item['url'] ?? ''}';
      if (id.isNotEmpty) itemsById.putIfAbsent(id, () => item);
    }
    final hasMore = teamXNextPage != null || fetched.any((batch) => batch.items.isNotEmpty);
    if (itemsById.isEmpty && hasMore && page < 4) {
      return fetchGenreDetail(genre, page: page + 1, genreName: genreName);
    }
    return ComicData(
      comicsList: itemsById.values
          .map(ComicService.mapComicItem)
          .toList(growable: false),
      pagination: Pagination(
        currentPage: page,
        prevPage: page > 1 ? page - 1 : null,
        nextPage: hasMore ? page + 1 : null,
      ),
      source: 'Manga sources',
      page: page,
      genres: [genre],
      status: '',
      type: 'manga',
      orderby: '',
    );
  }

  String _normalizeGenre(String value) =>
      localizeContentGenre(value).trim().toLowerCase().replaceAll(RegExp(r'[\s\-_]+'), '');
}
