import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mangaplus/app/data/sources/manga_sid_source.dart';
import 'package:mangaplus/app/data/sources/manga_source_registry.dart';

void main() {
  test('registers Mangasid URLs as a searchable source', () {
    final source = MangaSourceRegistry.forUrl(
      'https://mangasid.com/manga/magic-emperor',
    );
    expect(source?.id, 'mangasid');
    expect(source?.name, 'Mangasid');
  });

  test('search uses the public Mangasid search parameter and returns covers', () async {
    Uri? requestUri;
    final client = MockClient((request) async {
      requestUri = request.url;
      return http.Response(_listPage, 200, headers: _htmlHeaders);
    });
    final source = MangaSidSource(client: client);
    final results = await source.search('Magic emperor');

    expect(requestUri?.path, '/manga-list');
    expect(requestUri?.queryParameters['search'], 'Magic emperor');
    expect(results, hasLength(1));
    expect(results.single['title'], 'Magic emperor');
    expect(results.single['url'], 'https://mangasid.com/manga/magic-emperor');
    expect(results.single['image_url'], 'https://api.mangasid.com/covers/magic.jpg');
    expect(results.single['latest_chapter_number'], '927');
  });

  test('details decode embedded chapter data and preserve all chapter links', () async {
    final client = MockClient((request) async =>
        http.Response(_detailPage, 200, headers: _htmlHeaders));
    final source = MangaSidSource(client: client);
    final detail = await source.details(
      'https://mangasid.com/manga/magic-emperor',
    );
    final chapters = detail['chapters'] as List<Map<String, dynamic>>;

    expect(detail['title'], 'Magic emperor');
    expect(detail['image_url'], 'https://api.mangasid.com/covers/magic.jpg');
    expect(detail['genres'], contains('أكشن'));
    expect(chapters, hasLength(2));
    expect(chapters.first['number'], 927);
    expect(chapters.first['url'], 'https://mangasid.com/reader/magic-emperor/927');
    expect(chapters.last['url'], 'https://mangasid.com/reader/magic-emperor/926');
  });

  test('reader pages retain order and resolve relative image paths to Mangasid image host', () async {
    final client = MockClient((request) async =>
        http.Response(_readerPage, 200, headers: _htmlHeaders));
    final source = MangaSidSource(client: client);
    final chapter = await source.chapterImages(
      'https://mangasid.com/reader/magic-emperor/927',
    );
    final pages = chapter!['pages'] as List<String>;

    expect(pages, [
      'https://api.mangasid.com/storage/927/01.webp',
      'https://images.mangasidcdn.com/927/02.webp',
    ]);
    expect((chapter['images'] as List).length, 2);
    expect(chapter['chapter_number'], '927');
  });
}

const _htmlHeaders = {'content-type': 'text/html; charset=utf-8'};

const _listPage = '''
<html><body>
  <article class="manga-card">
    <a href="/manga/magic-emperor"><img data-src="https://api.mangasid.com/covers/magic.jpg" alt="غلاف مانجا Magic emperor"></a>
    <h3><a href="/manga/magic-emperor">Magic emperor</a></h3>
    <span>مانها مستمر</span>
    <a href="/reader/magic-emperor/927">الفصل 927</a>
    <span>9.5</span>
  </article>
</body></html>
''';

const _detailPage = '''
<html><head><meta name="manga:chapters" content="927"></head><body>
  <h1>Magic emperor امبراطور السحر</h1>
  <img src="https://api.mangasid.com/covers/magic.jpg" alt="غلاف مانجا Magic emperor">
  <a href="/manga-list?genres=%D8%A3%D9%83%D8%B4%D9%86">أكشن</a>
  <astro-island component-url="/_astro/MangaChaptersLoader.astro" props="{&quot;manga&quot;:{&quot;title&quot;:&quot;Magic emperor&quot;,&quot;cover_image&quot;:&quot;https://api.mangasid.com/covers/magic.jpg&quot;,&quot;description&quot;:&quot;وصف اختبار&quot;,&quot;Tags&quot;:[{&quot;name&quot;:&quot;أكشن&quot;}],&quot;MangaChapters&quot;:[{&quot;chapter_number&quot;:&quot;927&quot;,&quot;title&quot;:&quot;الفصل 927&quot;},{&quot;chapter_number&quot;:&quot;926&quot;,&quot;title&quot;:&quot;الفصل 926&quot;}]}}"></astro-island>
</body></html>
''';

const _readerPage = '''
<html><body>
  <h1>Magic emperor الفصل 927</h1>
  <div class="manga-page"><img class="block relative z-20 w-full h-auto" data-src="/storage/927/01.webp"></div>
  <div class="manga-page"><img class="block relative z-20 w-full h-auto" src="https://images.mangasidcdn.com/927/02.webp"></div>
  <a href="/reader/magic-emperor/926">السابق</a>
</body></html>
''';
