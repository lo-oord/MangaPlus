import 'package:mangaplus/app/core/utils/chapter_reference_identity.dart';
import 'package:mangaplus/app/data/models/chapter.dart';
import 'package:mangaplus/app/data/models/comic.dart';
import 'package:mangaplus/app/data/models/comic_detail.dart';
import 'package:mangaplus/app/data/sources/manga_html_utils.dart';
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
    Duration chapterRequestTimeout = const Duration(seconds: 30),
  })  : _teamX = source ?? MangaSourceRegistry.teamX,
        _sourceResolver = sourceResolver ?? MangaSourceRegistry.forUrl,
        _sourceById = sourceById ?? MangaSourceRegistry.byId,
        _detailRequestTimeout = detailRequestTimeout,
        _chapterRequestTimeout = chapterRequestTimeout;
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
  final Duration _chapterRequestTimeout;
  final _azora = MangaSourceRegistry.azora;
  final _mknov = MangaSourceRegistry.mknov;
  final _kawaiiManga = MangaSourceRegistry.kawaiiManga;
  final _kawaiiNovels = MangaSourceRegistry.kawaiiNovels;
  final _kolNovel = MangaSourceRegistry.kolNovel;
  static const String sourceName = 'Team X';

  /// Converts one raw source result into the shared card model.
  ///
  /// Normalising here means a source can expose `cover_image`, a relative
  /// image path, an Arabic status or a nested chapter list and still reach the
  /// UI in exactly the same shape as every other source.
  static ComicsList mapComicItem(Map<String, dynamic> item) {
    final id = SourceValues.firstText([
      item['url'],
      item['link'],
      item['comicId'],
    ]);
    final chapterName = SourceValues.text(item['latest_chapter_name']);
    final rawNumber = SourceValues.text(item['latest_chapter_number']);
    final nameNumber =
        RegExp(r'\d+(?:\.\d+)?').firstMatch(chapterName)?.group(0);
    final chapter = rawNumber.isNotEmpty &&
            !const {'0', 'null', 'nan'}.contains(rawNumber.toLowerCase())
        ? rawNumber
        : nameNumber ?? '';
    final sourceId = SourceValues.firstText([item['source_id']]);
    final fallbackType = SourceValues.canonicalType(
      [item['category'], item['source_kind'], item['kind']],
      fallback: sourceId.toLowerCase().contains('novel') ||
              sourceId.toLowerCase().contains('seanovel')
          ? 'novel'
          : 'manga',
    );
    return ComicsList(
      comicId: id,
      title: SourceValues.text(item['title']),
      link: id,
      image: SourceValues.image(item, baseUrl: id),
      type: SourceValues.canonicalType(
        [
          item['type'],
          item['seriesType'],
          item['series_type'],
          item['content_type'],
          item['format'],
        ],
        fallback: fallbackType,
      ),
      chapter: chapter,
      rating: SourceValues.rating(item),
      status: SourceValues.status(
        SourceValues.lookup(item, const [
              'status',
              'seriesStatus',
              'series_status',
              'state',
              'progress',
              'publication_status',
              'publicationStatus',
            ]) ??
            '',
      ),
      latestChapterDate: SourceValues.text(
        item['latest_chapter_date'] ??
            item['updated_on'] ??
            item['updated_at'],
      ),
      genres: _genres(item['genres'] ?? item['tags'] ?? item['categories']),
      totalChapters: SourceValues.chapterCount(
        item['chapters'] is List ? item['chapters'] : item,
      ),
      source: SourceValues.firstText([item['source'], item['source_id']]),
    );
  }

  /// Converts a raw `details()` payload into the shared detail model.
  ///
  /// The chapter count always describes the chapter list that was actually
  /// produced, so the number shown to the user can never disagree with the
  /// list rendered below it.
  static ComicDetail mapComicDetail(
    Map<String, dynamic> raw, {
    required String comicId,
    String fallbackType = 'manga',
  }) {
    final chapters = mapChapters(raw, comicId);
    final title = SourceValues.text(raw['title']);
    final nativeTitle = _nativeTitle(raw, title);
    final totalChapters = chapters.isNotEmpty
        ? '${chapters.length}'
        : SourceValues.chapterCount(raw);
    return ComicDetail(
      comicId: SourceValues.firstText([raw['url'], comicId]),
      coverImage: SourceValues.image(raw, baseUrl: comicId),
      title: title,
      nativeTitle: nativeTitle,
      alternativeTitles: _alternativeTitles(
        raw,
        title: title,
        nativeTitle: nativeTitle,
      ),
      genres: _genres(raw['genres'] ?? raw['tags'] ?? raw['categories']),
      releaseYear: SourceValues.year(SourceValues.firstText([
        raw['release_year'],
        raw['year'],
        raw['published'],
        raw['releaseDate'],
        raw['published_at'],
      ])),
      author: SourceValues.firstText([
        raw['author'],
        raw['writer'],
        raw['creator'],
      ]),
      artist: SourceValues.firstText([
        raw['artist'],
        raw['illustrator'],
      ]),
      translator: SourceValues.firstText([
        raw['translator'],
        raw['translation'],
      ]),
      status: SourceValues.status(SourceValues.firstText([
        raw['status'],
        raw['seriesStatus'],
        raw['publication_status'],
        raw['state'],
        raw['progress'],
      ])),
      type: SourceValues.canonicalType([
        raw['type'],
        raw['seriesType'],
        raw['content_type'],
        raw['format'],
        raw['category'],
      ], fallback: fallbackType),
      totalChapters: totalChapters,
      updatedOn: _formatDate(SourceValues.firstText([
        raw['updated_on'],
        raw['updated_at'],
        raw['latest_chapter_date'],
      ])),
      rating: SourceValues.rating(raw),
      synopsis: _plainText(SourceValues.firstText([
        raw['synopsis'],
        raw['description'],
        raw['summary'],
        raw['postContent'],
      ])),
      chapters: chapters,
    );
  }

  /// Builds the chapter list for one work, dropping invalid references and
  /// duplicate chapters so the same chapter can never be counted twice.
  static List<Chapter> mapChapters(Map<String, dynamic> raw, String comicId) {
    final rawChapters = raw['chapters'];
    if (rawChapters is! List) return const [];
    final seen = <String>{};
    final chapters = <Chapter>[];
    for (final entry in rawChapters) {
      if (entry is! Map) continue;
      final chapter = Map<String, dynamic>.from(entry);
      final reference = _chapterReference(
        chapter['url'] ??
            chapter['chapter_url'] ??
            chapter['chapterUrl'] ??
            chapter['chapter_id'] ??
            chapter['chapterId'] ??
            chapter['id'],
        baseUrl: comicId,
      );
      if (reference == null) continue;
      final identity = ChapterReferenceIdentity.identity(
        reference,
        baseReference: comicId,
      );
      if (identity.isEmpty || !seen.add(identity)) continue;
      final number = SourceValues.firstText([
        chapter['number'],
        chapter['chapter_number'],
        chapter['chapterNumber'],
      ]);
      var title = SourceValues.text(chapter['title'] ?? chapter['name']);
      if (title.isEmpty && number.isNotEmpty) title = 'الفصل $number';
      chapters.add(Chapter(
        chapterId: reference,
        title: title.isEmpty ? 'فصل' : title,
        link: reference,
        releaseTime: _formatDate(SourceValues.firstText([
          chapter['release_date'],
          chapter['date'],
          chapter['published_at'],
          chapter['created_at'],
        ])),
      ));
    }
    return chapters;
  }

  static List<String> _genres(dynamic raw) {
    if (raw is! List) return const [];
    final seen = <String>{};
    final genres = <String>[];
    for (final entry in raw) {
      final value = entry is Map
          ? SourceValues.firstText([
              entry['name'],
              entry['title'],
              entry['label'],
              entry['value'],
            ])
          : SourceValues.text(entry);
      if (value.isEmpty || !seen.add(value.toLowerCase())) continue;
      genres.add(value);
    }
    return genres;
  }

  static String _nativeTitle(Map<String, dynamic> raw, String title) {
    final value = SourceValues.firstText([
      raw['native_title'],
      raw['nativeTitle'],
      raw['original_title'],
      raw['originalTitle'],
      raw['japanese_title'],
    ]);
    if (value.isEmpty || _sameText(value, title)) return '';
    return value;
  }

  static List<String> _alternativeTitles(
    Map<String, dynamic> raw, {
    required String title,
    required String nativeTitle,
  }) {
    final values = <String>[];
    for (final key in const [
      'alternate_titles',
      'alternateTitles',
      'alternative_titles',
      'alternativeTitles',
      'aliases',
      'altTitles',
    ]) {
      final value = raw[key];
      if (value is List) {
        for (final entry in value) {
          values.add(entry is Map
              ? SourceValues.firstText([
                  entry['title'],
                  entry['name'],
                  entry['label'],
                  entry['value'],
                ])
              : SourceValues.text(entry));
        }
      } else if (value is String) {
        values.addAll(value.split(RegExp(r'\s*[•|؛]\s*')));
      }
    }
    final seen = <String>{title.toLowerCase(), nativeTitle.toLowerCase()};
    return values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty && seen.add(value.toLowerCase()))
        .take(6)
        .toList(growable: false);
  }

  static bool _sameText(String left, String right) =>
      left.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim() ==
      right.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  static String _plainText(String value) {
    final text = value.trim();
    if (text.isEmpty) return '';
    if (!text.contains('<') && !text.contains('&')) {
      return text.replaceAll(RegExp(r'\s+'), ' ');
    }
    return mangaHtmlToText(text);
  }

  ComicData _comicData(List<Map<String, dynamic>> items, {
    int page = 1,
    String source = sourceName,
    String type = 'manga',
  }) => ComicData(
        comicsList: items.map(mapComicItem).where((item) => item.comicId.isNotEmpty).toList(growable: false),
        source: source,
        page: page,
        genres: const [],
        status: '',
        type: type,
        orderby: '',
      );

  /// Home/latest combines Team X and Azora by default, or loads one selected source.
  Future<ComicData> fetchComics({int page = 1, String? sourceId}) async {
    final selectedId = sourceId?.trim() ?? '';
    if (selectedId.isNotEmpty && selectedId != 'all') {
      final source = _sourceById(selectedId);
      if (source == null ||
          (source.kind != 'manga' && source.kind != 'novel')) {
        throw StateError('لم يتم العثور على مصدر محتوى صالح.');
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
        type: source.kind,
      );
    }
    final results = await Future.wait(
      MangaSourceRegistry.searchableSources.map((source) async {
        try {
          final rawItems = await source
              .latest(page: page)
              .timeout(const Duration(seconds: 25));
          return rawItems
              .map((item) => {
                    ...item,
                    'source_id': item['source_id'] ?? source.id,
                    'source': item['source'] ?? source.name,
                  })
              .toList(growable: false);
        } catch (_) {
          // One unavailable provider must not prevent the combined feed.
          return <Map<String, dynamic>>[];
        }
      }),
    );
    final items = results.expand((result) => result).toList(growable: false);
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
      // A later fetch that comes back partial must not erase metadata we have
      // already shown; keep the known values for empty fields.
      final previous = _detailCache[key];
      final resolved = previous == null
          ? detail
          : ComicDetailData(
              comicDetail: detail.comicDetail.mergedWith(previous.comicDetail),
              source: detail.source.isNotEmpty ? detail.source : previous.source,
            );
      _detailCache[key] = resolved;
      _detailCacheTimes[key] = DateTime.now();
      if (_detailCache.length > 100) {
        for (final oldKey in _detailCache.keys.take(25).toList()) {
          _detailCache.remove(oldKey);
          _detailCacheTimes.remove(oldKey);
        }
      }
      return resolved;
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
    final detail = mapComicDetail(
      raw,
      comicId: comicId,
      fallbackType: source.kind,
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
    // A source that stops responding must not leave the reader waiting on the
    // same shared future forever, so the timeout lives inside the request.
    final request = load().timeout(_chapterRequestTimeout);
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

  static String? _firstChapterReference(
    Iterable<dynamic> values, {
    String? baseUrl,
  }) {
    for (final value in values) {
      final reference = _chapterReference(value, baseUrl: baseUrl);
      if (reference != null) return reference;
    }
    return null;
  }

  static String? _chapterReference(dynamic value, {String? baseUrl}) {
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

  static String _formatDate(String value) {
    final date = DateTime.tryParse(value.trim());
    if (date == null) return value;
    final local = date.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)}';
  }
}
