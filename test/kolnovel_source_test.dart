import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mangaplus/app/data/sources/kolnovel_source.dart';

void main() {
  test(
    'loads the default volume when its KolNovel volume ID is empty',
    () async {
      final requests = <Uri>[];
      final client = MockClient((request) async {
        requests.add(request.url);
        if (request.url.queryParameters.containsKey('chapter_page')) {
          return http.Response(_volumePage, 200, headers: _htmlHeaders);
        }
        return http.Response(_seriesPage, 200, headers: _htmlHeaders);
      });
      final source = KolNovelSource(client: client);

      final result = await source.details(
        'https://kolnovel.com/series/kolnovel-fixture-test/',
      );

      final chapters = result['chapters'] as List<Map<String, dynamic>>;
      expect(chapters.map((chapter) => chapter['number']).toList(), [3, 2, 1]);
      expect(requests, hasLength(2));
      expect(requests.last.queryParameters, containsPair('chapter_volume', ''));
      expect(requests.last.queryParameters, containsPair('chapter_page', '1'));
    },
  );

  test('reads chapter text from the current KolNovel reader container', () async {
    final source = KolNovelSource(client: MockClient((request) async {
      return http.Response('''
        <html><body>
          <h1 class="kol-chapter-context__title">الفصل 1</h1>
          <div class="kol-chapter-reading"><p>محتوى الفصل الحالي</p></div>
          <a aria-label="التالي" href="/novel-2/">التالي</a>
        </body></html>
      ''', 200, headers: _htmlHeaders);
    }));

    final chapter = await source.chapterContent(
      'https://kolnovel.com/novel-1/',
    );

    expect(chapter?['content'], contains('محتوى الفصل الحالي'));
    expect(chapter?['next_chapter'], 'https://kolnovel.com/novel-2/');
  });
}

const _htmlHeaders = {'content-type': 'text/html; charset=utf-8'};

const _seriesPage = '''
<html><body>
  <h1 class="kol-series-editorial__title">رواية اختبار</h1>
  <div class="kol-series-editorial__facts"><dl>
    <div><dt>الفصول</dt><dd>3</dd></div>
  </dl></div>
  <details data-kol-chapter-volume="" data-kol-volume-page="0"></details>
  <div class="kol-series-editorial__chapter-shortcuts">
    <a data-kol-chapter-transition-link data-kol-chapter-id="103"
       href="/chapter/103/">آخر فصل الفصل 3</a>
  </div>
</body></html>
''';

const _volumePage = '''
<html><body>
  <div class="kol-series-chapter">
    <a data-kol-chapter-transition-link data-kol-chapter-id="101"
       href="/chapter/101/">الفصل 1</a>
  </div>
  <div class="kol-series-chapter">
    <a data-kol-chapter-transition-link data-kol-chapter-id="102"
       href="/chapter/102/">الفصل 2</a>
  </div>
  <div class="kol-series-chapter">
    <a data-kol-chapter-transition-link data-kol-chapter-id="103"
       href="/chapter/103/">الفصل 3</a>
  </div>
</body></html>
''';
