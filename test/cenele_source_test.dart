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
            headers: {'content-type': 'text/html; charset=utf-8'});
      }),
    );

    final detail = await source.details('https://cenele.com/cont/example/');
    final chapters = detail['chapters'] as List<Map<String, dynamic>>;

    expect(detail['rating'], '8.5');
    expect(detail['total_chapters'], 2);
    expect(detail['latest_chapter_number'], 12);
    expect(detail['latest_chapter_date'], '2026-11-07');
    expect(chapters.map((chapter) => chapter['number']).toList(), [12, 11]);
  });
}
