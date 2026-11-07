import 'dart:convert';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'manga_html_utils.dart';
import 'source_base.dart';
import 'source_values.dart';

/// HTML adapter for the Arabic Mangasid catalogue and reader.
class MangaSidSource extends ContentSource {
  MangaSidSource({http.Client? client}) : _client = client ?? http.Client();

  static const String _site = 'https://mangasid.com';
  static const String _imageHost = 'https://api.mangasid.com';
  final http.Client _client;

  @override
  String get id => 'mangasid';

  @override
  String get name => 'Mangasid';

  @override
  String get kind => 'manga';

  @override
  List<String> get hosts => const ['mangasid.com'];

  @override
  Future<List<Map<String, dynamic>>> search(String query) {
    if (query.trim().isEmpty) return Future.value(const []);
    return _list(page: 1, query: query);
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
    final uri = Uri.parse('$_site/manga-list').replace(queryParameters: {
      if (query.trim().isNotEmpty) 'search': query.trim(),
      'page': '${page < 1 ? 1 : page}',
    });
    return _parseCards(await _document(uri.toString()));
  }

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final seriesUrl = _seriesUrl(url);
    final slug = _slugFromUrl(seriesUrl);
    if (slug.isEmpty) throw Exception('Mangasid: رابط المانجا غير صالح.');

    final document = await _document(seriesUrl);
    final data = _embeddedManga(document);
    final heading = mangaHtmlText(document.querySelector('h1'));
    final title = _text(data['title']).ifEmpty(heading).ifEmpty(slug);
    final coverElement = document.querySelector(
      'img[src*="/covers/"], img[data-src*="/covers/"], img[alt*="غلاف مانجا"]',
    );
    final cover = _coverUrl(data['cover_image']).ifEmpty(
      mangaImageUrl(coverElement, _site),
    );
    final chapters = _chapters(data, document, slug);
    final genres = _genres(data, document);
    final description = _text(data['description']).ifEmpty(_description(document));
    final chapterCount = _text(
      data['chapters_count'] ?? data['chapter_count'],
    ).ifEmpty(
      document.querySelector('meta[name="manga:chapters"]')?.attributes['content'] ??
          '${chapters.length}',
    );
    final status = _text(data['status']).ifEmpty(_labelValue(document, 'الحالة'));
    final type = SourceValues.type(
      [data['type'], data['manga_type'], data['content_type']],
      fallback: kind,
    );
    final rating = SourceValues.rating([
      data['rating'],
      document.querySelector('[itemprop="ratingValue"]')?.attributes['content'],
      document.querySelector('[data-rating]')?.attributes['data-rating'],
      document.querySelector('.rating, .rate, .rating-value')?.text,
    ]);

