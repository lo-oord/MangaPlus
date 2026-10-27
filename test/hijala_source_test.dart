import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mangaplus/app/data/sources/manga_source_registry.dart';
import 'package:mangaplus/app/data/sources/hijala_source.dart';

void main() {
  test('search extracts Hijala title, link and cover from the actual card shape', () async {
    final client = _FixtureClient({
      '/manga/': '''
        <div class="listupd"><div class="bs"><div class="bsx">
          <a href="https://hijala.com/solo-leveling/">
            <div class="limit"><img src="https://hijala.com/wp-content/uploads/cover.webp" alt="Solo Leveling"></div>
          </a>
          <div class="tt">Solo Leveling</div>
          <div class="adds"><span class="epxs">فصل 179</span></div>
        </div></div></div>
      ''',
    });
    final source = HijalaSource(client: client);

    final results = await source.search('solo');

    expect(client.requests.single.queryParameters['s'], 'solo');
    expect(results, hasLength(1));
    expect(results.single['title'], 'Solo Leveling');
    expect(results.single['url'], 'https://hijala.com/solo-leveling/');
    expect(results.single['image_url'], 'https://hijala.com/wp-content/uploads/cover.webp');
    expect(results.single['source_id'], 'hijala');
  });

  test('details reads lazy cover, metadata, genres and all chapter links', () async {
    final source = HijalaSource(client: _FixtureClient({
      '/solo-leveling/': '''
        <h1 class="entry-title">Solo Leveling</h1>
        <div class="info-left-margin">
          <div class="thumb"><img src="data:image/svg+xml;base64,AA" data-src="http://hijala.com/wp-content/uploads/solo-cover.webp" alt="Solo Leveling"></div>
          <div class="tsinfo">
            <div class="imptdt">الحالة<i>مكتمل</i></div>
            <div class="imptdt">النوع<a>Manhwa</a></div>
            <div class="imptdt">نشر بتاريخ<i>أبريل 9, 2026</i></div>
            <div class="imptdt">أخر تحديث<i>April 11, 2026</i></div>
          </div>
          <div class="rating bixbox"><div class="rating-prc"><div class="num" content="9.2">9.2</div></div></div>
        </div>
        <div class="info-desc"><span class="mgen"><a>أكشن</a><a>فنتازيا</a></span></div>
        <div class="info-right"><div class="entry-content">قصة البطل</div></div>
        <div class="eplister" id="chapterlist"><ul>
          <li data-num="2"><div class="eph-num"><a href="/solo-leveling-2/"><span class="chapternum">فصل 2</span><span class="chapterdate">أبريل 9, 2026</span></a></div></li>
          <li data-num="1"><div class="eph-num"><a href="/solo-leveling-1/"><span class="chapternum">فصل 1</span><span class="chapterdate">مارس 1, 2026</span></a></div></li>
        </ul></div>
      ''',
    }));

    final detail = await source.details('http://www.hijala.com/solo-leveling/');

    expect(detail['title'], 'Solo Leveling');
    expect(detail['image_url'], 'https://hijala.com/wp-content/uploads/solo-cover.webp');
    expect(detail['status'], 'مكتمل');
    expect(detail['type'], 'Manhwa');
    expect(detail['genres'], ['أكشن', 'فنتازيا']);
    expect(detail['synopsis'], 'قصة البطل');
    expect(detail['rating'], '9.2');
    expect(detail['release_year'], '2026');
    expect(detail['updated_on'], startsWith('2026-04-11'));
    expect(detail['total_chapters'], 2);
    final chapters = detail['chapters'] as List<Map<String, dynamic>>;
    expect(chapters.map((chapter) => chapter['url']).toList(), [
      'https://hijala.com/solo-leveling-2/',
      'https://hijala.com/solo-leveling-1/',
    ]);
    expect(chapters.first['release_date'], startsWith('2026-04-09'));
  });

  test('reader returns only page images and chapter navigation context', () async {
    final source = HijalaSource(client: _FixtureClient({
      '/solo-leveling/': '''
        <h1 class="entry-title">Solo Leveling</h1>
        <div class="eplister" id="chapterlist"><ul>
          <li data-num="2"><a href="/solo-leveling-2/"><span class="chapternum">فصل 2</span></a></li>
          <li data-num="1"><a href="/solo-leveling-1/"><span class="chapternum">فصل 1</span></a></li>
        </ul></div>
      ''',
          '/solo-leveling-2/': '''
        <div class="readercontent"><h1>Solo Leveling 2</h1>
          <div id="readerarea">
            <img src="https://hijala.com/wp-content/uploads/manga/ab12/01.webp">
            <img data-src="http://hijala.com/wp-content/uploads/manga/ab12/02.webp" src="data:image/gif;base64,AA">
          </div>
        </div>
        <aside><img src="https://hijala.com/wp-content/uploads/sidebar.webp"></aside>
      ''',
    }));
    await source.details('https://hijala.com/solo-leveling/');

    final chapter = await source.chapterImages('http://hijala.com/solo-leveling-2/');

    expect(chapter, isNotNull);
    expect(chapter!['chapter_number'], '2');
    expect(chapter['pages'], [
      'https://hijala.com/wp-content/uploads/manga/ab12/01.webp',
      'https://hijala.com/wp-content/uploads/manga/ab12/02.webp',
    ]);
    expect(chapter['previous_chapter'], 'https://hijala.com/solo-leveling-1/');
    expect(chapter['chapters'], hasLength(2));
  });

  test('reader accepts the current reading-content image container', () async {
    final source = HijalaSource(client: _FixtureClient({
      '/solo-leveling-3/': '''
        <div class="reading-content">
          <img src="https://hijala.com/wp-content/uploads/hijala.png">
          <img src="http://hijala.com/wp-content/uploads/manga/ab12/03.webp">
        </div>
      ''',
    }));

    final chapter = await source.chapterImages(
      'https://hijala.com/solo-leveling-3/',
    );

    expect(chapter?['pages'], [
      'https://hijala.com/wp-content/uploads/manga/ab12/03.webp',
    ]);
  });

  test('Hijala handles its own pages but not unrelated domains', () {
    final source = HijalaSource(client: _FixtureClient(const {}));
    expect(source.handles('https://www.hijala.com/solo-leveling/'), isTrue);
    expect(source.handles('https://example.com/solo-leveling/'), isFalse);
  });

  test('registry resolves Hijala URLs and includes Hijala in multi-source search', () {
    expect(
      MangaSourceRegistry.forUrl('https://hijala.com/solo-leveling/'),
      same(MangaSourceRegistry.hijala),
    );
    expect(MangaSourceRegistry.searchableSources, contains(MangaSourceRegistry.hijala));
  });
}

class _FixtureClient extends http.BaseClient {
  _FixtureClient(this.pages);

  final Map<String, String> pages;
  final List<Uri> requests = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request.url);
    final body = pages[request.url.path];
    if (body == null) {
      return http.StreamedResponse(Stream<List<int>>.value(utf8.encode('Not found')), 404);
    }
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(body)),
      200,
      headers: const {'content-type': 'text/html; charset=utf-8'},
    );
  }
}
