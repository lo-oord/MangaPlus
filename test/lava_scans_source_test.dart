import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mangaplus/app/data/sources/lava_scans_source.dart';

void main() {
  test('details extract and order chapter release dates from the chapter rows',
      () async {
    final source = LavaScansSource(
      client: MockClient((request) async {
        expect(request.url.path, '/manga/series-one');
        return http.Response(
            '''
          <html><body>
            <h1 class="lh-title">Series One</h1>
            <div class="lh-meta-row"><span class="fa-star">8.4</span></div>
            <div class="chapter-row">
              <a href="https://lavascans.com/manga/series-one-chapter-11">
                <span>الفصل 11</span><time datetime="2026-11-06T10:00:00Z"></time>
              </a>
            </div>
            <div class="chapter-row">
              <a href="https://lavascans.com/manga/series-one-chapter-12">
                <span>الفصل 12</span><time datetime="2026-11-07T10:00:00Z"></time>
              </a>
            </div>
          </body></html>
        ''',
            200,
            headers: {'content-type': 'text/html; charset=utf-8'});
      }),
    );

    final detail =
        await source.details('https://lavascans.com/manga/series-one');
    final chapters = detail['chapters'] as List<Map<String, dynamic>>;

    expect(detail['rating'], '8.4');
    expect(detail['total_chapters'], 2);
    expect(detail['latest_chapter_number'], 12);
    expect(detail['latest_chapter_date'], '2026-11-07T10:00:00.000Z');
    expect(chapters.map((chapter) => chapter['number']).toList(), [12, 11]);
    expect(chapters.first['release_date'], '2026-11-07T10:00:00.000Z');
  });
}
