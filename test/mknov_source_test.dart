import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mangaplus/app/data/sources/mknov_source.dart';

void main() {
  test(
      'latest keeps chapter count separate; details provide latest chapter metadata',
      () async {
    final source = MknovSource(
      client: MockClient((request) async {
        if (request.url.path == '/api/works') {
          return http.Response(
            jsonEncode({
              'works': [
                {
                  'id': 'fixture-work',
                  'titleAr': 'رواية تجريبية',
                  'totalChapters': 2,
                  'rating': 8.2,
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/works/fixture-work/chapters') {
          return http.Response(
            jsonEncode({
              'volumes': [
                {
                  'num': 1,
                  'chapters': [
                    {
                      'id': 'chapter-1',
                      'chapterNumber': 1,
                      'chapterTitle': 'قديم',
                      'publishDate': '2026-11-06T10:00:00Z',
                    },
                    {
                      'id': 'chapter-12',
                      'chapterNumber': 12,
                      'chapterTitle': 'أحدث',
                      'publishDate': '2026-11-07T10:00:00Z',
                    },
                  ],
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('not found', 404);
      }),
    );

    final latest = await source.latest();
    final detail = await source.details('https://mknov.com/novel/fixture-work');
    final chapters = detail['chapters'] as List<Map<String, dynamic>>;

    expect(latest.single['total_chapters'], 2);
    expect(latest.single.containsKey('latest_chapter_number'), isFalse);
    expect(detail['rating'], '8.2');
    expect(detail['total_chapters'], 2);
    expect(detail['latest_chapter_number'], '12');
    expect(detail['latest_chapter_date'], '2026-11-07T10:00:00Z');
    expect(chapters.first['release_date'], '2026-11-07T10:00:00Z');
  });
}
