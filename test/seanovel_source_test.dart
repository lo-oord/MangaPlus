import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mangaplus/app/data/sources/manga_source_registry.dart';
import 'package:mangaplus/app/data/sources/seanovel_source.dart';

void main() {
  test('registry includes SeaNovel as a novel source', () {
    expect(MangaSourceRegistry.searchableSources,
        contains(MangaSourceRegistry.seaNovel));
    expect(
      MangaSourceRegistry.forUrl(
          'https://seanovel.org/novels/the-greatest-sinner'),
      same(MangaSourceRegistry.seaNovel),
    );
  });

  test('SeaNovel search, details and chapter content work', () async {
    final source = SeanovelSource(client: MockClient((request) async {
      if (request.url.path == '/api/search-index') {
        return http.Response.bytes(utf8.encode(_index), 200);
      }
      if (request.url.path == '/api/novel/the-greatest-sinner/chapters') {
        return http.Response.bytes(utf8.encode(_chapters), 200);
      }
      if (request.url.path.contains('/chapters/326')) {
        return http.Response.bytes(utf8.encode(_chapter), 200);
      }
      return http.Response.bytes(utf8.encode(_novel), 200);
    }));

    final results = await source.search('greatest sinner');
    expect(results, hasLength(1));
    expect(results.single['image_url'],
        contains('/api/novel/the-greatest-sinner/cover'));

    final details = await source.details(
      'https://seanovel.org/novels/the-greatest-sinner',
    );
    expect(details['chapters'], hasLength(2));
    expect(details['total_chapters'], 2);
    expect(details['latest_chapter_number'], 326);
    expect(details['latest_chapter_date'], '2026-11-07T10:00:00.000Z');
    expect(
      (details['chapters'] as List<Map<String, dynamic>>).last['release_date'],
      '2026-11-07T10:00:00.000Z',
    );

    final chapter = await source.chapterContent(
      'https://seanovel.org/novels/the-greatest-sinner/chapters/326',
    );
    expect(chapter?['chapter_number'], 326);
    expect(chapter?['content'], contains('نص الفصل'));
  });

  test('latest list includes rating and publish/update dates from novel API',
      () async {
    final entries = [
      _indexEntry(
        'sea-older',
        'رواية أقدم',
        '2026-11-06T08:00:00.000Z',
        '2026-10-01T08:00:00.000Z',
      ),
      _indexEntry(
        'sea-newer',
        'رواية أحدث',
        '2026-11-07T21:30:00.000Z',
        '2026-10-05T08:00:00.000Z',
      ),
    ];
    final source = SeanovelSource(
      client: MockClient((request) async {
        if (request.url.path == '/api/search-index') return _json(entries);
        final slug = request.url.pathSegments.last;
        return _json({
          'slug': slug,
          'rating': slug == 'sea-newer' ? 4.6 : 3.8,
          'last_updated': slug == 'sea-newer'
              ? '2026-11-07T21:30:00.000Z'
              : '2026-11-06T08:00:00.000Z',
          'first_published_at': slug == 'sea-newer'
              ? '2026-10-05T08:00:00.000Z'
              : '2026-10-01T08:00:00.000Z',
        });
      }),
    );

    final items = await source.latest();

    expect(items, hasLength(2));
    expect(items.first['title'], 'رواية أحدث');
    expect(items.first['rating'], '4.6');
    expect(items.first['latest_chapter_date'], '2026-11-07T21:30:00.000Z');
    expect(items.first['updated_on'], '2026-11-07T21:30:00.000Z');
    expect(items.first['first_published_at'], '2026-10-05T08:00:00.000Z');
    expect(items.first['release_year'], '2026');
  });

  test('search results include API rating and dates', () async {
    final source = SeanovelSource(
      client: MockClient((request) async {
        if (request.url.path == '/api/search-index') {
          return _json([
            _indexEntry(
              'sea-search-target',
              'رواية بحث مميزة',
              '2026-11-08T01:00:00.000Z',
              '2026-09-01T01:00:00.000Z',
            ),
            _indexEntry(
              'sea-search-other',
              'عمل مختلف',
              '2026-11-06T01:00:00.000Z',
              '2026-08-01T01:00:00.000Z',
            ),
          ]);
        }
        expect(request.url.path, '/api/novel/sea-search-target');
        return _json({
          'slug': 'sea-search-target',
          'rating': 4.9,
          'last_updated': '2026-11-08T01:00:00.000Z',
          'first_published_at': '2026-09-01T01:00:00.000Z',
        });
      }),
    );

    final results = await source.search('بحث');

    expect(results, hasLength(1));
    expect(results.single['title'], 'رواية بحث مميزة');
    expect(results.single['rating'], '4.9');
    expect(results.single['latest_chapter_date'], '2026-11-08T01:00:00.000Z');
    expect(results.single['first_published_at'], '2026-09-01T01:00:00.000Z');
  });
}

const _index = '''
[{"slug":"the-greatest-sinner","title_ar":"أعظم الخاطئين","title_original":"The Greatest Sinner","genres":["أكشن"],"chapters_count":326,"cover_version":"1"}]
''';

const _chapters = '''
{"chapters":[{"id":1,"chapter_number":1,"title":"البداية","date":"2026-11-06T10:00:00Z"},{"id":326,"chapter_number":326,"title":"بلورات مانا","date":"2026-11-07T10:00:00Z"}],"total":326,"offset":0,"hasMore":false}
''';

const _novel = '''
<html><body><h1 class="novel-title">أعظم الخاطئين</h1><img class="novel-cover" src="/api/novel/the-greatest-sinner/cover?type=original"></body></html>
''';

const _chapter = '''
<html><body><h1 class="reader-chapter-title">بلورات مانا</h1><article class="reader-content"><p class="sr-only">وصف</p><p>نص الفصل الحقيقي.</p></article></body></html>
''';

Map<String, dynamic> _indexEntry(
  String slug,
  String title,
  String updatedAt,
  String publishedAt,
) => {
      'slug': slug,
      'title_ar': title,
      'title_original': 'Original $slug',
      'status': 'ongoing',
      'genres': ['خيال'],
      'chapters_count': 20,
      'last_updated': updatedAt,
      'first_published_at': publishedAt,
      'cover_version': '2',
    };

http.Response _json(dynamic body) => http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
