import 'dart:convert';

import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import 'manga_html_utils.dart';
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
    final data = await _get('/series/search', {'search': value});
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
    final chapters = await _chaptersFromPage(raw);
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
  Future<Map<String, dynamic>?> chapterContent(String url) async {
    final response = await _client.get(
      Uri.parse(url),
      headers: {..._headers, 'Accept': 'text/html'},
    ).timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('ProComic: فشل تحميل فصل الرواية (${response.statusCode}).');
    }
    final document = html_parser.parse(
      utf8.decode(response.bodyBytes, allowMalformed: true),
    );
    final content = document.querySelector(
      '.chapter-text__content, [class*="chapter-text"]',
    );
    final text = mangaHtmlToReadableText(content?.innerHtml);
    if (text.isEmpty) {
      throw Exception('ProComic: لم يتم العثور على نص فصل الرواية.');
    }
    final chapterLinks = document.querySelectorAll('a[href*="/chapter/"]');
    String navigation(String label) {
      for (final link in chapterLinks) {
        final value = _text(link.attributes['aria-label']);
        final title = _text(link.text);
        if (value == label || title.contains(label)) {
          return Uri.parse(url).resolve(link.attributes['href'] ?? '').toString();
        }
      }
      return '';
    }
    return {
      'title': _text(document.querySelector('h1')?.text),
      'content': text,
      'chapter_number': _chapterNumber(url),
      'previous_chapter': navigation('السابق'),
      'next_chapter': navigation('التالي'),
      'url': url,
    };
  }

  @override
  Future<Map<String, dynamic>?> chapterImages(String url) async {
    final response = await _client.get(
      Uri.parse(url),
      headers: {
        ..._headers,
        'Accept': 'text/html,application/xhtml+xml',
        'Referer': '$_site/',
      },
    ).timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('ProComic: فشل تحميل الفصل (${response.statusCode}).');
    final html = utf8.decode(response.bodyBytes, allowMalformed: true).replaceAll(r'\/', '/');
    final images = <String>[];
    final chapterId = _chapterId(url);
    final pattern = RegExp(r'https://(?:cdn\d+|app)\.procomic\.pro/[^"\\\s<>]+?\.(?:avif|webp|jpg|jpeg|png)', caseSensitive: false);
    for (final match in pattern.allMatches(html)) {
      final image = match.group(0)!;
      final isChapterImage = chapterId.isNotEmpty &&
          image.contains('/$chapterId/');
      if (!images.contains(image) && isChapterImage) images.add(image);
    }
    if (images.isEmpty) return null;
    return {'title': 'الفصل ${_chapterNumber(url)}', 'chapter_number': _chapterNumber(url), 'pages': images, 'images': images.map((e) => {'url': e}).toList(), 'url': url};
  }

  Future<List<Map<String, dynamic>>> _chaptersFromPage(Map<String, dynamic> raw) async {
    final id = _int(raw['id']);
    final seriesUrl = _seriesUrl(raw);
    if (id <= 0 || seriesUrl.isEmpty) return const [];
    final response = await _client.get(Uri.parse(seriesUrl), headers: {..._headers, 'Accept': 'text/html'}).timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) return const [];
    final document = html_parser.parse(utf8.decode(response.bodyBytes, allowMalformed: true));
    final base = Uri.parse(seriesUrl);
    final seen = <String>{};
    final result = <Map<String, dynamic>>[];
    for (final anchor in document.querySelectorAll('a[href*="/chapter/"]')) {
      final href = anchor.attributes['href']?.trim() ?? '';
      if (href.isEmpty) continue;
      final chapterUri = base.resolve(href);
      if (chapterUri.host != 'procomic.pro' && !chapterUri.host.endsWith('.procomic.pro')) continue;
      final path = chapterUri.pathSegments.isEmpty ? '' : chapterUri.pathSegments.last;
      final match = RegExp(r'-([0-9]+(?:\.[0-9]+)?)-([0-9]+)$').firstMatch(path);
      if (match == null) continue;
      final number = match.group(1)!;
      final chapterId = match.group(2)!;
      if (!seen.add('$number|$chapterId')) continue;
      result.add({
        'title': 'الفصل $number',
        'number': double.tryParse(number) ?? number,
        'chapter_number': number,
        'chapter_id': int.tryParse(chapterId) ?? 0,
        'url': chapterUri.toString(),
      });
    }
    result.sort((a, b) => _chapterValue(b['number']).compareTo(_chapterValue(a['number'])));
    return result;
  }

  List<Map<String, dynamic>> _items(List<Map<String, dynamic>> raw) => raw.map(_item).where((e) => '${e['title']}'.trim().isNotEmpty).toList(growable: false);
  Map<String, dynamic> _item(Map<String, dynamic> raw) {
    final metadata = _metadata(raw); final title = _text(raw['title']);
    final appCover = raw['coverImageApp'] is Map
        ? (raw['coverImageApp'] as Map)['desktop'] ?? (raw['coverImageApp'] as Map)['mobile']
        : raw['coverImageApp'];
    final image = _image(
      _firstImageText([
        raw['coverImage'],
        raw['cover_image'],
        raw['coverUrl'],
        raw['cover_url'],
        raw['image'],
        raw['image_url'],
        metadata['coverImage'],
        metadata['cover_image'],
        metadata['coverUrl'],
        metadata['appCoverImage'],
        metadata['appCardImage'],
        metadata['socialImage'],
        raw['appCoverImage'],
        raw['appCardImage'],
        raw['socialImage'],
        raw['thumbnail'],
        appCover,
      ]),
      cdnPath: _text(raw['cdn_path']),
    );
    final result = item(title: title, url: _seriesUrl(raw), image: image, type: _text(raw['type']), genres: _listStrings(metadata['genres']), description: _text(raw['description']), rating: SourceValues.rating(raw['series_rating'] ?? raw['rating']));
    result.addAll({'native_title': _text(metadata['originalTitle']), 'alternate_titles': metadata['altTitles'] ?? metadata['alternate_titles'] ?? const [], 'status': _text(raw['progress']), 'total_chapters': '${raw['chapters_count'] ?? ''}', 'latest_chapter_number': '${raw['chapters_count'] ?? ''}',});
    return result;
  }

  Future<Map<String, dynamic>> _get(String path, [Map<String, String>? query]) async {
    final uri = Uri.parse('$_api$path').replace(queryParameters: query);
    final response = await _client.get(uri, headers: _headers).timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('ProComic: فشل طلب المصدر (${response.statusCode}).');
    final decoded = jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true));
    return decoded is Map<String, dynamic> ? decoded : Map<String, dynamic>.from(decoded as Map);
  }

  List<Map<String, dynamic>> _list(Map<String, dynamic> raw) {
    final data = raw['data'];
    final entries = data is List
        ? data
        : data is Map
            ? data['series'] ?? data['results'] ?? data['items'] ?? data['content'] ?? const []
            : const [];
    return entries is List
        ? entries.whereType<Map>().map((entry) => Map<String, dynamic>.from(entry)).toList(growable: false)
        : const [];
  }
  Map<String, dynamic> _metadata(Map<String, dynamic> raw) => raw['metadata'] is Map ? Map<String, dynamic>.from(raw['metadata']) : {};
  List<String> _listStrings(dynamic value) => value is List ? value.map(_text).where((e) => e.isNotEmpty).toList() : const [];
  String _image(String value, {String cdnPath = 'cdn2'}) {
    if (value.isEmpty) return '';
    final uri = Uri.tryParse(value);
    if (uri?.hasScheme == true) {
      return uri!.scheme == 'http' || uri.scheme == 'https' ? uri.toString() : '';
    }
    final cdn = RegExp(r'^cdn\d+$').hasMatch(cdnPath) ? cdnPath : 'cdn2';
    final path = value.startsWith('/') ? value : '/$value';
    return 'https://$cdn.procomic.pro$path';
  }
  String _seriesUrl(Map<String, dynamic> raw) {
    final type = _text(raw['type']);
    final id = _int(raw['id']);
    final slug = _text(raw['slug']);
    if (type.isEmpty || id <= 0 || slug.isEmpty) return '';
    if (type.toLowerCase() == 'novel') {
      return '$_site/ar/${Uri.encodeComponent(slug)}-$id';
    }
    return '$_site/ar/series/${Uri.encodeComponent(type)}/$id/${Uri.encodeComponent(slug)}';
  }

  int _contentId(String value) {
    final uri = Uri.tryParse(value);
    if (uri != null) {
      final segments = uri.pathSegments;
      final seriesIndex = segments.indexOf('series');
      if (seriesIndex >= 0 && seriesIndex + 2 < segments.length) {
        final id = int.tryParse(segments[seriesIndex + 2]);
        if (id != null) return id;
      }
    }
    return int.tryParse(RegExp(r'(?:-|/)(\d+)(?:/?$)').firstMatch(value)?.group(1) ?? '') ?? 0;
  }
  String _chapterNumber(String value) => RegExp(r'-([0-9]+)-[0-9]+/?$').firstMatch(value)?.group(1) ?? '';
  String _chapterId(String value) => RegExp(r'-[0-9]+-([0-9]+)/?$').firstMatch(value)?.group(1) ?? '';
  double _chapterValue(dynamic value) => double.tryParse('$value') ?? -1;
  String _firstText(Iterable<dynamic> values) {
    for (final value in values) {
      final text = _text(value);
      if (text.isNotEmpty && text != 'null') return text;
    }
    return '';
  }
  String _firstImageText(Iterable<dynamic> values) {
    for (final value in values) {
      if (value is Map) {
        final nested = _firstImageText(value.values);
        if (nested.isNotEmpty) return nested;
        continue;
      }
      if (value is List) {
        final nested = _firstImageText(value);
        if (nested.isNotEmpty) return nested;
        continue;
      }
      final text = _text(value);
      if (text.isNotEmpty && text != 'null' &&
          (text.startsWith('http') || text.startsWith('/'))) {
        return text;
      }
    }
    return '';
  }
  String _text(dynamic value) => value?.toString().trim() ?? '';
  int _int(dynamic value) => int.tryParse(_text(value)) ?? 0;
}
