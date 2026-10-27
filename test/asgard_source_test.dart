import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mangaplus/app/data/sources/asgard_source.dart';
import 'package:mangaplus/app/data/sources/manga_source_registry.dart';

void main() {
  test('registry includes Asgard and resolves its series URLs', () {
    expect(MangaSourceRegistry.searchableSources, contains(MangaSourceRegistry.asgard));
    expect(
      MangaSourceRegistry.forUrl('https://asgardscans.com/manga/shadow-slave'),
      same(MangaSourceRegistry.asgard),
    );
  });

  test('parses Asgard search, full chapters, cover and reader page ids', () async {
    final source = AsgardSource(client: MockClient((request) async {
      if (request.url.path.endsWith('/manga/shadow-slave/31')) {
        return http.Response.bytes(utf8.encode(_chapterPage), 200);
      }
      return http.Response.bytes(utf8.encode(_seriesPage), 200);
    }));

    final result = await source.search('Shadow Slave');
    expect(result, hasLength(1));
    expect(result.single['image_url'], 'https://asgardscans.com/media/covers/cover.jpg');

    final details = await source.details('https://asgardscans.com/manga/shadow-slave');
    expect(details['chapters'], hasLength(2));
    expect(details['chapters'][0]['number'], 31);

    final chapter = await source.chapterImages(
      'https://asgardscans.com/manga/shadow-slave/31',
    );
    expect(chapter?['pages'], [
      'https://asgardscans.com/api/public/page/page-1',
      'https://asgardscans.com/api/public/page/page-2',
    ]);
  });
}

const _seriesPage = '''
<html><body>
<h1>Shadow Slave</h1>
<a href="/manga/shadow-slave"><h3>Shadow Slave</h3><img alt="Shadow Slave" src="/media/covers/cover.jpg"></a>
<a href="/manga/shadow-slave/31">الفصل 31</a>
<a href="/manga/shadow-slave/30-old">الفصل 30</a>
</body></html>
''';

const _chapterPage = '''
<html><body>
<script>pages:[{imageUrl:"/api/public/page/page-1"},{imageUrl:"/api/public/page/page-2"}]</script>
</body></html>
''';
