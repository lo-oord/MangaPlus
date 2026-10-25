import 'dart:convert';

import 'package:http/http.dart' as http;

import 'source_base.dart';
import 'source_values.dart';

/// Fast adapter for ProComic's public API and chapter pages.
class ProComicSource extends ContentSource {
  ProComicSource({http.Client? client}) : _client = client ?? http.Client();

  static const _site = 'https://procomic.pro';
  static const _api = 'https://procomic.pro/api/public';
  static const _headers = {
    'Accept': 'application/json',
    'Accept-Language': 'ar,en;q=0.8',
    'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/131 Mobile Safari/537.36',
  };
  static const _timeout = Duration(seconds: 12);
  final http.Client _client;

  @override String get id => 'procomic';
  @override String get name => 'ProComic';
  @override String get kind => 'manga';
  @override List<String> get hosts => const ['procomic.pro', 'cdn2.procomic.pro', 'app.procomic.pro'];

  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    final value = query.trim();
    if (value.isEmpty) return const [];
    final data = await _get('/content', {'search': value, 'status': 'approved', 'limit': '30', 'page': '1'});
    return _items(_list(data));
  }

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) async {
    final data = await _get('/content', {'status': 'approved', 'limit': '30', 'sort': 'new', 'page': '${page < 1 ? 1 : page}'});
    return _items(_list(data));
  }

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final id = _contentId(url);
    if (id <= 0) throw Exception('ProComic: رابط السلسلة غير صالح.');
    final raw = await _get('/content/$id');
    final chapters = await _chaptersFromPage(url, raw);
    final entry = _item(raw);
    entry.addAll({
      'native_title': _text(_metadata(raw)['originalTitle']),
      'synopsis': entry['description'] ?? '',
      'author': _text(_metadata(raw)['author']),
      'artist': _text(_metadata(raw)['artist']),
      'status': _text(raw['progress']),
      'release_year': _text(_metadata(raw)['year']),
      'total_chapters': chapters.length,
      'latest_chapter_number': chapters.isEmpty ? '' : chapters.first['number'],
      'chapters': chapters,
    });
    return entry;
  }

  @override Future<Map<String, dynamic>?> streams(String url) async => null;

  @override
  Future<Map<String, dynamic>?> chapterImages(String url) async {
    final response = await _client.get(Uri.parse(url), headers: {..._headers, 'Accept': 'text/html'}).timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('ProComic: فشل تحميل الفصل (${response.statusCode}).');
    final html = utf8.decode(response.bodyBytes, allowMalformed: true);
    final images = <String>[];
    final pattern = RegExp(r'https://(?:cdn2|app)\.procomic\.pro/[^"\\]+?\.(?:avif|webp|jpg|jpeg|png)', caseSensitive: false);
    for (final match in pattern.allMatches(html)) {
      final image = match.group(0)!;
      if (!images.contains(image) && (image.contains('/chapters/') || image.contains('/${_contentId(url)}/'))) images.add(image);
    }
    if (images.isEmpty) return null;
    return {'title': 'الفصل ${_chapterNumber(url)}', 'chapter_number': _chapterNumber(url), 'pages': images, 'images': images.map((e) => {'url': e}).toList(), 'url': url};
  }

  Future<List<Map<String, dynamic>>> _chaptersFromPage(String url, Map<String, dynamic> raw) async {
    final slug = _text(raw['slug']);
    final id = _int(raw['id']);
    if (slug.isEmpty || id <= 0) return const [];
    final response = await _client.get(Uri.parse('$_site/ar/$slug-$id'), headers: {..._headers, 'Accept': 'text/html'}).timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) return const [];
    final html = utf8.decode(response.bodyBytes, allowMalformed: true);
    final pattern = RegExp(r'https://procomic\.pro/(?:ar|en)/chapter/[^"< ]+-([0-9]+)-([0-9]+)', caseSensitive: false);
    final seen = <String>{}; final result = <Map<String, dynamic>>[];
    for (final match in pattern.allMatches(html)) {
      final number = match.group(1)!; final chapterId = match.group(2)!;
      if (!seen.add('$number|$chapterId')) continue;
      final chapterUrl = match.group(0)!;
      result.add({'title': 'الفصل $number', 'number': double.tryParse(number) ?? number, 'chapter_number': number, 'chapter_id': int.tryParse(chapterId) ?? 0, 'url': chapterUrl});
    }
    result.sort((a, b) => _chapterValue(b['number']).compareTo(_chapterValue(a['number'])));
    return result;
  }

  List<Map<String, dynamic>> _items(List<Map<String, dynamic>> raw) => raw.map(_item).where((e) => '${e['title']}'.trim().isNotEmpty).toList(growable: false);
  Map<String, dynamic> _item(Map<String, dynamic> raw) {
    final metadata = _metadata(raw); final title = _text(raw['title']);
    final image = _image(_text(raw['coverImage']).isNotEmpty ? _text(raw['coverImage']) : _text(raw['thumbnail']));
    final result = item(title: title, url: '$_site/ar/${_text(raw['slug'])}-${_int(raw['id'])}', image: image, type: _text(raw['type']), genres: _listStrings(metadata['genres']), description: _text(raw['description']), rating: SourceValues.rating(raw['series_rating'] ?? raw['rating']));
    result.addAll({'native_title': _text(metadata['originalTitle']), 'status': _text(raw['progress']), 'total_chapters': '${raw['chapters_count'] ?? ''}', 'latest_chapter_number': '${raw['chapters_count'] ?? ''}',});
    return result;
  }

  Future<Map<String, dynamic>> _get(String path, [Map<String, String>? query]) async {
    final uri = Uri.parse('$_api$path').replace(queryParameters: query);
    final response = await _client.get(uri, headers: _headers).timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('ProComic: فشل طلب المصدر (${response.statusCode}).');
    final decoded = jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true));
    return decoded is Map<String, dynamic> ? decoded : Map<String, dynamic>.from(decoded as Map);
  }

  List<Map<String, dynamic>> _list(Map<String, dynamic> raw) => (raw['data'] is List ? raw['data'] as List : const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  Map<String, dynamic> _metadata(Map<String, dynamic> raw) => raw['metadata'] is Map ? Map<String, dynamic>.from(raw['metadata']) : {};
  List<String> _listStrings(dynamic value) => value is List ? value.map(_text).where((e) => e.isNotEmpty).toList() : const [];
  String _image(String value) => value.isEmpty ? '' : value.startsWith('http') ? value : 'https://cdn2.procomic.pro$value';
  int _contentId(String value) => int.tryParse(RegExp(r'(?:-|/)(\d+)(?:/?$)').firstMatch(value)?.group(1) ?? '') ?? 0;
  String _chapterNumber(String value) => RegExp(r'-([0-9]+)-[0-9]+/?$').firstMatch(value)?.group(1) ?? '';
  double _chapterValue(dynamic value) => double.tryParse('$value') ?? -1;
  String _text(dynamic value) => value?.toString().trim() ?? '';
  int _int(dynamic value) => int.tryParse(_text(value)) ?? 0;
}
