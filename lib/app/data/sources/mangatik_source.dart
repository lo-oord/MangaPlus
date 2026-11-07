import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import 'manga_html_utils.dart';
import 'source_base.dart';
import 'source_values.dart';

/// HTML adapter for MangaTik, following the selectors and routes in Keiyoushi.
class MangaTikSource extends ContentSource {
  MangaTikSource({http.Client? client}) : _client = client ?? http.Client();
  static const String _site = 'https://mangatik.com';
  static const Map<String, String> _headers = {
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'ar,en;q=0.8',
    'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/131 Mobile Safari/537.36',
    'Referer': 'https://mangatik.com/',
  };
  final http.Client _client;
  final Map<String, Map<String, dynamic>> _chapterContexts = {};

  @override
  String get id => 'mangatik';
  @override
  String get name => 'MangaTik';
  @override
  String get kind => 'manga';
  @override
  List<String> get hosts => const ['mangatik.com'];

  @override
  Future<List<Map<String, dynamic>>> search(String query) {
    final term = query.trim();
    if (term.isEmpty) return Future.value(const []);
    return _list(path: '/manga', page: 1, query: term);
  }

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) =>
      _list(path: '/latest', page: page);

  @override
  Future<List<Map<String, dynamic>>> catalog({int page = 1}) =>
      _list(path: '/manga', page: page);

  @override
  Future<List<Map<String, dynamic>>> nextPage({String query = '', int page = 2}) =>
      _list(path: query.trim().isEmpty ? '/manga' : '/manga', page: page, query: query);

  Future<List<Map<String, dynamic>>> _list({required String path, required int page, String query = ''}) async {
    final safePage = page < 1 ? 1 : page;
    final uri = Uri.parse(_site).replace(path: path, queryParameters: {
      if (query.trim().isNotEmpty) 'q': query.trim(),
      'page': '$safePage',
    });
    final document = await _document(uri.toString());
    return document.querySelectorAll('article.manga-card').map((card) {
      final anchor = card.querySelector('.manga-title > a[href], a[href*="/manga/"]');
      if (anchor == null) return <String, dynamic>{};
      final url = mangaAbsoluteUrl(_site, anchor.attributes['href']);
      final title = mangaHtmlText(anchor);
      final image = mangaImageUrl(card.querySelector('img.manga-poster'), _site);
      final ratingText = mangaHtmlText(card.querySelector('.manga-rating-badge'));
      return item(title: title, url: url, image: image, rating: SourceValues.rating(ratingText));
    }).where((entry) => '${entry['title']}'.isNotEmpty && '${entry['url']}'.isNotEmpty).toList(growable: false);
  }

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final seriesUrl = _canonical(url);
    if (seriesUrl.isEmpty) throw Exception('MangaTik: رابط العمل غير صالح.');
    final document = await _document(seriesUrl);
    final jsonLd = _jsonLd(document);
    final title = _first([
      '${jsonLd['name'] ?? ''}',
      mangaHtmlText(document.querySelector('h1')),
    ]);
    if (title.isEmpty) throw Exception('MangaTik: لم يتم العثور على تفاصيل العمل.');
    final imageData = jsonLd['image'];
    final image = imageData is Map ? imageData['url'] : imageData;
    final cover = SourceValues.imageUrl(image ?? mangaImageUrl(document.querySelector('img.manga-poster'), _site), baseUrl: _site);
    final synopsis = _first(['${jsonLd['description'] ?? ''}', mangaHtmlText(document.querySelector('.description, .synopsis, .manga-description'))]);
    final genreData = jsonLd['genre'];
    final genres = genreData is List
        ? genreData.map((entry) => '$entry'.trim()).where((entry) => entry.isNotEmpty).toList(growable: false)
        : genreData == null ? <String>[] : ['$genreData'];
    final chapters = _chapters(document);
    final ratingData = jsonLd['aggregateRating'];
    final rating = SourceValues.rating(ratingData is Map ? ratingData['ratingValue'] : ratingData);
    final authorData = jsonLd['author'];
    final author = authorData is Map ? '${authorData['name'] ?? ''}' : '$authorData';
    final status = mangaHtmlText(document.querySelector('.badge-status, .manga-status, [data-status]'));
    _rememberChapters(chapters);
    final result = item(
      title: title,
      url: seriesUrl,
      image: cover,
      genres: genres,
      description: synopsis,
      rating: rating,
      type: kind,
    );
    result.addAll({
      'synopsis': synopsis,
      'alternate_titles': jsonLd['alternateName'] ?? '',
      'author': author == 'null' ? '' : author,
      'status': status,
      'release_year': '${jsonLd['datePublished'] ?? ''}',
      'total_chapters': chapters.length,
      'latest_chapter_number': chapters.isEmpty ? '' : chapters.first['number'],
      'chapters': chapters,
    });
    return result;
  }

  @override
  Future<Map<String, dynamic>?> streams(String url) async => null;

  @override
  Future<Map<String, dynamic>?> chapterImages(String url) async {
    final chapterUrl = _canonical(url);
    if (chapterUrl.isEmpty) return null;
    final document = await _document(chapterUrl);
    final seen = <String>{};
    final pages = document.querySelectorAll('img.webtoon-image').map((image) {
      final value = mangaImageUrl(image, _site);
      return value;
    }).where((value) => value.isNotEmpty && seen.add(value)).toList(growable: false);
    if (pages.isEmpty) throw Exception('MangaTik: لا توجد صور متاحة لهذا الفصل.');
    final context = _chapterContexts[chapterUrl];
    final segments = Uri.parse(chapterUrl).pathSegments.where((entry) => entry.isNotEmpty).toList();
    final number = segments.isEmpty ? '' : segments.last;
    final heading = mangaHtmlText(document.querySelector('h1'));
    return {
      'title': heading.isEmpty ? 'الفصل $number' : '$heading - الفصل $number',
      'chapter_number': number,
      'url': chapterUrl,
      'pages': pages,
      'images': pages.map((page) => {'url': page}).toList(growable: false),
      if (context?['previous_chapter'] case final String previous when previous.isNotEmpty) 'previous_chapter': previous,
      if (context?['next_chapter'] case final String next when next.isNotEmpty) 'next_chapter': next,
      if (context?['chapters'] case final List<Map<String, dynamic>> chapters) 'chapters': chapters,
    };
  }

  Future<Document> _document(String url) async {
    final response = await _client.get(Uri.parse(url), headers: _headers).timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('MangaTik: فشل تحميل الصفحة (${response.statusCode}).');
    }
    return html_parser.parse(utf8.decode(response.bodyBytes, allowMalformed: true));
  }

  List<Map<String, dynamic>> _chapters(Document document) {
    final chapters = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final anchor in document.querySelectorAll('a.chapter-item-card[href]')) {
      final url = _canonical(mangaAbsoluteUrl(_site, anchor.attributes['href']));
      if (url.isEmpty || !seen.add(url)) continue;
      final number = _number(anchor.attributes['data-chapter'] ?? '');
      final title = mangaHtmlText(anchor);
      final date = mangaHtmlText(anchor.querySelector('time, .chapter-date, .date'));
      chapters.add({
        'id': url,
        'number': number ?? _number(title) ?? 0,
        'title': title.isEmpty ? 'الفصل ${number ?? ''}' : title,
        'url': url,
        'release_date': date,
        'date': date,
      });
    }
    return chapters;
  }

  void _rememberChapters(List<Map<String, dynamic>> chapters) {
    for (var i = 0; i < chapters.length; i++) {
      final url = '${chapters[i]['url']}';
      _chapterContexts[url] = {
        'chapters': chapters,
        if (i + 1 < chapters.length) 'next_chapter': chapters[i + 1]['url'],
        if (i > 0) 'previous_chapter': chapters[i - 1]['url'],
      };
    }
  }

  Map<String, dynamic> _jsonLd(Document document) {
    for (final element in document.querySelectorAll('script[type="application/ld+json"]')) {
      try {
        final decoded = jsonDecode(element.text.trim());
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is List) {
          final found = decoded.whereType<Map>().cast<Map<String, dynamic>>().firstOrNull;
          if (found != null) return found;
        }
      } catch (_) {
        // Continue to the next JSON-LD block or HTML fallback.
      }
    }
    return const {};
  }

  String _canonical(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !handles(url)) return '';
    return Uri.parse(_site).replace(path: uri.path).toString();
  }
  String _first(List<String> values) => values.map((value) => value.trim()).firstWhere((value) => value.isNotEmpty, orElse: () => '');
  num? _number(String text) {
    final match = RegExp(r'\d+(?:\.\d+)?').firstMatch(text);
    return match == null ? null : num.tryParse(match.group(0)!);
  }
}
