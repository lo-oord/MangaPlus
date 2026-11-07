import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import 'manga_html_utils.dart';
import 'source_base.dart';

/// HTML/SSR adapter for Asgard Scans' Arabic manga catalogue.
class AsgardSource extends ContentSource {
  AsgardSource({http.Client? client}) : _client = client ?? http.Client();

  static const String _site = 'https://asgardscans.com';
  static const Map<String, String> _headers = {
    'Accept': 'text/html,application/xhtml+xml,application/json',
    'Accept-Language': 'ar,en;q=0.8',
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/131 Mobile Safari/537.36',
  };
  static const Duration _timeout = Duration(seconds: 30);

  final http.Client _client;

  @override
  String get id => 'asgard';

  @override
  String get name => 'Asgard Scans';

  @override
  String get kind => 'manga';

  @override
  List<String> get hosts => const ['asgardscans.com'];

  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    final value = query.trim();
    if (value.isEmpty) return const [];
    return _cards(await _document(Uri.parse('$_site/manga').replace(
      queryParameters: {'q': value},
    ).toString()));
  }

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) async {
    final safePage = page < 1 ? 1 : page;
    return _cards(await _document(Uri.parse('$_site/manga').replace(
      queryParameters: {if (safePage > 1) 'page': '$safePage'},
    ).toString()));
  }

  @override
  Future<List<Map<String, dynamic>>> catalog({int page = 1}) =>
      latest(page: page);

  @override
  Future<List<Map<String, dynamic>>> nextPage({
    String query = '',
    int page = 2,
  }) async {
    final params = <String, String>{
      if (query.trim().isNotEmpty) 'q': query.trim(),
      if (page > 1) 'page': '${page < 1 ? 1 : page}',
    };
    return _cards(await _document(
      Uri.parse('$_site/manga').replace(queryParameters: params).toString(),
    ));
  }

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final seriesUrl = _seriesUrl(url);
    if (seriesUrl.isEmpty) {
      throw Exception('Asgard: رابط العمل غير صالح.');
    }
    final document = await _document(seriesUrl);
    final title = mangaHtmlText(document.querySelector('h1'));
    if (title.isEmpty) {
      throw Exception('Asgard: لم يتم العثور على تفاصيل العمل.');
    }
    final cover = _cover(document, title);
    final chapters = _chapters(document, seriesUrl);
    final description = mangaHtmlText(
      document.querySelector('[class*="description"], [class*="synopsis"]'),
    );
    final typeText = mangaHtmlText(
      document.querySelector('[class*="badge"], [class*="type"]'),
    );
    final status = mangaHtmlText(
      document.querySelector('[class*="status"], [data-status]'),
    );
    return item(
      title: title,
      url: seriesUrl,
      image: cover,
      type: _normalizeType(typeText),
      description: description,
    )..addAll({
        'synopsis': description,
        'status': status,
        'total_chapters': chapters.length,
        'latest_chapter_number': chapters.isEmpty ? '' : chapters.first['number'],
        'chapters': chapters,
      });
  }

  @override
  Future<Map<String, dynamic>?> streams(String url) async => null;

  @override
  Future<Map<String, dynamic>?> chapterImages(String url) async {
    final chapterUrl = _chapterUrl(url);
    if (chapterUrl.isEmpty) return null;
    final response = await _client
        .get(Uri.parse(chapterUrl), headers: _headers)
        .timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Asgard: فشل تحميل الفصل (${response.statusCode}).');
    }
    final html = utf8.decode(response.bodyBytes, allowMalformed: true);
    final seen = <String>{};
    final pages = <String>[];
    final pattern = RegExp(
      r'''imageUrl\s*:\s*["']([^"']*?/api/public/page/[^"']+)["']''',
      caseSensitive: false,
    );
    for (final match in pattern.allMatches(html)) {
      final page = mangaAbsoluteUrl(_site, match.group(1));
      if (page.isNotEmpty && seen.add(page)) pages.add(page);
    }
    if (pages.isEmpty) {
      throw Exception('Asgard: لم توجد صفحات لهذا الفصل.');
    }
    final number = _chapterNumber(chapterUrl);
    return {
      'title': 'الفصل $number',
      'chapter_number': number,
      'pages': pages,
      'images': pages.map((page) => {'url': page}).toList(growable: false),
      'url': chapterUrl,
    };
  }

  List<Map<String, dynamic>> _cards(Document document) {
    final results = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final anchor in document.querySelectorAll('a[href^="/manga/"]')) {
      final url = _seriesUrl(mangaAbsoluteUrl(_site, anchor.attributes['href']));
      if (url.isEmpty || !seen.add(url)) continue;
      final imageElement = anchor.querySelector('img') ??
          anchor.parent?.querySelector('img');
      final title = mangaHtmlText(anchor.querySelector('bdi, h2, h3'))
          .ifEmpty(mangaHtmlText(anchor))
          .replaceAll(RegExp(r'^(مانجا|مانهوا|مانها|رواية)\s+'), '')
          .trim();
      if (title.isEmpty) continue;
      final image = mangaImageUrl(imageElement, _site);
      results.add(item(
        title: title,
        url: url,
        image: image,
        type: _normalizeType(mangaHtmlText(anchor)),
      ));
    }
    return results;
  }

  String _cover(Document document, String title) {
    String? fallback;
    for (final image in document.querySelectorAll('img')) {
      final alt = image.attributes['alt']?.trim() ?? '';
      final source = image.attributes['src'] ?? '';
      if (!source.contains('/media/covers/')) continue;
      final value = mangaImageUrl(image, _site);
      if (value.isEmpty) continue;
      if (alt == title || !value.contains('?w=')) return value;
      fallback ??= value;
    }
    return fallback ?? '';
  }

  List<Map<String, dynamic>> _chapters(Document document, String seriesUrl) {
    final slug = Uri.parse(seriesUrl).pathSegments.last;
    final chapters = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final anchor in document.querySelectorAll('a[href^="/manga/"]')) {
      final href = anchor.attributes['href']?.trim() ?? '';
      final uri = Uri.tryParse(mangaAbsoluteUrl(_site, href));
      if (uri == null ||
          uri.pathSegments.length < 3 ||
          uri.pathSegments[1] != slug) {
        continue;
      }
      final number = _chapterNumber(uri.toString());
      if (number.isEmpty || !seen.add(uri.toString())) {
        continue;
      }
      chapters.add({
        'title': mangaHtmlText(anchor).ifEmpty('الفصل $number'),
        'number': num.tryParse(number) ?? number,
        'chapter_number': num.tryParse(number) ?? number,
        'url': uri.toString(),
      });
    }
    chapters.sort((a, b) => _number(b['number']).compareTo(_number(a['number'])));
    return chapters;
  }

  String _seriesUrl(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.host.replaceFirst('www.', '') != 'asgardscans.com') {
      return '';
    }
    final segments = uri.pathSegments.where((part) => part.isNotEmpty).toList();
    if (segments.length != 2 || segments.first != 'manga') return '';
    return Uri.https('asgardscans.com', '/manga/${segments[1]}').toString();
  }

  String _chapterUrl(String raw) {
    final uri = Uri.tryParse(mangaAbsoluteUrl(_site, raw));
    if (uri == null || uri.host.replaceFirst('www.', '') != 'asgardscans.com') {
      return '';
    }
    final segments = uri.pathSegments.where((part) => part.isNotEmpty).toList();
    if (segments.length != 3 || segments.first != 'manga') return '';
    return Uri.https('asgardscans.com', '/manga/${segments[1]}/${segments[2]}')
        .toString();
  }

  String _chapterNumber(String url) {
    final segments = Uri.tryParse(url)?.pathSegments;
    if (segments == null || segments.length < 3) return '';
    return RegExp(r'^(\d+(?:\.\d+)?)(?:-|$)')
            .firstMatch(segments.last)
            ?.group(1) ??
        '';
  }

  double _number(dynamic value) => double.tryParse('$value') ?? -1;

  String _normalizeType(String raw) {
    final value = raw.toLowerCase();
    if (value.contains('novel') || value.contains('روا')) return 'novel';
    if (value.contains('manhwa') || value.contains('مانهوا')) return 'manhwa';
    if (value.contains('manhua') || value.contains('مانها')) return 'manhua';
    return raw.trim().isEmpty ? kind : raw.trim();
  }

  Future<Document> _document(String url) async {
    final response = await _client.get(Uri.parse(url), headers: _headers).timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Asgard: فشل طلب المصدر (${response.statusCode}).');
    }
    return html_parser.parse(utf8.decode(response.bodyBytes, allowMalformed: true));
  }
}

extension on String {
  String ifEmpty(String fallback) => trim().isEmpty ? fallback : this;
}
