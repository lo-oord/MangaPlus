import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import 'manga_html_utils.dart';
import 'source_base.dart';
import 'source_values.dart';

/// HTML adapter for Hizo Manga (Keiyoushi's Madara-based Arabic source).
class HizoMangaSource extends ContentSource {
  HizoMangaSource({http.Client? client}) : _client = client ?? http.Client();
  static const String _site = 'https://hizomanga.net';
  static const Map<String, String> _headers = {
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'ar,en;q=0.8',
    'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/131 Mobile Safari/537.36',
    'Referer': 'https://hizomanga.net/',
  };
  final http.Client _client;
  final Map<String, Map<String, dynamic>> _chapterContexts = {};

  @override
  String get id => 'hizomanga';
  @override
  String get name => 'Hizo Manga';
  @override
  String get kind => 'manga';
  @override
  List<String> get hosts => const ['hizomanga.net'];

  @override
  Future<List<Map<String, dynamic>>> search(String query) {
    final term = query.trim();
    if (term.isEmpty) return Future.value(const []);
    return _list(page: 1, query: term);
  }

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) => _list(page: page);

  @override
  Future<List<Map<String, dynamic>>> catalog({int page = 1}) => _list(page: page);

  @override
  Future<List<Map<String, dynamic>>> nextPage({String query = '', int page = 2}) =>
      _list(page: page, query: query);

  Future<List<Map<String, dynamic>>> _list({required int page, String query = ''}) async {
    final safePage = page < 1 ? 1 : page;
    // The site's current catalogue is /series/; keep the standard Madara
    // query parameters so existing/redirected WordPress installations work.
    final uri = Uri.parse(_site).replace(
      path: safePage == 1 ? '/series/' : '/series/page/$safePage/',
      queryParameters: query.trim().isEmpty
          ? null
          : {'s': query.trim(), 'post_type': 'wp-manga'},
    );
    final document = await _document(uri.toString());
    final items = _cards(document);
    if (items.isNotEmpty || query.trim().isNotEmpty) return items;
    // Current Hizo landing page exposes the same catalogue through /mangas/.
    final fallback = Uri.parse(_site).replace(
      path: safePage == 1 ? '/mangas/' : '/mangas/page/$safePage/',
    );
    return _cards(await _document(fallback.toString()));
  }

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final seriesUrl = _canonical(url);
    if (seriesUrl.isEmpty) throw Exception('Hizo Manga: رابط العمل غير صالح.');
    final document = await _document(seriesUrl);
    final title = mangaHtmlText(document.querySelector(
      'div.manga-title > h2, .post-title h1, .post-title h2, h1.entry-title, h1',
    ));
    if (title.isEmpty) throw Exception('Hizo Manga: لم يتم العثور على تفاصيل العمل.');
    final cover = _secure(mangaImageUrl(document.querySelector(
      '.summary_image img, .item-thumb img, .manga-thumb img, .summary_image img',
    ), _site));
    final synopsis = mangaHtmlText(document.querySelector(
      '.manga-excerpt .excerpt-content, .description-summary .summary__content, .summary_content .manga-excerpt, .entry-content',
    ));
    final status = mangaHtmlText(document.querySelector(
      '.manga-status span:last-child, .summary-content, .summary-heading',
    ));
    final genres = document
        .querySelectorAll('.genres-content a, .manga-genres a, .genres a, .mgen a')
        .map(mangaHtmlText)
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final chapters = _chapters(document, seriesUrl);
    final number = chapters.isEmpty ? '' : chapters.first['number'];
    final type = _info(document, const ['النوع', 'Type']);
    final author = _info(document, const ['المؤلف', 'الكاتب', 'Author']);
    final rating = SourceValues.rating(mangaHtmlText(document.querySelector(
      '[itemprop="ratingValue"], .rating .num, .post-total-rating .score',
    )));
    _rememberChapters(seriesUrl, chapters);
    final result = item(
      title: title,
      url: seriesUrl,
      image: cover,
      type: SourceValues.type(type, fallback: kind),
      genres: genres,
      description: synopsis,
      rating: rating,
    );
    result.addAll({
      'synopsis': synopsis,
      'status': status,
      'author': author,
      'chapters': chapters,
      'total_chapters': chapters.length,
      'latest_chapter_number': number,
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
    final pages = <String>[];
    final selectors = const [
      '#readerarea img', '.reading-content img', '.wp-manga-chapter-img img',
      '.chapter-content img', '.entry-content img', '.reader-area img',
    ];
    for (final selector in selectors) {
      for (final image in document.querySelectorAll(selector)) {
        final page = _secure(mangaImageUrl(image, _site));
        if (page.isEmpty || _isDecorative(page) || !seen.add(page)) continue;
        pages.add(page);
      }
      if (pages.isNotEmpty) break;
    }
    if (pages.isEmpty) throw Exception('Hizo Manga: لا توجد صور متاحة لهذا الفصل.');
    final context = _chapterContexts[chapterUrl];
    final heading = mangaHtmlText(document.querySelector('.reading-content h1, .readercontent h1, h1.entry-title, h1'));
    final number = '${context?['number'] ?? _chapterNumber(chapterUrl)}';
    return {
      'title': heading.isEmpty ? 'الفصل $number' : heading,
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
      throw Exception('Hizo Manga: فشل تحميل الصفحة (${response.statusCode}).');
    }
    return html_parser.parse(utf8.decode(response.bodyBytes, allowMalformed: true));
  }

  List<Map<String, dynamic>> _cards(Document document) {
    final output = <Map<String, dynamic>>[];
    final seen = <String>{};
    final cards = document.querySelectorAll(
      '.page-listing-item, .c-tabs-item__content, .wp-manga, .manga-item, .bs, article',
    );
    for (final card in cards) {
      final anchor = card.querySelector(
        '.item-thumb a[href], .post-title a[href], .manga-title a[href], .bsx a[href], a[href*="/content/"], a[href*="/serie/"]',
      );
      if (anchor == null) continue;
      final url = _canonical(mangaAbsoluteUrl(_site, anchor.attributes['href']));
      if (url.isEmpty || !seen.add(url)) continue;
      final title = mangaHtmlText(card.querySelector(
        '.post-title a, .manga-title, .tt, h3, h2',
      )).isNotEmpty
          ? mangaHtmlText(card.querySelector('.post-title a, .manga-title, .tt, h3, h2'))
          : (anchor.attributes['title'] ?? mangaHtmlText(anchor)).trim();
      if (title.isEmpty) continue;
      final cover = _secure(mangaImageUrl(card.querySelector('img'), _site));
      final chapterText = mangaHtmlText(card.querySelector('.list-chapter a, .latest-chapter, .chapter'));
      final number = _number(chapterText);
      output.add(item(title: title, url: url, image: cover)
        ..addAll({if (number != null) 'latest_chapter_number': number}));
    }
    return output;
  }

  List<Map<String, dynamic>> _chapters(Document document, String seriesUrl) {
    final list = <Map<String, dynamic>>[];
    final seen = <String>{};
    final links = document.querySelectorAll(
      '.wp-manga-chapter a[href], .list-chapter a[href], .eplister a[href], .chapter-list a[href]',
    );
    for (final anchor in links) {
      final url = _canonical(mangaAbsoluteUrl(_site, anchor.attributes['href']));
      if (url.isEmpty || url == seriesUrl || !seen.add(url)) continue;
      final title = mangaHtmlText(anchor);
      final number = _number(title) ?? _number(url);
      if (number == null) continue;
      final date = mangaHtmlText(anchor.parent?.querySelector('time, .chapterdate, .post-on'));
      list.add({
        'id': url,
        'number': number,
        'title': title.isEmpty ? 'الفصل $number' : title,
        'url': url,
        'release_date': date,
        'date': date,
      });
    }
    return list;
  }

  void _rememberChapters(String seriesUrl, List<Map<String, dynamic>> chapters) {
    for (var i = 0; i < chapters.length; i++) {
      final chapter = chapters[i];
      final url = '${chapter['url']}';
      _chapterContexts[url] = {
        'number': chapter['number'],
        'chapters': chapters,
        if (i + 1 < chapters.length) 'next_chapter': chapters[i + 1]['url'],
        if (i > 0) 'previous_chapter': chapters[i - 1]['url'],
      };
    }
  }

  String _canonical(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !handles(url)) return '';
    final path = uri.path.endsWith('/') ? uri.path : '${uri.path}/';
    return Uri.parse(_site).replace(path: path).toString();
  }

  String _info(Document document, List<String> labels) {
    for (final row in document.querySelectorAll('.post-content_item, .summary-content, .info-block, .manga-status')) {
      final text = mangaHtmlText(row);
      if (labels.any(text.toLowerCase().contains)) {
        final value = row.querySelector('.summary-content, .summary-heading + div, span:last-child, a, i');
        if (value != null) return mangaHtmlText(value);
      }
    }
    return '';
  }

  String _secure(String url) => url.replaceFirst(RegExp(r'^http://'), 'https://');
  bool _isDecorative(String url) => url.contains('/logo') || url.contains('avatar') || url.endsWith('.svg');
  num? _number(String text) {
    final match = RegExp(r'\d+(?:\.\d+)?').firstMatch(text);
    return match == null ? null : num.tryParse(match.group(0)!);
  }
  String _chapterNumber(String url) {
    final segments = Uri.tryParse(url)?.pathSegments.where((e) => e.isNotEmpty).toList() ?? const <String>[];
    return segments.isEmpty ? '' : segments.last;
  }
}
