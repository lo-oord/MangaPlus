import 'package:flutter_test/flutter_test.dart';
import 'package:mangaplus/app/data/services/comic_service.dart';
import 'package:mangaplus/app/data/services/genre_service.dart';
import 'package:mangaplus/app/data/sources/source_base.dart';
import 'package:mangaplus/app/data/sources/team_x_source.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('latest feed is loaded and date-sorted from the chosen manga source', () async {
    final source = _CatalogSource('picked', [
      _work('Older', '2026-01-01T10:00:00Z', ['أكشن']),
      _work('Newest', '2026-02-01T10:00:00Z', ['دراما']),
    ]);
    final service = ComicService(sourceById: (id) => id == source.id ? source : null);

    final result = await service.fetchComics(sourceId: source.id);

    expect(result.source, source.name);
    expect(result.comicsList.map((item) => item.title).toList(), ['Newest', 'Older']);
    expect(result.comicsList.map((item) => item.source).toSet(), {source.name});
  });

  test('selected Team X latest feed is ordered by chapter publication date', () async {
    final source = TeamXSource(client: _teamXFeedClient());
    final service = ComicService(
      source: source,
      sourceById: (id) => id == source.id ? source : null,
    );

    final result = await service.fetchComics(sourceId: source.id);

    expect(
      result.comicsList.map((item) => item.title).toList(),
      ['Newer chapter', 'Older chapter'],
    );
    expect(
      result.comicsList.map((item) => item.latestChapterDate).toList(),
      ['2026-11-07T14:00:00.000Z', '2026-11-06T14:00:00.000Z'],
    );
  });

  test('source-specific genres and genre results exclude other sources', () async {
    final picked = _CatalogSource('picked', [
      _work('Picked action', '', ['أكشن']),
      _work('Picked fantasy', '', ['فانتازيا']),
    ]);
    final other = _CatalogSource('other', [
      _work('Other action', '', ['أكشن']),
      _work('Other romance', '', ['رومانسية']),
    ]);
    final teamX = TeamXSource(
      client: MockClient((_) async => http.Response('unavailable', 503)),
    );
    final service = GenreService(source: teamX, sources: [teamX, picked, other]);

    final genres = await service.fetchGenres(sourceId: picked.id);
    final results = await service.fetchGenreDetail(
      'أكشن',
      genreName: 'أكشن',
      sourceId: picked.id,
    );

    expect(genres.source, picked.name);
    expect(genres.genres.map((genre) => genre.link).toSet(), {'أكشن', 'فانتازيا'});
    expect(results.source, picked.name);
    expect(results.comicsList.map((comic) => comic.title), ['Picked action']);
  });

  test('a selected novel source supplies latest works and its own genres', () async {
    final source = _CatalogSource(
      'novel-picked',
      [
        _work('Novel action', '2026-03-01T10:00:00Z', ['مغامرة'], type: 'novel'),
      ],
      kind: 'novel',
    );
    final comicService =
        ComicService(sourceById: (id) => id == source.id ? source : null);
    final teamX = TeamXSource(
      client: MockClient((_) async => http.Response('unavailable', 503)),
    );
    final genreService = GenreService(source: teamX, sources: [teamX, source]);

    final latest = await comicService.fetchComics(sourceId: source.id);
    final genres = await genreService.fetchGenres(sourceId: source.id);
    final genreWorks = await genreService.fetchGenreDetail(
      'مغامرة',
      genreName: 'مغامرة',
      sourceId: source.id,
    );

    expect(latest.comicsList.single.type, 'novel');
    expect(genres.source, source.name);
    expect(genres.genres.map((genre) => genre.link), ['مغامرة']);
    expect(genreWorks.source, source.name);
    expect(genreWorks.type, 'novel');
    expect(genreWorks.comicsList.single.type, 'novel');
  });
}

Map<String, dynamic> _work(
  String title,
  String date,
  List<String> genres, {
  String type = 'manga',
}) => {
      'title': title,
      'url': 'https://$title.example/series/$title',
      'image_url': '',
      'type': type,
      'latest_chapter_date': date,
      'latest_chapter_number': 12,
      'rating': '8.4',
      'genres': genres,
    };

class _CatalogSource extends ContentSource {
  _CatalogSource(this.id, this.works, {this.kind = 'manga'});

  @override
  final String id;
  final List<Map<String, dynamic>> works;

  @override
  String get name => 'Source $id';
  @override
  final String kind;
  @override
  List<String> get hosts => const ['example.test'];
  @override
  Future<List<Map<String, dynamic>>> search(String query) async => works;
  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) async => works;
  @override
  Future<List<Map<String, dynamic>>> catalog({int page = 1}) async => works;
  @override
  Future<Map<String, dynamic>> details(String url) async =>
      works.firstWhere((work) => work['url'] == url);
  @override
  Future<Map<String, dynamic>?> streams(String url) async => null;
}

http.Client _teamXFeedClient() => MockClient((request) async {
      if (request.url.path == '/') {
        return http.Response('''
          <div class="box">
            <div class="uta">
              <div class="imgu"><a href="/series/older"><img src="/older.jpg"></a></div>
              <div class="info"><h3>Older chapter</h3><a href="/series/older/12">الفصل 12</a></div>
            </div>
            <div class="uta">
              <div class="imgu"><a href="/series/newer"><img src="/newer.jpg"></a></div>
              <div class="info"><h3>Newer chapter</h3><a href="/series/newer/8">الفصل 8</a></div>
            </div>
          </div>
        ''', 200, headers: {'content-type': 'text/html; charset=utf-8'});
      }
      if (request.url.path == '/series/older') {
        return http.Response('''
          <div class="chapter-card" data-number="12" data-date="2026-11-06T14:00:00Z">
            <span class="chapter-number">الفصل 12</span><h3 class="chapter-title">الفصل 12</h3>
          </div>
        ''', 200, headers: {'content-type': 'text/html; charset=utf-8'});
      }
      if (request.url.path == '/series/newer') {
        return http.Response('''
          <div class="chapter-card" data-number="8" data-date="2026-11-07T14:00:00Z">
            <span class="chapter-number">الفصل 8</span><h3 class="chapter-title">الفصل 8</h3>
          </div>
        ''', 200, headers: {'content-type': 'text/html; charset=utf-8'});
      }
      return http.Response('not found', 404);
    });
