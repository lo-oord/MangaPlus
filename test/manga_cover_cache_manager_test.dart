import 'package:flutter_test/flutter_test.dart';
import 'package:mangaplus/app/core/cache/manga_cover_cache_manager.dart';

void main() {
  test('uses the Kawaii site as the cover referrer for Kawaii works', () {
    final headers = MangaCoverCacheManager.requestHeadersForWorkUrl(
      'https://kawaiimanga.org/manga/example',
    );
    expect(headers['Referer'], 'https://kawaiimanga.org/');
  });

  test('resolves Team X internal work URLs before choosing the referrer', () {
    final workUrl = Uri(
      scheme: 'teamx',
      host: 'series',
      queryParameters: {'url': 'https://olympustaff.com/series/example'},
    ).toString();
    final headers = MangaCoverCacheManager.requestHeadersForWorkUrl(workUrl);
    expect(headers['Referer'], 'https://olympustaff.com/');
  });

  test('uses each other source work origin instead of a global Team X referrer', () {
    final headers = MangaCoverCacheManager.requestHeadersForWorkUrl(
      'https://manga.example/series/example',
    );
    expect(headers['Referer'], 'https://manga.example/');
    expect(headers['Referer'], isNot('https://olympustaff.com/'));
  });
}
