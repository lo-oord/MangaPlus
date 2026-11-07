import 'package:flutter_test/flutter_test.dart';
import 'package:mangaplus/app/data/models/comic_detail.dart';
import 'package:mangaplus/app/data/services/comic_service.dart';
import 'package:mangaplus/app/data/sources/source_values.dart';

ComicDetail _detail({
  String id = 'm1',
  String cover = '',
  String title = 'Title',
  String nativeTitle = '',
  List<String> alt = const [],
  List<String> genres = const [],
  String year = '',
  String author = '',
  String artist = '',
  String translator = '',
  String status = '',
  String type = 'manga',
  String total = '',
  String updated = '',
  String rating = '',
  String synopsis = '',
  List<Chapter> chapters = const [],
}) =>
    ComicDetail(
      comicId: id,
      coverImage: cover,
      title: title,
      nativeTitle: nativeTitle,
      alternativeTitles: alt,
      genres: genres,
      releaseYear: year,
      author: author,
      artist: artist,
      translator: translator,
      status: status,
      type: type,
      totalChapters: total,
      updatedOn: updated,
      rating: rating,
      synopsis: synopsis,
      chapters: chapters,
    );

Chapter _chapter(String id, String link, {String title = ''}) => Chapter(
      chapterId: id,
      title: title.isEmpty ? id : title,
      link: link,
      releaseTime: '',
    );

