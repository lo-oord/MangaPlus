import 'package:get/get.dart';
import 'package:mangaplus/app/data/models/chapter.dart';
import 'package:mangaplus/app/data/models/comic.dart';
import 'package:mangaplus/app/data/models/comic_detail.dart';
import 'package:mangaplus/app/data/sources/manga_source_registry.dart';
import 'package:mangaplus/app/data/sources/source_base.dart';
import 'package:mangaplus/app/data/sources/source_values.dart';
import 'package:mangaplus/app/data/sources/team_x_source.dart';

class ComicService {
  ComicService({TeamXSource? source}) : _teamX = source ?? MangaSourceRegistry.teamX;

  final TeamXSource _teamX;
  final _azora = MangaSourceRegistry.azora;
  static const String sourceName = 'Team X';

  static ComicsList mapComicItem(Map<String, dynamic> item) {
    final title = '${item['title'] ?? ''}'.trim();
    final id = '${item['url'] ?? ''}'.trim();
    final number = item['latest_chapter_number'];
    final chapterName = '${item['latest_chapter_name'] ?? ''}'.trim();
    final rawNumber = number?.toString().trim() ?? '';
    final nameNumber = RegExp(r'\d+(?:\.\d+)?').firstMatch(chapterName)?.group(0);
    final chapter = rawNumber.isNotEmpty && rawNumber != 'null'
        ? rawNumber
        : nameNumber ?? '';
    return ComicsList(
      comicId: id,
      title: title,
      link: id,
      image: '${item['image_url'] ?? ''}',
      type: '${item['type'] ?? 'manga'}',
      chapter: chapter,
      rating: '${item['rating'] ?? ''}',
      status: item['status']?.toString() ?? '',
      latestChapterDate: '${item['latest_chapter_date'] ?? ''}',
      genres: item['genres'] is List
          ? (item['genres'] as List).map((value) => value.toString()).toList()
          : const [],
      totalChapters: '${item['total_chapters'] ?? ''}',
      source: '${item['source'] ?? item['source_id'] ?? ''}',
    );
  }

  ComicData _comicData(List<Map<String, dynamic>> items, {
    int page = 1,
    String source = sourceName,
  }) => ComicData(
        comicsList: items.map(mapComicItem).where((item) => item.comicId.isNotEmpty).toList(growable: false),
        source: source,
        page: page,
        genres: const [],
        status: '',
        type: 'manga',
        orderby: '',
      );

  /// Home/latest combines Team X and Azora into one date-ordered feed.
  Future<ComicData> fetchComics({int page = 1}) async {
    final results = await Future.wait([
      _teamX.latestWithChapterDates(page: page).catchError((_) => <Map<String, dynamic>>[]),
      _azora.latest(page: page).catchError((_) => <Map<String, dynamic>>[]),
    ]);
    final items = [...results[0], ...results[1]];
    final indexed = items.asMap().entries.toList();
    indexed.sort((leftEntry, rightEntry) {
      final left = DateTime.tryParse('${leftEntry.value['latest_chapter_date'] ?? ''}'.trim());
      final right = DateTime.tryParse('${rightEntry.value['latest_chapter_date'] ?? ''}'.trim());
      if (left == null) return right == null ? leftEntry.key.compareTo(rightEntry.key) : 1;
      if (right == null) return -1;
      final byDate = right.compareTo(left);
      return byDate == 0 ? leftEntry.key.compareTo(rightEntry.key) : byDate;
    });
    return _comicData(indexed.map((entry) => entry.value).toList(growable: false), page: page);
  }

  /// Search streams batches from every configured manga source as they arrive.
  Future<ComicData> searchComics(
    String query, {
    void Function(List<ComicsList> batch)? onBatch,
  }) async {
    final items = <Map<String, dynamic>>[];
    final result = await MangaSourceRegistry.search(query, onBatch: (batch) {
      items.addAll(batch);
      onBatch?.call(batch.map(mapComicItem).toList(growable: false));
    });
    return _comicData(result.isEmpty ? items : result, source: 'Manga sources');
  }

  Future<ComicData> fetchSearchSuggestions({int limit = 8}) async =>
      _comicData((await _teamX.searchSuggestions(limit: limit)).take(limit).toList());

