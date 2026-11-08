import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mangaplus/app/data/sources/manga_swat_source.dart';

void main() {
  test(
      'latest does not mistake a series publication timestamp for chapter date',
      () async {
    final source = MangaSwatSource(
      client: MockClient((request) async {
        expect(request.url.path, '/v2/api/v2/series/');
        return http.Response(
          jsonEncode({
            'results': [
              {
                'id': 42,
                'title': 'عمل تجريبي',
                'chapters_count': 12,
                'published_at': '2026-11-07T10:00:00Z',
                'latest_chapter': {'title': 'فصل خاص'},
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final results = await source.latest();

    expect(results.single.containsKey('latest_chapter_date'), isFalse);
    expect(results.single.containsKey('latest_chapter_number'), isFalse);
  });

  test('details leaves a chapter number unknown when the API has no number',
      () async {
    final source = MangaSwatSource(
      client: MockClient((request) async {
        if (request.url.path == '/v2/api/v2/series/42/') {
          return http.Response(
            jsonEncode({'id': 42, 'title': 'عمل تجريبي', 'chapters_count': 1}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/v2/api/v2/series/42/chapters/') {
          return http.Response(
            jsonEncode({
              'results': [
                {'id': 99, 'title': 'Special issue'},
              ],
              'next': null,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('not found', 404);
      }),
    );

    final detail = await source.details('swat://series/42/example');
    final chapters = detail['chapters'] as List<Map<String, dynamic>>;

    expect(chapters.single['number'], isNull);
    expect(chapters.single['chapter_number'], '');
    expect(chapters.single['title'], 'Special issue');
    expect(detail['total_chapters'], 1);
  });
}