void main() {
  group('ComicService.mapComicItem regressions', () {
    test('reads image_url and resolves relative covers against work link', () {
      final item = ComicService.mapComicItem({
        'id': '1',
        'title': 'عمل',
        'link': 'https://site.test/manga/work',
        'image_url': '/covers/a.webp',
        'status': 'ongoing',
        'chapters': [
          {'url': 'https://site.test/c/1'},
          {'url': 'https://site.test/c/2'},
        ],
      });
      expect(item.image, 'https://site.test/covers/a.webp');
      expect(item.totalChapters, '2');
      expect(item.status, SourceValues.statusOngoing);
    });

    test('normalizes MangaTek on_hiatus and prefers real chapter list count', () {
      final item = ComicService.mapComicItem({
        'comic_id': 'mt-1',
        'title': 'MangaTek Work',
        'link': 'https://mangatek.test/work',
        'image': 'https://cdn.test/cover.jpg',
        'status': 'on_hiatus',
        'total_chapters': 0,
        'chapters': [
          {'url': 'https://mangatek.test/c/10', 'number': 10},
        ],
      });
      expect(item.status, SourceValues.statusHiatus);
      expect(item.totalChapters, '1');
    });

    test('reads nested status/count aliases', () {
      final item = ComicService.mapComicItem({
        'id': '2',
        'title': 'Nested',
        'link': 'https://site.test/n',
        'image': 'https://cdn.test/n.jpg',
        'details': {'status': {'name': 'Completed'}, 'chaptersCount': 87},
      });
      expect(item.status, SourceValues.statusCompleted);
      expect(item.totalChapters, '87');
    });

    test('keeps unknown status/count/image empty', () {
      final item = ComicService.mapComicItem({
        'id': '3',
        'title': 'Unknown',
        'link': 'https://site.test/u',
      });
      expect(item.status, '');
      expect(item.chapter, '');
      expect(item.image, '');
    });
  });

  group('ComicService.mapComicDetail regressions', () {
    test('extracts author/artist/translator and de-dupes alternative titles', () {
      final detail = ComicService.mapComicDetail({
        'comic_id': 'd1',
        'title': 'Title',
        'link': 'https://site.test/d1',
        'image': 'https://cdn.test/d1.jpg',
        'description': 'Desc',
        'status': 'hiatus',
        'author': 'كاتب',
        'artist': 'رسام',
        'translator': 'مترجم',
        'alternative_titles': ['Alt 1', 'Alt 2', 'Title'],
        'native_title': 'Title',
        'genres': ['Action', 'Drama'],
        'chapters': [
          {'url': 'https://site.test/d1/c/2', 'number': 2, 'title': 'الفصل 2'},
          {'url': 'https://site.test/d1/c/1', 'number': 1, 'title': 'الفصل 1'},
        ],
      }, comicId: 'd1');
      expect(detail.status, SourceValues.statusHiatus);
      expect(detail.author, 'كاتب');
      expect(detail.artist, 'رسام');
      expect(detail.translator, 'مترجم');
      expect(detail.alternativeTitles, ['Alt 1', 'Alt 2']);
      expect(detail.nativeTitle, '');
      expect(detail.chapters.length, 2);
      expect(detail.totalChapters, '2');
    });

    test('deduplicates chapters by reference and drops invalid entries', () {
      final detail = ComicService.mapComicDetail({
        'id': 'd2',
        'title': 'Dedupe',
        'link': 'https://site.test/d2',
        'chapters': [
          {'url': 'https://site.test/c/5', 'number': 5},
          {'url': 'https://site.test/c/3', 'number': 3},
          {'url': 'https://site.test/c/5/', 'number': 5},
          {'title': 'no reference'},
        ],
      }, comicId: 'd2');
      expect(detail.chapters.length, 2);
      expect(detail.chapters.map((c) => c.link).toSet().length, 2);
      expect(detail.totalChapters, '2');
    });

    test('uses chapter list length when provider count is wrong or zero', () {
      final detail = ComicService.mapComicDetail({
        'id': 'd3',
        'title': 'Count',
        'link': 'https://site.test/d3',
        'total_chapters': 0,
        'chapters': List.generate(
          4,
          (i) => {'url': 'https://site.test/c/${i + 1}', 'number': i + 1},
        ),
      }, comicId: 'd3');
      expect(detail.totalChapters, '4');
    });
  });

  group('ComicDetail.mergedWith', () {
    test('falls back to previous data when incoming fields are empty', () {
      final previous = _detail(
        id: 'm1',
        cover: 'https://cdn.test/base.jpg',
        title: 'Base',
        synopsis: 'وصف كامل',
        genres: const ['Action'],
        status: SourceValues.statusOngoing,
        rating: '4.5',
        chapters: [_chapter('1', 'u1')],
        author: 'مؤلف',
        year: '2020',
        nativeTitle: 'Native',
        updated: '2024-01-01',
      );
      final partial = _detail(
        id: '',
        cover: '',
        title: '',
        synopsis: '',
        status: '',
        rating: '',
        chapters: const [],
        author: '',
        year: '',
      );
      final merged = partial.mergedWith(previous);
      expect(merged.title, 'Base');
      expect(merged.coverImage, 'https://cdn.test/base.jpg');
      expect(merged.synopsis, 'وصف كامل');
      expect(merged.status, SourceValues.statusOngoing);
      expect(merged.rating, '4.5');
      expect(merged.chapters.length, 1);
      expect(merged.author, 'مؤلف');
      expect(merged.releaseYear, '2020');
      expect(merged.nativeTitle, 'Native');
      expect(merged.updatedOn, '2024-01-01');
      expect(merged.totalChapters, '1');
    });

    test('accepts incoming data that is genuinely present', () {
      final previous = _detail(id: 'm1', title: 'Base');
      final incoming = _detail(
        id: 'm1',
        title: 'Base',
        cover: 'https://cdn.test/new.jpg',
        synopsis: 'جديد',
        genres: const ['Drama'],
        status: SourceValues.statusCompleted,
        rating: '4.0',
        chapters: [_chapter('1', 'u1'), _chapter('2', 'u2')],
        artist: 'رسام',
      );
      final merged = incoming.mergedWith(previous);
      expect(merged.coverImage, 'https://cdn.test/new.jpg');
      expect(merged.synopsis, 'جديد');
      expect(merged.status, SourceValues.statusCompleted);
      expect(merged.chapters.length, 2);
      expect(merged.artist, 'رسام');
    });
  });

  group('source count edge cases', () {
    test('Manga Swat-style zero counter alone stays unavailable', () {
      final item = ComicService.mapComicItem({
        'id': 'z',
        'title': 'Z',
        'link': 'https://site.test/z',
        'total_chapters': 0,
      });
      expect(item.chapter, '');
    });
  });
}
