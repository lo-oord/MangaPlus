import 'package:get/get.dart';
import 'package:mangaplus/app/data/models/chapter.dart';
import 'package:mangaplus/app/data/models/comic.dart';
import 'package:mangaplus/app/data/models/comic_detail.dart';
import 'package:mangaplus/app/data/sources/manga_source_registry.dart';
import 'package:mangaplus/app/data/sources/source_base.dart';
import 'package:mangaplus/app/data/sources/source_values.dart';
import 'package:mangaplus/app/data/sources/team_x_source.dart';

class ComicService {
  ComicService({
    TeamXSource? source,
    ContentSource? Function(String url)? sourceResolver,
    ContentSource? Function(String id)? sourceById,
    Duration detailRequestTimeout = const Duration(seconds: 20),
  })  : _teamX = source ?? MangaSourceRegistry.teamX,
        _sourceResolver = sourceResolver ?? MangaSourceRegistry.forUrl,
        _sourceById = sourceById ?? MangaSourceRegistry.byId,
        _detailRequestTimeout = detailRequestTimeout;
  static const Duration _detailCacheTtl = Duration(minutes: 15);
  static const Duration _chapterCacheTtl = Duration(minutes: 15);
  static final Map<String, ComicDetailData> _detailCache = {};
  static final Map<String, DateTime> _detailCacheTimes = {};
  static final Map<String, Future<ComicDetailData>> _detailRequests = {};
  static final Map<String, ChapterData> _chapterCache = {};
  static final Map<String, DateTime> _chapterCacheTimes = {};
  static final Map<String, Future<ChapterData>> _chapterRequests = {};

