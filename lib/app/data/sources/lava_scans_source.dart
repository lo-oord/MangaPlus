import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import 'manga_html_utils.dart';
import 'source_base.dart';

/// Read-only adapter for the Arabic Lava Scans manga source.
class LavaScansSource extends ContentSource {
  static const String _site = 'https://lavascans.com';
  static final http.Client _client = http.Client();

  @override
  String get id => 'lava_scans';
  @override
  String get name => 'Lava Scans';
  @override
  String get kind => 'manga';
  @override
  List<String> get hosts => const ['lavascans.com'];
  @override
  bool handles(String url) => url.startsWith('lava://') || super.handles(url);

  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return const [];
    return _parseSeriesList(await _document(_searchUri(normalized, 1).toString()));
  }

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) =>
      catalog(page: page);

  @override
  Future<List<Map<String, dynamic>>> catalog({int page = 1}) async {
    final uri = Uri.parse('$_site/manga/').replace(queryParameters: {
      'order': 'latest',
      'page': '${page < 1 ? 1 : page}',
    });
    return _parseSeriesList(await _document(uri.toString()));
  }

  @override
  Future<List<Map<String, dynamic>>> nextPage({String query = '', int page = 2}) =>
      query.trim().isEmpty ? catalog(page: page) : search(query);

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final seriesUrl = _seriesUrl(url);
    if (seriesUrl.isEmpty) throw Exception('Lava Scans: رابط المانجا غير صالح.');
    final document = await _document(seriesUrl);
    final title = mangaHtmlText(document.querySelector('.lh-title, .single-manga h1, h1.entry-title'));
    if (title.isEmpty) throw Exception('Lava Scans: لم يتم العثور على تفاصيل المانجا.');
    final description = mangaHtmlText(document.querySelector(
          '.lh-description, .lh-summary, .summary__content, .description-summary, .entry-content',
        ));
    final genres = document.querySelectorAll('.lh-genres a, .genres-content a')
        .map(mangaHtmlText).where((value) => value.isNotEmpty).toList();
    final image = mangaImageUrl(document.querySelector('.lh-cover img, .summary_image img, .poster img'), _site);
    final status = mangaHtmlText(document.querySelector('.lh-meta-item.status-badge-lux, .post-status'));
    final chapters = _chapters(document, seriesUrl);
    final result = item(
      title: title,
      url: _internalSeries(seriesUrl),
      image: image,
      type: 'manga',
      genres: genres,
      description: description,
      rating: _rating(document),
    )..addAll({
        'synopsis': description,
        'status': status,
        'total_chapters': chapters.length,
        'chapters': chapters,
      });
    return result;
  }

  @override
  Future<Map<String, dynamic>?> streams(String url) async => null;

  @override
  Future<Map<String, dynamic>?> chapterImages(String url) async {
    final chapterUrl = _chapterUrl(url);
    if (chapterUrl.isEmpty) return null;
    final document = await _document(chapterUrl);
    List<String> pages = const [];
    for (final script in document.querySelectorAll('script')) {
      var source = script.text.trim();
      final src = (script.attributes['src'] ?? '').trim();
      const prefix = 'data:text/javascript;base64,';
      if (src.startsWith(prefix)) {
        try {
          source = utf8.decode(base64.decode(src.substring(prefix.length)), allowMalformed: true);
        } catch (_) {
          continue;
        }
      }
      final payload = _tsReaderPayload(source);
      if (payload == null) continue;
      try {
        final decoded = jsonDecode(payload);
        if (decoded is! Map || decoded['sources'] is! List) continue;
        for (final sourceEntry in (decoded['sources'] as List).whereType<Map>()) {
          final rawImages = sourceEntry['images'];
          if (rawImages is! List) continue;
          pages = rawImages
              .map((entry) => entry is Map
                  ? (entry['url'] ?? entry['imageUrl'] ?? '').toString().trim()
                  : entry.toString().trim())
              .map((entry) => mangaAbsoluteUrl(_site, entry))
              .where((entry) => entry.isNotEmpty)
              .toList(growable: false);
          if (pages.isNotEmpty) break;
        }
      } catch (_) {
        continue;
      }
      if (pages.isNotEmpty) break;
    }

    if (pages.isEmpty) {
      pages = document.querySelectorAll('div#readerarea img').map((image) => mangaImageUrl(image, _site))
          .where((image) => image.isNotEmpty).toList(growable: false);
    }
    if (pages.isEmpty) {
      throw Exception('Lava Scans: لم تُوجد قائمة صور صالحة في قارئ الفصل.');
    }
    return {
      'title': mangaHtmlText(document.querySelector('.reader-chapter-badge, h1')),
      'pages': pages,
      'images': pages.map((image) => {'url': image}).toList(),
      'url': chapterUrl,
    };
  }

  List<Map<String, dynamic>> _parseSeriesList(Document document) {
    final results = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final card in document.querySelectorAll('.manga-card-v, .legend-inner')) {
      Element? anchor;
      if (card.classes.contains('manga-card-v')) {
        anchor = card.querySelector('.card-v-body h3 a, .card-v-cover a');
      } else {
        anchor = card.querySelector('.legend-title a, a.legend-poster');
      }
      final seriesUrl = _validatedUrl(anchor?.attributes['href'] ?? '', isSeries: true);
      if (seriesUrl.isEmpty || !seen.add(seriesUrl)) continue;
      final title = mangaHtmlText(card.querySelector('.card-v-title a, .legend-title a'))
          .isNotEmpty
          ? mangaHtmlText(card.querySelector('.card-v-title a, .legend-title a'))
          : (anchor?.querySelector('img')?.attributes['alt'] ?? '').trim();
      final image = mangaImageUrl(card.querySelector('.card-v-cover img, .legend-img'), _site);
      if (title.isEmpty) continue;
      final entry = _seriesItem(title, seriesUrl, image);
      final chapterAnchor = card.querySelector('.latest-chapter a, .chapter-title a, .last-chapter a, .chapter a');
      final chapterNumber = mangaChapterNumber(mangaHtmlText(chapterAnchor));
      if (chapterNumber != null) entry['latest_chapter_number'] = chapterNumber;
      final chapterHref = _validatedUrl(chapterAnchor?.attributes['href'] ?? '', isSeries: false);
      if (chapterHref.isNotEmpty) entry['latest_chapter_url'] = _internalChapter(chapterHref);
      final time = card.querySelector('time[datetime]');
      final rawDate = time?.attributes['datetime'] ??
          card.attributes['data-date'] ??
          mangaHtmlText(card.querySelector('.chapter-date, .date, time'));
      final releaseDate = mangaDateFromUnixSeconds(rawDate);
      if (releaseDate.isNotEmpty) entry['latest_chapter_date'] = releaseDate;
      results.add(entry);
    }

    // Compatibility with the legacy MangaReader cards used by some archive pages.
    if (results.isEmpty) {
      for (final card in document.querySelectorAll('.bsx')) {
        final anchor = card.querySelector('a');
        final seriesUrl = _validatedUrl(anchor?.attributes['href'] ?? '', isSeries: true);
        final title = (anchor?.attributes['title'] ?? mangaHtmlText(anchor)).trim();
        if (seriesUrl.isEmpty || title.isEmpty || !seen.add(seriesUrl)) continue;
        results.add(_seriesItem(title, seriesUrl, mangaImageUrl(card.querySelector('img'), _site)));
      }
    }
    return results;
  }

  List<Map<String, dynamic>> _chapters(Document document, String seriesUrl) {
    final series = Uri.parse(seriesUrl);
    final slug = series.pathSegments.where((part) => part.isNotEmpty).last;
    final rows = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final anchor in document.querySelectorAll('a[href*="-chapter-"]')) {
      final target = _validatedUrl(anchor.attributes['href'] ?? '', isSeries: false);
      if (target.isEmpty || !seen.add(target)) continue;
      final uri = Uri.parse(target);
      final path = uri.pathSegments.where((part) => part.isNotEmpty).join('/');
      if (!path.startsWith('$slug-chapter-')) continue;
      final label = mangaHtmlText(anchor);
      final number = mangaChapterNumber(path) ?? mangaChapterNumber(label) ?? (rows.length + 1);
      final locked = (anchor.attributes['data-coin'] ?? '').toLowerCase() == 'yes';
      if (locked) continue;
      rows.add({
        'title': label.isEmpty ? 'الفصل $number' : label,
        'number': number,
        'chapter_number': number,
        'url': _internalChapter(target),
      });
    }
    return rows;
  }

  String? _tsReaderPayload(String source) {
    final marker = source.indexOf('ts_reader.run');
    if (marker < 0) return null;
    final openParen = source.indexOf('(', marker);
    if (openParen < 0) return null;
    var start = openParen + 1;
    while (start < source.length && source[start].trim().isEmpty) {
      start++;
    }
    if (start >= source.length || source[start] != '{') return null;
    var depth = 0;
    var inString = false;
    var escaped = false;
    var quote = '';
    for (var index = start; index < source.length; index++) {
      final char = source[index];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (char.codeUnitAt(0) == 92) {
          escaped = true;
        } else if (char == quote) {
          inString = false;
        }
        continue;
      }
      if (char == '"' || char == "'") {
        inString = true;
        quote = char;
      } else if (char == '{') {
        depth++;
      } else if (char == '}') {
        depth--;
        if (depth == 0) return source.substring(start, index + 1);
      }
    }
    return null;
  }

  Future<Document> _document(String url) async {
    final response = await _client.get(Uri.parse(url), headers: const {
      'Accept': 'text/html,application/xhtml+xml',
      'Accept-Language': 'ar,en;q=0.8',
      'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/131 Mobile Safari/537.36',
    }).timeout(const Duration(seconds: 25));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Lava Scans: فشل طلب المصدر (${response.statusCode}).');
    }
    return html_parser.parse(utf8.decode(response.bodyBytes, allowMalformed: true));
  }

  Uri _searchUri(String query, int page) => Uri.parse('$_site/page/$page/').replace(
        queryParameters: {'s': query},
      );

  String _seriesUrl(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null) return '';
    if (uri.scheme == 'lava') {
      return _validatedUrl(uri.queryParameters['url'] ?? '', isSeries: true);
    }
    return _validatedUrl(raw, isSeries: true);
  }

  String _chapterUrl(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null) return '';
    if (uri.scheme == 'lava') {
      return _validatedUrl(uri.queryParameters['url'] ?? '', isSeries: false);
    }
    return _validatedUrl(raw, isSeries: false);
  }

  String _validatedUrl(String raw, {required bool isSeries}) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.scheme != 'https' ||
        !const {'lavascans.com', 'www.lavascans.com'}.contains(uri.host.toLowerCase())) {
      return '';
    }
    final path = uri.path.toLowerCase();
    if (isSeries && !path.startsWith('/manga/')) return '';
    if (!isSeries && !path.contains('-chapter-')) return '';
    return uri.replace(fragment: '').toString();
  }

  String _internalSeries(String url) =>
      'lava://series?url=${Uri.encodeQueryComponent(url)}';
  String _internalChapter(String url) =>
      'lava://chapter?url=${Uri.encodeQueryComponent(url)}';

  Map<String, dynamic> _seriesItem(String title, String url, String image) => item(
        title: title,
        url: _internalSeries(url),
        image: image,
        type: 'manga',
      );

  String _rating(Document document) {
    final parent = document.querySelector('.lh-meta-row .fa-star')?.parent;
    final text = parent is Element ? mangaHtmlText(parent) : '';
    return text.replaceAll(RegExp(r'[^\d.,]'), '').replaceAll(',', '.');
  }
}