  Future<ComicDetailData> fetchComicDetail(String comicId) async {
    final source = MangaSourceRegistry.forUrl(comicId);
    if (source == null) throw StateError('لم يتم العثور على مصدر لهذا الرابط.');
    final raw = await source.details(comicId);
    final rawChapters = raw['chapters'] is List
        ? (raw['chapters'] as List)
            .whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .toList(growable: false)
        : const <Map<String, dynamic>>[];
    final chapters = rawChapters.map((entry) {
      final url = '${entry['url'] ?? entry['chapter_url'] ?? ''}'.trim();
      final id = url.isNotEmpty ? url : '${entry['chapter_id'] ?? entry['id'] ?? ''}';
      return Chapter(
        chapterId: id,
        title: '${entry['title'] ?? 'الفصل ${entry['number'] ?? entry['chapter_number'] ?? ''}'}'.trim(),
        link: id,
        releaseTime: _formatDate('${entry['release_date'] ?? entry['date'] ?? ''}'),
      );
    }).where((chapter) => chapter.chapterId.isNotEmpty).toList(growable: false);
    final genres = raw['genres'] is List
        ? (raw['genres'] as List).map((value) => value is Map ? '${value['name'] ?? value['title'] ?? ''}' : value.toString()).where((v) => v.trim().isNotEmpty).toList()
        : <String>[];
    final detail = ComicDetail(
      comicId: '${raw['url'] ?? comicId}',
      coverImage: '${raw['image_url'] ?? raw['image'] ?? ''}',
      title: '${raw['title'] ?? ''}',
      nativeTitle: '${raw['native_title'] ?? ''}',
      genres: genres,
      releaseYear: '${raw['release_year'] ?? raw['year'] ?? ''}',
      author: '${raw['author'] ?? raw['artist'] ?? ''}',
      status: '${raw['status'] ?? ''}',
      type: SourceValues.type([
        raw['type'],
        raw['seriesType'],
        raw['content_type'],
        raw['format'],
      ]),
      totalChapters: '${raw['total_chapters'] ?? chapters.length}',
      updatedOn: _formatDate('${raw['updated_on'] ?? raw['updated_at'] ?? ''}'),
      rating: '${raw['rating'] ?? ''}',
      synopsis: '${raw['synopsis'] ?? raw['description'] ?? ''}',
      chapters: chapters,
    );
    return ComicDetailData(comicDetail: detail, source: source.name);
  }

  Future<ChapterData> fetchChapter(String chapterId) async {
    final source = MangaSourceRegistry.forUrl(chapterId);
    if (source == null) throw StateError('لم يتم العثور على مصدر لهذا الفصل.');
    final raw = await source.chapterImages(chapterId);
    if (raw == null) throw StateError('${source.name} لم يرجع صفحات الفصل.');
    final images = (raw['pages'] as List? ?? const [])
        .map((image) => image.toString())
        .where((image) => image.isNotEmpty)
        .toList(growable: false);
    final navigation = raw['navigation'] is Map
        ? Map<String, dynamic>.from(raw['navigation'])
        : const <String, dynamic>{};
    final chapterItems = (raw['chapters'] as List? ?? const [])
        .whereType<Map>()
        .map((item) {
          final reference = _firstChapterReference([
            item['url'],
            item['chapterUrl'],
            item['chapter_url'],
            item['chapterId'],
            item['chapter_id'],
            item['id'],
          ]);
          return ChapterElement(
            chapterId: reference ?? '',
            title: '${item['title'] ?? ''}',
            url: reference ?? '',
          );
        })
        .where((item) => item.chapterId.isNotEmpty)
        .toList(growable: false);
    final previousChapter = _firstChapterReference([
      raw['previousChapter'],
      raw['previous_chapter'],
      raw['prevChapter'],
      raw['prev_chapter'],
      navigation['prev_chapter'],
      navigation['previous_chapter'],
      navigation['previous'],
      navigation['previousChapter'],
    ]);
    final nextChapter = _firstChapterReference([
      raw['nextChapter'],
      raw['next_chapter'],
      navigation['next_chapter'],
      navigation['next'],
      navigation['nextChapter'],
    ]);
    return ChapterData(
      chapter: DataChapter(
        chapterId: chapterId,
        title: '${raw['title'] ?? ''}',
        images: images,
        previousChapter: previousChapter ?? '',
        nextChapter: nextChapter,
        chapters: chapterItems,
      ),
      source: source.name,
    );
  }

  String? _firstChapterReference(Iterable<dynamic> values) {
    for (final value in values) {
      final reference = _chapterReference(value);
      if (reference != null) return reference;
    }
    return null;
  }

  String? _chapterReference(dynamic value) {
    if (value is Map) {
      return _firstChapterReference([
        value['url'],
        value['chapterUrl'],
        value['chapter_url'],
        value['chapterId'],
        value['chapter_id'],
        value['id'],
      ]);
    }
    final reference = value?.toString().trim() ?? '';
    if (reference.isEmpty ||
        const {'null', 'undefined', '0'}.contains(reference.toLowerCase())) {
      return null;
    }
    final uri = Uri.tryParse(reference);
    if (uri == null || uri.scheme.isEmpty) return null;
    return reference;
  }

  String _formatDate(String value) {
    final date = DateTime.tryParse(value.trim());
    if (date == null) return value;
    final local = date.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)}';
  }
}
