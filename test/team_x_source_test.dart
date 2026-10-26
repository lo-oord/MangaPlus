import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mangaplus/app/data/sources/team_x_source.dart';

const _htmlHeaders = {'content-type': 'text/html; charset=utf-8'};

void main() {
  test('loads latest Team X works from the current .uta homepage cards', () async {
    Uri? requested;
    final client = MockClient((request) async {
      requested = request.url;
      return http.Response('''
        <div class="box"><div class="uta">
          <div class="imgu"><a href="/series/martial-peak"><img data-src="/covers/martial.jpg"></a></div>
          <div class="info"><a href="/series/martial-peak"><h3>Martial Peak</h3></a>
            <ul><li><a href="/series/martial-peak/61.5">الفصل 61.5</a></li></ul>
          </div>
        </div></div>
      ''', 200, headers: _htmlHeaders);
    });
    final items = await TeamXSource(client: client).latest();
    expect(requested?.host, 'olympustaff.com');
    expect(items, hasLength(1));
    expect(items.single['title'], 'Martial Peak');
    expect(items.single['url'], startsWith('teamx://series'));
    expect(items.single['image_url'], 'https://olympustaff.com/covers/martial.jpg');
    expect(items.single['latest_chapter_number'], 61.5);
  });

  test('uses the server-rendered /ajax/search result fragment', () async {
    final requested = <Uri>[];
    final client = MockClient((request) async {
      requested.add(request.url);
      if (request.url.path == '/ajax/search') {
        return http.Response('''
          <a href="/series/martial-peak"><img data-src="/covers/martial.jpg"><h4>Martial Peak</h4></a>
        ''', 200, headers: _htmlHeaders);
      }
      if (request.url.path == '/series/martial-peak') {
        return http.Response('<h1>Martial Peak</h1>', 200, headers: _htmlHeaders);
      }
      return http.Response('not found', 404);
    });
    final items = await TeamXSource(client: client).search('Martial Peak');
    expect(requested.first.path, '/ajax/search');
    expect(requested.first.queryParameters['keyword'], 'Martial Peak');
    expect(items, hasLength(1));
    expect(items.single['title'], 'Martial Peak');
  });

  test('loads catalog cards and genre options from current markup', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/series/') {
        return http.Response('''
          <select name="genre"><option value="">تصنيف المانجا</option><option value="فانتازيا">فانتازيا</option></select>
          <div class="bs"><div class="bsx"><a href="/series/martial-peak" title="Martial Peak"><img data-src="/covers/martial.jpg"><div class="tt">Martial Peak</div></a></div></div>
          <ul class="pagination"><li><a class="page-link" href="?page=2">2</a></li></ul>
        ''', 200, headers: _htmlHeaders);
      }
      if (request.url.path == '/series/martial-peak') {
        return http.Response('<h1>Martial Peak</h1>', 200, headers: _htmlHeaders);
      }
      return http.Response('not found', 404);
    });
    final source = TeamXSource(client: client);
    final page = await source.catalogPage();
    final genres = await source.genres();
    expect(page.items, hasLength(1));
    expect(page.nextPage, 2);
    expect(genres, [{'name': 'فانتازيا', 'value': 'فانتازيا'}]);
  });
}
