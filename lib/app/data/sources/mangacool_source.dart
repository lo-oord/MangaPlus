import 'dart:convert';

import 'package:http/http.dart' as http;

import 'source_base.dart';
import 'source_values.dart';

/// API adapter for the Arabic MangaCool catalogue and reader.
class MangaCoolSource extends ContentSource {
  MangaCoolSource({http.Client? client}) : _client = client ?? http.Client();

  static const String _site = 'https://mangacool.net';
  static const String _api = 'https://api.mangacool.net/api';
  static const String _imageHost = 'https://img.mangacool.net';
  static const Map<String, String> _headers = {
    'Accept': 'application/json',
    'Accept-Language': 'ar,en;q=0.8',
    'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/131 Mobile Safari/537.36',
    'x-app-source': 'mangacool',
  };
  static const Duration _timeout = Duration(seconds: 25);

  final http.Client _client;

  @override
  String get id => 'mangacool';

  @override
  String get name => 'MangaCool';

  @override
  String get kind => 'manga';

  @override
  List<String> get hosts => const ['mangacool.net', 'img.mangacool.net'];

  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    final value = query.trim();
    if (value.isEmpty) return const [];
    final raw = await _get('/manga/search', {'query': value});
    return _items(_list(raw));
  }

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) async {
    final raw = await _get('/manga', {'page': '${page < 1 ? 1 : page}'});
    return _items(_list(raw));
  }

  @override
  Future<List<Map<String, dynamic>>> catalog({int page = 1}) =>
      latest(page: page);

  @override
  Future<List<Map<String, dynamic>>> nextPage({
    String query = '',
    int page = 2,
  }) => query.trim().isEmpty ? latest(page: page) : search(query);

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final manga = await _findManga(url);
    if (manga.isEmpty) throw Exception('MangaCool: لم يتم العثور على المانجا.');
    final id = _int(manga['id']);
    if (id <= 0) throw Exception('MangaCool: معرف المانجا غير صالح.');

    final chapters = <Map<String, dynamic>>[];
    final rawChapters = manga['MangaChapters'] ?? manga['chapters'];
    if (rawChapters is List) {
      for (final raw in rawChapters.whereType<Map>()) {
        final chapter = Map<String, dynamic>.from(raw);
        final number = _number(chapter['chapter_number'] ?? chapter['number']);
        final chapterId = _int(chapter['id'] ?? chapter['chapter_id']);
        if (chapterId <= 0 || number.isEmpty) continue;
        chapters.add({
          'title': '${chapter['title'] ?? 'الفصل $number'}',
          'number': number,
          'chapter_number': number,
          'url': _chapterUrl('${manga['slug'] ?? ''}', number),
          'release_date': '${chapter['release_date'] ?? chapter['created_at'] ?? ''}',
          'date': '${chapter['release_date'] ?? chapter['created_at'] ?? ''}',
          'chapter_id': chapterId,
        });
      }
    }
    chapters.sort((a, b) => _compareChapterNumbers(
          '${b['number']}',
          '${a['number']}',
        ));

    final title = _text(manga['title_ar']).isNotEmpty
        ? _text(manga['title_ar'])
        : _text(manga['title']);
    final originalTitle = _text(manga['title']);
    final genres = (manga['Tags'] ?? manga['tags']) is List
        ? ((manga['Tags'] ?? manga['tags']) as List)
            .whereType<Map>()
            .map((tag) => _text(tag['name']))
            .where((tag) => tag.isNotEmpty)
            .toList(growable: false)
        : const <String>[];
    final image = _imageUrl(_text(manga['cover_image']));
    final seriesUrl = _mangaUrl(_text(manga['slug']), id);
    final totalChapters = _int(manga['chapters_count']);
    return item(
      title: title,
      url: seriesUrl,
      image: image,
      type: _text(manga['type']).isEmpty ? 'manga' : _text(manga['type']),
      genres: genres,
      description: _description(manga),
      rating: SourceValues.rating(manga['rating']),
    )
      ..addAll({
        'native_title': originalTitle,
        'synopsis': _description(manga),
        'author': _text(manga['author']),
        'status': _text(manga['status']),
        'release_year': '${manga['publication_year'] ?? ''}',
        'total_chapters': totalChapters > 0 ? '$totalChapters' : '${chapters.length}',
        'latest_chapter_number': chapters.isEmpty ? '' : chapters.first['number'],
        'chapters': chapters,
      });
  }

  @override
  Future<Map<String, dynamic>?> streams(String url) async => null;

  @override
  Future<Map<String, dynamic>?> chapterImages(String url) async {
    final parsed = _chapterParts(url);
    if (parsed == null) throw Exception('MangaCool: رابط الفصل غير صالح.');
    final manga = await _findManga(parsed['slug']!);
    if (manga.isEmpty) throw Exception('MangaCool: لم يتم العثور على المانجا.');
    final rawChapters = manga['MangaChapters'] ?? manga['chapters'];
    if (rawChapters is! List) return null;

    Map<String, dynamic>? match;
    for (final raw in rawChapters.whereType<Map>()) {
      if (_number(raw['chapter_number'] ?? raw['number']) == parsed['number']) {
        match = Map<String, dynamic>.from(raw);
        break;
      }
    }
    if (match == null) return null;
    final chapterId = _int(match['id'] ?? match['chapter_id']);
    if (chapterId <= 0) return null;
    final chapterResponse = await _get('/chapters/$chapterId');
    final chapter = _map(chapterResponse);
    final path = _text(chapter['path']);
    final pages = _pages(chapter);
    if (path.isEmpty || pages.isEmpty) return null;
    final version = _text(chapter['version']);
    final imagePages = pages
        .map((page) => _imageHost + '/' + path.replaceFirst(RegExp(r'^/+'), '') +
            '/' + page + (version.isEmpty ? '' : '?v=$version'))
        .toList(growable: false);
    return {
      'title': _text(match['title']).isEmpty ? 'الفصل ${parsed['number']}' : _text(match['title']),
      'pages': imagePages,
      'images': imagePages.map((page) => {'url': page}).toList(growable: false),
      'chapter_number': parsed['number'],
      'url': url,
    };
  }

  Future<Map<String, dynamic>> _findManga(String value) async {
    final parsed = Uri.tryParse(value);
    final slug = parsed?.pathSegments.contains('manga') == true
        ? parsed!.pathSegments.last
        : value.trim().replaceAll(RegExp(r'^/+|/+$'), '');
    final idMatch = RegExp(r'/(?:manga|series)/(\d+)/?$').firstMatch(value);
    if (idMatch != null) {
      final raw = await _get('/manga/${idMatch.group(1)}');
      return _map(raw);
    }
    final results = await _get('/manga/search', {'query': slug});
    for (final manga in _list(results)) {
      if (_text(manga['slug']).toLowerCase() == slug.toLowerCase()) {
        final id = _int(manga['id']);
        return id > 0 ? _map(await _get('/manga/$id')) : manga;
      }
    }
    final list = _list(results);
    if (list.isEmpty) return <String, dynamic>{};
    final id = _int(list.first['id']);
    return id > 0 ? _map(await _get('/manga/$id')) : list.first;
  }

  List<Map<String, dynamic>> _items(List<Map<String, dynamic>> rawItems) =>
      rawItems.map((manga) {
        final id = _int(manga['id']);
        final title = _text(manga['title_ar']).isNotEmpty
            ? _text(manga['title_ar'])
            : _text(manga['title']);
        return item(
          title: title,
          url: _mangaUrl(_text(manga['slug']), id),
          image: _imageUrl(_text(manga['cover_image'])),
          type: _text(manga['type']).isEmpty ? 'manga' : _text(manga['type']),
          genres: _tags(manga),
          description: _description(manga),
          rating: SourceValues.rating(manga['rating']),
        )
          ..addAll({
            'native_title': _text(manga['title']),
            'status': _text(manga['status']),
            'total_chapters': '${manga['chapters_count'] ?? ''}',
            'latest_chapter_number': '${manga['chapters_count'] ?? ''}',
          });
      }).where((entry) => '${entry['title']}'.trim().isNotEmpty).toList(growable: false);

  List<String> _tags(Map<String, dynamic> manga) {
    final raw = manga['Tags'] ?? manga['tags'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((tag) => _text(tag['name'])).where((tag) => tag.isNotEmpty).toList(growable: false);
  }

  List<String> _pages(Map<String, dynamic> chapter) {
    final raw = chapter['pages_list'];
    if (raw is List) return raw.map(_text).where((page) => page.isNotEmpty).toList(growable: false);
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) return decoded.map(_text).where((page) => page.isNotEmpty).toList(growable: false);
      } catch (_) {}
    }
    return const [];
  }

  Future<Map<String, dynamic>> _get(String path, [Map<String, String>? query]) async {
    final uri = Uri.parse('$_api$path').replace(queryParameters: query);
    final response = await _client.get(uri, headers: _headers).timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('MangaCool: فشل طلب المصدر (${response.statusCode}).');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true));
    if (decoded is! Map || decoded['success'] != true) {
      throw Exception('MangaCool: استجابة API غير صالحة.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  List<Map<String, dynamic>> _list(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is List) return data.whereType<Map>().map(Map<String, dynamic>.from).toList(growable: false);
    if (data is Map && data['mangas'] is List) {
      return (data['mangas'] as List).whereType<Map>().map(Map<String, dynamic>.from).toList(growable: false);
    }
    return const [];
  }

  Map<String, dynamic> _map(Map<String, dynamic> response) {
    final data = response['data'];
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  String _mangaUrl(String slug, int id) => slug.isEmpty ? '$_site/manga/$id' : '$_site/manga/$slug';
  String _chapterUrl(String slug, String number) => '$_site/reader/$slug/$number';
  String _imageUrl(String value) => value.isEmpty ? '' : value.startsWith('http') ? value : 'https://api.mangacool.net/$value';
  String _description(Map<String, dynamic> manga) => _text(manga['description_cool']).isNotEmpty ? _text(manga['description_cool']) : _text(manga['description_ar']).isNotEmpty ? _text(manga['description_ar']) : _text(manga['description']);
  String _text(dynamic value) => value?.toString().trim() ?? '';
  int _int(dynamic value) => int.tryParse(_text(value)) ?? 0;
  String _number(dynamic value) => _text(value);

  int _compareChapterNumbers(String left, String right) {
    final a = double.tryParse(left) ?? -1;
    final b = double.tryParse(right) ?? -1;
    return a.compareTo(b);
  }

  Map<String, String>? _chapterParts(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host != 'mangacool.net') return null;
    final parts = uri.pathSegments;
    final index = parts.indexOf('reader');
    if (index < 0 || index + 2 >= parts.length) return null;
    return {'slug': parts[index + 1], 'number': parts[index + 2]};
  }
}
