import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:html/dom.dart' show Document;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import 'source_base.dart';
import 'source_values.dart';

/// Read-only adapter for MKNOV (مملكة الروايات).
///
/// Work and chapter metadata are served by MKNOV's public JSON endpoints. Its
/// chapter body uses a per-page protected WOFF2 font, which is decoded by the
/// Android platform implementation through [_fontDecoder].
class MknovSource extends ContentSource {
  static const String _site = 'https://mknov.com';
  static const Duration _catalogTtl = Duration(minutes: 10);
  static const Duration _chapterTtl = Duration(minutes: 10);
  static const int _pageSize = 24;
  static const MethodChannel _fontDecoder =
      MethodChannel('com.mangaplus.app/mknov_font_decoder');
  static final http.Client _client = http.Client();

  static List<Map<String, dynamic>>? _catalogCache;
  static DateTime? _catalogCachedAt;
  static Future<List<Map<String, dynamic>>>? _catalogRequest;
  static final Map<String, (DateTime, List<Map<String, dynamic>>)> _chapterCache = {};
  static final Map<String, Future<List<Map<String, dynamic>>>> _chapterRequests = {};

  @override
  String get id => 'mknov';

  @override
  String get name => 'MKNOV';

  @override
  String get kind => 'novel';

  @override
  List<String> get hosts => const ['mknov.com'];

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