  final TeamXSource _teamX;
  final ContentSource? Function(String url) _sourceResolver;
  final ContentSource? Function(String id) _sourceById;
  final Duration _detailRequestTimeout;
  final _azora = MangaSourceRegistry.azora;
  final _mknov = MangaSourceRegistry.mknov;
  final _kawaiiManga = MangaSourceRegistry.kawaiiManga;
  final _kawaiiNovels = MangaSourceRegistry.kawaiiNovels;
  final _kolNovel = MangaSourceRegistry.kolNovel;
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
      rating: _cardRating(item),
      status: _cardStatus(item),
      latestChapterDate: '${item['latest_chapter_date'] ?? ''}',
      genres: item['genres'] is List
          ? (item['genres'] as List).map((value) => value.toString()).toList()
          : const [],
      totalChapters: _cardChapterCount(item),
      source: '${item['source'] ?? item['source_id'] ?? ''}',
    );
  }

  static String _cardRating(Map<String, dynamic> item) =>
      SourceValues.rating(item);

  static String _detailImage(Map<String, dynamic> raw) {
    for (final key in const [
      'image_url',
      'image',
      'cover_image',
      'coverImage',
      'cover_url',
      'coverUrl',
      'cover',
      'thumbnail',
      'poster',
    ]) {
      final value = _findCardValue(raw, key, 0);
      final image = _imageText(value, 0);
      if (image.isNotEmpty) return image;
    }
    return '';
  }

  static String _imageText(dynamic value, int depth) {
    if (depth > 4 || value == null) return '';
    if (value is String) {
      final text = value.trim();
      return text.startsWith('http') || text.startsWith('/') ? text : '';
    }
    if (value is List) {
      for (final entry in value) {
        final image = _imageText(entry, depth + 1);
        if (image.isNotEmpty) return image;
      }
      return '';
    }
    if (value is Map) {
      for (final key in const [
        'desktop',
        'mobile',
        'card',
        'url',
        'src',
        'image',
        'cover',
      ]) {
        if (!value.containsKey(key)) continue;
        final image = _imageText(value[key], depth + 1);
        if (image.isNotEmpty) return image;
      }
    }
    return '';
  }

  static String _cardStatus(Map<String, dynamic> item) {
    final value = _nestedCardValue(item, const [
      'status',
      'state',
      'progress',
      'publication_status',
      'publicationStatus',
      'series_status',
      'seriesStatus',
    ]);
    if (value is Map) {
      return '${value['name'] ?? value['title'] ?? value['label'] ?? value['value'] ?? ''}'.trim();
    }
    return value?.toString().trim() ?? '';
  }

  static String _cardChapterCount(Map<String, dynamic> item) {
    final value = _nestedCardValue(item, const [
      'total_chapters',
      'totalChapters',
      'chapter_count',
      'chapterCount',
      'chapters_count',
      'chaptersCount',
      'number_of_chapters',
      'numberOfChapters',
      'chapters',
    ]);
    if (value is List) return '${value.length}';
    if (value == null) return '';
    return value.toString().trim();
  }

  static dynamic _nestedCardValue(
    Map<String, dynamic> item,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = _findCardValue(item, key, 0);
      if (value != null && value.toString().trim().isNotEmpty) return value;
    }
    return null;
  }

  static dynamic _findCardValue(dynamic value, String key, int depth) {
    if (depth > 3 || value == null) return null;
    if (value is Map) {
      if (value.containsKey(key)) return value[key];
      for (final container in const ['data', 'details', 'stats', 'statistics', 'metadata']) {
        if (!value.containsKey(container)) continue;
        final found = _findCardValue(value[container], key, depth + 1);
        if (found != null) return found;
      }
    }
    return null;
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

  /// Home/latest combines Team X and Azora by default, or loads one selected source.
  Future<ComicData> fetchComics({int page = 1, String? sourceId}) async {
    final selectedId = sourceId?.trim() ?? '';
    if (selectedId.isNotEmpty && selectedId != 'all') {
      final source = _sourceById(selectedId);
      if (source == null || source.kind != 'manga') {
        throw StateError('لم يتم العثور على مصدر مانجا صالح.');
      }
      final rawItems = await source.latest(page: page);
      final taggedItems = rawItems.map((item) => {
            ...item,
            'source_id': item['source_id'] ?? source.id,
            'source': item['source'] ?? source.name,
          }).toList(growable: false);
      final indexedItems = taggedItems.asMap().entries.toList();
      indexedItems.sort((leftEntry, rightEntry) {
        final left = DateTime.tryParse(
          '${leftEntry.value['latest_chapter_date'] ?? ''}'.trim(),
        );
        final right = DateTime.tryParse(
          '${rightEntry.value['latest_chapter_date'] ?? ''}'.trim(),
        );
        if (left == null) return right == null ? leftEntry.key.compareTo(rightEntry.key) : 1;
        if (right == null) return -1;
        final byDate = right.compareTo(left);
        return byDate == 0 ? leftEntry.key.compareTo(rightEntry.key) : byDate;
      });
      return _comicData(
        indexedItems.map((entry) => entry.value).toList(growable: false),
        page: page,
        source: source.name,
      );
    }
    final results = await Future.wait([
      _teamX.latest(page: page).catchError((_) => <Map<String, dynamic>>[]),
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

  Future<List<ComicsList>> enrichLatestChapterDates(
    List<ComicsList> comics,
  ) async {
    final candidates = comics
        .where((comic) => comic.comicId.startsWith('teamx://'))
        .take(12)
        .map((comic) => <String, dynamic>{
              'url': comic.comicId,
              'title': comic.title,
              'image_url': comic.image,
              'type': comic.type,
              'latest_chapter_number': comic.chapter,
              'latest_chapter_date': comic.latestChapterDate,
              'rating': comic.rating,
              'status': comic.status,
              'genres': comic.genres,
              'total_chapters': comic.totalChapters,
              'source': comic.source,
            })
        .toList(growable: false);
    if (candidates.isEmpty) return const [];
    final enriched = await _teamX.enrichLatestChapterDates(candidates);
    return enriched.map(mapComicItem).toList(growable: false);
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

  Future<ComicData> fetchSearchSuggestions({int limit = 8}) async {
    final results = await Future.wait<List<Map<String, dynamic>>>([
      _teamX
          .searchSuggestions(limit: limit)
          .catchError((_) => <Map<String, dynamic>>[]),
      _azora
          .searchNovelSuggestions(limit: limit * 2)
          .catchError((_) => <Map<String, dynamic>>[]),
      _mknov
          .searchSuggestions(limit: limit)
          .timeout(const Duration(seconds: 15))
          .catchError((_) => <Map<String, dynamic>>[]),
      _kawaiiManga
          .searchSuggestions(limit: limit)
          .timeout(const Duration(seconds: 20))
          .catchError((_) => <Map<String, dynamic>>[]),
      _kawaiiNovels
          .searchSuggestions(limit: limit)
          .timeout(const Duration(seconds: 40))
          .catchError((_) => <Map<String, dynamic>>[]),
      _kolNovel
          .searchSuggestions(limit: limit)
          .timeout(const Duration(seconds: 40))
          .catchError((_) => <Map<String, dynamic>>[]),
    ]);
    final bySource = <List<Map<String, dynamic>>>[
      results[0]
          .map((item) => {
                ...item,
                'source_id': item['source_id'] ?? 'team_x',
                'source': item['source'] ?? 'Team X',
              })
          .toList(growable: false),
      results[1]
          .map((item) => {
                ...item,
                'source_id': item['source_id'] ?? 'azora',
                'source': item['source'] ?? 'Azora Manga',
              })
          .toList(growable: false),
      results[2]
          .map((item) => {
                ...item,
                'source_id': item['source_id'] ?? 'mknov',
                'source': item['source'] ?? 'MKNOV',
              })
          .toList(growable: false),
      results[3]
          .map((item) => {
                ...item,
                'source_id': item['source_id'] ?? _kawaiiManga.id,
                'source': item['source'] ?? _kawaiiManga.name,
              })
          .toList(growable: false),
      results[4]
          .map((item) => {
                ...item,
                'source_id': item['source_id'] ?? _kawaiiNovels.id,
                'source': item['source'] ?? _kawaiiNovels.name,
              })
          .toList(growable: false),
      results[5]
          .map((item) => {
                ...item,
                'source_id': item['source_id'] ?? _kolNovel.id,
                'source': item['source'] ?? _kolNovel.name,
              })
          .toList(growable: false),
    ];
    final items = <Map<String, dynamic>>[];
    final maxPerSource = bySource.fold<int>(
      0,
      (max, items) => items.length > max ? items.length : max,
    );
    for (var index = 0; index < maxPerSource; index++) {
      for (final sourceItems in bySource) {
        if (index < sourceItems.length) items.add(sourceItems[index]);
      }
    }
    final seen = <String>{};
    final unique = items.where((item) {
      final id = '${item['source_id']}|${item['url']}';
      return seen.add(id);
    }).take(limit * 3).toList(growable: false);
    return _comicData(unique, source: 'Search suggestions');
  }

  Future<ComicDetailData> fetchComicDetail(String comicId) async {
    final key = comicId.trim();
    final cached = _detailCache[key];
    final cachedAt = _detailCacheTimes[key];
    if (cached != null && cachedAt != null &&
        DateTime.now().difference(cachedAt) < _detailCacheTtl) {
      return cached;
    }
    final active = _detailRequests[key];
    if (active != null) return active;
    // Keep the timeout inside the shared in-flight request so every caller
    // settles and the request entry is removed even when a source hangs.
    final request = _fetchComicDetailUncached(key).timeout(_detailRequestTimeout);
    _detailRequests[key] = request;
    try {
      final detail = await request;
      _detailCache[key] = detail;
      _detailCacheTimes[key] = DateTime.now();
      if (_detailCache.length > 100) {
        for (final oldKey in _detailCache.keys.take(25).toList()) {
          _detailCache.remove(oldKey);
          _detailCacheTimes.remove(oldKey);
        }
      }
      return detail;
    } catch (_) {
      if (cached != null) return cached;
      rethrow;
    } finally {
      if (identical(_detailRequests[key], request)) {
        _detailRequests.remove(key);
      }
    }
  }

  Future<ComicDetailData> _fetchComicDetailUncached(String comicId) async {
    final source = _sourceResolver(comicId);
    if (source == null) throw StateError('لم يتم العثور على مصدر لهذا الرابط.');
    final raw = await source.details(comicId);
    final rawChapters = raw['chapters'] is List
        ? (raw['chapters'] as List)
            .whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .toList(growable: false)
        : const <Map<String, dynamic>>[];
    final chapters = rawChapters.map((entry) {
      final url = _chapterReference(
        entry['url'] ?? entry['chapter_url'] ?? entry['chapter_id'] ?? entry['id'],
        baseUrl: comicId,
      );
      final id = url ?? '';
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
      coverImage: _detailImage(raw),
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
    final sourceName = source.id == 'azora' &&
            detail.type.trim().toLowerCase() == 'novel'
        ? 'Azora Novels'
        : source.id == 'kawaii_novels'
            ? 'Kawaii Novels'
            : source.name;
    return ComicDetailData(comicDetail: detail, source: sourceName);
  }

  Future<ChapterData> fetchChapter(String chapterId) => _withChapterCache(
        'manga|${chapterId.trim()}',
        () => _fetchChapterUncached(chapterId),
      );

  Future<ChapterData> _fetchChapterUncached(String chapterId) async {
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
          ], baseUrl: chapterId);
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
    ], baseUrl: chapterId);
    final nextChapter = _firstChapterReference([
      raw['nextChapter'],
      raw['next_chapter'],
      navigation['next_chapter'],
      navigation['next'],
      navigation['nextChapter'],
    ], baseUrl: chapterId);
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

  Future<ChapterData> fetchNovelChapter(String chapterId) => _withChapterCache(
        'novel|${chapterId.trim()}',
        () => _fetchNovelChapterUncached(chapterId),
      );

  Future<ChapterData> _fetchNovelChapterUncached(String chapterId) async {
    final source = MangaSourceRegistry.forUrl(chapterId);
    if (source == null) throw StateError('لم يتم العثور على مصدر لهذا الفصل.');
    final sourceName = source.id == 'azora'
        ? 'Azora Novels'
        : source.id == 'kawaii_novels'
            ? 'Kawaii Novels'
            : source.name;
    final raw = await source.chapterContent(chapterId);
    if (raw == null) throw StateError('$sourceName لم يرجع محتوى الفصل النصي.');
    final content = '${raw['content'] ?? ''}'.trim();
    if (content.isEmpty) throw StateError('$sourceName أرجع فصلًا نصيًا فارغًا.');
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
          ], baseUrl: chapterId);
          return ChapterElement(
            chapterId: reference ?? '',
            title: '${item['title'] ?? ''}',
            url: reference ?? '',
          );
        })
        .where((item) => item.chapterId.isNotEmpty)
        .toList(growable: false);
    return ChapterData(
      chapter: DataChapter(
        chapterId: chapterId,
        title: '${raw['title'] ?? ''}',
        images: const [],
        content: content,
        previousChapter: _firstChapterReference([
              raw['previousChapter'],
              raw['previous_chapter'],
            ], baseUrl: chapterId) ??
            '',
        nextChapter: _firstChapterReference([
          raw['nextChapter'],
          raw['next_chapter'],
        ], baseUrl: chapterId),
        chapters: chapterItems,
      ),
      source: sourceName,
    );
  }

  Future<ChapterData> prefetchChapter(
    String chapterId, {
    required bool isNovel,
  }) => isNovel ? fetchNovelChapter(chapterId) : fetchChapter(chapterId);

  Future<ChapterData> _withChapterCache(
    String key,
    Future<ChapterData> Function() load,
  ) async {
    final cached = _chapterCache[key];
    final cachedAt = _chapterCacheTimes[key];
    if (cached != null && cachedAt != null &&
        DateTime.now().difference(cachedAt) < _chapterCacheTtl) {
      return cached;
    }
    final active = _chapterRequests[key];
    if (active != null) return active;
    final request = load();
    _chapterRequests[key] = request;
    try {
      final chapter = await request;
      _chapterCache[key] = chapter;
      _chapterCacheTimes[key] = DateTime.now();
      if (_chapterCache.length > 8) {
        final oldest = _chapterCacheTimes.entries.toList()
          ..sort((left, right) => left.value.compareTo(right.value));
        for (final entry in oldest.take(_chapterCache.length - 8)) {
          _chapterCache.remove(entry.key);
          _chapterCacheTimes.remove(entry.key);
        }
      }
      return chapter;
    } finally {
      if (identical(_chapterRequests[key], request)) {
        _chapterRequests.remove(key);
      }
    }
  }

  String? _firstChapterReference(
    Iterable<dynamic> values, {
    String? baseUrl,
  }) {
    for (final value in values) {
      final reference = _chapterReference(value, baseUrl: baseUrl);
      if (reference != null) return reference;
    }
    return null;
  }

  String? _chapterReference(dynamic value, {String? baseUrl}) {
    if (value is Map) {
      return _firstChapterReference([
        value['url'],
        value['chapterUrl'],
        value['chapter_url'],
        value['chapterId'],
        value['chapter_id'],
        value['id'],
      ], baseUrl: baseUrl);
    }
    final reference = value?.toString().trim() ?? '';
    if (reference.isEmpty ||
        const {'null', 'undefined', '0'}.contains(reference.toLowerCase())) {
      return null;
    }
    final uri = Uri.tryParse(reference);
    if (uri == null) return null;
    if (uri.hasScheme) return reference;
    final base = Uri.tryParse(baseUrl ?? '');
    if (base == null || !base.hasScheme) return null;
    return base.resolveUri(uri).toString();
  }

  String _formatDate(String value) {
    final date = DateTime.tryParse(value.trim());
    if (date == null) return value;
    final local = date.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)}';
  }
}
