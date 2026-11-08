import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mangaplus/app/data/sources/mangatek_source.dart';

void main() {
  test('reader collects lazy, srcset and picture images once in source order',
      () async {
    final source = MangaTekSource(
      client: MockClient((request) async {
        expect(request.url.toString(), contains('/reader/magic-emperor/932'));
        return http.Response(_readerPage, 200, headers: const {
          'content-type': 'text/html; charset=utf-8',
        });
      }),
    );

    final chapter = await source.chapterImages(
      'mangatek://chapter?slug=magic-emperor&number=932',
    );

    expect(chapter, isNotNull);
    expect(chapter!['pages'], [
      'https://api.mangatek.com/chapters/450/932/01.webp',
      'https://api.mangatek.com/chapters/450/932/02.webp',
      'https://api.mangatek.com/chapters/450/932/03.webp',
    ]);
  });

  test('reader prefers the complete Astro imageUrls payload', () async {
    final source = MangaTekSource(
      client:
          MockClient((request) async => http.Response(_astroReaderPage, 200)),
    );

    final chapter = await source.chapterImages(
      'mangatek://chapter?slug=magic-emperor&number=933',
    );

    expect(chapter?['pages'], [
      'https://api.mangatek.com/chapters/450/933/01.webp',
      'https://api.mangatek.com/chapters/450/933/02.webp',
      'https://api.mangatek.com/chapters/450/933/03.webp',
    ]);
  });

  test(
      'latest does not substitute the chapter count for a missing latest number',
      () async {
    final source = MangaTekSource(
      client: MockClient((request) async {
        expect(request.url.host, 'api.mangatek.com');
        return http.Response(
          jsonEncode({
            'data': {
              'mangas': [
                {'slug': 'fixture', 'title': 'Fixture', 'chapters_count': 12},
              ],
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final latest = await source.latest();

    expect(latest.single['total_chapters'], 12);
    expect(latest.single.containsKey('latest_chapter_number'), isFalse);
  });

  test('details expose the newest chapter date from the HTML fallback',
      () async {
    final source = MangaTekSource(
      client: MockClient((request) async {
        expect(request.url.path, '/manga/fixture');
        return http.Response(
            '''
          <html><body>
            <h1>Fixture</h1>
            <div class="manga-chapter"><a href="/reader/fixture/11"><h3>الفصل 11</h3><time datetime="2026-11-06T10:00:00Z"></time></a></div>
            <div class="manga-chapter"><a href="/reader/fixture/12"><h3>الفصل 12</h3><time datetime="2026-11-07T10:00:00Z"></time></a></div>
          </body></html>
        ''',
            200,
            headers: {'content-type': 'text/html; charset=utf-8'});
      }),
    );

    final detail = await source.details('mangatek://series?slug=fixture');
    final chapters = detail['chapters'] as List<Map<String, dynamic>>;

    expect(chapters.map((chapter) => chapter['number']).toList(), [12, 11]);
    expect(detail['latest_chapter_number'], 12);
    expect(detail['latest_chapter_date'], '2026-11-07T10:00:00.000Z');
    expect(chapters.first['release_date'], '2026-11-07T10:00:00.000Z');
  });
}

const _readerPage = '''
<html><body>
  <div class="manga-page">
    <img data-src="https://api.mangatek.com/chapters/450/932/01.webp" src="data:image/gif;base64,AA">
  </div>
  <div class="manga-page">
    <img data-srcset="https://api.mangatek.com/chapters/450/932/02.webp 1x, https://api.mangatek.com/chapters/450/932/02@2x.webp 2x">
  </div>
  <div class="manga-page">
    <picture>
      <source srcset="https://api.mangatek.com/chapters/450/932/03.webp 1x">
      <img src="https://api.mangatek.com/chapters/450/932/03.webp">
    </picture>
  </div>
</body></html>
''';

const _astroReaderPage = '''
<html><body>
  <astro-island props='{"imageUrls":["https://api.mangatek.com/chapters/450/933/01.webp","https://api.mangatek.com/chapters/450/933/02.webp","https://api.mangatek.com/chapters/450/933/03.webp"]}'></astro-island>
</body></html>
''';
