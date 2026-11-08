import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mangaplus/app/data/sources/cenele_source.dart';

void main() {
  test('novel details expose the date from the chronologically newest chapter',
      () async {
    final source = CeneleNovelSource(
      client: MockClient((request) async {
        expect(request.url.host, 'cenele.com');
        return http.Response(
          '''
          <html><body>
            <h1 class="nhv-novel-title">رواية تجريبية</h1>
            <div class="nhv-simple-rating__avg">8.5</div>
            <ul>
              <li class="wp-manga-chapter">
                <a href="/cont/example/chapter-11">الفصل 11</a>
                <span class="chapter-release-date">2026-11-06</span>
              </li>
              <li class="wp-manga-chapter">
                <a href="/cont/example/chapter-12">الفصل 12</a>
                <span class="chapter-release-date">2026-11-07</span>
              </li>
            </ul>
          </body></html>
        ''',
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
        );
      }),
    );

    final detail = await source.details('https://cenele.com/cont/example/');
    final chapters = detail['chapters'] as List<Map<String, dynamic>>;

    expect(detail['rating'], '8.5');
    expect(detail['total_chapters'], 2);
    expect(detail['latest_chapter_number'], 12);
    expect(detail['latest_chapter_date'], startsWith('2026-11-07'));
    expect(chapters.map((chapter) => chapter['number']).toList(), [12, 11]);
  });

  test('latest novel cards include rating and a machine-readable update date',
      () async {
    final source = CeneleNovelSource(
      client: MockClient((request) async {
        if (request.url.path == '/cont/') {
          return _html('''
            <article class="nhv-library-card">
              <a class="nhv-library-card__cover" href="https://cenele.com/cont/list-latest/">
                <img class="wp-post-image" src="/covers/latest.webp">
                <span class="nhv-library-card__status is-ongoing">مستمرة</span>
              </a>
              <div class="nhv-library-card__body">
                <h2 class="nhv-library-card__title"><a href="https://cenele.com/cont/list-latest/">رواية الأحدث</a></h2>
                <div class="nhv-library-card__meta">23 فصل</div>
              </div>
            </article>
          ''');
        }
        if (request.url.path == '/cont/list-latest/') {
          return _html('''
            <h1 class="nhv-novel-title">رواية الأحدث</h1>
            <span class="nhv-simple-rating__avg">8.7</span>
            <div class="nhv-novel-meta"><div><span>الحالة</span><strong>مستمرة</strong></div></div>
            <ul><li class="wp-manga-chapter">
              <a href="/cont/list-latest/chapter-23">الفصل 23</a>
              <time datetime="2026-11-08T01:00:00+00:00"></time>
              <span class="chapter-release-date">منذ ساعة</span>
            </li></ul>
          ''');
        }
        throw StateError('Unexpected Cenele request: ${request.url}');
      }),
    );

    final items = await source.latest();
    final item = items.single;
    final date = DateTime.tryParse('${item['latest_chapter_date']}');

    expect(item['title'], 'رواية الأحدث');
    expect(item['image_url'], 'https://cenele.com/covers/latest.webp');
    expect(item['rating'], '8.7');
    expect(item['status'], 'مستمرة');
    expect(item['total_chapters'], 23);
    expect(item['latest_chapter_number'], 23);
    expect(date, isNotNull);
    expect(date!.toUtc(), DateTime.parse('2026-11-08T01:00:00+00:00'));
  });

  test('novel search results are enriched with rating and relative update date',
      () async {
    final source = CeneleNovelSource(
      client: MockClient((request) async {
        if (request.url.path == '/') {
          expect(request.url.queryParameters['s'], 'تجريب');
          return _html('''
            <div class="c-tabs-item__content">
              <div class="tab-thumb"><a href="https://cenele.com/cont/search-result/"><img src="/covers/search.webp"></a></div>
              <div class="post-title"><a href="https://cenele.com/cont/search-result/">نتيجة تجريبية</a></div>
              <div class="post-content">وصف مختصر</div>
            </div>
          ''');
        }
        if (request.url.path == '/cont/search-result/') {
          return _html('''
            <h1 class="nhv-novel-title">نتيجة تجريبية</h1>
            <span class="nhv-simple-rating__avg">9.1</span>
            <ul><li class="wp-manga-chapter">
              <a href="/cont/search-result/chapter-9">الفصل 9</a>
              <span class="chapter-release-date">منذ 2 أيام</span>
            </li></ul>
          ''');
        }
        throw StateError('Unexpected Cenele request: ${request.url}');
      }),
    );

    final results = await source.search('تجريب');
    final item = results.single;
    final date = DateTime.tryParse('${item['latest_chapter_date']}');

    expect(item['title'], 'نتيجة تجريبية');
    expect(item['rating'], '9.1');
    expect(date, isNotNull);
    expect(DateTime.now().difference(date!).inHours, inInclusiveRange(47, 49));
  });
}

http.Response _html(String body) => http.Response(
      body,
      200,
      headers: {'content-type': 'text/html; charset=utf-8'},
    );
