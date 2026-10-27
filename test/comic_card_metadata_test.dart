import 'package:flutter_test/flutter_test.dart';
import 'package:mangaplus/app/data/services/comic_service.dart';

void main() {
  test('normalizes card metadata aliases and nested API values', () {
    final comic = ComicService.mapComicItem({
      'url': 'https://example.test/manga/one',
      'title': 'One',
      'rating': {'average': 8.7},
      'state': {'name': 'ongoing'},
      'details': {
        'chaptersCount': 42,
      },
    });

    expect(comic.rating, '8.7');
    expect(comic.status, 'ongoing');
    expect(comic.totalChapters, '42');
  });

  test('uses chapter list length when a source returns chapters instead of a count', () {
    final comic = ComicService.mapComicItem({
      'url': 'https://example.test/manga/two',
      'title': 'Two',
      'chapters': [
        {'id': 1},
        {'id': 2},
        {'id': 3},
      ],
    });

    expect(comic.totalChapters, '3');
  });
}
