import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mangaplus/app/data/sources/despair_source.dart';
import 'package:mangaplus/app/data/sources/hizomanga_source.dart';
import 'package:mangaplus/app/data/sources/manga_source_registry.dart';
import 'package:mangaplus/app/data/sources/mangatik_source.dart';

void main() {
  group('MangaTikSource', () {
    test('parses official manga cards and relative cover URLs', () async {
      final client = _FixtureClient({
        '/latest': '''
          <article class="manga-card">
            <div class="manga-title"><a href="/manga/series-one">Series One</a></div>
            <img class="manga-poster" src="/storage/covers/one.webp">
            <span class="manga-rating-badge">★ 8.3</span>
          </article>
        ''',
      });
      final results = await MangaTikSource(client: client).latest();
      expect(results.single['title'], 'Series One');
      expect(results.single['url'], 'https://mangatik.com/manga/series-one');
      expect(results.single['image_url'], 'https://mangatik.com/storage/covers/one.webp');
      expect(results.single['source_id'], 'mangatik');
    });

    test('uses JSON-LD metadata and official chapter card/image selectors', () async {
      final client = _FixtureClient({
        '/manga/series-one': '''
          <h1>Series One</h1>
          <script type="application/ld+json">{"@type":"ComicSeries","name":"Series One","description":"Synopsis","image":{"url":"https://mangatik.com/cover.webp"},"genre":["أكشن"],"aggregateRating":{"ratingValue":8.2}}</script>
          <a class="chapter-item-card" data-chapter="2.0" href="/manga/series-one/2"><span>الفصل 2</span></a>
          <a class="chapter-item-card" data-chapter="1.0" href="/manga/series-one/1"><span>الفصل 1</span></a>
        ''',
        '/manga/series-one/2': '''<h1>Series One</h1><img class="webtoon-image" src="https://images.example/page-1.webp"><img class="webtoon-image" src="https://images.example/page-2.webp">''',
      });
      final source = MangaTikSource(client: client);
      final detail = await source.details('https://mangatik.com/manga/series-one');
      expect(detail['description'], 'Synopsis');
      expect(detail['genres'], ['أكشن']);
      expect((detail['chapters'] as List).length, 2);
      final chapter = await source.chapterImages('https://mangatik.com/manga/series-one/2');
      expect(chapter?['pages'], [
        'https://images.example/page-1.webp',
        'https://images.example/page-2.webp',
      ]);
    });
  });

  group('HizoMangaSource', () {
    test('extracts current WordPress catalogue cards', () async {
      final source = HizoMangaSource(client: _FixtureClient({
        '/series/': '''
          <div class="page-listing-item">
            <div class="item-thumb"><a href="/content/123/" title="عنوان العمل"><img src="/cover.webp"></a></div>
            <div class="item-summary"><div class="post-title"><h3><a href="/content/123/">عنوان العمل</a></h3></div><div class="list-chapter"><a href="/content/123/4/">الفصل 4</a></div></div>
          </div>
        ''',
      }));
      final results = await source.latest();
      expect(results.single['title'], 'عنوان العمل');
      expect(results.single['url'], 'https://hizomanga.net/content/123/');
      expect(results.single['image_url'], 'https://hizomanga.net/cover.webp');
    });

    test('parses current Hizo details and reader pages', () async {
      final source = HizoMangaSource(client: _FixtureClient({
        '/content/123/': '''
          <div class="manga-title"><h2>عنوان العمل</h2></div>
          <div class="summary_image"><img src="http://hizomanga.net/cover.webp"></div>
          <div class="manga-excerpt"><div class="excerpt-content"><p>ملخص</p></div></div>
          <div class="manga-status"><span>الحالة</span><span>مستمرة</span></div>
          <div class="wp-manga-chapter"><a href="/content/123/4/">الفصل 4</a></div>
        ''',
        '/content/123/4/': '''
          <div id="readerarea"><img src="https://images.example/page-1.webp"><img data-src="https://images.example/page-2.webp"></div>
        ''',
      }));
      final detail = await source.details('https://hizomanga.net/content/123/');
      expect(detail['title'], 'عنوان العمل');
      expect(detail['description'], 'ملخص');
      expect(detail['status'], 'مستمرة');
      expect((detail['chapters'] as List).single['url'], 'https://hizomanga.net/content/123/4/');
      final chapter = await source.chapterImages('https://hizomanga.net/content/123/4/');
      expect(chapter?['pages'], [
        'https://images.example/page-1.webp',
        'https://images.example/page-2.webp',
      ]);
    });
  });

  group('DespairSource', () {
    test('keeps manga and novel URLs distinct and loads novel text', () async {
      final client = _JsonFixtureClient((uri) {
        if (uri.path.endsWith('/manga_works')) {
          return [
            {'id': 'm1', 'slug': 'manga-one', 'title_ar': 'مانجا', 'cover_url': 'https://img.example/manga.jpg', 'genres': ['أكشن'], 'chapters_count': 1},
          ];
        }
        if (uri.path.endsWith('/novel_works')) {
          return [
            {'id': 'n1', 'slug': 'novel-one', 'title_ar': 'رواية', 'cover_url': 'https://img.example/novel.jpg', 'genres': ['خيال'], 'chapters_count': 1},
          ];
        }
        if (uri.path.endsWith('/chapters')) {
          return [
            {'id': 'mc1', 'work_id': 'm1', 'chapter_number': 3, 'title': 'الفصل 3', 'pages': ['https://img.example/1.webp']},
          ];
        }
        if (uri.path.endsWith('/novel_chapters')) {
          return [
            {'id': 'nc1', 'work_id': 'n1', 'chapter_number': 2, 'title': 'بداية', 'content': 'نص الفصل'},
          ];
        }
        return [];
      });
      final manga = DespairMangaSource(client: client);
      final novels = DespairNovelsSource(client: client);
      expect(manga.handles('https://despair-world.com/series/manga-one'), isTrue);
      expect(manga.handles('https://despair-world.com/novels/novel-one'), isFalse);
      expect(novels.handles('https://despair-world.com/novels/novel-one'), isTrue);
      expect(novels.handles('https://despair-world.com/series/manga-one'), isFalse);

      final mangaWork = (await manga.latest()).single;
      final novelWork = (await novels.latest()).single;
      expect(mangaWork['type'], 'manga');
      expect(novelWork['type'], 'novel');
      expect(novelWork['url'], 'https://despair-world.com/novels/novel-one');
      final detail = await novels.details(novelWork['url'] as String);
      final chapterUrl = (detail['chapters'] as List).single['url'] as String;
      final content = await novels.chapterContent(chapterUrl);
      expect(content?['content'], 'نص الفصل');

      final mangaDetail = await manga.details(mangaWork['url'] as String);
      final mangaChapterUrl = (mangaDetail['chapters'] as List).single['url'] as String;
      expect((await manga.chapterImages(mangaChapterUrl))?['pages'], ['https://img.example/1.webp']);
    });
  });

  test('all new sources are registered for app-wide source resolution', () {
    expect(MangaSourceRegistry.byId('despair_manga'), same(MangaSourceRegistry.despairManga));
    expect(MangaSourceRegistry.byId('despair_novels'), same(MangaSourceRegistry.despairNovels));
    expect(MangaSourceRegistry.byId('hizomanga'), same(MangaSourceRegistry.hizoManga));
    expect(MangaSourceRegistry.byId('mangatik'), same(MangaSourceRegistry.mangaTik));
    expect(MangaSourceRegistry.forUrl('https://despair-world.com/novels/series/'), same(MangaSourceRegistry.despairNovels));
    expect(MangaSourceRegistry.forUrl('https://despair-world.com/series/series/'), same(MangaSourceRegistry.despairManga));
  });
}

class _FixtureClient extends http.BaseClient {
  _FixtureClient(this.pages);
  final Map<String, String> pages;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = pages[request.url.path];
    if (body == null) return http.StreamedResponse(Stream.value(utf8.encode('Not found')), 404);
    return http.StreamedResponse(Stream.value(utf8.encode(body)), 200, headers: const {'content-type': 'text/html; charset=utf-8'});
  }
}

class _JsonFixtureClient extends http.BaseClient {
  _JsonFixtureClient(this.handler);
  final List<Map<String, dynamic>> Function(Uri uri) handler;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(Stream.value(utf8.encode(jsonEncode(handler(request.url)))), 200, headers: const {'content-type': 'application/json'});
}
