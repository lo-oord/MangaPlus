import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mangaplus/app/data/sources/despair_source.dart';
import 'package:mangaplus/app/data/sources/hizomanga_source.dart';
import 'package:mangaplus/app/data/sources/manga_source_registry.dart';
import 'package:mangaplus/app/data/sources/mangatik_source.dart';
import 'package:mangaplus/app/data/sources/source_brand.dart';

void main() {
  group('MangaTikSource', () {
    test('parses official manga cards and relative cover URLs', () async {
      final client = _FixtureClient({
        '/latest': '''
          <article class="manga-card">
            <a class="cover-link" href="/manga/series-one"><img class="manga-poster" data-src="/storage/covers/one.webp" src="/placeholder.webp" alt="Series One"></a>
            <div class="manga-title"><a href="/manga/series-one">Series One</a></div>
            <span class="manga-rating-badge">★ 8.3</span>
          </article>
        ''',
      });
      final results = await MangaTikSource(client: client).latest();
      expect(results.single['title'], 'Series One');
      expect(results.single['url'], 'https://mangatik.com/manga/series-one');
      expect(results.single['image_url'],
          'https://mangatik.com/storage/covers/one.webp');
      expect(results.single['source_id'], 'mangatik');
    });

    test('uses JSON-LD metadata and official chapter card/image selectors',
        () async {
      final client = _FixtureClient({
        '/manga/series-one': '''
          <h1>Series One</h1>
          <script type="application/ld+json">{"@type":"ComicSeries","name":"Series One","description":"Synopsis","image":{"url":"https://mangatik.com/cover.webp"},"genre":["أكشن"],"author":{"name":"Updating"},"aggregateRating":{"ratingValue":8.2}}</script>
          <a class="chapter-item-card" data-chapter="2.0" href="/manga/series-one/2"><span>الفصل 2</span></a>
          <a class="chapter-item-card" data-chapter="1.0" href="/manga/series-one/1"><span>الفصل 1</span></a>
        ''',
        '/manga/series-one/2':
            '''<h1>Series One</h1><img class="webtoon-image" src="https://images.example/page-1.webp"><img class="webtoon-image" src="https://images.example/page-2.webp">''',
      });
      final source = MangaTikSource(client: client);
      final detail =
          await source.details('https://mangatik.com/manga/series-one');
      expect(detail['description'], 'Synopsis');
      expect(detail['genres'], ['أكشن']);
      expect(detail['author'], '');
      expect((detail['chapters'] as List).length, 2);
      final chapter =
          await source.chapterImages('https://mangatik.com/manga/series-one/2');
      expect(chapter?['pages'], [
        'https://images.example/page-1.webp',
        'https://images.example/page-2.webp',
      ]);
    });

    test(
        'uses the visible rating badge and structured chapter dates as fallbacks',
        () async {
      final source = MangaTikSource(
          client: _FixtureClient({
        '/manga/series-two': '''
          <html><body>
            <h1>Series Two</h1>
            <span class="manga-rating-badge">★ 9.1</span>
            <a class="chapter-item-card" data-chapter="2" href="/manga/series-two/2">
              <span>الفصل 2</span><time datetime="2026-11-06T10:00:00Z"></time>
            </a>
            <a class="chapter-item-card" data-chapter="1" href="/manga/series-two/1">
              <span>الفصل 1</span><time datetime="2026-11-07T10:00:00Z"></time>
            </a>
          </body></html>
        ''',
      }));

      final detail =
          await source.details('https://mangatik.com/manga/series-two');
      final chapters = detail['chapters'] as List<Map<String, dynamic>>;

      expect(detail['rating'], '9.1');
      expect(detail['latest_chapter_number'], 1);
      expect(detail['latest_chapter_date'], '2026-11-07T10:00:00.000Z');
      expect(chapters.first['release_date'], '2026-11-07T10:00:00.000Z');
    });
  });

  group('HizoMangaSource', () {
    test('extracts current WordPress catalogue cards', () async {
      final source = HizoMangaSource(
          client: _FixtureClient({
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

    test(
        'searches the actual WordPress search route and reads its Madara cards',
        () async {
      final source = HizoMangaSource(
          client: _FixtureClient({
        '/': '''
          <div class="c-tabs-item__content">
            <div class="tab-thumb"><a href="https://hizomanga.net/content/164882/" title="At the End of Betrayal"><img src="/cover-search.webp"></a></div>
            <div class="post-title"><h3><a href="https://hizomanga.net/content/164882/">At the End of Betrayal</a></h3></div>
            <div class="genres-content"><a>رواية مترجمة</a></div>
          </div>
        ''',
      }));
      final results = await source.search('aya');
      expect(results.single['title'], 'At the End of Betrayal');
      expect(results.single['type'], 'novel');
      expect(results.single['image_url'],
          'https://hizomanga.net/cover-search.webp');
    });

    test('parses current Hizo details and reader pages', () async {
      final source = HizoMangaSource(
          client: _FixtureClient({
        '/content/123/': '''
          <div class="manga-title"><h2>عنوان العمل</h2></div>
          <div class="summary_image"><img src="http://hizomanga.net/cover.webp"></div>
          <div class="manga-excerpt"><div class="excerpt-content"><p>ملخص</p></div></div>
          <div class="manga-status"><span>الحالة</span><span>مستمرة</span></div>
          <div class="manga-tags"><div class="tags-content"><a>رواية مترجمة</a></div></div>
          <div class="wp-manga-chapter"><a href="/content/123/4/">الفصل 4</a></div>
        ''',
        '/content/123/4/': '''
          <div class="reading-content"><p>الفقرة الأولى.</p><p>الفقرة الثانية.</p></div>
          <div class="entry-content"><img src="https://images.example/unrelated-forum.webp"></div>
        ''',
      }));
      final detail = await source.details('https://hizomanga.net/content/123/');
      expect(detail['title'], 'عنوان العمل');
      expect(detail['description'], 'ملخص');
      expect(detail['status'], 'مستمرة');
      expect(detail['type'], 'novel');
      expect((detail['chapters'] as List).single['url'],
          'https://hizomanga.net/content/123/4/');
      final chapter =
          await source.chapterContent('https://hizomanga.net/content/123/4/');
      expect(chapter?['content'], 'الفقرة الأولى.\n\nالفقرة الثانية.');
      expect(chapter?['content'], isNot(contains('unrelated')));
    });
  });

  group('DespairSource', () {
    test('keeps manga and novel URLs distinct and loads novel text', () async {
      final client = _JsonFixtureClient((uri) {
        if (uri.path.endsWith('/manga_works')) {
          return [
            {
              'id': 'm1',
              'slug': 'manga-one',
              'title_ar': 'مانجا',
              'cover_url': 'https://img.example/manga.jpg',
              'genres': ['أكشن'],
              'chapters_count': 1,
              'rating_avg': 8.7,
              'rating_count': 12
            },
          ];
        }
        if (uri.path.endsWith('/novel_works')) {
          return [
            {
              'id': 'n1',
              'slug': 'novel-one',
              'title_ar': 'رواية',
              'cover_url': 'https://img.example/novel.jpg',
              'genres': ['خيال'],
              'chapters_count': 0
            },
          ];
        }
        if (uri.path.endsWith('/work_ratings')) {
          return [
            {'work_id': 'n1', 'stars': 9},
            {'work_id': 'n1', 'stars': 10},
          ];
        }
        if (uri.path.endsWith('/chapters')) {
          return [
            {
              'id': 'mc1',
              'work_id': 'm1',
              'chapter_number': 3,
              'title': 'الفصل 3',
              'pages': ['https://img.example/1.webp']
            },
          ];
        }
        if (uri.path.endsWith('/novel_chapters')) {
          if (uri.queryParameters.containsKey('chapter_number')) {
            return [
              {
                'id': 'nc1',
                'work_id': 'n1',
                'chapter_number': 2,
                'title': 'بداية',
                'content': 'نص الفصل'
              },
            ];
          }
          return [
            {
              'id': 'nc0',
              'work_id': 'n1',
              'chapter_number': 1,
              'title': 'فارغ',
              'content': ''
            },
            {
              'id': 'nc1',
              'work_id': 'n1',
              'chapter_number': 2,
              'title': 'بداية',
              'content': 'نص الفصل'
            },
          ];
        }
        return [];
      });
      final manga = DespairMangaSource(client: client);
      final novels = DespairNovelsSource(client: client);
      expect(
          manga.handles('https://despair-world.com/series/manga-one'), isTrue);
      expect(novels.handles('https://despair-world.com/series/novel-one'),
          isFalse);
      expect(
          novels.handles(
              'https://despair-world.com/series/novel-one?mangaplus_source=despair_novels'),
          isTrue);
      expect(novels.handles('https://despair-world.com/series/manga-one'),
          isFalse);

      final mangaWork = (await manga.latest()).single;
      final novelWork = (await novels.latest()).single;
      expect(mangaWork['type'], 'manga');
      expect(mangaWork['rating'], '8.7');
      expect(novelWork['type'], 'novel');
      expect(novelWork['rating'], '9.5');
      expect(novelWork['url'],
          'https://despair-world.com/series/novel-one?mangaplus_source=despair_novels');
      expect(novelWork['total_chapters'], isNull);
      final detail = await novels.details(novelWork['url'] as String);
      expect((detail['chapters'] as List).length, 1);
      final chapterUrl = (detail['chapters'] as List).single['url'] as String;
      final content = await novels.chapterContent(chapterUrl);
      expect(content?['content'], 'نص الفصل');
      expect(detail['rating'], '9.5');

      final mangaDetail = await manga.details(mangaWork['url'] as String);
      final mangaChapterUrl =
          (mangaDetail['chapters'] as List).single['url'] as String;
      expect((await manga.chapterImages(mangaChapterUrl))?['pages'],
          ['https://img.example/1.webp']);
    });

    test(
        'loads novel pages until PostgREST end, uses id when slug is absent, and shows ratings',
        () async {
      final client = _JsonFixtureClient(
        (uri) {
          if (uri.path.endsWith('/novel_works')) {
            return [
              {
                'id': 'id-only-novel',
                'slug': null,
                'title_ar': 'رواية بلا slug',
                'cover_url': 'https://img.example/novel.webp'
              },
            ];
          }
          if (uri.path.endsWith('/work_ratings')) {
            return [
              {'work_id': 'id-only-novel', 'stars': 8},
              {'work_id': 'id-only-novel', 'stars': 10},
            ];
          }
          return [];
        },
        statusCodeForUri: (uri) => uri.path.endsWith('/novel_works') &&
                uri.queryParameters['offset'] == '24'
            ? 416
            : 200,
      );
      final source = DespairNovelsSource(client: client);
      final firstPage = await source.latest();
      expect(firstPage.single['title'], 'رواية بلا slug');
      expect(firstPage.single['url'],
          'https://despair-world.com/series/id-only-novel?mangaplus_source=despair_novels');
      expect(firstPage.single['rating'], '9.0');
      expect(await source.latest(page: 2), isEmpty);
      final detail = await source.details(firstPage.single['url'] as String);
      expect(detail['title'], 'رواية بلا slug');
      expect(detail['rating'], '9.0');
    });
  });

  test('all new sources are registered for app-wide source resolution', () {
    expect(MangaSourceRegistry.byId('despair_manga'),
        same(MangaSourceRegistry.despairManga));
    expect(MangaSourceRegistry.byId('despair_novels'),
        same(MangaSourceRegistry.despairNovels));
    expect(MangaSourceRegistry.byId('hizomanga'),
        same(MangaSourceRegistry.hizoManga));
    expect(MangaSourceRegistry.byId('mangatik'),
        same(MangaSourceRegistry.mangaTik));
    expect(
        MangaSourceRegistry.forUrl(
            'https://despair-world.com/series/novel?mangaplus_source=despair_novels'),
        same(MangaSourceRegistry.despairNovels));
    expect(
        MangaSourceRegistry.forUrl('https://despair-world.com/series/series/'),
        same(MangaSourceRegistry.despairManga));
  });

  test('new sources resolve their own website icons for branding', () {
    expect(SourceBrand.siteFor('Despair Manga', '')?.host, 'despair-world.com');
    expect(
        SourceBrand.siteFor('Despair Novels', '')?.host, 'despair-world.com');
    expect(SourceBrand.siteFor('Hizo Manga', '')?.host, 'hizomanga.net');
    expect(SourceBrand.siteFor('MangaTik', '')?.host, 'mangatik.com');
  });
}

class _FixtureClient extends http.BaseClient {
  _FixtureClient(this.pages);
  final Map<String, String> pages;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = pages[request.url.path];
    if (body == null)
      return http.StreamedResponse(Stream.value(utf8.encode('Not found')), 404);
    return http.StreamedResponse(Stream.value(utf8.encode(body)), 200,
        headers: const {'content-type': 'text/html; charset=utf-8'});
  }
}

class _JsonFixtureClient extends http.BaseClient {
  _JsonFixtureClient(this.handler, {this.statusCodeForUri});
  final List<Map<String, dynamic>> Function(Uri uri) handler;
  final int Function(Uri uri)? statusCodeForUri;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(handler(request.url)))),
        statusCodeForUri?.call(request.url) ?? 200,
        headers: const {'content-type': 'application/json'},
      );
}
