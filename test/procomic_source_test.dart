import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mangaplus/app/data/sources/procomic_source.dart';
import 'package:mangaplus/app/data/sources/search_relevance.dart';

void main() {
  test('preserves Arabic alternate titles for the app relevance filter', () async {
    Uri? requestedUri;
    final client = MockClient((request) async {
      requestedUri = request.url;
      return http.Response(
        jsonEncode({
          'data': [
            {
              'id': 686,
              'title': 'Global Class Advancement',
              'slug': 'global-class-advancement',
              'type': 'manhua',
              'thumbnail': '/686/image_series/cover.avif',
              'cdn_path': 'cdn3',
              'metadata': {
                'altTitles': ['سيد الظلال', 'Lord of Shadows'],
              },
            },
          ],
          'meta': {'total': 1},
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final source = ProComicSource(client: client);

    final results = await source.search('سيد الظلال');

    expect(requestedUri?.path, '/api/public/series/search');
    expect(requestedUri?.queryParameters['search'], 'سيد الظلال');
    expect(results, hasLength(1));
    expect(
      results.single['url'],
      'https://procomic.pro/ar/series/manhua/686/global-class-advancement',
    );
    expect(
      results.single['image_url'],
      'https://cdn3.procomic.pro/686/image_series/cover.avif',
    );
    expect(SearchRelevance.isRelevant('سيد الظلال', results.single), isTrue);
  });

  test('reads ordered chapter pages from current ProComic image paths', () async {
    final client = MockClient((request) async =>
        http.Response(_readerPage, 200, headers: _htmlHeaders));
    final source = ProComicSource(client: client);
    final chapter = await source.chapterImages(
      'https://procomic.pro/ar/chapter/global-class-advancement-3-50319',
    );
    expect(chapter?['chapter_number'], '3');
    expect(chapter?['pages'], [
      'https://app.procomic.pro/chapters/686/50319/p1/page-1.avif',
      'https://cdn3.procomic.pro/chapters/686/50319/p2/page-2.webp',
    ]);
  });

  test('reads current ProComic RSC image URLs and nested cover fields', () async {
    final client = MockClient((request) async {
      if (request.url.path.contains('/chapter/')) {
        return http.Response(_currentReaderPage, 200, headers: _htmlHeaders);
      }
      return http.Response(jsonEncode({
        'id': 744,
        'title': 'Shadow Slave',
        'slug': 'shadow-slave',
        'type': 'novel',
        'metadata': {
          'appCardImage': 'https://app.procomic.pro/series-cards-app/744/card.webp',
        },
      }), 200, headers: _jsonHeaders);
    });
    final source = ProComicSource(client: client);

    final details = await source.details(
      'https://procomic.pro/ar/series/novel/744/shadow-slave',
    );
    final chapter = await source.chapterImages(
      'https://procomic.pro/ar/chapter/shadow-slave-3-50319',
    );

    expect(details['image_url'], 'https://app.procomic.pro/series-cards-app/744/card.webp');
    expect(chapter?['pages'], [
      'https://app.procomic.pro/chapters/744/50319/p1/page-1.avif',
      'https://cdn2.procomic.pro/744/50319/page-2.webp',
    ]);
  });

  test('reads ProComic novel chapters as text', () async {
    Uri? requestedUri;
    final client = MockClient((request) async {
      requestedUri = request.url;
      return http.Response(_novelReaderPage, 200, headers: _htmlHeaders);
    });
    final source = ProComicSource(client: client);
    final chapter = await source.chapterContent(
      'https://procomic.pro/ar/chapter/the-strongest-son-in-law-1-25357',
    );
    expect(requestedUri?.path, contains('/ar/chapter/'));
    expect(chapter?['chapter_number'], '1');
    expect(chapter?['content'], contains('بداية الفصل'));
  });

  test('loads details using the current ProComic series route', () async {
    final requestedPaths = <String>[];
    final client = MockClient((request) async {
      requestedPaths.add(request.url.path);
      if (request.url.path == '/api/public/content/686') {
        return http.Response(jsonEncode(_seriesData), 200, headers: _jsonHeaders);
      }
      if (request.url.path ==
          '/ar/series/manhua/686/global-class-advancement') {
        return http.Response(_seriesPage, 200, headers: _htmlHeaders);
      }
      return http.Response('not found', 404);
    });
    final source = ProComicSource(client: client);

    final details = await source.details(
      'https://procomic.pro/ar/series/manhua/686/global-class-advancement',
    );

    expect(requestedPaths, [
      '/api/public/content/686',
      '/ar/series/manhua/686/global-class-advancement',
    ]);
    expect(details['chapters'], hasLength(1));
    expect(details['chapters'][0]['number'], 3.0);
  });
}

const _jsonHeaders = {'content-type': 'application/json; charset=utf-8'};
const _htmlHeaders = {'content-type': 'text/html; charset=utf-8'};

const _seriesData = {
  'id': 686,
  'title': 'Global Class Advancement',
  'slug': 'global-class-advancement',
  'type': 'manhua',
  'thumbnail': 'https://app.procomic.pro/cover.avif',
  'description': 'Test series',
  'progress': 'مستمر',
  'chapters_count': 3,
  'metadata': {'altTitles': ['سيد الظلال']},
};

const _seriesPage = '''
<html><body>
  <a href="/ar/chapter/global-class-advancement-3-50319">
    الفصل 3
  </a>
</body></html>
''';

const _readerPage = '''
<html><body>
  <img src="https://app.procomic.pro/chapters/686/50319/p1/page-1.avif">
  <img src="https://cdn3.procomic.pro/chapters/686/50319/p2/page-2.webp">
</body></html>
''';

const _currentReaderPage = r'''
<script>"images":["https:\/\/cdn2.procomic.pro\/744\/50319\/page-2.webp"],"appImages":[{"desktop":"https:\/\/app.procomic.pro\/chapters\/744\/50319\/p1\/page-1.avif"}]</script>
''';

const _novelReaderPage = '''
<html><body>
  <main>
    <h1>الفصل 1</h1>
    <div class="chapter-text__content prose">
      <div><p>بداية الفصل</p></div>
      <div><p>هذا نص الرواية.</p></div>
    </div>
  </main>
</body></html>
''';
