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
              'thumbnail': 'https://app.procomic.pro/cover.avif',
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
    expect(SearchRelevance.isRelevant('سيد الظلال', results.single), isTrue);
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
  <a href="https://procomic.pro/ar/chapter/global-class-advancement-3-50319">
    الفصل 3
  </a>
</body></html>
''';
