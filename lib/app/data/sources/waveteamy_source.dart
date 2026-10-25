import 'dart:convert';

import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import 'manga_html_utils.dart';
import 'source_base.dart';
import 'source_values.dart';

/// Conservative HTML adapter for WaveTeamy. It is search/catalog only when the
/// site permits the request; a blocked request is isolated by the registry.
class WaveTeamySource extends ContentSource {
  WaveTeamySource({http.Client? client}) : _client = client ?? http.Client();
  static const _site = 'https://waveteamy.com';
  static const _headers = {'Accept': 'text/html,application/xhtml+xml', 'Accept-Language': 'ar,en;q=0.8', 'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/131 Mobile Safari/537.36'};
  final http.Client _client;

  @override String get id => 'waveteamy';
  @override String get name => 'WaveTeamy';
  @override String get kind => 'manga';
  @override List<String> get hosts => const ['waveteamy.com'];

  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    final value = query.trim();
    if (value.isEmpty) return const [];
    final document = await _document(Uri.parse('$_site/series').replace(queryParameters: {'keyword': value}).toString());
    return _cards(document);
  }

  @override Future<List<Map<String, dynamic>>> latest({int page = 1}) async => _cards(await _document('$_site/series?page=${page < 1 ? 1 : page}'));
  @override Future<List<Map<String, dynamic>>> catalog({int page = 1}) => latest(page: page);
  @override Future<List<Map<String, dynamic>>> nextPage({String query = '', int page = 2}) => query.trim().isEmpty ? latest(page: page) : search(query);

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final document = await _document(url);
    final title = mangaHtmlText(document.querySelector('h1'));
    if (title.isEmpty) throw Exception('WaveTeamy: لم يتم العثور على تفاصيل العمل.');
    final description = mangaHtmlText(document.querySelector('article, .description, [class*="description"]'));
    final text = mangaHtmlText(document.body);
    final result = item(title: title, url: url, image: mangaAbsoluteUrl(_site, document.querySelector('meta[property="og:image"]')?.attributes['content']), type: 'manga', description: description, rating: SourceValues.rating(text));
    final chapters = _chapters(document);
    result.addAll({'synopsis': description, 'status': text.contains('متوقف') ? 'متوقف' : text.contains('منتهي') ? 'منتهي' : 'مستمر', 'author': _label(text, 'المؤلف'), 'artist': _label(text, 'الرسام'), 'total_chapters': chapters.length, 'latest_chapter_number': chapters.isEmpty ? '' : chapters.first['number'], 'chapters': chapters});
    return result;
  }

  @override Future<Map<String, dynamic>?> streams(String url) async => null;

  @override
  Future<Map<String, dynamic>?> chapterImages(String url) async {
    final document = await _document(url); final pages = <String>[];
    for (final image in document.querySelectorAll('img')) {
      final src = mangaAbsoluteUrl(_site, image.attributes['data-src'] ?? image.attributes['src']);
      if (src.isNotEmpty && !pages.contains(src)) pages.add(src);
    }
    if (pages.isEmpty) return null;
    return {'pages': pages, 'images': pages.map((e) => {'url': e}).toList(), 'url': url};
  }

  List<Map<String, dynamic>> _cards(dynamic document) {
    final results = <Map<String, dynamic>>[]; final seen = <String>{};
    for (final anchor in document.querySelectorAll('a[href*="/series/"]')) {
      final href = mangaAbsoluteUrl(_site, anchor.attributes['href']);
      if (href.isEmpty || !seen.add(href)) continue;
      final title = mangaHtmlText(anchor.querySelector('h2, h3, h4, .title'));
      if (title.isEmpty) continue;
      final text = mangaHtmlText(anchor); final image = mangaImageUrl(anchor.querySelector('img'), _site);
      final entry = item(title: title, url: href, image: image, type: 'manga', rating: SourceValues.rating(text));
      final chapter = RegExp(r'الفصل\s*([0-9]+(?:\.[0-9]+)?)').firstMatch(text)?.group(1);
      if (chapter != null) entry['latest_chapter_number'] = chapter;
      results.add(entry);
    }
    return results;
  }

  List<Map<String, dynamic>> _chapters(dynamic document) {
    final out = <Map<String, dynamic>>[]; final seen = <String>{};
    for (final anchor in document.querySelectorAll('a[href*="/chapter"], a[href*="/read"]')) {
      final href = mangaAbsoluteUrl(_site, anchor.attributes['href']); final number = RegExp(r'(?:الفصل|chapter)[^0-9]*([0-9]+(?:\.[0-9]+)?)', caseSensitive: false).firstMatch(mangaHtmlText(anchor))?.group(1) ?? '';
      if (href.isEmpty || number.isEmpty || !seen.add(href)) continue;
      out.add({'title': 'الفصل $number', 'number': double.tryParse(number) ?? number, 'chapter_number': number, 'url': href});
    }
    out.sort((a, b) => (double.tryParse('${b['number']}') ?? -1).compareTo(double.tryParse('${a['number']}') ?? -1));
    return out;
  }

  String _label(String text, String label) { final match = RegExp('$label\\s*:?\\s*([^\\n]+)').firstMatch(text); return match?.group(1)?.trim() ?? ''; }
  Future<dynamic> _document(String url) async { final response = await _client.get(Uri.parse(url), headers: _headers).timeout(const Duration(seconds: 12)); if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('WaveTeamy: فشل طلب المصدر (${response.statusCode}).'); return html_parser.parse(utf8.decode(response.bodyBytes, allowMalformed: true)); }
}