  /// Used by the blank-search state, in the same way as Azora suggestions.
  Future<List<Map<String, dynamic>>> searchSuggestions({int limit = 8}) async {
    if (limit <= 0) return const [];
    final works = await _fetchCatalog(limit: limit.clamp(1, 40).toInt());
    return works.take(limit).map(_workItem).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _catalogPage(int page) async {
    final works = await _loadCatalog();
    final start = ((page < 1 ? 1 : page) - 1) * _pageSize;
    if (start >= works.length) return const [];
    return works.skip(start).take(_pageSize).map(_workItem).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _searchPage(String query, int page) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return _catalogPage(page);
    final works = await _loadCatalog();
    final matching = works.where((work) {
      final fields = [
        work['titleAr'],
        work['title'],
        work['slug'],
        work['author'],
        work['translator'],
      ].map((value) => value?.toString().toLowerCase() ?? '');
      return fields.any((value) => value.contains(normalized));
    });
    final start = ((page < 1 ? 1 : page) - 1) * _pageSize;
    return matching.skip(start).take(_pageSize).map(_workItem).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _loadCatalog() async {
    final cachedAt = _catalogCachedAt;
    final cached = _catalogCache;
    if (cached != null && cachedAt != null &&
        DateTime.now().difference(cachedAt) < _catalogTtl) {
      return cached;
    }

    final inFlight = _catalogRequest;
    if (inFlight != null) return inFlight;

    final request = _fetchCatalog();
    _catalogRequest = request;
    try {
      final works = await request;
      _catalogCache = works;
      _catalogCachedAt = DateTime.now();
      return works;
    } finally {
      if (identical(_catalogRequest, request)) _catalogRequest = null;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchCatalog({int limit = 5000}) async {
    final response = await _request(
      Uri.parse('$_site/api/works?limit=$limit'),
      accept: 'application/json',
    );
    final decoded = jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true));
    final records = decoded is List
        ? decoded
        : decoded is Map && decoded['works'] is List
            ? decoded['works'] as List
            : const <dynamic>[];
    if (records.isEmpty && decoded is! List) {
      throw Exception('MKNOV: استجابة فهرس الروايات غير صالحة.');
    }
    return records
        .whereType<Map>()
        .map((record) => Map<String, dynamic>.from(record))
        .where((record) => '${record['id'] ?? ''}'.trim().isNotEmpty &&
            '${record['titleAr'] ?? record['title'] ?? ''}'.trim().isNotEmpty)
        .toList(growable: false);
  }

  Map<String, dynamic> _workItem(Map<String, dynamic> work) {
    final id = '${work['id'] ?? ''}'.trim();
    final title = '${work['titleAr'] ?? work['title'] ?? ''}'.trim();
    final description = '${work['description'] ?? ''}'.trim();
    final genres = _strings(work['genres']);
    final chapters = work['totalChapters'];
    final rating = SourceValues.rating(work);
    final item = this.item(
      title: title,
      url: '$_site/novel/$id',
      image: _absoluteUrl('${work['image'] ?? ''}'),
      type: 'novel',
      genres: genres,
      description: description,
      rating: rating,
    );
    item.addAll({
      'manga_id': id,
      'series_id': id,
      'slug': '${work['slug'] ?? id}',
      'author': '${work['author'] ?? ''}',
      'translator': '${work['translator'] ?? ''}',
      'status': _normalizeStatus(work['status']),
      'year': work['year'] ?? '',
      'release_year': work['year'] ?? '',
      'total_chapters': chapters ?? 0,
      'latest_chapter_number': chapters ?? 0,
      'view_count': work['totalViews'] ?? 0,
    });
    return item;
  }

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final id = _workId(url);
    if (id.isEmpty) throw Exception('MKNOV: رابط الرواية غير صالح.');
    final works = await _loadCatalog();
    Map<String, dynamic>? work;
    for (final record in works) {
      if ('${record['id']}' == id) {
        work = record;
        break;
      }
    }
    if (work == null) throw Exception('MKNOV: لم يتم العثور على الرواية.');

    final chapters = await _loadChapters(id).catchError(
      (_) => <Map<String, dynamic>>[],
    );
    final latestDate = chapters.isEmpty ? '' : '${chapters.first['release_date'] ?? ''}';
    return _workItem(work)
      ..addAll({
        'native_title': '${work['title'] ?? ''}',
        'nativeTitle': '${work['title'] ?? ''}',
        'description': '${work['description'] ?? ''}',
        'synopsis': '${work['description'] ?? ''}',
        'genres': _strings(work['genres']),
        'author': '${work['author'] ?? ''}',
        'translator': '${work['translator'] ?? ''}',
        'status': _normalizeStatus(work['status']),
        'release_year': work['year'] ?? '',
        'year': work['year'] ?? '',
        'total_chapters': work['totalChapters'] ?? chapters.length,
        'updated_on': latestDate,
        'updated_at': latestDate,
        'latest_chapter_date': latestDate,
        'latest_chapter_number': chapters.isEmpty
            ? 0
            : _formatChapterNumber(chapters.first['number']),
        'chapters': chapters,
      });
  }

  @override
  Future<Map<String, dynamic>?> streams(String url) async => null;

  @override
  Future<Map<String, dynamic>?> chapterContent(String url) async {
    final parts = _chapterParts(url);
    if (parts == null) throw Exception('MKNOV: رابط الفصل غير صالح.');
    final chapterUrl = '$_site/novel/${parts.$1}/chapter/${parts.$2}';
    final response = await _request(
      Uri.parse(chapterUrl),
      accept: 'text/html,application/xhtml+xml',
      referer: '$_site/novel/${parts.$1}',
    );
    final html = utf8.decode(response.bodyBytes, allowMalformed: true);
    final document = html_parser.parse(html);
    final fontUrl = _protectedFontUrl(document);
    final protectedBody = document.querySelector('div.whitespace-pre-wrap');
    final rawBody = protectedBody?.text.trim() ?? '';
    final body = rawBody.isNotEmpty ? rawBody : _cleanFallback(document);
    if (body.isEmpty) throw Exception('MKNOV: لم يتم العثور على نص الفصل.');

    final chaptersRequest = _loadChapters(parts.$1).catchError(
      (_) => <Map<String, dynamic>>[],
    );
    final content = rawBody.isNotEmpty && fontUrl != null
        ? await _decodeProtectedBody(rawBody, fontUrl, referer: chapterUrl)
        : _normalizeText(body);
    if (content.trim().isEmpty) throw Exception('MKNOV: تعذر فك نص الفصل.');

    final chapters = await chaptersRequest;
    final index = chapters.indexWhere((chapter) => '${chapter['id']}' == parts.$2);
    final previous = index >= 0 && index + 1 < chapters.length
        ? chapters[index + 1]['url']
        : null;
    final next = index > 0 ? chapters[index - 1]['url'] : null;
    final current = index >= 0 ? chapters[index] : null;
    final chapterNumber = _formatChapterNumber(current?['number'] ?? '');
    final chapterTitle = '${current?['chapter_title'] ?? ''}'.trim();
    return {
      'title': chapterTitle.isEmpty
          ? 'الفصل $chapterNumber'
          : 'الفصل $chapterNumber: $chapterTitle',
      'chapter_number': chapterNumber,
      'content': content,
      'previousChapter': previous,
      'nextChapter': next,
      'chapters': chapters,
      'url': chapterUrl,
    };
  }

  Future<String> _decodeProtectedBody(
    String body,
    Uri fontUrl, {
    required String referer,
  }) async {
    final response = await _request(
      fontUrl,
      accept: 'font/woff2,application/font-woff2,*/*;q=0.8',
      referer: referer,
    );
    try {
      final decoded = await _fontDecoder.invokeMethod<String>(
        'decodeChapterBody',
        {'text': body, 'font': response.bodyBytes},
      );
      if (decoded == null || decoded.trim().isEmpty) {
        throw Exception('MKNOV: أعاد مفكك الخط نصًا فارغًا.');
      }
      return _normalizeText(decoded);
    } on PlatformException catch (error) {
      throw Exception('MKNOV: تعذر فك الخط المحمي (${error.message ?? error.code}).');
    } on MissingPluginException {
      throw Exception('MKNOV: فك الخط المحمي متاح في نسخة Android فقط.');
    }
  }

  Uri? _protectedFontUrl(Document document) {
    final styles = document
        .querySelectorAll('style')
        .map((style) => style.text)
        .join('\n');
    final match = RegExp(
      r'''src\s*:\s*url\(\s*["']?([^"')\s]+\.woff2[^"')\s]*)["']?\s*\)''',
      caseSensitive: false,
    ).firstMatch(styles);
    if (match == null) return null;
    final raw = match.group(1)?.replaceAll('&amp;', '&').trim() ?? '';
    if (raw.isEmpty) return null;
    return Uri.tryParse(_site)?.resolve(raw);
  }

  String _cleanFallback(Document document) {
    document
        .querySelectorAll('script, style, nav, header, footer, .ad, ins, iframe')
        .forEach((element) => element.remove());
    return _normalizeText(document.body?.text ?? '');
  }

  Future<List<Map<String, dynamic>>> _loadChapters(String workId) async {
    final cached = _chapterCache[workId];
    if (cached != null && DateTime.now().difference(cached.$1) < _chapterTtl) {
      return cached.$2;
    }
    final inFlight = _chapterRequests[workId];
    if (inFlight != null) return inFlight;

    final request = _fetchChapters(workId);
    _chapterRequests[workId] = request;
    try {
      final chapters = await request;
      _chapterCache[workId] = (DateTime.now(), chapters);
      return chapters;
    } finally {
      if (identical(_chapterRequests[workId], request)) {
        _chapterRequests.remove(workId);
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchChapters(String workId) async {
    final response = await _request(
      Uri.parse('$_site/api/works/$workId/chapters'),
      accept: 'application/json',
      referer: '$_site/novel/$workId',
    );
    final decoded = jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true));
    final volumes = decoded is Map && decoded['volumes'] is List
        ? decoded['volumes'] as List
        : const <dynamic>[];
    final records = <({int index, Map<String, dynamic> chapter})>[];
    var index = 0;
    for (final volume in volumes.whereType<Map>()) {
      final list = volume['chapters'];
      if (list is! List) continue;
      for (final raw in list.whereType<Map>()) {
        final chapter = Map<String, dynamic>.from(raw);
        if ('${chapter['id'] ?? ''}'.trim().isNotEmpty) {
          records.add((index: index++, chapter: chapter));
        }
      }
    }
    records.sort((left, right) {
      final byNumber = _chapterNumber(right.chapter).compareTo(_chapterNumber(left.chapter));
      return byNumber == 0 ? left.index.compareTo(right.index) : byNumber;
    });
    return records.map((record) {
      final chapter = record.chapter;
      final id = '${chapter['id']}';
      final number = chapter['chapterNumber'] ?? '';
      final displayNumber = _formatChapterNumber(number);
      final chapterTitle = '${chapter['chapterTitle'] ?? ''}'.trim();
      final title = chapterTitle.isEmpty
          ? 'الفصل $displayNumber'
          : 'الفصل $displayNumber: $chapterTitle';
      final publishDate = '${chapter['publishDate'] ?? ''}';
      final url = '$_site/novel/$workId/chapter/$id';
      return <String, dynamic>{
        'id': id,
        'title': title,
        'chapter_title': chapterTitle,
        'number': number,
        'chapter_number': number,
        'release_date': publishDate,
        'date': publishDate,
        'url': url,
      };
    }).toList(growable: false);
  }

  double _chapterNumber(Map<String, dynamic> chapter) {
    final value = chapter['chapterNumber'];
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  String _formatChapterNumber(dynamic value) {
    final number = value is num ? value.toDouble() : double.tryParse('$value');
    if (number == null || !number.isFinite) return '$value';
    return number == number.truncateToDouble()
        ? number.toInt().toString()
        : number.toString();
  }

  Future<http.Response> _request(
    Uri uri, {
    required String accept,
    String? referer,
  }) async {
    final response = await _client.get(uri, headers: {
      'Accept': accept,
      'Accept-Language': 'ar,en-US;q=0.8,en;q=0.6',
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/131.0.0.0 Mobile Safari/537.36',
      'Referer': referer ?? '$_site/',
    }).timeout(const Duration(seconds: 40));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('MKNOV: فشل طلب المصدر (${response.statusCode}).');
    }
    return response;
  }

  List<String> _strings(dynamic raw) => raw is List
      ? raw.map((value) => value.toString().trim()).where((value) => value.isNotEmpty).toSet().toList(growable: false)
      : const [];

  String _normalizeStatus(dynamic raw) {
    final status = '${raw ?? ''}'.trim();
    return switch (status) {
      'متوقفة' || 'متوقف' => 'متوقف مؤقتًا',
      _ => status,
    };
  }

  String _workId(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null) return '';
    if (uri.scheme == 'mknov') return uri.queryParameters['id'] ?? '';
    final parts = uri.pathSegments.where((part) => part.isNotEmpty).toList();
    if (parts.length >= 2 && parts[0] == 'novel') return parts[1];
    return '';
  }

  (String, String)? _chapterParts(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    if (uri.scheme == 'mknov' && uri.host == 'chapter') {
      final workId = uri.queryParameters['work'] ?? '';
      final chapterId = uri.queryParameters['id'] ?? '';
      return workId.isEmpty || chapterId.isEmpty ? null : (workId, chapterId);
    }
    final parts = uri.pathSegments.where((part) => part.isNotEmpty).toList();
    if (parts.length >= 4 && parts[0] == 'novel' && parts[2] == 'chapter') {
      return (parts[1], parts[3]);
    }
    return null;
  }

  String _absoluteUrl(String raw) {
    if (raw.trim().isEmpty) return '';
    final uri = Uri.tryParse(raw.trim());
    if (uri == null) return '';
    return Uri.parse(_site).resolveUri(uri).toString();
  }

  String _normalizeText(String text) => text
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll(RegExp(r'[\t ]+'), ' ')
      .replaceAll(RegExp(r' *\n *'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}
