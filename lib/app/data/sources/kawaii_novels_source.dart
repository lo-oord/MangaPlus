import 'package:mangaplus/app/data/sources/kawaii_api_client.dart';
import 'package:mangaplus/app/data/sources/source_base.dart';

/// Novel-only adapter for the /novel section of kawaiimanga.org.
///
/// Novel slugs and manga slugs are routed by path and are never treated as
/// manga records, even though the API and website host are shared.
class KawaiiNovelsSource extends ContentSource {
  static const String _site = 'https://kawaiimanga.org';
  static const int _pageSize = 24;
  static const Duration _catalogTtl = Duration(minutes: 10);
  static const Duration _novelTtl = Duration(minutes: 8);

  static List<Map<String, dynamic>>? _catalogCache;
  static DateTime? _catalogCachedAt;
  static Future<List<Map<String, dynamic>>>? _catalogRequest;
  static final Map<String, (DateTime, Map<String, dynamic>)> _novelCache = {};
  static final Map<String, Future<Map<String, dynamic>>> _novelRequests = {};

  @override
  String get id => 'kawaii_novels';

  @override
  String get name => 'Kawaii Novels';

  @override
  String get kind => 'novel';

  @override
  List<String> get hosts => const ['kawaiimanga.org'];

  @override
  bool handles(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !super.handles(url)) return false;
    final segments = uri.pathSegments.where((part) => part.isNotEmpty).toList();
    return segments.length >= 2 && segments.first == 'novel';
  }

  @override
  Future<List<Map<String, dynamic>>> search(String query) =>
      _searchPage(query, 1);

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) =>
      _catalogPage(page);

  @override
  Future<List<Map<String, dynamic>>> catalog({int page = 1}) =>
      _catalogPage(page);

  @override
  Future<List<Map<String, dynamic>>> nextPage({String query = '', int page = 2}) =>
      query.trim().isEmpty ? _catalogPage(page) : _searchPage(query, page);

  Future<List<Map<String, dynamic>>> searchSuggestions({int limit = 8}) async {
    if (limit <= 0) return const [];
    final novels = await _loadCatalog();
    return novels.take(limit).map(_workItem).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _catalogPage(int page) async {
    final novels = await _loadCatalog();
    final start = ((page < 1 ? 1 : page) - 1) * _pageSize;
    if (start >= novels.length) return const [];
    return novels.skip(start).take(_pageSize).map(_workItem).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _searchPage(String query, int page) async {
    final normalized = _normalize(query);
    if (normalized.isEmpty) return _catalogPage(page);
    final novels = await _loadCatalog();
    final matching = novels.where((novel) {
      final fields = [
        novel['titleAr'],
        novel['title'],
        novel['slug'],
        novel['author'],
        if (novel['genres'] is List) ...(novel['genres'] as List),
      ];
      return fields.any((field) => _normalize('$field').contains(normalized));
    });
    final start = ((page < 1 ? 1 : page) - 1) * _pageSize;
    return matching.skip(start).take(_pageSize).map(_workItem).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _loadCatalog() async {
    final cached = _catalogCache;
    final cachedAt = _catalogCachedAt;
    if (cached != null && cachedAt != null &&
        DateTime.now().difference(cachedAt) < _catalogTtl) {
      return cached;
    }
    final active = _catalogRequest;
    if (active != null) return active;

    final request = _fetchCatalog();
    _catalogRequest = request;
    try {
      final novels = await request;
      _catalogCache = novels;
      _catalogCachedAt = DateTime.now();
      return novels;
    } finally {
      if (identical(_catalogRequest, request)) _catalogRequest = null;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchCatalog() async {
    final response = await KawaiiApiClient.getJson('novels');
    final records = response['novels'];
    if (records is! List) {
      throw const FormatException('Kawaii Novels: فهرس الروايات غير صالح.');
    }
    final novels = records.whereType<Map>()
        .map((record) => Map<String, dynamic>.from(record))
        .where((novel) => _string(novel['slug']).isNotEmpty &&
            (_string(novel['titleAr']).isNotEmpty || _string(novel['title']).isNotEmpty))
        .toList();
    novels.sort((left, right) => _date(right['latestChapterAt'] ?? right['updatedAt'])
        .compareTo(_date(left['latestChapterAt'] ?? left['updatedAt'])));
    return novels;
  }

  Map<String, dynamic> _workItem(Map<String, dynamic> raw) {
    final slug = _string(raw['slug']);
    final arabicTitle = _string(raw['titleAr']);
    final title = arabicTitle.isNotEmpty ? arabicTitle : _string(raw['title']);
    final description = _string(raw['descriptionAr']).isNotEmpty
        ? _string(raw['descriptionAr'])
        : _string(raw['description']);
    final genres = _strings(raw['genres']);
    final chapterCount = raw['chapterCount'] ?? raw['latestChapter'] ?? 0;
    final item = this.item(
      title: title,
      url: '$_site/novel/$slug',
      image: _string(raw['coverUrl']),
      type: 'novel',
      genres: genres,
      description: description,
    );
    item.addAll({
      'slug': slug,
      'manga_id': _string(raw['id']),
      'series_id': _string(raw['id']),
      'native_title': _string(raw['title']),
      'author': _string(raw['author']),
      'status': _string(raw['status']),
      'total_chapters': chapterCount,
      'latest_chapter_number': raw['latestChapter'] ?? chapterCount,
      'latest_chapter_date': _string(raw['latestChapterAt'] ?? raw['updatedAt']),
      'view_count': raw['viewCount'] ?? 0,
    });
    return item;
  }

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final slug = _workSlug(url);
    if (slug.isEmpty) throw Exception('Kawaii Novels: رابط الرواية غير صالح.');
    final raw = await _loadNovel(slug);
    final chapters = _chapterItems(raw, slug);
    final updatedAt = _string(raw['updatedAt']);
    final firstChapter = chapters.isEmpty ? null : chapters.first;
    final item = _workItem(raw);
    return item..addAll({
      'url': '$_site/novel/$slug',
      'title': _string(raw['titleAr']).isNotEmpty
          ? _string(raw['titleAr'])
          : _string(raw['title']),
      'native_title': _string(raw['title']),
      'type': 'novel',
      'seriesType': 'novel',
      'content_type': 'novel',
      'image_url': _string(raw['coverUrl']),
      'cover': _string(raw['coverUrl']),
      'description': _string(raw['descriptionAr']).isNotEmpty
          ? _string(raw['descriptionAr'])
          : _string(raw['description']),
      'synopsis': _string(raw['descriptionAr']).isNotEmpty
          ? _string(raw['descriptionAr'])
          : _string(raw['description']),
      'genres': _strings(raw['genres']),
      'author': _string(raw['author']),
      'status': _string(raw['status']),
      'release_year': _year(updatedAt),
      'year': _year(updatedAt),
      'total_chapters': raw['chapterCount'] ?? chapters.length,
      'latest_chapter_number': firstChapter?['number'] ?? raw['chapterCount'] ?? chapters.length,
      'updated_on': updatedAt,
      'updated_at': updatedAt,
      'latest_chapter_date': _string(firstChapter?['release_date'] ?? updatedAt),
      'chapters': chapters,
    });
  }

  @override
  Future<Map<String, dynamic>?> streams(String url) async => null;

  @override
  Future<Map<String, dynamic>?> chapterContent(String url) async {
    final parts = _chapterParts(url);
    if (parts == null) throw Exception('Kawaii Novels: رابط الفصل غير صالح.');
    final novel = await _loadNovel(parts.$1);
    final number = double.tryParse(parts.$2);
    if (number == null) throw Exception('Kawaii Novels: رقم الفصل غير صالح.');

    final response = await KawaiiApiClient.getJson('novel-chapter', {
      'novelId': _string(novel['id']),
      'number': parts.$2,
    });
    final content = _string(response['content']);
    if (content.isEmpty) throw Exception('Kawaii Novels: الفصل النصي فارغ.');

    final chapters = _chapterItems(novel, parts.$1);
    final allChapters = _chapterRecords(novel);
    final currentMatches = allChapters.where((chapter) =>
        _number(chapter['number']) == number).toList();
    if (currentMatches.isEmpty) {
      throw Exception('Kawaii Novels: لم يتم العثور على الفصل المطلوب.');
    }
    final currentRecord = currentMatches.first;
    final previous = _neighborChapter(allChapters, currentRecord, lower: true);
    final next = _neighborChapter(allChapters, currentRecord, lower: false);
    return {
      'title': _string(response['title']).isEmpty
          ? 'الفصل ${response['number'] ?? parts.$2}'
          : _string(response['title']),
      'chapter_number': response['number'] ?? parts.$2,
      'content': content,
      'previousChapter': previous == null ? null : _chapterUrl(parts.$1, previous['number']),
      'nextChapter': next == null ? null : _chapterUrl(parts.$1, next['number']),
      'chapters': chapters,
      'url': _chapterUrl(parts.$1, response['number'] ?? parts.$2),
    };
  }

  Future<Map<String, dynamic>> _loadNovel(String slug) async {
    final cached = _novelCache[slug];
    if (cached != null && DateTime.now().difference(cached.$1) < _novelTtl) {
      return cached.$2;
    }
    final active = _novelRequests[slug];
    if (active != null) return active;

    final request = KawaiiApiClient.getJson('novel', {'slug': slug});
    _novelRequests[slug] = request;
    try {
      final novel = await request;
      _novelCache[slug] = (DateTime.now(), novel);
      return novel;
    } finally {
      if (identical(_novelRequests[slug], request)) _novelRequests.remove(slug);
    }
  }

  List<Map<String, dynamic>> _chapterRecords(Map<String, dynamic> novel) {
    final raw = novel['chapters'];
    if (raw is! List) return const [];
    final chapters = raw.whereType<Map>()
        .map((chapter) => Map<String, dynamic>.from(chapter))
        .toList();
    chapters.sort((left, right) => _number(right['number']).compareTo(_number(left['number'])));
    return chapters;
  }

  List<Map<String, dynamic>> _chapterItems(
    Map<String, dynamic> novel,
    String slug,
  ) => _chapterRecords(novel).map((chapter) {
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
    return segments.length >= 2 && segments.first == 'novel' ? segments[1] : '';
  }

  (String, String)? _chapterParts(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !super.handles(url)) return null;
    final segments = uri.pathSegments.where((part) => part.isNotEmpty).toList();
    if (segments.length < 3 || segments.first != 'novel') return null;
    return (segments[1], segments[2]);
  }

  String _chapterUrl(String slug, dynamic number) =>
      '$_site/novel/$slug/${Uri.encodeComponent('$number')}';

  String _normalize(String value) => value.toLowerCase()
      .replaceAll(RegExp(r'[\u064B-\u0652\u0670\u0640]'), '')
      .replaceAll(RegExp(r'[أإآٱ]'), 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي')
      .replaceAll(RegExp(r'[-_]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  double _number(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse('$value') ?? double.negativeInfinity;

  DateTime _date(dynamic value) => DateTime.tryParse('$value') ?? DateTime.fromMillisecondsSinceEpoch(0);

  String _year(String value) => DateTime.tryParse(value)?.year.toString() ?? '';

  String _string(dynamic value) => value?.toString().trim() ?? '';

  List<String> _strings(dynamic values) => values is List
      ? values.map(_string).where((value) => value.isNotEmpty).toSet().toList(growable: false)
      : const [];
}
