import 'package:get/get.dart';
import 'package:mangaplus/app/data/models/chapter.dart';
import 'package:mangaplus/app/data/models/comic.dart';
import 'package:mangaplus/app/data/models/comic_detail.dart';
import 'package:mangaplus/app/data/sources/team_x_source.dart';

/// Maps Team X's HTML-backed catalog into the application's existing models.
class ComicService {
  ComicService({TeamXSource? source}) : _source = source ?? TeamXSource();

  final TeamXSource _source;
  static const String sourceName = 'Team X';

  static ComicsList mapComicItem(Map<String, dynamic> item) {
    final title = '${item['title'] ?? ''}'.trim();
    final id = '${item['url'] ?? ''}'.trim();
    final number = item['latest_chapter_number'];
    final chapterName = '${item['latest_chapter_name'] ?? ''}'.trim();
    final rawNumber = number?.toString().trim() ?? '';
    final nameNumber =
        RegExp(r'\d+(?:\.\d+)?').firstMatch(chapterName)?.group(0);
    final chapterNumber = rawNumber.isNotEmpty && rawNumber != 'null'
        ? rawNumber
        : nameNumber;
    final chapter = chapterNumber == null
        ? ''
        : chapterNumber.toString();
    return ComicsList(
      comicId: id,
      title: title,
      link: id,
      image: '${item['image_url'] ?? ''}',
      type: '${item['type'] ?? 'manga'}',
      chapter: chapter,
      rating: '${item['rating'] ?? ''}',
      status: '${item['status'] ?? ''}',
      latestChapterDate: '${item['latest_chapter_date'] ?? ''}',
      genres: item['genres'] is List
          ? (item['genres'] as List).map((value) => value.toString()).toList()
          : const [],
      totalChapters: '${item['total_chapters'] ?? ''}',
    );
  }

  ComicData _comicData(List<Map<String, dynamic>> items, {int page = 1}) =>
      ComicData(
        comicsList: items.map(mapComicItem).toList(growable: false),
        source: sourceName,
        page: page,
        genres: const [],
        status: '',
        type: 'manga',
        orderby: '',
      );

  Future<ComicData> fetchComics({int page = 1}) async =>
      _comicData(await _source.latestWithChapterDates(page: page), page: page);

  Future<ComicData> searchComics(String query) async =>
      _comicData(await _source.search(query));

  Future<ComicData> fetchSearchSuggestions({int limit = 8}) async =>
      _comicData(await _source.searchSuggestions(limit: limit));

  Future<ComicDetailData> fetchComicDetail(String comicId) async {
    final raw = await _source.details(comicId);
    final rawChapters = raw['chapters'] is List
        ? (raw['chapters'] as List)
            .whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .toList(growable: false)
        : const <Map<String, dynamic>>[];
    final chapters = rawChapters.map((entry) {
      final url = '${entry['url'] ?? ''}';
      return Chapter(
        chapterId: url,
        title: '${entry['title'] ?? ''}',
        link: url,
        releaseTime: _formatDate('${entry['release_date'] ?? ''}'),
      );
    }).toList(growable: false);
    final genres = raw['genres'] is List
        ? (raw['genres'] as List).map((value) => value.toString()).toList()
        : <String>[];
    final detail = ComicDetail(
      comicId: '${raw['url'] ?? comicId}',
      coverImage: '${raw['image_url'] ?? ''}',
      title: '${raw['title'] ?? ''}',
      nativeTitle: '',
      genres: genres,
      releaseYear: '${raw['release_year'] ?? ''}',
      author: '${raw['artist'] ?? ''}',
      status: '${raw['status'] ?? ''}',
      type: '${raw['type'] ?? 'manga'}',
      totalChapters: '${raw['total_chapters'] ?? chapters.length}',
      updatedOn: _formatDate('${raw['updated_on'] ?? ''}'),
      rating: '${raw['rating'] ?? ''}',
      synopsis: '${raw['synopsis'] ?? raw['description'] ?? ''}',
      chapters: chapters,
    );
    return ComicDetailData(comicDetail: detail, source: sourceName);
  }

  Future<ChapterData> fetchChapter(String chapterId) async {
    final raw = await _source.chapterImages(chapterId);
    if (raw == null) throw StateError('Team X did not return chapter data.');
    final images = (raw['pages'] as List? ?? const [])
        .map((image) => image.toString())
        .where((image) => image.isNotEmpty)
        .toList(growable: false);
    return ChapterData(
      chapter: DataChapter(
        chapterId: chapterId,
        title: '${raw['title'] ?? ''}',
        images: images,
        previousChapter: '${raw['previousChapter'] ?? ''}',
        nextChapter: raw['nextChapter']?.toString(),
        chapters: const [],
      ),
      source: sourceName,
    );
  }

  String _formatDate(String value) {
    final date = DateTime.tryParse(value.trim());
    if (date == null) return value;
    String two(int number) => number.toString().padLeft(2, '0');
    final local = date.toLocal();
    return '${local.year}-${two(local.month)}-${two(local.day)}';
  }
}
