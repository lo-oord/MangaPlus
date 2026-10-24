import 'package:mangaplus/app/data/sources/kawaii_api_client.dart';
import 'package:mangaplus/app/data/sources/source_base.dart';
import 'package:mangaplus/app/data/sources/source_values.dart';

/// Manga-only adapter for kawaiimanga.org.
///
/// Kawaii novels use a separate adapter and source ID even though both live on
/// the same website and share its public API.
class KawaiiMangaSource extends ContentSource {
  static const String _site = 'https://kawaiimanga.org';
  static const int _pageSize = 24;
  static const Duration _seriesTtl = Duration(minutes: 8);
  static final Map<String, (DateTime, Map<String, dynamic>)> _seriesCache = {};
  static final Map<String, Future<Map<String, dynamic>>> _seriesRequests = {};

  @override
  String get id => 'kawaii_manga';

  @override
  String get name => 'Kawaii Manga';

  @override
  String get kind => 'manga';

  @override
  List<String> get hosts => const ['kawaiimanga.org'];

  @override
  bool handles(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !super.handles(url)) return false;
    final segments = uri.pathSegments.where((part) => part.isNotEmpty).toList();
    return segments.length >= 2 &&
        (segments.first == 'manga' || segments.first == 'reader');
  }

  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final response = await KawaiiApiClient.getJson('search', {'q': trimmed});
    final records = response['results'];
    final directResults = records is List
        ? records.whereType<Map>().map((record) => _workItem(
      Map<String, dynamic>.from(record),
    )).toList(growable: false)
        : const <Map<String, dynamic>>[];
    if (directResults.isNotEmpty) return directResults;

    final browseResponse = await KawaiiApiClient.getJson('browse', {
      'page': '1',
      'limit': '100',
      'sort': 'latest',
    });
    final browseRecords = browseResponse['results'];
    if (browseRecords is! List) return const [];
    final normalized = _normalize(trimmed);
    return browseRecords.whereType<Map>().where((record) {
      final values = [
        record['title'],
        record['titleEn'],
        record['titleAr'],
        record['slug'],
        record['author'],
        if (record['genres'] is List) ...(record['genres'] as List),
      ];
      return values.any((value) => _normalize('$value').contains(normalized));
    }).map((record) => _workItem(
      Map<String, dynamic>.from(record),
    )).toList(growable: false);
  }

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) =>
      _browse(page: page, sort: 'latest');

  @override
  Future<List<Map<String, dynamic>>> catalog({int page = 1}) =>
      _browse(page: page, sort: 'views');

  @override
  Future<List<Map<String, dynamic>>> nextPage({String query = '', int page = 2}) =>
      query.trim().isEmpty ? catalog(page: page) : search(query);

  Future<List<Map<String, dynamic>>> searchSuggestions({int limit = 8}) async {
    if (limit <= 0) return const [];
    final response = await KawaiiApiClient.getJson('browse', {
      'page': '1',
      'limit': '${limit.clamp(1, 40)}',
      'sort': 'latest',
    });
    final records = response['results'];
    if (records is! List) return const [];
    return records.whereType<Map>().map((record) => _workItem(
      Map<String, dynamic>.from(record),
    )).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _browse({
    required int page,
    required String sort,
  }) async {
    final response = await KawaiiApiClient.getJson('browse', {
      'page': '${page < 1 ? 1 : page}',
      'limit': '$_pageSize',
      'sort': sort,
    });
    final records = response['results'];
    if (records is! List) return const [];
    return records.whereType<Map>().map((record) => _workItem(
      Map<String, dynamic>.from(record),
    )).toList(growable: false);
  }

  Map<String, dynamic> _workItem(Map<String, dynamic> raw) {
    final slug = '${raw['slug'] ?? ''}'.trim();
    final title = _string(raw['title']).isNotEmpty
        ? _string(raw['title'])
        : _string(raw['titleAr']);
    final genres = _strings(raw['genres']);
    final item = this.item(
      title: title,
      url: '$_site/manga/$slug',
      image: _string(raw['coverUrl']),
      type: _string(raw['type']).isEmpty ? 'manga' : _string(raw['type']),
      genres: genres,
      description: _string(raw['description']),
      rating: SourceValues.rating(raw['rating']),
    );
    final chapterCount = raw['mainChapterCount'] ?? raw['chapterCount'] ?? 0;
    item.addAll({
      'slug': slug,
      'native_title': _string(raw['titleAr']),
      'author': _string(raw['author']),
      'artist': _string(raw['artist']),
      'status': _string(raw['status']),
      'total_chapters': chapterCount,
      'latest_chapter_number': chapterCount,
      'latest_chapter_date': _string(raw['updatedAt']),
      'view_count': raw['viewCount'] ?? 0,
    });
    return item;
  }

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final slug = _workSlug(url);
    if (slug.isEmpty) throw Exception('Kawaii Manga: رابط العمل غير صالح.');
    final raw = await _loadSeries(slug);
    final chapters = _chapterItems(raw, slug);
    final item = _workItem(raw);
    final updatedAt = _string(raw['updatedAt']);
    return item..addAll({
      'url': '$_site/manga/$slug',
      'title': _string(raw['title']).isEmpty
          ? _string(raw['titleAr'])
          : _string(raw['title']),
      'native_title': _string(raw['titleAr']).isEmpty
          ? _string(raw['titleEn'])
          : _string(raw['titleAr']),
      'type': _string(raw['type']).isEmpty ? 'manga' : _string(raw['type']),
      'seriesType': _string(raw['type']),
      'content_type': 'manga',
      'image_url': _string(raw['coverUrl']),
      'cover': _string(raw['coverUrl']),
      'description': _string(raw['description']),
      'synopsis': _string(raw['description']),
      'genres': _strings(raw['genres']),
      'author': _string(raw['author']),
      'artist': _string(raw['artist']),
      'status': _string(raw['status']),
      'release_year': _year(updatedAt),
      'year': _year(updatedAt),
      'total_chapters': raw['mainChapterCount'] ?? raw['chapterCount'] ?? chapters.length,
      'latest_chapter_number': raw['mainChapterCount'] ?? raw['chapterCount'] ?? chapters.length,
      'updated_on': updatedAt,
      'updated_at': updatedAt,
      'latest_chapter_date': updatedAt,
      'rating': SourceValues.rating(raw['rating']),
      'chapters': chapters,
    });
  }

  @override
  Future<Map<String, dynamic>?> streams(String url) async => null;

  @override
  Future<Map<String, dynamic>?> chapterImages(String url) async {
    final parts = _chapterParts(url);
    if (parts == null) throw Exception('Kawaii Manga: رابط الفصل غير صالح.');
    final series = await _loadSeries(parts.$1);
    final allChapters = _chapterRecords(series);
    final currentMatches = allChapters.where((chapter) =>
        _sameNumber(chapter['number'], parts.$2)).toList();
    if (currentMatches.isEmpty) {
      throw Exception('Kawaii Manga: لم يتم العثور على الفصل المطلوب.');
    }
    final current = currentMatches.first;

    final chapterId = _string(current['id']);
    final response = await KawaiiApiClient.getJson('pages', {'chapterId': chapterId});
    final pages = response['pages'];
    if (pages is! List || pages.isEmpty) {
      throw Exception('Kawaii Manga: لا توجد صور متاحة لهذا الفصل.');
    }
    final previous = _neighborChapter(allChapters, current, lower: true);
    final next = _neighborChapter(allChapters, current, lower: false);
    return {
      'title': _string(current['title']),
      'pages': pages.map((page) => page.toString()).where((page) => page.isNotEmpty).toList(growable: false),
      'previousChapter': previous == null ? null : _chapterUrl(parts.$1, previous['number']),
      'nextChapter': next == null ? null : _chapterUrl(parts.$1, next['number']),
      'chapters': _chapterItems(series, parts.$1),
    };
  }

  Future<Map<String, dynamic>> _loadSeries(String slug) async {
    final cached = _seriesCache[slug];
    if (cached != null && DateTime.now().difference(cached.$1) < _seriesTtl) {
      return cached.$2;
    }
    final active = _seriesRequests[slug];
    if (active != null) return active;

    final request = KawaiiApiClient.getJson('series', {'slug': slug});
    _seriesRequests[slug] = request;
    try {
      final series = await request;
      _seriesCache[slug] = (DateTime.now(), series);
      return series;
    } finally {
      if (identical(_seriesRequests[slug], request)) _seriesRequests.remove(slug);
    }
  }

  List<Map<String, dynamic>> _chapterRecords(Map<String, dynamic> series) {
    final raw = series['chapters'];
    if (raw is! List) return const [];
    final chapters = raw.whereType<Map>()
        .map((chapter) => Map<String, dynamic>.from(chapter))
        .toList();
    chapters.sort((left, right) => _number(right['number']).compareTo(_number(left['number'])));
    return chapters;
  }

  List<Map<String, dynamic>> _chapterItems(
    Map<String, dynamic> series,
    String slug,
  ) => _chapterRecords(series).map((chapter) {
        final number = chapter['number'];
        final date = _string(chapter['createdAt']);
        return <String, dynamic>{
          'id': _string(chapter['id']),
          'number': number,
          'chapter_number': number,
          'title': _string(chapter['title']).isEmpty ? 'الفصل $number' : _string(chapter['title']),
          'release_date': date,
          'date': date,
          'url': _chapterUrl(slug, number),
        };
      }).toList(growable: false);

  Map<String, dynamic>? _neighborChapter(
    List<Map<String, dynamic>> chapters,
    Map<String, dynamic> current, {
    required bool lower,
  }) {
    final currentNumber = _number(current['number']);
    final candidates = chapters.where((chapter) {
      final number = _number(chapter['number']);
      return lower ? number < currentNumber : number > currentNumber;
    }).toList();
    if (candidates.isEmpty) return null;
    candidates.sort((left, right) => lower
        ? _number(right['number']).compareTo(_number(left['number']))
        : _number(left['number']).compareTo(_number(right['number'])));
    return candidates.first;
  }

  String _workSlug(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !super.handles(url)) return '';
    final segments = uri.pathSegments.where((part) => part.isNotEmpty).toList();
    if (segments.length < 2 || !{'manga', 'reader'}.contains(segments.first)) return '';
    return segments[1];
  }

  (String, String)? _chapterParts(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !super.handles(url)) return null;
    final segments = uri.pathSegments.where((part) => part.isNotEmpty).toList();
    if (segments.length < 3 || segments.first != 'reader') return null;
    return (segments[1], segments[2]);
  }

  String _chapterUrl(String slug, dynamic number) =>
      '$_site/reader/$slug/${Uri.encodeComponent('$number')}';

  bool _sameNumber(dynamic left, dynamic right) => _number(left) == _number(right);

  double _number(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse('$value') ?? double.negativeInfinity;

  String _year(String value) => DateTime.tryParse(value)?.year.toString() ?? '';

  String _string(dynamic value) => value?.toString().trim() ?? '';

  List<String> _strings(dynamic values) => values is List
      ? values.map(_string).where((value) => value.isNotEmpty).toSet().toList(growable: false)
      : const [];

  String _normalize(String value) => value.toLowerCase()
      .replaceAll(RegExp(r'[\u064B-\u0652\u0670\u0640]'), '')
      .replaceAll(RegExp(r'[أإآٱ]'), 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي')
      .replaceAll(RegExp(r'[-_]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
