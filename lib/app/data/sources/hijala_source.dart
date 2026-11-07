import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import 'manga_html_utils.dart';
import 'source_base.dart';
import 'source_values.dart';

/// Read-only HTML adapter for Hijala's Arabic manga catalogue and reader.
class HijalaSource extends ContentSource {
  HijalaSource({http.Client? client}) : _client = client ?? http.Client();

  static const String _site = 'https://hijala.com';
  static const Map<String, String> _headers = {
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
    'Accept-Language': 'ar,en;q=0.8',
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/131 Mobile Safari/537.36',
    'Referer': 'https://hijala.com/',
  };

  final http.Client _client;
  final Map<String, Map<String, dynamic>> _chapterContexts = {};

  @override
  String get id => 'hijala';

  @override
  String get name => 'Hijala';

  @override
  String get kind => 'manga';

  @override
  List<String> get hosts => const ['hijala.com'];

  @override
  Future<List<Map<String, dynamic>>> search(String query) {
    final normalized = query.trim();
    if (normalized.isEmpty) return Future.value(const []);
    return _list(page: 1, query: normalized);
  }

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) =>
      _list(page: page);

  @override
  Future<List<Map<String, dynamic>>> catalog({int page = 1}) =>
      _list(page: page);

  @override
  Future<List<Map<String, dynamic>>> nextPage({String query = '', int page = 2}) =>
      _list(page: page, query: query);

  Future<List<Map<String, dynamic>>> _list({
    required int page,
    String query = '',
  }) async {
    final safePage = page < 1 ? 1 : page;
    final uri = Uri.parse(_site).replace(
      path: safePage == 1 ? '/manga/' : '/manga/page/$safePage/',
      queryParameters: query.trim().isEmpty ? null : {'s': query.trim()},
    );
    return _cards(await _document(uri.toString()));
  }

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final seriesUrl = _seriesUrl(url);
    if (seriesUrl.isEmpty) {
      throw Exception('Hijala: رابط العمل غير صالح.');
    }

    final document = await _document(seriesUrl);
    final title = mangaHtmlText(document.querySelector('h1.entry-title, h1'));
    if (title.isEmpty) {
      throw Exception('Hijala: لم يتم العثور على تفاصيل العمل.');
    }

    final cover = _secureImageUrl(
      mangaImageUrl(document.querySelector('.info-left-margin .thumb img'), _site),
    );
    final synopsis = mangaHtmlText(
      document.querySelector('.info-right .entry-content, .entry-content-single'),
    );
    final genres = document
        .querySelectorAll('.info-desc .mgen a, .mgen a')
        .map(mangaHtmlText)
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final chapters = _chapters(document);
    final published = _infoValue(document, const ['نشر بتاريخ', 'تاريخ النشر']);
    final updated = _infoValue(document, const ['أخر تحديث', 'آخر تحديث']);
    final status = _infoValue(document, const ['الحالة']);
    final type = _infoValue(document, const ['النوع']);
    final ratingElement = document.querySelector(
      '.rating-prc [itemprop="ratingValue"], .rating [itemprop="ratingValue"], .rating .num',
    );
    final rating = SourceValues.rating(
      ratingElement?.attributes['content'] ?? mangaHtmlText(ratingElement),
    );
    final releaseYear = RegExp(r'\b(?:19|20)\d{2}\b')
            .firstMatch(published)
            ?.group(0) ??
        '';
    final author = _infoValue(document, const ['المؤلف', 'الكاتب']);
    final artist = _infoValue(document, const ['الرسام', 'الفنان']);

    _rememberChapterContexts(chapters);
    return item(
      title: title,
      url: seriesUrl,
      image: cover,
      type: SourceValues.type(type, fallback: kind),
      genres: genres,
      description: synopsis,
      rating: rating,
    )..addAll({
        'native_title': '',
        'synopsis': synopsis,
        'author': author,
        'artist': artist,
        'status': status,
        'release_year': releaseYear,
        'updated_on': _normalizeDate(updated),
        'published': _normalizeDate(published),
        'total_chapters': chapters.length,
        'latest_chapter_number': chapters.isEmpty ? '' : chapters.first['number'],
        'chapters': chapters,
      });
  }

  @override
  Future<Map<String, dynamic>?> streams(String url) async => null;

  @override
  Future<Map<String, dynamic>?> chapterImages(String url) async {
    final chapterUrl = _canonicalUrl(url);
    if (chapterUrl.isEmpty) return null;

    final document = await _document(chapterUrl);
    final seen = <String>{};
    final pages = <String>[];
    final readerImages = document.querySelectorAll(
      '#readerarea img[src], #readerarea img[data-src], '
      '#readerarea img[data-lazy-src], .readercontent #readerarea img, '
      '.readercontent img[src], .readercontent img[data-src], '
      '.reading-content img[src], .reading-content img[data-src], '
      '.wp-manga-chapter-img img[src], .page-break img[src]',
    );
    for (final image in readerImages) {
      final pageUrl = _secureImageUrl(mangaImageUrl(image, _site));
      if (pageUrl.isEmpty ||
          pageUrl.contains('/readerarea.svg') ||
          pageUrl.contains('/hijala.png') ||
          pageUrl.contains('/logo') ||
          !seen.add(pageUrl)) {
        continue;
      }
      pages.add(pageUrl);
    }
    if (pages.isEmpty) {
      throw Exception('Hijala: لا توجد صور متاحة لهذا الفصل.');
    }
    // The official Keiyoushi extension stitches every two half-images when
    // this marker is present. Hijala currently uses that anti-scraping reader.
    if (document.querySelector('#chapter-pages-js-before') != null) {
      final paired = <String>[];
      for (var i = 0; i + 1 < pages.length; i += 2) {
        paired.add(_pairUrl(pages[i], pages[i + 1]));
      }
      if (paired.isNotEmpty) {
        pages
          ..clear()
          ..addAll(paired);
      }
    }

    final context = _chapterContexts[chapterUrl];
    final number = '${context?['number'] ?? _chapterNumberFromUrl(chapterUrl)}';
    final heading = mangaHtmlText(
      document.querySelector('.readercontent h1, .chapterbody h1, h1.entry-title, h1'),
    );
    final chapterList = context?['chapters'] as List<Map<String, dynamic>>?;
    final previous = context?['previous_chapter']?.toString();
    final next = context?['next_chapter']?.toString();
    return {
      'title': heading.isEmpty ? 'الفصل $number' : heading,
      'chapter_number': number,
      'pages': pages,
      'images': pages.map((page) => {'url': page}).toList(growable: false),
      'url': chapterUrl,
      if (previous != null && previous.isNotEmpty) 'previous_chapter': previous,
      if (next != null && next.isNotEmpty) 'next_chapter': next,
      if (chapterList != null) 'chapters': chapterList,
    };
  }

  Future<Document> _document(String url) async {
    final response = await _client
        .get(Uri.parse(url), headers: _headers)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Hijala: فشل تحميل الصفحة (${response.statusCode}).');
    }
    return html_parser.parse(
      utf8.decode(response.bodyBytes, allowMalformed: true),
    );
  }

  List<Map<String, dynamic>> _cards(Document document) {
    final results = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final card in document.querySelectorAll('.listupd .bs, .bs')) {
      final anchor = card.querySelector('.bsx a[href], a[href]');
      if (anchor == null) continue;
      final url = _seriesUrl(mangaAbsoluteUrl(_site, anchor.attributes['href']));
      if (url.isEmpty || !seen.add(url)) continue;

      final imageElement = card.querySelector('.limit img, img');
      final title = mangaHtmlText(card.querySelector('.tt, .tt a, h3'))
          .ifEmpty(anchor.attributes['title'] ?? '')
          .ifEmpty(imageElement?.attributes['alt'] ?? '');
      if (title.isEmpty) continue;

      final image = _secureImageUrl(mangaImageUrl(imageElement, _site));
      final type = mangaHtmlText(card.querySelector('.type, .typez'));
      final rating = SourceValues.rating(
        card.querySelector('.num')?.attributes['content'] ??
            mangaHtmlText(card.querySelector('.num, [data-rating]')),
      );
      final entry = item(
        title: title,
        url: url,
        image: image,
        type: SourceValues.type(type, fallback: kind),
        rating: rating,
      );
      final chapterText = mangaHtmlText(
        card.querySelector('.adds, .epxs, .chapter'),
      );
      final chapterNumber = mangaChapterNumber(chapterText);
      if (chapterNumber != null) entry['latest_chapter_number'] = chapterNumber;
      final status = mangaHtmlText(card.querySelector('.status'));
      if (status.isNotEmpty) entry['status'] = status;
      results.add(entry);
    }
    return results;
  }

  List<Map<String, dynamic>> _chapters(Document document) {
    final items = <Map<String, dynamic>>[];
    final seen = <String>{};
    final rows = document.querySelectorAll('#chapterlist li').isNotEmpty
        ? document.querySelectorAll('#chapterlist li')
        : document.querySelectorAll('.eplister li');
    for (final row in rows) {
      final anchor = row.querySelector('.eph-num a[href], a[href]');
      if (anchor == null) continue;
      final chapterUrl = _canonicalUrl(anchor.attributes['href'] ?? '');
      if (chapterUrl.isEmpty || !seen.add(chapterUrl)) continue;

      final title = mangaHtmlText(
        anchor.querySelector('.chapternum'),
      ).ifEmpty(mangaHtmlText(anchor));
      if (title.isEmpty) continue;
      final number = row.attributes['data-num']
              ?.trim()
              .ifEmpty(_numberFromText(title)) ??
          _numberFromText(title);
      final date = mangaHtmlText(anchor.querySelector('.chapterdate'));
      items.add({
        'title': title,
        'url': chapterUrl,
        'number': number,
        if (date.isNotEmpty) 'release_date': _normalizeDate(date),
      });
    }
    return items;
  }

  void _rememberChapterContexts(List<Map<String, dynamic>> chapters) {
    final fullList = chapters
        .map((chapter) => Map<String, dynamic>.from(chapter))
        .toList(growable: false);
    for (var i = 0; i < fullList.length; i++) {
      final chapterUrl = '${fullList[i]['url'] ?? ''}';
      if (chapterUrl.isEmpty) continue;
      _chapterContexts[chapterUrl] = {
        'number': fullList[i]['number'],
        'chapters': fullList,
        if (i > 0) 'next_chapter': fullList[i - 1]['url'],
        if (i + 1 < fullList.length) 'previous_chapter': fullList[i + 1]['url'],
      };
    }
    if (_chapterContexts.length > 5000) {
      final excess = _chapterContexts.length - 3000;
      for (final key in _chapterContexts.keys.take(excess).toList()) {
        _chapterContexts.remove(key);
      }
    }
  }

  String _infoValue(Document document, List<String> labels) {
    for (final element in document.querySelectorAll('.tsinfo .imptdt')) {
      final text = mangaHtmlText(element);
      for (final label in labels) {
        if (!text.startsWith(label)) continue;
        return text.substring(label.length).trim().replaceFirst(RegExp(r'^[:：\s]+'), '');
      }
    }
    return '';
  }

  String _seriesUrl(String rawUrl) {
    final canonical = _canonicalUrl(rawUrl);
    if (canonical.isEmpty) return '';
    final uri = Uri.tryParse(canonical);
    if (uri == null || uri.pathSegments.isEmpty) return '';
    final slug = uri.pathSegments.first.trim();
    if (slug.isEmpty || slug.toLowerCase() == 'page') return '';
    return Uri.https('hijala.com', '/$slug/').toString();
  }

  String _canonicalUrl(String rawUrl) {
    final absolute = mangaAbsoluteUrl(_site, rawUrl);
    if (absolute.isEmpty) return '';
    final uri = Uri.tryParse(absolute);
    final host = uri?.host.toLowerCase().replaceFirst('www.', '') ?? '';
    if (uri == null || (host != 'hijala.com' && !host.endsWith('.hijala.com'))) {
      return '';
    }
    return uri.replace(scheme: 'https', host: 'hijala.com').toString().split('#').first;
  }

  String _secureImageUrl(String rawUrl) {
    final absolute = mangaAbsoluteUrl(_site, rawUrl);
    if (absolute.isEmpty) return '';
    final uri = Uri.tryParse(absolute);
    final host = uri?.host.toLowerCase().replaceFirst('www.', '') ?? '';
    if (uri == null) return '';
    if (host == 'hijala.com' || host.endsWith('.hijala.com')) {
      return uri.replace(scheme: 'https', host: 'hijala.com').toString();
    }
    return absolute;
  }

  String _pairUrl(String left, String right) {
    final query = Uri(queryParameters: {
      'leftImage': left,
      'rightImage': right,
    }).query;
    return 'hijala-pair://page?$query';
  }

  String _numberFromText(String text) {
    final match = RegExp(r'\d+(?:\.\d+)?(?:-\d+)?').firstMatch(text);
    return match?.group(0) ?? '';
  }

  String _chapterNumberFromUrl(String url) {
    final path = Uri.tryParse(url)?.pathSegments;
    if (path == null || path.isEmpty) return '';
    final match = RegExp(r'-(\d+(?:\.\d+)?(?:-\d+)?)$').firstMatch(path.last);
    return match?.group(1) ?? '';
  }

  String _normalizeDate(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    final direct = DateTime.tryParse(value);
    if (direct != null) return direct.toUtc().toIso8601String();

    const months = <String, int>{
      'january': 1, 'يناير': 1,
      'february': 2, 'فبراير': 2,
      'march': 3, 'مارس': 3,
      'april': 4, 'أبريل': 4, 'ابريل': 4,
      'may': 5, 'مايو': 5,
      'june': 6, 'يونيو': 6,
      'july': 7, 'يوليو': 7,
      'august': 8, 'أغسطس': 8, 'اغسطس': 8,
      'september': 9, 'سبتمبر': 9,
      'october': 10, 'أكتوبر': 10, 'اكتوبر': 10,
      'november': 11, 'نوفمبر': 11,
      'december': 12, 'ديسمبر': 12,
    };
    final monthFirst = RegExp(r'^([^\d\s]+)\s+(\d{1,2}),?\s+(\d{4})$').firstMatch(value);
    final dayFirst = RegExp(r'^(\d{1,2})\s+([^\d\s]+)\s+(\d{4})$').firstMatch(value);
    final monthName = (monthFirst?.group(1) ?? dayFirst?.group(2) ?? '').toLowerCase();
    final month = months[monthName];
    final day = int.tryParse(monthFirst?.group(2) ?? dayFirst?.group(1) ?? '');
    final year = int.tryParse(monthFirst?.group(3) ?? dayFirst?.group(3) ?? '');
    if (month == null || day == null || year == null) return value;
    try {
      return DateTime.utc(year, month, day).toIso8601String();
    } on ArgumentError {
      return value;
    }
  }
}

extension on String {
  String ifEmpty(String fallback) => trim().isEmpty ? fallback : this;
}
