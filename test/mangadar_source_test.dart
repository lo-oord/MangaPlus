import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mangaplus/app/data/sources/mangadar_source.dart';

void main() {
  test('latest cards expose rating and latest chapter date', () async {
    final source = MangaDarSource(
      client: MockClient((request) async {
        expect(request.url.path, '/manga/');
        return http.Response(
          '''
          <html><body>
            <a class="group block" href="/manga/example/">
              <h3>Example</h3>
              <div data-current-average="8.2"></div>
              <time datetime="2026-11-09T08:15:00+02:00"></time>
              <span title="إجمالي الفصول">24</span>
            </a>
          </body></html>
          ''',
          200,
        );
      }),
    );

    final latest = await source.latest();

    expect(latest, hasLength(1));
    expect(latest.single['rating'], '8.2');
    expect(latest.single['latest_chapter_date'], '2026-11-09T06:15:00.000Z');
    expect(latest.single['total_chapters'], 24);
  });

  test(
      'details load every chapter from MangaDar REST, not only navigation links',
      () async {
    final requestedPaths = <String>[];
    final client = MockClient((request) async {
      requestedPaths.add(request.url.path);
      if (request.url.path == '/manga/ghost-fixers/') {
        return http.Response(
            '''
          <html><body class="single-manga postid-205985">
            <h1>Ghost Fixers</h1>
            <span class="tabular-nums">8.4</span>
            <a href="/manga/ghost-fixers/1/">ابدأ القراءة</a>
            <a href="/manga/ghost-fixers/10/">آخر فصل (10)</a>
            <div x-data="mdgMangaChapters"></div>
          </body></html>
        ''',
            200,
            headers: {'content-type': 'text/html; charset=utf-8'});
      }
      if (request.url.path == '/wp-json/mangadar/v1/manga/205985/chapters') {
        return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 301,
                  'number': '10',
                  'title': 'Ghost Fixers الفصل 10',
                  'date': '2026-10-25T08:12:36+00:00',
                  'url': 'https://mangadar.com/manga/ghost-fixers/10/'
                },
                {
                  'id': 302,
                  'number': '6.5',
                  'title': 'Ghost Fixers الفصل 6.5',
                  'date': '2026-10-24T08:12:36+00:00',
                  'url': 'https://mangadar.com/manga/ghost-fixers/6.5/'
                },
                {
                  'id': 303,
                  'number': '1',
                  'title': 'Ghost Fixers الفصل 1',
                  'date': '2026-10-23T08:12:36+00:00',
                  'url': 'https://mangadar.com/manga/ghost-fixers/1/'
                },
              ],
              'page': 1,
              'total': 3,
              'total_pages': 1,
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }
      return http.Response('not found', 404);
    });

    final detail = await MangaDarSource(client: client).details(
      'https://mangadar.com/manga/ghost-fixers/',
    );
    final chapters = detail['chapters'] as List<Map<String, dynamic>>;

    expect(requestedPaths, [
      '/manga/ghost-fixers/',
      '/wp-json/mangadar/v1/manga/205985/chapters',
    ]);
    expect(chapters, hasLength(3));
    expect(chapters.map((chapter) => chapter['number']), [10, 6.5, 1]);
    expect(
        chapters.first['url'], 'https://mangadar.com/manga/ghost-fixers/10/');
    expect(chapters[1]['url'], 'https://mangadar.com/manga/ghost-fixers/6.5/');
    expect(chapters.last['url'], 'https://mangadar.com/manga/ghost-fixers/1/');
    expect(chapters.first['release_date'], '2026-10-25T08:12:36.000Z');
    expect(detail['rating'], '8.4');
    expect(detail['total_chapters'], 3);
    expect(detail['latest_chapter_number'], 10);
    expect(detail['latest_chapter_date'], '2026-10-25T08:12:36.000Z');
  });

  test(
      'continues to use static chapter links when REST chapters are unavailable',
      () async {
    final client = MockClient((request) async {
      if (request.url.path == '/manga/example/') {
        return http.Response(
            '''
          <html><body class="single-manga postid-7">
            <h1>Example</h1>
            <div data-current-average="7.6"><svg></svg></div>
            <div class="chapter-row"><a href="/manga/example/3/">الفصل 3</a><time datetime="2026-11-08T14:30:00+03:00"></time></div>
            <a href="/manga/example/1/">ابدأ القراءة</a>
            <a href="/manga/example/3/">آخر فصل (3)</a>
          </body></html>
        ''',
            200,
            headers: {'content-type': 'text/html; charset=utf-8'});
      }
      return http.Response('unavailable', 503);
    });

    final detail = await MangaDarSource(client: client).details(
      'https://mangadar.com/manga/example/',
    );
    final chapters = detail['chapters'] as List<Map<String, dynamic>>;

    expect(chapters, hasLength(2));
    expect(chapters.first['number'], 3);
    expect(chapters.last['number'], 1);
    expect(detail['rating'], '7.6');
    expect(chapters.first['release_date'], '2026-11-08T11:30:00.000Z');
    expect(detail['latest_chapter_date'], '2026-11-08T11:30:00.000Z');
  });
}
