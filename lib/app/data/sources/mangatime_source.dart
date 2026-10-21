import 'dart:convert';
import 'package:http/http.dart' as http;
import 'episode_date_formatter.dart';
import 'source_base.dart';
import 'source_values.dart';

/// Public MangaTime tRPC source. Each result keeps a MangaTime-specific URI.
class MangaTimeSource extends ContentSource {
  static const _site = 'https://mangatime.org';
  static const _trpc = '$_site/api/trpc';
  static const _appVersion = '1.5.45';
  static final http.Client _client = http.Client();

  @override String get id => 'mangatime';
  @override String get name => 'Manga Time';
  @override String get kind => 'manga';
  @override List<String> get hosts => const ['mangatime.org'];
  @override bool handles(String url) => url.startsWith('mangatime://') || super.handles(url);

  @override
  Future<List<Map<String, dynamic>>> search(String query) => _search(query, 1);

  @override
  Future<List<Map<String, dynamic>>> nextPage({String query = '', int page = 2}) =>
      query.trim().isEmpty ? latest(page: page) : _search(query, page);

  Future<List<Map<String, dynamic>>> _search(String query, int page) async {
    if (query.trim().isEmpty) return const [];
    final data = await _call('search.searchSeries', {'query': query.trim(), 'page': page, 'limit': 30});
    return _list(data).map(_series).where((item) => item['title'].toString().trim().isNotEmpty).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) async {
    final data = await _call('homepage.getLatestReleases', {'page': page < 1 ? 1 : page, 'limit': 30});
    return _list(data).map(_series).where((item) => item['title'].toString().trim().isNotEmpty).toList();
  }

