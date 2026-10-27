import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mangaplus/app/data/sources/manga_source_registry.dart';
import 'package:mangaplus/app/data/sources/seanovel_source.dart';

void main() {
  test('registry includes SeaNovel as a novel source', () {
    expect(MangaSourceRegistry.searchableSources, contains(MangaSourceRegistry.seaNovel));
    expect(
      MangaSourceRegistry.forUrl('https://seanovel.org/novels/the-greatest-sinner'),
      same(MangaSourceRegistry.seaNovel),
    );
  });

  test('SeaNovel search, details and chapter content work', () async {
    final source = SeanovelSource(client: MockClient((request) async {
      if (request.url.path == '/api/search-index') {
        return http.Response.bytes(utf8.encode(_index), 200);
      }
      if (request.url.path == '/api/novel/the-greatest-sinner/chapters') {
        return http.Response.bytes(utf8.encode(_chapters), 200);
      }
      if (request.url.path.contains('/chapters/326')) {
        return http.Response.bytes(utf8.encode(_chapter), 200);
      }
      return http.Response.bytes(utf8.encode(_novel), 200);
    }));

    final results = await source.search('greatest sinner');
    expect(results, hasLength(1));
    expect(results.single['image_url'], contains('/api/novel/the-greatest-sinner/cover'));

    final details = await source.details(
      'https://seanovel.org/novels/the-greatest-sinner',
    );
    expect(details['chapters'], hasLength(2));
    expect(details['total_chapters'], 2);

    final chapter = await source.chapterContent(
      'https://seanovel.org/novels/the-greatest-sinner/chapters/326',
    );
    expect(chapter?['chapter_number'], 326);
    expect(chapter?['content'], contains('نص الفصل')); 
  });
}

const _index = '''
[{"slug":"the-greatest-sinner","title_ar":"أعظم الخاطئين","title_original":"The Greatest Sinner","genres":["أكشن"],"chapters_count":326,"cover_version":"1"}]
''';

const _chapters = '''
{"chapters":[{"id":1,"title":"البداية"},{"id":326,"title":"بلورات مانا"}],"total":326,"offset":0,"hasMore":false}
''';

const _novel = '''
<html><body><h1 class="novel-title">أعظم الخاطئين</h1><img class="novel-cover" src="/api/novel/the-greatest-sinner/cover?type=original"></body></html>
''';

const _chapter = '''
<html><body><h1 class="reader-chapter-title">بلورات مانا</h1><article class="reader-content"><p class="sr-only">وصف</p><p>نص الفصل الحقيقي.</p></article></body></html>
''';
