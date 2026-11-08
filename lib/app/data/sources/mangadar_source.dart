import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import 'manga_html_utils.dart';
import 'source_base.dart';
import 'source_values.dart';

/// Read-only HTML adapter for the MangaDar Arabic manga catalog.
class MangaDarSource extends ContentSource {
  MangaDarSource({http.Client? client}) : _client = client ?? http.Client();

  static const String _site = 'https://mangadar.com';
  static const Map<String, String> _pageHeaders = {
    'Accept': 'text/html,application/xhtml+xml',
    'Accept-Language': 'ar,en;q=0.8',
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/131 Mobile Safari/537.36',
  };
  static const Map<String, String> imageHeaders = {
    'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
    'Referer': 'https://mangadar.com/',
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/131 Mobile Safari/537.36',
  };

  final http.Client _client;

  @override
  String get id => 'mangadar';

  @override
  String get name => 'MangaDar';

  @override
  String get kind => 'manga';

  @override
  List<String> get hosts => const ['mangadar.com'];

  @override
  bool handles(String url) =>
      url.startsWith('mangadar://') || super.handles(url);

  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return const [];
    final uri = Uri.parse(_site).replace(
      queryParameters: {'s': normalized},
    );
    final document = await _document(uri.toString());
    return _cards(document);
  }

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) =>
      _catalog(page < 1 ? 1 : page);

  @override
  Future<List<Map<String, dynamic>>> catalog({int page = 1}) =>
      _catalog(page < 1 ? 1 : page);

  @override
  Future<List<Map<String, dynamic>>> nextPage({
    String query = '',
    int page = 2,
  }) =>
      query.trim().isEmpty ? _catalog(page) : search(query);

  Future<List<Map<String, dynamic>>> _catalog(int page) async {
    final path = page <= 1 ? '/manga/' : '/manga/page/$page/';
    final document = await _document('$_site$path');
    return _cards(document);
  }

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final slug = _slugFromUrl(url);
    if (slug.isEmpty) throw Exception('MangaDar: رابط المانجا غير صالح.');

    final seriesUrl = '$_site/manga/${Uri.encodeComponent(slug)}/';
    final document = await _document(seriesUrl);
    final title = mangaHtmlText(document.querySelector('h1'));
    if (title.isEmpty) {
      throw Exception('MangaDar: لم يتم العثور على تفاصيل المانجا.');
    }

    final subtitle = mangaHtmlText(document.querySelector('h1 + p'));
    final cover = _cover(document, title);
    final info = _infoFields(document);
    final description = mangaHtmlText(
      document.querySelector('[x-ref="synContent"]') ??
          document.querySelector('.text-neutral-300'),
    );
    final genres = document
        .querySelectorAll('a[href*="/genre/"]')
        .map(mangaHtmlText)
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final chapters = await _chapters(document, slug);
    final rating = _rating(document);
    final type = info['النوع'] ?? _typeFromPage(document);
    final status = info['الحالة'] ?? '';
    final author = info['المؤلف'] ?? '';
    final artist = info['الرسام'] ?? '';
    final published = info['منشور'] ?? '';
    final releaseYear =
        RegExp(r'\b(19|20)\d{2}\b').firstMatch(published)?.group(0) ?? '';

    return item(
      title: title,
      url: seriesUrl,
      image: cover,
      type: SourceValues.type(type),
      genres: genres,
      description: description,
      rating: rating,
    )..addAll({
        'native_title': subtitle,
        'synopsis': description,
        'author': author,
        'artist': artist,
        'status': status,
        'release_year': releaseYear,
        'published': published,
        'total_chapters': chapters.length,
        'latest_chapter_number':
            chapters.isEmpty ? '' : chapters.first['number'] ?? '',
        'latest_chapter_date':
            chapters.isEmpty ? '' : chapters.first['release_date'] ?? '',
        'chapters': chapters,
      });
  }

  @override
  Future<Map<String, dynamic>?> streams(String url) async => null;

  @override
  Future<Map<String, dynamic>?> chapterImages(String url) async {
    final parts = _chapterParts(url);
    if (parts == null) return null;

    final chapterUrl = '$_site/manga/${Uri.encodeComponent(parts.$1)}/'
        '${Uri.encodeComponent(parts.$2)}/';
    final document = await _document(chapterUrl);
    final pages = <String>[];
    for (final image
        in document.querySelectorAll('img[data-mds], img.h-page-img')) {
      final encoded = image.attributes['data-mds']?.trim();
      var pageUrl = '';
      if (encoded != null && encoded.isNotEmpty) {
        try {
          pageUrl = utf8.decode(base64.decode(encoded));
        } on FormatException {
          // Fall back to the current src when the token is malformed.
        }
      }
      if (pageUrl.isEmpty) {
        pageUrl = mangaAbsoluteUrl(_site, image.attributes['src']);
      }
      if (pageUrl.isNotEmpty && !pages.contains(pageUrl)) pages.add(pageUrl);
    }
    if (pages.isEmpty) {
      throw Exception('MangaDar: لا توجد صور متاحة لهذا الفصل.');
    }
    return {
      'title': 'الفصل ${parts.$2}',
      'chapter_number': mangaChapterNumber(parts.$2) ?? parts.$2,
      'pages': pages,
      'images': pages.map((image) => {'url': image}).toList(growable: false),
      'url': chapterUrl,
    };
  }

  List<Map<String, dynamic>> _cards(Document document) {
    final results = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final anchor in document.querySelectorAll('a.group.block')) {
      final href = mangaAbsoluteUrl(_site, anchor.attributes['href']);
      final slug = _slugFromUrl(href);
      if (slug.isEmpty || !seen.add(slug)) continue;
      final title = mangaHtmlText(anchor.querySelector('h3'));
      if (title.isEmpty) continue;
      final image = mangaImageUrl(anchor.querySelector('img'), _site);
      final text = mangaHtmlText(anchor);
      final rating = SourceValues.rating(text);
      final type = mangaHtmlText(anchor.querySelector('div.absolute span'));
      final status = mangaHtmlText(anchor.querySelector(
        'span.text-emerald-400, span.text-amber-400, span.text-red-400',
      ));
      final chapters = mangaChapterNumber(
        mangaHtmlText(anchor.querySelector('span[title="إجمالي الفصول"]')),
      );
      final entry = item(
        title: title,
        url: href,
        image: image,
        type: SourceValues.type(type),
        rating: rating,
      );
      entry.addAll({
        if (status.isNotEmpty) 'status': status,
        if (chapters != null) 'total_chapters': chapters,
      });
      results.add(entry);
    }
    return results;
  }

  Future<List<Map<String, dynamic>>> _chapters(
    Document document,
    String slug,
  ) async {
    try {
      final chapters = await _chaptersFromApi(document, slug);
      if (chapters.isNotEmpty) return chapters;
    } catch (_) {
      // Keep chapter details available if MangaDar's REST API is unavailable.
    }
    return _chaptersFromHtml(document, slug);
  }

  Future<List<Map<String, dynamic>>> _chaptersFromApi(
    Document document,
    String slug,
  ) async {
    final bodyClass = document.body?.attributes['class'] ?? '';
    final postId = RegExp(r'\bpostid-(\d+)\b').firstMatch(bodyClass)?.group(1);
    if (postId == null) return const [];
    final endpoint = Uri.parse(
      '$_site/wp-json/mangadar/v1/manga/$postId/chapters',
    );
    final apiHeaders = {
      ..._pageHeaders,
      'Accept': 'application/json',
    };
    Future<Map<String, dynamic>> fetchPage(int page) async {
      final uri = page <= 1
          ? endpoint
          : endpoint.replace(queryParameters: {'page': '$page'});
      final response = await _client.get(uri, headers: apiHeaders).timeout(
            const Duration(seconds: 25),
          );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('MangaDar chapters API: HTTP ${response.statusCode}.');
      }
      final decoded = jsonDecode(
        utf8.decode(response.bodyBytes, allowMalformed: true),
      );
      if (decoded is! Map) return const {};
      return Map<String, dynamic>.from(decoded);
    }

    final firstPage = await fetchPage(1);
    final results = <Map<String, dynamic>>[];
    void addRecords(dynamic value) {
      if (value is! List) return;
      for (final raw in value.whereType<Map>()) {
        final record = Map<String, dynamic>.from(raw);
        final url = mangaAbsoluteUrl(_site, '${record['url'] ?? ''}');
        final parts = _chapterParts(url);
        if (parts == null || parts.$1 != slug) continue;
        final numberText = '${record['number'] ?? ''}'.trim();
        final title = '${record['title'] ?? ''}'.trim();
        final number =
            mangaChapterNumber(numberText.isEmpty ? title : numberText);
        final date = mangaDateFromUnixSeconds(
          '${record['date'] ?? record['created_at'] ?? ''}',
        );
        results.add({
          if (record['id'] != null) 'id': record['id'],
          'title': title.isEmpty
              ? (number == null ? 'فصل' : 'الفصل $number')
              : title,
          'number': number,
          'chapter_number': number ?? numberText,
          'release_date': date,
          'date': date,
          'url': url,
        });
      }
    }

    addRecords(firstPage['items']);
    final totalPages = int.tryParse('${firstPage['total_pages'] ?? 1}') ?? 1;
    for (var page = 2; page <= totalPages; page++) {
      final nextPage = await fetchPage(page);
      addRecords(nextPage['items']);
    }
    final seen = <String>{};
    final unique =
        results.where((chapter) => seen.add('${chapter['url']}')).toList();
    unique.sort((a, b) => (mangaChapterNumber('${b['number']}') ?? 0)
        .compareTo(mangaChapterNumber('${a['number']}') ?? 0));
    return unique;
  }

  List<Map<String, dynamic>> _chaptersFromHtml(
    Document document,
    String slug,
  ) {
    final results = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final anchor in document.querySelectorAll('a[href*="/manga/"]')) {
      final href = mangaAbsoluteUrl(_site, anchor.attributes['href']);
      final parts = _chapterParts(href);
      if (parts == null || parts.$1 != slug || !seen.add(parts.$2)) continue;
      final title = mangaHtmlText(anchor);
      final number = mangaChapterNumber(title) ?? mangaChapterNumber(parts.$2);
      final rowText = mangaHtmlText(anchor.parent);
      final date = _dateFromText(rowText);
      results.add({
        'title':
            title.isEmpty ? (number == null ? 'فصل' : 'الفصل $number') : title,
        'number': number,
        'chapter_number': number,
        'release_date': date,
        'date': date,
        'url': href,
      });
    }
    // MangaDar keeps the complete chapter list in an Alpine x-data `rows`
    // attribute and only turns it into <a> elements in the browser. A plain
    // HTTP client therefore sees only the first/last navigation links.
    final chapterUrlPattern = RegExp(
      r'https?://mangadar\.com/manga/([^/"\s]+)/([^/"\s]+)/',
    );
    for (final node in document.querySelectorAll('[x-data]')) {
      final data = node.attributes.values.join(' ');
      for (final match in chapterUrlPattern.allMatches(data)) {
        if (match.group(1) != slug) continue;
        final chapter = match.group(2)!;
        final href = match.group(0)!;
        if (!seen.add(chapter)) continue;
        final number = mangaChapterNumber(chapter);
        results.add({
          'title': 'الفصل $chapter',
          'number': number ?? 0,
          'chapter_number': number ?? chapter,
          'release_date': '',
          'date': '',
          'url': href,
        });
      }
    }
    results.sort((a, b) => (mangaChapterNumber('${b['number']}') ?? 0)
        .compareTo(mangaChapterNumber('${a['number']}') ?? 0));
    return results;
  }

  Map<String, String> _infoFields(Document document) {
    final fields = <String, String>{};
    for (final row in document.querySelectorAll(
      'div.flex.items-center.justify-between',
    )) {
      if (row.children.length < 2) continue;
      final label = mangaHtmlText(row.children.first);
      final value = mangaHtmlText(row.children.last);
      if (label.isNotEmpty && value.isNotEmpty) fields[label] = value;
    }
    return fields;
  }

  String _cover(Document document, String title) {
    for (final image in document.querySelectorAll('img')) {
      if (image.attributes['alt']?.trim() == title) {
        final url = mangaImageUrl(image, _site);
        if (url.isNotEmpty) return url;
      }
    }
    final ogImage = document
        .querySelector('meta[property="og:image"]')
        ?.attributes['content'];
    return mangaAbsoluteUrl(_site, ogImage);
  }

  String _rating(Document document) {
    for (final node in document.querySelectorAll('span')) {
      final classes = node.attributes['class'] ?? '';
      if (classes.contains('tabular-nums')) {
        final value = SourceValues.rating(mangaHtmlText(node));
        if (value.isNotEmpty) return value;
      }
    }
    return '';
  }

  String _typeFromPage(Document document) {
    for (final span in document.querySelectorAll('span')) {
      if ((span.attributes['class'] ?? '').contains('bg-violet-500/15')) {
        final value = mangaHtmlText(span);
        if (value.isNotEmpty) return value;
      }
    }
    return '';
  }

  Future<Document> _document(String url) async {
    final response =
        await _client.get(Uri.parse(url), headers: _pageHeaders).timeout(
              const Duration(seconds: 25),
            );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('MangaDar: فشل طلب المصدر (${response.statusCode}).');
    }
    return html_parser.parse(
      utf8.decode(response.bodyBytes, allowMalformed: true),
    );
  }

  String _slugFromUrl(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null) return '';
    if (uri.scheme == 'mangadar') {
      return uri.queryParameters['slug'] ??
          (uri.pathSegments.isEmpty ? '' : uri.pathSegments.last);
    }
    final parts = uri.pathSegments.where((part) => part.isNotEmpty).toList();
    if (parts.length >= 2 && parts.first == 'manga') return parts[1];
    return '';
  }

  (String, String)? _chapterParts(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    if (uri.scheme == 'mangadar') {
      final series = uri.queryParameters['series'] ?? '';
      final chapter = uri.queryParameters['chapter'] ?? '';
      return series.isEmpty || chapter.isEmpty ? null : (series, chapter);
    }
    final parts = uri.pathSegments.where((part) => part.isNotEmpty).toList();
    if (parts.length >= 3 && parts[0] == 'manga') {
      return (parts[1], parts[2]);
    }
    return null;
  }

  String _dateFromText(String value) {
    final match = RegExp(
      r'\b(19|20)\d{2}[-/]\d{1,2}[-/]\d{1,2}\b',
    ).firstMatch(value);
    final raw = match?.group(0) ?? '';
    return raw.isEmpty ? '' : mangaDateFromUnixSeconds(raw);
  }
}