  @override
  Future<Map<String, dynamic>?> streams(String url) async => null;

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final slug = _slugFrom(url);
    if (slug.isEmpty) throw Exception('MangaTime: invalid series slug');
    final raw = _asMap(await _call('content.getSeriesBySlug', {'slug': slug}));
    if (raw.isEmpty) throw Exception('MangaTime: series not found');
    final item = _series(raw);
    final id = _string(raw['id'] ?? raw['_id'] ?? raw['seriesId']);
    item['url'] = _seriesUrl(id, slug);
    item['chapters'] = await _chapters(id);
    item['total_chapters'] = (item['chapters'] as List).length;
    return item;
  }

  @override
  Future<Map<String, dynamic>?> chapterImages(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'mangatime') return null;
    final id = uri.queryParameters['id'] ?? '';
    if (id.isEmpty) throw Exception('MangaTime: missing chapter id');
    final raw = _asMap(await _call('content.getChapterPages', {'chapterId': id}));
    final pages = _plainStrings(raw['pages']).map(_imageUrl).where((value) => value.isNotEmpty).toList();
    if (pages.isEmpty) throw Exception('MangaTime: chapter pages not found');
    final number = uri.queryParameters['number'] ?? '';
    return {
      'title': _string(raw['title'], 'الفصل $number'.trim()),
      'chapter_number': raw['number'] ?? number,
      'format': raw['format'] ?? 'images',
      'page_dimensions': raw['pageDimensions'] is List ? raw['pageDimensions'] : const [],
      'pages': pages,
      'images': pages.map((image) => {'url': image}).toList(),
      'url': url,
      'navigation': {
        if (raw['prevChapter'] is Map && _string(raw['prevChapter']['id']).isNotEmpty)
          'prev_chapter': _chapterUrl(_string(raw['prevChapter']['id']), raw['prevChapter']['number']),
        if (raw['nextChapter'] is Map && _string(raw['nextChapter']['id']).isNotEmpty)
          'next_chapter': _chapterUrl(_string(raw['nextChapter']['id']), raw['nextChapter']['number']),
      },
    };
  }

  Future<List<Map<String, dynamic>>> _chapters(String seriesId) async {
    if (seriesId.isEmpty) return const [];
    // The site's web client uses limit=-1 to request all chapters in one response.
    final raw = _list(await _call('content.getChapters', {'seriesId': seriesId, 'limit': -1}));
    final chapters = raw.map((entry) {
      final id = _string(entry['id'] ?? entry['_id'] ?? entry['chapterId'] ?? entry['chapter_id']);
      final number = entry['number'] ?? entry['chapterNumber'] ?? _number(entry['title']);
      final releaseDate = _releaseDate(entry);
      return <String, dynamic>{
        'id': id, 'chapter_id': id, 'chapter_number': number ?? 0, 'number': number ?? 0,
        'title': _string(entry['title'], 'الفصل ${number ?? ''}'.trim()),
        'volume': entry['volume'] ?? '',
        'release_date': releaseDate,
        'date': releaseDate,
        'format': entry['format'] ?? 'images', 'page_count': entry['pageCount'] ?? 0,
        'url': _chapterUrl(id, number),
      };
    }).where((entry) => entry['id'].toString().isNotEmpty).toList();
    chapters.sort((a, b) => (_number(b['number']) ?? 0).compareTo(_number(a['number']) ?? 0));
    return chapters;
  }

  Map<String, dynamic> _series(Map<String, dynamic> raw) {
    final stats = _asMap(raw['stats']);
    final genresRaw = raw['genres'];
    final genres = genresRaw is List ? genresRaw.map((entry) => entry is Map ? _string(entry['name']) : _string(entry)).where((entry) => entry.isNotEmpty).toList() : <String>[];
    final alternatives = raw['alternativeTitles'] ?? raw['alternateTitles'];
    final recent = raw['latestChapter'] is Map
        ? Map<String, dynamic>.from(raw['latestChapter'])
        : raw['recentChapters'] is List && (raw['recentChapters'] as List).isNotEmpty && (raw['recentChapters'] as List).first is Map
            ? Map<String, dynamic>.from((raw['recentChapters'] as List).first as Map)
            : <String, dynamic>{};
    final item = this.item(
      title: _string(raw['title'], 'بدون عنوان'),
      url: _seriesUrl(_string(raw['id']), _string(raw['slug'])),
      image: _imageUrl(raw['coverUrl'] ?? raw['cover']),
      type: _string(raw['type'], 'manga'), genres: genres,
      description: _cleanText(raw['description']), rating: SourceValues.rating(raw),
    );
    item.addAll({
      'manga_id': _string(raw['id']), 'series_id': _string(raw['id']), 'slug': _string(raw['slug']),
      'alternate_titles': _stringsWithKey(alternatives, mapKey: 'title'), 'author': _string(raw['author']),
      'artist': _string(raw['artist']), 'status': _string(raw['status']), 'year': raw['year'] ?? '',
      'banner_image_url': _imageUrl(raw['bannerUrl']), 'updated_at': _string(raw['updatedAt']),
      'published_at': _string(raw['publishedAt']),
      'total_chapters': raw['chapterCount'] ?? stats['chapterCount'] ?? '',
      'latest_chapter_number': recent['number'] ?? recent['chapterNumber'] ?? 0,
      if (_releaseDate(recent).isNotEmpty) 'latest_chapter_date': _releaseDate(recent),
      if ((recent['title'] ?? '').toString().isNotEmpty) 'latest_chapter_name': recent['title'],
    });
    return item;
  }

  Future<dynamic> _call(String procedure, Map<String, dynamic> input) async {
    final encoded = Uri.encodeQueryComponent(jsonEncode({'json': input}));
    final response = await _client.get(Uri.parse('$_trpc/$procedure?input=$encoded'), headers: const {
      'Accept': 'application/json', 'X-MT-Platform': 'app', 'X-MT-App-Version': _appVersion, 'X-MT-UIMode': 'dark',
    }).timeout(const Duration(seconds: 25));
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('MangaTime request failed (${response.statusCode})');
    final decoded = jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true));
    if (decoded is Map && decoded['error'] != null) throw Exception('MangaTime server error');
    return _unwrap(decoded);
  }

  static dynamic _unwrap(dynamic value) {
    var current = value;
    for (var i = 0; i < 8; i++) {
      if (current is Map && current.containsKey('result')) current = current['result'];
      else if (current is Map && current.containsKey('data')) current = current['data'];
      else if (current is Map && current.containsKey('json')) current = current['json'];
      else break;
    }
    return current;
  }
  static List<Map<String, dynamic>> _list(dynamic value) {
    final current = _unwrap(value);
    if (current is List) return current.whereType<Map>().map((entry) => Map<String, dynamic>.from(entry)).toList();
    if (current is Map) {
      for (final key in const ['results', 'items', 'chapters', 'docs', 'records', 'rows']) {
        final found = _list(current[key]);
        if (found.isNotEmpty) return found;
      }
    }
    return const [];
  }
  static Map<String, dynamic> _asMap(dynamic value) => value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
  static String _string(dynamic value, [String fallback = '']) => value == null || value.toString().trim().isEmpty ? fallback : value.toString().trim();
  static String _cleanText(dynamic value) => _string(value).replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n').replaceAll(RegExp(r'<[^>]+>'), ' ').replaceAll('&amp;', '&').replaceAll('&quot;', '"').replaceAll('&#39;', "'").replaceAll('&nbsp;', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  static List<String> _stringsWithKey(dynamic value, {String? mapKey}) {
    if (value is String) return value.trim().isEmpty ? const [] : [value.trim()];
    if (value is List) return value.map((entry) => entry is Map && mapKey != null ? _string(entry[mapKey]) : _string(entry)).where((entry) => entry.isNotEmpty).toList();
    return const [];
  }
  static String _imageUrl(dynamic value) {
    final raw = _string(value);
    if (raw.isEmpty) return '';
    return raw.startsWith('http://') || raw.startsWith('https://') ? raw : '$_site/${raw.replaceFirst(RegExp(r'^/+'), '')}';
  }
  static String _releaseDate(Map<String, dynamic> entry) {
    for (final key in const [
      'publishedAt', 'published_at', 'releaseDate', 'release_date',
      'createdAt', 'created_at', 'date', 'timestamp',
    ]) {
      final value = entry[key];
      if (value == null) continue;
      final date = EpisodeDateFormatter.normalize(value);
      if (date.isNotEmpty) return date;
    }
    return '';
  }
  static String _seriesUrl(String id, [String slug = '']) => 'mangatime://series/${Uri.encodeComponent(slug.isNotEmpty ? slug : id)}?id=${Uri.encodeQueryComponent(id)}';
  static String _chapterUrl(String id, dynamic number) => 'mangatime://chapter?id=${Uri.encodeQueryComponent(id)}&number=${Uri.encodeQueryComponent(_string(number))}';
  static String _slugFrom(String url) {
    final uri = Uri.tryParse(url);
    if (uri?.scheme == 'mangatime') return uri!.pathSegments.isEmpty ? '' : Uri.decodeComponent(uri.pathSegments.last);
    if (uri != null && uri.host.contains('mangatime.org')) {
      final parts = uri.pathSegments.where((part) => part.isNotEmpty).toList();
      return parts.isEmpty ? '' : parts.last;
    }
    return '';
  }
  static num? _number(dynamic value) {
    if (value is num) return value;
    final match = RegExp(r'\d+(?:\.\d+)?').firstMatch(_string(value));
    return match == null ? null : num.tryParse(match.group(0)!);
  }
  static List<String> _plainStrings(dynamic value) {
    if (value is String) return [value];
    if (value is List) return value.map(_string).where((item) => item.isNotEmpty).toList();
    return const [];
  }
}
