import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mangaplus/app/data/sources/dilar_source.dart';
import 'package:mangaplus/app/data/sources/manga_source_registry.dart';
import 'package:mangaplus/app/data/sources/source_brand.dart';

void main() {
  test('Dilar is registered and resolves its site brand and links', () {
    final source = MangaSourceRegistry.byId('dilar');
    expect(source, isA<DilarSource>());
    expect(source!.kind, 'manga');
    expect(source.handles('https://dilar.tube/series/123/example'), isTrue);
    expect(source.handles('dilar://series/123'), isTrue);
    expect(
      MangaSourceRegistry.forUrl(
        'https://dilar.tube/reader/123/title/1?release=7',
      )?.id,
      'dilar',
    );
    expect(
      SourceBrand.siteFor('Dilar', 'https://dilar.tube/series/123')?.host,
      'dilar.tube',
    );
  });

  test('latest and popular items include usable cover, rating, status, genres and date', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/api/series') {
        expect(request.url.queryParameters['page'], '2');
        return _json({
          'series': [_series()],
          'currentPage': 2,
          'totalPages': 5,
        });
      }
      if (request.url.path == '/api/rankings') {
        return _json({
          'topSeries': [_series()],
        });
      }
      return http.Response('not found', 404);
    });
    final source = DilarSource(client: client);
    final latest = await source.latest(page: 2);
    final popular = await source.catalog();

    for (final item in [latest.single, popular.single]) {
      expect(item['source_id'], 'dilar');
      expect(item['source'], 'Dilar');
      expect(item['title'], 'Example Manga');
      expect(item['url'], 'https://dilar.tube/series/123/example-manga');
      expect(
        item['image_url'],
        'https://dilar.tube/uploads/manga/cover/123/large_cover-file.webp',
      );
      expect(item['rating'], '8.75');
      expect(item['status'], 'ongoing');
      expect(item['latest_chapter_number'], '12');
      expect(item['latest_chapter_date'], '2026-11-08T20:00:00.000Z');
      expect(item['genres'], ['أكشن', 'دراما']);
    }
  });

  test('search sends Dilar filters and keeps results paginated', () async {
    http.Request? captured;
    final client = MockClient((request) async {
      captured = request;
      return _json({
        'rows': [_series()],
        'total': 31,
        'page': 3,
        'perPage': 10,
      });
    });
    final source = DilarSource(client: client);
    final result = await source.nextPage(query: 'مثال', page: 3);

    expect(result, hasLength(1));
    expect(captured!.method, 'POST');
    expect(captured!.url.path, '/api/search/filter');
    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    expect(body['query'], 'مثال');
    expect(body['page'], 3);
    expect((body['seriesType'] as Map)['exclude'], ['99']);
    expect(body['categories'], {'include': <int>[], 'exclude': <int>[]});
    expect(body['over17'], isNull);
    expect(result.single['rating'], '8.75');
    expect(result.single['status'], 'ongoing');
  });

  test('quick search returns only manga and enriches card metadata', () async {
    http.Request? searchRequest;
    final client = MockClient((request) async {
      if (request.url.path == '/api/search/quick_search') {
        searchRequest = request;
        return _json([
          {
            'class': 'Team',
            'data': [
              {'id': '76', 'name': 'Solo leveling'},
            ],
          },
          {
            'class': 'Manga',
            'data': [
              {
                'id': '123',
                'title': 'Example Manga',
                'cover': 'cover-file.webp',
                'series_type': {'id': '2', 'title': 'مانهوا'},
                'synonyms': ['مثال مانجا'],
              },
              {
                'id': '900',
                'title': 'Example Novel',
                'series_type': {'id': '99', 'title': 'رواية'},
              },
            ],
          },
        ]);
      }
      if (request.url.path == '/api/series/123') return _json(_series());
      return http.Response('not found', 404);
    });
    final results = await DilarSource(client: client).search('مثال مانجا');

    expect(searchRequest!.method, 'POST');
    expect(searchRequest!.url.path, '/api/search/quick_search');
    expect(jsonDecode(searchRequest!.body), {
      'query': 'مثال مانجا',
      'includes': ['Manga'],
      'lite': false,
      'synonyms': 'matched',
    });
    expect(results, hasLength(1));
    expect(results.single['title'], 'Example Manga');
    expect(results.single['rating'], '8.75');
    expect(results.single['status'], 'ongoing');
    expect(results.single['latest_chapter_date'], '2026-11-08T20:00:00.000Z');
    expect(results.single['alternate_titles'], contains('مثال مانجا'));
  });

  test('details return metadata, newest release date, chapter links and thumbnails', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/api/series/123') return _json(_series());
      if (request.url.path == '/api/series/123/chapters') {
        return _json({
          'chapters': [
            {
              'id': 'c11',
              'chapter': '11.00',
              'title': 'الفصل الأخير',
              'created_at': '2026-11-08T19:59:00.000Z',
              'releases': [
                {
                  'id': 'r11',
                  'created_at': '2026-11-08T20:00:00.000Z',
                  'init_team_id': '1',
                  'thumbnail': 'thumb.webp',
                  'thumbnail_meta': {
                    'path': '/uploads/thumbnail/1/123/r11/thumb.webp',
                  },
                },
              ],
            },
            {
              'id': 'c10',
              'chapter': '10.00',
              'created_at': '2026-11-01T20:00:00.000Z',
              'releases': [
                {'id': 'r10', 'created_at': '2026-11-01T20:00:00.000Z'},
              ],
            },
          ],
          'totalItems': 2,
        });
      }
      return http.Response('not found', 404);
    });
    final detail = await DilarSource(client: client)
        .details('https://dilar.tube/series/123/example-manga');
    final chapters = detail['chapters'] as List<Map<String, dynamic>>;

    expect(detail['title'], 'Example Manga');
    expect(detail['rating'], '8.75');
    expect(detail['status'], 'ongoing');
    expect(detail['synopsis'], 'Description');
    expect(detail['author'], 'Writer');
    expect(detail['artist'], 'Artist');
    expect(detail['release_year'], '2024');
    expect(detail['total_chapters'], 2);
    expect(detail['latest_chapter_date'], '2026-11-08T20:00:00.000Z');
    expect(chapters.map((chapter) => chapter['number']), [11, 10]);
    expect(
      chapters.first['url'],
      'https://dilar.tube/reader/123/example-manga/11.00?release=r11',
    );
    expect(chapters.first['release_date'], '2026-11-08T20:00:00.000Z');
    expect(
      chapters.first['thumbnail'],
      'https://dilar.tube/uploads/thumbnail/1/123/r11/thumb.webp',
    );
    expect(
      MangaSourceRegistry.forUrl(chapters.first['url'] as String)?.id,
      'dilar',
    );
  });

  test(
    'status values are normalized and empty search makes no request',
    () async {
      var requestCount = 0;
      final client = MockClient((request) async {
        requestCount++;
        return _json({'rows': []});
      });
      final source = DilarSource(client: client);
      expect(await source.search('  '), isEmpty);
      expect(requestCount, 0);
      expect(await source.search('x'), isEmpty);
      expect(requestCount, 1);
    },
  );

  test('decrypted reader manifest produces ordered signed page URLs', () {
    final pages = DilarSource.pageUrlsFromManifest({
      'storage_key': 'release-folder',
      'media_token': 'signed token',
      'pages': [
        {'url': 'page-2.webp', 'order': 2},
        {'url': 'page-1.webp', 'order': 1},
      ],
    });

    expect(pages, [
      'https://dilar.tube/uploads/releases/release-folder/hq/page-1.webp?t=signed+token',
      'https://dilar.tube/uploads/releases/release-folder/hq/page-2.webp?t=signed+token',
    ]);
  });
}

Map<String, dynamic> _series() => {
  'id': '123',
  'title': 'Example Manga',
  'cover': 'cover-file.png',
  'rating': '8.75',
  'translation_status': 'ongoing',
  'story_status': 'ongoing',
  'total_chapters': 12,
  'chapterCount': 12,
  'updated_at': '2026-11-08T20:00:00.000Z',
  's_date': '2024-06-01',
  'summary': 'Description',
  'series_type_id': '2',
  'seriesType': {'id': '2', 'title': 'مانهوا'},
  'latestChapter': {'id': 'c12', 'chapter': '12.00'},
  'categories': [
    {'id': '1', 'name': 'أكشن'},
    {'id': '2', 'name': 'دراما'},
  ],
  'staff': [
    {
      'name': 'Writer',
      'Staff': {'role': 'Author'},
    },
    {
      'name': 'Artist',
      'Staff': {'role': 'Artist'},
    },
  ],
  'synonyms': {
    'arabic': ['مثال مانجا'],
    'english': ['An Example Manga'],
  },
};

http.Response _json(Object value) => http.Response(
  jsonEncode(value),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
