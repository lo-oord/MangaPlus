import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mangaplus/app/data/sources/mangatek_source.dart';

void main() {
  test('reader collects lazy, srcset and picture images once in source order', () async {
    final source = MangaTekSource(
      client: MockClient((request) async {
        expect(request.url.toString(), contains('/reader/magic-emperor/932'));
        return http.Response(_readerPage, 200, headers: const {
          'content-type': 'text/html; charset=utf-8',
        });
      }),
    );

    final chapter = await source.chapterImages(
      'mangatek://chapter?slug=magic-emperor&number=932',
    );

    expect(chapter, isNotNull);
    expect(chapter!['pages'], [
      'https://api.mangatek.com/chapters/450/932/01.webp',
      'https://api.mangatek.com/chapters/450/932/02.webp',
      'https://api.mangatek.com/chapters/450/932/03.webp',
    ]);
  });
}

const _readerPage = '''
<html><body>
  <div class="manga-page">
    <img data-src="https://api.mangatek.com/chapters/450/932/01.webp" src="data:image/gif;base64,AA">
  </div>
  <div class="manga-page">
    <img data-srcset="https://api.mangatek.com/chapters/450/932/02.webp 1x, https://api.mangatek.com/chapters/450/932/02@2x.webp 2x">
  </div>
  <div class="manga-page">
    <picture>
      <source srcset="https://api.mangatek.com/chapters/450/932/03.webp 1x">
      <img src="https://api.mangatek.com/chapters/450/932/03.webp">
    </picture>
  </div>
</body></html>
''';
