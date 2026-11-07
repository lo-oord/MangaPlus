import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import 'manga_html_utils.dart';
import 'source_base.dart';
import 'source_values.dart';

/// Read-only adapter for the Arabic Onma / Manga Online source.
class MangaOnlineSource extends ContentSource {
  // The catalogue moved off onma.top; old links stay valid through [hosts].
  static const String _site = 'https://manonga.online';
  static final http.Client _client = http.Client();

  @override
  String get id => 'manga_online';
  @override
  String get name => 'Manga Online';
  @override
  String get kind => 'manga';
  @override
  List<String> get hosts => const ['onma.top', 'manonga.online'];
  @override
  bool handles(String url) => url.startsWith('onma://') || super.handles(url);

  @override
  Future<List<Map<String, dynamic>>> search(String query) =>
      _search(query, page: 1);

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) =>
      _latest(page < 1 ? 1 : page);

  @override
  Future<List<Map<String, dynamic>>> catalog({int page = 1}) =>
      _latest(page < 1 ? 1 : page);

  @override
  Future<List<Map<String, dynamic>>> nextPage({String query = '', int page = 2}) =>
      query.trim().isEmpty ? _latest(page) : _search(query, page: page);

  Future<List<Map<String, dynamic>>> _search(String query, {required int page}) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return const [];
    final uri = Uri.parse('$_site/search').replace(queryParameters: {'query': normalized});
    final response = await _request(uri.toString(), accept: 'application/json');
    final decoded = jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true));
    if (decoded is! Map || decoded['suggestions'] is! List) return const [];
    final suggestions = (decoded['suggestions'] as List).whereType<Map>().toList();
    final start = (page < 1 ? 0 : page - 1) * 24;
    if (start >= suggestions.length) return const [];
    return suggestions.skip(start).take(24).map((suggestion) {
      final slug = (suggestion['data'] ?? '').toString().trim();
      final title = (suggestion['value'] ?? '').toString().trim();
      final cover = slug.isEmpty
          ? ''
          : '$_site/uploads/manga/$slug/cover/cover_250x350.jpg';
      final entry = _seriesItem(title, slug, cover);
      entry['slug'] = slug;
      return entry;
    }).where((entry) =>
        (entry['title'] as String).isNotEmpty &&
        (entry['slug'] as String).isNotEmpty).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _latest(int page) async {
    final uri = Uri.parse('$_site/latest-release').replace(
      queryParameters: {'page': '$page'},
    );
    final document = await _document(uri.toString());
    final results = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final card in document.querySelectorAll('div.mangalist div.manga-item')) {
      final anchor = card.querySelector('.manga-heading a, .media-heading a');
      final title = mangaHtmlText(anchor);
      final slug = _slugFromUrl(anchor?.attributes['href'] ?? '');
      if (title.isEmpty || slug.isEmpty || !seen.add(slug)) continue;
      final image = mangaImageUrl(card.querySelector('.right-image img, img'), _site);
      final entry = _seriesItem(title, slug, image);
      final latestChapter = card.querySelector(
        '.manga-chapter a, .events-subtitle a, .chapter-title a, .latest-chapter a, .chapter a',
      );
      final chapterLabel = mangaHtmlText(latestChapter);
      final chapterNumber = mangaChapterNumber(chapterLabel) ??
          mangaChapterNumber(latestChapter?.attributes['href'] ?? '');
      if (chapterNumber != null) entry['latest_chapter_number'] = chapterNumber;
      final chapterUrl = mangaAbsoluteUrl(_site, latestChapter?.attributes['href']);
      if (chapterUrl.isNotEmpty) entry['latest_chapter_url'] = 'onma://chapter?series=${Uri.encodeQueryComponent(slug)}&chapter=${Uri.encodeQueryComponent(chapterUrl.split('/').last)}';
      final chapterDate = mangaHtmlText(card.querySelector('.chapter-date, .date-chapter-title-rtl, time'));
      if (chapterDate.isNotEmpty) entry['latest_chapter_date'] = chapterDate;
      results.add(entry);
    }
    return results;
  }

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final slug = _slugFromUrl(url);
    if (slug.isEmpty) throw Exception('Manga Online: رابط المانجا غير صالح.');
    final seriesUrl = '$_site/manga/${Uri.encodeComponent(slug)}';
    final document = await _document(seriesUrl);
    final title = mangaHtmlText(document.querySelector('.panel-heading'));
    if (title.isEmpty) throw Exception('Manga Online: لم يتم العثور على تفاصيل المانجا.');

    final genres = <String>[];
    var author = '';
    var artist = '';
    var status = '';
    var type = '';
    for (final field in document.querySelectorAll('.panel-body h3')) {
      final label = _ownText(field).toLowerCase();
      final value = field.querySelector('.text');
      if (value == null) continue;
      if (label.contains('التصنيف')) {
        genres.addAll(value.querySelectorAll('a').map(mangaHtmlText));
        if (genres.isEmpty && mangaHtmlText(value).isNotEmpty) genres.add(mangaHtmlText(value));
      } else if (label.contains('المؤلف')) {
        author = mangaHtmlText(value);
      } else if (label.contains('الرسام')) {
        artist = mangaHtmlText(value);
      } else if (label.contains('الحالة')) {
        status = mangaHtmlText(value);
      } else if (label.contains('النوع') || label.contains('type')) {
        type = mangaHtmlText(value);
      }
    }
    final image = mangaImageUrl(
      document.querySelector('.row img.img-responsive, .panel-body img, .manga-image img, .right-image img'),
      _site,
    );
    final description = mangaHtmlText(document.querySelector(
          '.row .well p, .manga-summary, .description, #description, .entry-content, .panel-body p',
        ));
    final chapters = _chapters(document, slug);
    final rating = SourceValues.rating({
      'rating': document.querySelector('[itemprop=ratingValue]')?.attributes['content'] ??
          document.querySelector('[data-rating]')?.attributes['data-rating'] ??
          mangaHtmlText(document.querySelector('.rating, .rate, .rating-value, #rating')),
    });
    return _seriesItem(title, slug, image, type: type)
      ..addAll({
        if (rating.isNotEmpty) 'rating': rating,
        'description': description,
        'synopsis': description,
        'genres': genres.where((entry) => entry.isNotEmpty).toSet().toList(),
        'author': author,
        'artist': artist,
        'status': status,
        'total_chapters': chapters.length,
        'latest_chapter_number': chapters.isEmpty ? 0 : chapters.first['number'],
        'chapters': chapters,
      });
  }

  @override
  Future<Map<String, dynamic>?> streams(String url) async => null;

  @override
  Future<Map<String, dynamic>?> chapterImages(String url) async {
    final parts = _chapterParts(url);
    if (parts == null) return null;
    final chapterUrl = '$_site/manga/${Uri.encodeComponent(parts.$1)}/${Uri.encodeComponent(parts.$2)}';
    final document = await _document(chapterUrl);
    final pages = document.querySelectorAll('#all > img.img-responsive').map((image) {
      final raw = (image.attributes['data-background-image'] ??
              image.attributes['data-cfsrc'] ??
              image.attributes['data-lazy-src'] ??
              image.attributes['data-src'] ??
              image.attributes['src'] ??
              '')
          .trim();
      return mangaAbsoluteUrl(_site, raw);
    }).where((value) => value.isNotEmpty).toList(growable: false);
    if (pages.isEmpty) throw Exception('Manga Online: لا توجد صور متاحة لهذا الفصل.');
    return {
      'title': 'الفصل ${parts.$2}',
      'chapter_number': mangaChapterNumber(parts.$2) ?? parts.$2,
      'pages': pages,
      'images': pages.map((image) => {'url': image}).toList(),
      'url': chapterUrl,
    };
  }

  List<Map<String, dynamic>> _chapters(Document document, String seriesSlug) {
    final chapters = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final row in document.querySelectorAll('ul.chapters > li:not(.btn)')) {
      final anchor = row.querySelector('h5.chapter-title-rtl a');
      if (anchor == null) continue;
      final chapterUrl = mangaAbsoluteUrl(_site, anchor.attributes['href']);
      final uri = Uri.tryParse(chapterUrl);
      if (uri == null ||
          !handles(chapterUrl) ||
          uri.pathSegments.length < 3 ||
          uri.pathSegments[0] != 'manga' || uri.pathSegments[1] != seriesSlug ||
          !seen.add(uri.path)) {
        continue;
      }
      final title = mangaHtmlText(anchor);
      final number = mangaChapterNumber(title) ?? mangaChapterNumber(uri.pathSegments.last) ??
          (chapters.length + 1);
      final date = mangaHtmlText(row.querySelector('.date-chapter-title-rtl, .chapter-date, time'));
      chapters.add({
        'title': title.isEmpty ? 'الفصل $number' : title,
        'number': number,
        'chapter_number': number,
        'release_date': date,
        'date': date,
        'url': 'onma://chapter?series=${Uri.encodeQueryComponent(seriesSlug)}'
            '&chapter=${Uri.encodeQueryComponent(uri.pathSegments.last)}',
      });
    }
    return chapters;
  }

  Future<Document> _document(String url) async {
    final response = await _request(url, accept: 'text/html,application/xhtml+xml');
    return html_parser.parse(utf8.decode(response.bodyBytes, allowMalformed: true));
  }

  Future<http.Response> _request(String url, {required String accept}) async {
    final response = await _client.get(Uri.parse(url), headers: {
      'Accept': accept,
      'Accept-Language': 'ar,en;q=0.8',
      'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/131 Mobile Safari/537.36',
    }).timeout(const Duration(seconds: 25));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Manga Online: فشل طلب المصدر (${response.statusCode}).');
    }
    return response;
  }

  Map<String, dynamic> _seriesItem(
    String title,
    String slug,
    String image, {
    String type = 'manga',
  }) => item(
        title: title,
        url: 'onma://series?slug=${Uri.encodeQueryComponent(slug)}',
        image: image,
        type: SourceValues.type(type),
      );

  String _slugFromUrl(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null) return '';
    if (uri.scheme == 'onma') return uri.queryParameters['slug'] ?? '';
    final parts = uri.pathSegments.where((part) => part.isNotEmpty).toList();
    if (parts.length >= 2 && parts.first == 'manga') return parts[1];
    return '';
  }

  (String, String)? _chapterParts(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    if (uri.scheme == 'onma' && uri.host == 'chapter') {
      final series = uri.queryParameters['series'] ?? '';
      final chapter = uri.queryParameters['chapter'] ?? '';
      return series.isEmpty || chapter.isEmpty ? null : (series, chapter);
    }
    final parts = uri.pathSegments.where((part) => part.isNotEmpty).toList();
    if (parts.length >= 3 && parts[0] == 'manga') return (parts[1], parts[2]);
    return null;
  }

  String _ownText(Element element) => element.nodes
      .whereType<Text>()
      .map((node) => node.data)
      .join(' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s*[:：]\s*$'), '');
}
