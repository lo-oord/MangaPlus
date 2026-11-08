import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mangaplus/app/data/sources/galaxy_novels_source.dart';
import 'package:mangaplus/app/data/sources/manga_source_registry.dart';
import 'package:mangaplus/app/data/sources/source_brand.dart';

void main() {
  group('Galaxy Novels source', () {
    test(
      'search reads the official manifest/index and maps Arabic metadata',
      () async {
        final source = GalaxyNovelsSource(
          client: MockClient((request) async {
            if (request.url.path.endsWith('/search/manifest.json')) {
              return http.Response(
                jsonEncode({'index': '/search/index.json'}),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            if (request.url.path == '/search/index.json') {
              return http.Response(
                jsonEncode({
                  'items': [
                    {
                      't': 'رواية تجريبية',
                      'o': 'Example Novel',
                      'u': '/novel/example/',
                      'c': '/covers/example.webp',
                      'g': ['فانتازيا', 'مغامرة'],
                      'n': 42,
                      'st': 'مستمرة',
                      's': 'رواية تجريبية example novel',
                      'r': 991234,
                    },
                    {
                      't': 'عمل آخر',
                      'u': '/novel/other/',
                      'c': '/covers/other.webp',
                      's': 'شيء آخر',
                    },
                  ],
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            throw StateError('Unexpected request: ${request.url}');
          }),
        );

        final results = await source.search('رواية تجريبية');
        expect(results, hasLength(1));
        expect(results.single['title'], 'رواية تجريبية');
        expect(results.single['native_title'], 'Example Novel');
        expect(
          results.single['url'],
          'https://galaxynovels.com/novel/example/',
        );
        expect(
          results.single['image_url'],
          'https://galaxynovels.com/covers/example.webp',
        );
        expect(results.single['genres'], ['فانتازيا', 'مغامرة']);
        expect(results.single['type'], 'novel');
        expect(results.single['source_id'], 'galaxynovels');
        expect(results.single['total_chapters'], 42);
        expect(
          results.single['rating'],
          isEmpty,
          reason: 'The index r value is a ranking score, not the rating.',
        );
      },
    );

    test(
      'latest reads novel cards including covers, status and date',
      () async {
        final source = GalaxyNovelsSource(
          client: MockClient((request) async {
            expect(request.url.host, 'galaxynovels.com');
            expect(request.url.path, '/novels/');
            expect(request.url.queryParameters['sort'], 'new');
            expect(request.url.queryParameters['page'], '2');
            return http.Response(
              '''
            <article class="wor-novel-card">
              <a class="wor-novel-card__cover" href="/novel/example/">
                <img class="wor-cover-img" src="/covers/example.webp">
              </a>
              <h3><a href="/novel/example/">رواية أحدث</a></h3>
              <span class="wor-cover-status">مستمرة</span>
              <time datetime="2026-11-07T12:00:00+00:00">قبل يوم</time>
            </article>
            ''',
              200,
              headers: {'content-type': 'text/html; charset=utf-8'},
            );
          }),
        );

        final results = await source.latest(page: 2);
        expect(results, hasLength(1));
        expect(results.single['title'], 'رواية أحدث');
        expect(
          results.single['image_url'],
          'https://galaxynovels.com/covers/example.webp',
        );
        expect(results.single['status'], 'مستمرة');
        expect(
          results.single['latest_chapter_date'],
          '2026-11-07T12:00:00+00:00',
        );
      },
    );

    test(
      'details expose rating, metadata, newest chapter and its date',
      () async {
        final source = GalaxyNovelsSource(
          client: MockClient((request) async {
            if (request.url.path == '/novel/example/') {
              return http.Response(
                '''
              <html><head><meta property="og:title" content="Example – Galaxy Novels"></head>
              <body>
                <h1>رواية تجريبية</h1>
                <img class="wor-cover-img" data-src="/covers/detail.webp">
                <p class="wor-single-hero__meta-text">المؤلف: <span>كاتب</span></p>
                <div class="wor-single-summary__text">ملخص القصة</div>
                <a class="wor-tag-pill">فانتازيا</a>
                <span class="wor-cover-status">مكتملة</span>
                <button data-current-average="4.6">★ 4.6</button>
                <div data-wor-chapters-container data-rendered-total="2"
                  data-manifest-url="/chapters/manifest.json"></div>
              </body></html>
              ''',
                200,
                headers: {'content-type': 'text/html; charset=utf-8'},
              );
            }
            if (request.url.path == '/chapters/manifest.json') {
              return http.Response(
                jsonEncode({
                  'total': 2,
                  'chapters': [
                    {
                      'id': 101,
                      'position': 1,
                      'number': '1',
                      'label': 'الفصل 1',
                      'title': 'البداية',
                      'url': '/novel/example/chapter-1/start/',
                      'date_iso': '2026-11-05T10:00:00+00:00',
                    },
                    {
                      'id': 102,
                      'position': 2,
                      'number': '2',
                      'label': 'الفصل 2',
                      'title': 'المواجهة',
                      'url': '/novel/example/chapter-2/fight/',
                      'date_iso': '2026-11-07T10:00:00+00:00',
                    },
                  ],
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            throw StateError('Unexpected request: ${request.url}');
          }),
        );

        final detail = await source.details(
          'https://www.galaxynovels.com/novel/example/',
        );
        final chapters = detail['chapters'] as List<Map<String, dynamic>>;
        expect(detail['title'], 'رواية تجريبية');
        expect(
          detail['image_url'],
          'https://galaxynovels.com/covers/detail.webp',
        );
        expect(detail['rating'], '4.6');
        expect(detail['author'], 'كاتب');
        expect(detail['genres'], ['فانتازيا']);
        expect(detail['status'], 'مكتملة');
        expect(detail['description'], 'ملخص القصة');
        expect(detail['synopsis'], 'ملخص القصة');
        expect(detail['total_chapters'], 2);
        expect(detail['latest_chapter_number'], 2);
        expect(detail['latest_chapter_date'], '2026-11-07T10:00:00+00:00');
        expect(chapters.map((chapter) => chapter['number']).toList(), [2, 1]);
        expect(
          chapters.first['url'],
          'https://galaxynovels.com/novel/example/chapter-2/fight/',
        );
      },
    );

    test(
      'chapter reader uses the source API and returns readable text',
      () async {
        final source = GalaxyNovelsSource(
          client: MockClient((request) async {
            expect(request.url.path, '/wp-json/wor-reader-app/v1/chapters/12');
            return http.Response(
              jsonEncode({
                'data': {
                  'title': 'الفصل 12',
                  'content_html': '<p>فقرة أولى</p><p>فقرة ثانية</p>',
                },
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        );

        final result = await source.chapterContent(
          'https://galaxynovels.com/novel/example/chapter-12/slug/',
        );
        expect(result?['title'], 'الفصل 12');
        expect(result?['content'], 'فقرة أولى\nفقرة ثانية');
        expect(
          result?['url'],
          'https://galaxynovels.com/novel/example/chapter-12/slug/',
        );
      },
    );

    test('registry resolves Galaxy novel and source branding', () {
      expect(
        MangaSourceRegistry.byId('galaxynovels'),
        same(MangaSourceRegistry.galaxyNovels),
      );
      expect(
        MangaSourceRegistry.forUrl(
          'https://galaxynovels.com/novel/example/chapter-1/',
        ),
        same(MangaSourceRegistry.galaxyNovels),
      );
      expect(MangaSourceRegistry.galaxyNovels.kind, 'novel');
      expect(
        SourceBrand.siteFor('Galaxy Novels', '')?.host,
        'galaxynovels.com',
      );
    });
  });
}