    return item(
      title: title,
      url: seriesUrl,
      image: cover,
      type: type,
      genres: genres,
      description: description,
      rating: rating,
    )..addAll({
        'native_title': _text(data['alternative_titles']),
        'author': _text(data['author']).ifEmpty(_labelValue(document, 'المؤلف')),
        'artist': _text(data['artist']).ifEmpty(_labelValue(document, 'الرسام')),
        'status': status,
        'release_year': _text(data['release_year'] ?? data['year']),
        'updated_on': _text(data['updated_at'] ?? data['updated_on'])
            .ifEmpty(_labelValue(document, 'آخر تحديث')),
        'total_chapters': chapterCount,
        'latest_chapter_number': chapters.isEmpty ? '' : chapters.first['number'],
        'chapters': chapters,
      });
  }

  @override
  Future<Map<String, dynamic>?> streams(String url) async => null;

  @override
  Future<Map<String, dynamic>?> chapterImages(String url) async {
    final reference = _readerReference(url);
    if (reference == null) return null;
    final document = await _document(
      url,
      referer: '$_site/',
      readerPage: true,
    );
    final selectors = [
      '.manga-page img[src]',
      '.manga-page img[data-src]',
      '.manga-page img[srcset]',
      '.manga-page source[srcset]',
      'img.block.relative.z-20.w-full.h-auto',
      'img[data-srcset]',
      '.reader-content img[src]',
      '.reader-content img[data-src]',
      '.reader-content img[srcset]',
      '.reader-content source[srcset]',
    ].join(', ');
    final seen = <String>{};
    final pages = document.querySelectorAll(selectors).map((image) {
      return _pageImageUrl(_preferredImageUrl(image));
    }).where((image) => image.isNotEmpty && seen.add(image)).toList(growable: false);
    if (pages.isEmpty) {
      throw Exception('Mangasid: لم يتم العثور على صور لهذا الفصل.');
    }

    String? chapterLink(Iterable<Element> links, String label) {
      for (final link in links) {
        if (mangaHtmlText(link).contains(label)) {
          final value = mangaAbsoluteUrl(_site, link.attributes['href']);
          if (value.isNotEmpty) return value;
        }
      }
      return null;
    }

    final readerLinks = document.querySelectorAll('a[href*="/reader/"]');
    final previous = chapterLink(readerLinks, 'السابق');
    final next = chapterLink(readerLinks, 'التالي');
    return {
      'title': mangaHtmlText(document.querySelector('h1'))
          .ifEmpty('الفصل ${reference['number']}'),
      'chapter_number': reference['number'],
      'pages': pages,
      'images': pages.map((page) => {'url': page}).toList(growable: false),
      'url': url,
      'navigation': {
        if (previous != null) 'previous_chapter': previous,
        if (next != null) 'next_chapter': next,
      },
    };
  }

  Future<Document> _document(
    String url, {
    String? referer,
    bool readerPage = false,
  }) async {
    final headers = <String, String>{
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
      'Accept-Language': 'ar,en;q=0.8',
      'User-Agent': 'MangaPlus/1.1',
      'Referer': referer ?? '$_site/',
      if (readerPage) 'Sec-Fetch-Dest': 'document',
      if (readerPage) 'Sec-Fetch-Mode': 'navigate',
      if (readerPage) 'Sec-Fetch-Site': 'same-origin',
    };
    final response = await _client
        .get(Uri.parse(url), headers: headers)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Mangasid: فشل تحميل الصفحة (${response.statusCode}).');
    }
    return html_parser.parse(
      utf8.decode(response.bodyBytes, allowMalformed: true),
    );
  }

  List<Map<String, dynamic>> _parseCards(Document document) {
    final cards = document.querySelectorAll('.manga-card');
    final results = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final card in cards) {
      final link = card.querySelector(
            'h3 a[href^="/manga/"], a.block[href^="/manga/"][dir="auto"]',
          ) ??
          card.querySelector('a[href^="/manga/"]');
      if (link == null) continue;
      final url = mangaAbsoluteUrl(_site, link.attributes['href']);
      final slug = _slugFromUrl(url);
      final imageElement = card.querySelector('img[src], img[data-src]');
      final title = mangaHtmlText(link)
          .ifEmpty(mangaHtmlText(imageElement).ifEmpty(imageElement?.attributes['alt'] ?? ''))
          .ifEmpty(slug);
      if (slug.isEmpty || title.isEmpty || !seen.add(url)) continue;

      final latestLink = card.querySelector('a[href^="/reader/"]');
      final latestUrl = mangaAbsoluteUrl(_site, latestLink?.attributes['href']);
      final latestNumber = _readerReference(latestUrl)?['number'] ??
          _numberText(mangaHtmlText(latestLink));
      final cardText = _normalizeDigits(mangaHtmlText(card));
      final chapterCount = RegExp(r'(\d+)\s*(?:فصل|فصول)')
              .firstMatch(cardText)
              ?.group(1) ??
          '';
      final ratingText = card.querySelector('[data-rating]')?.attributes['data-rating'] ??
          card.querySelector('[itemprop="ratingValue"]')?.attributes['content'] ??
          card.querySelector('.fa-star')?.parent?.text ??
          '';
      final status = mangaHtmlText(card.querySelector('.absolute.bottom-0 span'));
      final genreList = card
          .querySelectorAll('a[href*="genres="], .genre, [data-genre]')
          .map(mangaHtmlText)
          .where((genre) => genre.isNotEmpty)
          .toSet()
          .toList(growable: false);
      final typeMatch = RegExp(r'مانهوا|مانجا|مانها|رواية')
          .firstMatch(cardText);
      final result = item(
        title: title,
        url: url,
        image: mangaImageUrl(imageElement, _site),
        type: typeMatch?.group(0) ?? kind,
        genres: genreList,
        rating: SourceValues.rating(ratingText),
      )..addAll({
          if (status.isNotEmpty) 'status': status,
          if (chapterCount.isNotEmpty) 'total_chapters': chapterCount,
          if (latestNumber.isNotEmpty) 'latest_chapter_number': latestNumber,
        });
      results.add(result);
    }
    return results;
  }

  Map<String, dynamic> _embeddedManga(Document document) {
    for (final island in document.querySelectorAll('astro-island')) {
      final component = island.attributes['component-url'] ?? '';
      if (!component.contains('MangaChaptersLoader')) continue;
      final props = island.attributes['props'];
      if (props == null || props.isEmpty) continue;
      try {
        final decoded = _decodeWire(jsonDecode(props));
        if (decoded is Map) {
          final manga = decoded['manga'];
          if (manga is Map) return _stringMap(manga);
          if (decoded.containsKey('MangaChapters') || decoded.containsKey('title')) {
            return _stringMap(decoded);
          }
        }
      } catch (_) {
        // Prefer the visible HTML when a site payload changes shape.
      }
    }
    return <String, dynamic>{};
  }

  dynamic _decodeWire(dynamic value) {
    if (value is List) {
      if (value.length == 2 && value.first is num) {
        final tag = (value.first as num).toInt();
        if (tag == 0) return _decodeWire(value[1]);
        if (tag == 1 && value[1] is List) {
          return (value[1] as List).map(_decodeWire).toList(growable: false);
        }
      }
      return value.map(_decodeWire).toList(growable: false);
    }
    if (value is Map) {
      return value.map((key, entry) => MapEntry('$key', _decodeWire(entry)));
    }
    return value;
  }

  Map<String, dynamic> _stringMap(Map value) => value.map(
        (key, entry) => MapEntry('$key', entry),
      );

  List<Map<String, dynamic>> _chapters(
    Map<String, dynamic> data,
    Document document,
    String slug,
  ) {
    final result = <Map<String, dynamic>>[];
    final seen = <String>{};
    final payload = data['MangaChapters'] ?? data['chapters'] ?? data['manga_chapters'];
    if (payload is List) {
      for (final entry in payload.whereType<Map>()) {
        final rawNumber = _text(
          entry['chapter_number'] ?? entry['number'] ?? entry['chapter'],
        );
        final title = _text(entry['title']);
        final number = _numberText(rawNumber).ifEmpty(_numberText(title));
        if (number.isEmpty) continue;
        final directUrl = _text(entry['url'] ?? entry['chapter_url']);
        final url = directUrl.contains('/reader/')
            ? mangaAbsoluteUrl(_site, directUrl)
            : _readerUrl(slug, number);
        if (url.isEmpty || !seen.add(url)) continue;
        final chapterTitle = title.isEmpty ? 'الفصل $number' : title;
        final date = _text(entry['created_at'] ?? entry['release_date'] ?? entry['date']);
        result.add({
          'title': chapterTitle,
          'number': num.tryParse(number) ?? number,
          'chapter_number': number,
          'url': url,
          if (date.isNotEmpty) 'date': date,
          if (date.isNotEmpty) 'release_date': date,
        });
      }
    }

    if (result.isEmpty) {
      for (final link in document.querySelectorAll('a[href^="/reader/"]')) {
        final url = mangaAbsoluteUrl(_site, link.attributes['href']);
        final reference = _readerReference(url);
        if (reference == null || reference['slug'] != slug || !seen.add(url)) continue;
        final number = reference['number']!;
        final title = mangaHtmlText(link).ifEmpty('الفصل $number');
        result.add({
          'title': title,
          'number': num.tryParse(number) ?? number,
          'chapter_number': number,
          'url': url,
        });
      }
    }
    result.sort((left, right) {
      final a = num.tryParse('${left['number']}') ?? 0;
      final b = num.tryParse('${right['number']}') ?? 0;
      return b.compareTo(a);
    });
    return result;
  }

  List<String> _genres(Map<String, dynamic> data, Document document) {
    final tags = data['Tags'] ?? data['tags'] ?? data['genres'];
    final values = <String>[];
    if (tags is List) {
      for (final tag in tags) {
        final value = tag is Map
            ? _text(tag['name'] ?? tag['title'] ?? tag['label'])
            : _text(tag);
        if (value.isNotEmpty) values.add(value);
      }
    }
    if (values.isEmpty) {
      values.addAll(document
          .querySelectorAll('a[href*="genres="]')
          .map(mangaHtmlText)
          .where((genre) => genre.isNotEmpty));
    }
    return values.toSet().toList(growable: false);
  }

  String _description(Document document) {
    final heading = document.querySelectorAll('h2, h3, h4').firstWhere(
      (element) => mangaHtmlText(element).contains('نبذة عن العمل'),
      orElse: () => Element.tag('missing'),
    );
    final description = mangaHtmlText(heading.nextElementSibling);
    if (description.isNotEmpty) return description;
    final meta = document.querySelector('meta[name="description"]');
    return meta?.attributes['content'] ?? '';
  }

  String _labelValue(Document document, String label) {
    for (final row in document.querySelectorAll('.flex.justify-between.items-center')) {
      final text = mangaHtmlText(row);
      if (text.startsWith(label)) return text.substring(label.length).trim();
    }
    return '';
  }

  String _seriesUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) return '';
    if (uri.scheme == 'mangasid') {
      final slug = uri.queryParameters['slug'] ?? (uri.pathSegments.isEmpty ? '' : uri.pathSegments.last);
      return slug.isEmpty ? '' : '$_site/manga/${Uri.encodeComponent(slug)}';
    }
    if (uri.hasScheme && !hosts.any((host) => uri.host == host || uri.host.endsWith('.$host'))) {
      return '';
    }
    final slug = _slugFromUrl(value);
    return slug.isEmpty ? '' : '$_site/manga/${Uri.encodeComponent(slug)}';
  }

  String _slugFromUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) return '';
    final segments = uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
    final index = segments.indexOf('manga');
    if (index >= 0 && index + 1 < segments.length) return segments[index + 1];
    return uri.scheme == 'mangasid' ? uri.queryParameters['slug'] ?? '' : '';
  }

  Map<String, String>? _readerReference(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) return null;
    if (uri.scheme.isNotEmpty &&
        uri.scheme != 'http' &&
        uri.scheme != 'https' &&
        uri.scheme != 'mangasid') {
      return null;
    }
    if (uri.hasAuthority &&
        uri.host != 'mangasid.com' &&
        !uri.host.endsWith('.mangasid.com')) {
      return null;
    }
    final segments = uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
    if (segments.length < 3 || segments[0] != 'reader') return null;
    final number = _numberText(segments.last);
    if (number.isEmpty) return null;
    return {'slug': segments[1], 'number': number};
  }

  String _readerUrl(String slug, String number) =>
      '$_site/reader/${Uri.encodeComponent(slug)}/${Uri.encodeComponent(number)}';

  String _numberText(String value) {
    final normalized = _normalizeDigits(value);
    final number = mangaChapterNumber(normalized);
    if (number == null) return '';
    return number == number.toInt() ? '${number.toInt()}' : '$number';
  }

  String _coverUrl(dynamic raw) {
    final value = _text(raw);
    if (value.isEmpty) return '';
    return mangaAbsoluteUrl(_site, value);
  }

  String _preferredImageUrl(Element image) {
    for (final key in const [
      'data-src',
      'data-lazy-src',
      'data-cfsrc',
      'data-original',
      'src',
      'data-srcset',
      'data-lazy-srcset',
      'srcset',
    ]) {
      final raw = image.attributes[key]?.trim() ?? '';
      final value = key.endsWith('srcset')
          ? raw.split(',').first.trim().split(RegExp(r'\s+')).first
          : raw;
      if (value.isNotEmpty && !value.startsWith('data:')) return value;
    }
    final srcset = image.attributes['srcset'] ?? '';
    if (srcset.trim().isEmpty) return '';
    return srcset.split(',').last.trim().split(RegExp(r'\s+')).first;
  }

  String _pageImageUrl(String raw) {
    final value = raw.trim();
    if (value.isEmpty || value.startsWith('data:') || value.startsWith('javascript:')) {
      return '';
    }
    final uri = Uri.tryParse(value);
    if (uri == null) return '';
    if (uri.hasScheme) {
      return uri.scheme == 'http' || uri.scheme == 'https' ? uri.toString() : '';
    }
    if (value.startsWith('//')) return 'https:$value';
    return Uri.parse('$_imageHost/').resolveUri(uri).toString();
  }

  String _normalizeDigits(String value) {
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    var result = value;
    for (var index = 0; index < 10; index++) {
      result = result.replaceAll(arabic[index], '$index');
      result = result.replaceAll(persian[index], '$index');
    }
    return result;
  }

  String _text(dynamic value) {
    if (value == null) return '';
    final text = '$value'.trim();
    return text == 'null' ? '' : text;
  }
}

extension _MangaSidStringFallback on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
