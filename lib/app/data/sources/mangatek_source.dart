import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import 'manga_html_utils.dart';
import 'source_base.dart';
import 'source_values.dart';

/// Adapter for the Arabic MangaTek extension (Keiyoushi).
class MangaTekSource extends ContentSource {
  static const _site = 'https://mangatek.com';
  static final http.Client _client = http.Client();

  @override
  String get id => 'mangatek';
  @override
  String get name => 'MangaTek';
  @override
  String get kind => 'manga';
  @override
  List<String> get hosts => const ['mangatek.com'];
  @override
  bool handles(String url) => url.startsWith('mangatek://') || super.handles(url);

  @override
  Future<List<Map<String, dynamic>>> search(String query) =>
      _list(page: 1, query: query);

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) =>
      _list(page: page);

  @override
  Future<List<Map<String, dynamic>>> nextPage({String query = '', int page = 2}) =>
      _list(page: page, query: query);

  Future<List<Map<String, dynamic>>> _list({required int page, String query = ''}) async {
    try {
      final response = await _apiGet('/api/manga', query: {
        if (query.trim().isNotEmpty) 'search': query.trim(),
        'page': '${page < 1 ? 1 : page}',
        'limit': '24',
      });
      final data = _asMap(response['data']);
      final mangas = data['mangas'];
      if (mangas is List) {
        final results = mangas
            .whereType<Map>()
            .map((entry) => _apiItem(Map<String, dynamic>.from(entry)))
            .where((item) => item['title'].toString().isNotEmpty)
            .toList(growable: false);
        if (results.isNotEmpty) return results;
      }
    } catch (_) {
      // Fall back to the public HTML catalogue when the API is unavailable.
    }
    final uri = Uri.parse('$_site/manga-list').replace(queryParameters: {
      if (query.trim().isNotEmpty) 'search': query.trim(),
      'page': '${page < 1 ? 1 : page}',
    });
    final document = await _document(uri.toString());
    return document.querySelectorAll('.flex-grow .grid a').map((anchor) {
      final title = (anchor.querySelector('h3')?.attributes['title'] ??
              mangaHtmlText(anchor.querySelector('h3')))
          .trim();
      final url = mangaAbsoluteUrl(_site, anchor.attributes['href']);
      final image = mangaImageUrl(anchor.querySelector('img'), _site);
      return _item(title, url, image);
    }).where((item) => item['title'].toString().isNotEmpty && item['url'].toString().isNotEmpty).toList(growable: false);
  }

  Map<String, dynamic> _apiItem(Map<String, dynamic> manga) {
    final slug = '${manga['slug'] ?? ''}'.trim();
    final title = '${manga['title_ar'] ?? manga['title'] ?? ''}'.trim();
    final result = _item(
      title,
      'mangatek://series?slug=${Uri.encodeQueryComponent(slug)}',
      _coverUrl(_firstImageValue(manga, const [
        'cover_image', 'cover', 'cover_url', 'coverUrl',
        'image', 'image_url', 'poster',
      ])),
      type: _typeFromData(manga),
    );
    result.addAll({
      'native_title': '${manga['title'] ?? ''}',
      'alternate_titles': manga['alternative_titles'] ?? '',
      'author': '${manga['author'] ?? ''}',
      'status': _status('${manga['status'] ?? ''}'),
      'total_chapters': manga['chapters_count'] ?? manga['chapter_count'] ?? 0,
      'latest_chapter_number': manga['latest_chapter_number'] ?? 0,
    });
    return result;
  }

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final seriesUrl = _seriesUrl(url);
    if (seriesUrl.isEmpty) throw Exception('MangaTek: رابط المانجا غير صالح.');
    Document document;
    try {
      document = await _document(seriesUrl);
    } catch (_) {
      return _apiDetails(url);
    }
    final raw = _astro(document, 'manga');
    final manga = _asMap(raw['manga'] ?? raw);
    final slug = _slug(seriesUrl);
    if (manga.isEmpty) {
      final title = mangaHtmlText(document.querySelector('h1'));
      final description = mangaHtmlText(document.querySelector('div.grid p, p.text-gray-300, div.description, div.synopsis'));
      final chapters = _chaptersFromHtml(document, slug);
      if (title.isEmpty && chapters.isEmpty) {
        throw Exception('MangaTek: لم يتم العثور على تفاصيل المانجا.');
      }
      final cover = mangaImageUrl(document.querySelector('img'), _site);
      return _item(
        title,
        'mangatek://series?slug=${Uri.encodeQueryComponent(slug)}',
        cover,
        type: _typeFromHtml(document),
      )
        ..addAll({
          'description': description,
          'synopsis': description,
          'genres': document.querySelectorAll('div.flex.gap-2 span.text-gray-300').map(mangaHtmlText).where((tag) => tag.isNotEmpty).toList(),
          'status': mangaHtmlText(document.querySelector('span.border')),
          'total_chapters': chapters.length,
          'latest_chapter_number': chapters.isEmpty ? 0 : chapters.first['number'],
          'chapters': chapters,
        });
    }
    final chapters = _chapters(manga['MangaChapters'] ?? manga['chapters'], slug);
    final rawTags = manga['Tags'] ?? manga['tags'];
    final genres = rawTags is List
        ? rawTags
            .map((tag) => tag is Map ? '${tag['name'] ?? ''}' : '$tag')
            .where((tag) => tag.trim().isNotEmpty)
            .toList()
        : <String>[];
    final description = mangaHtmlToText('${manga['description'] ?? ''}');
    return _item(
      '${manga['title'] ?? ''}',
      'mangatek://series?slug=${Uri.encodeQueryComponent(slug)}',
      _coverUrl(_firstImageValue(manga, const [
        'cover_image', 'cover', 'cover_url', 'coverUrl',
        'image', 'image_url', 'poster',
      ])),
      type: _typeFromData(manga),
    )..addAll({
        'description': description,
        'synopsis': description,
        'genres': genres,
        'author': '${manga['author'] ?? ''}',
        'status': _status('${manga['status'] ?? ''}'),
        'rating': SourceValues.rating(manga['rating']),
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
    final readerUrl = '$_site/reader/${Uri.encodeComponent(parts.$1)}/${Uri.encodeComponent(parts.$2)}';
    final document = await _document(readerUrl);
    // The working MangaPeak parser reads the rendered reader images directly.
    // MangaTek does not consistently expose an Astro imageUrls payload.
    final pages = document
        .querySelectorAll('div.manga-page img[src], div.manga-page img[data-src]')
        .map((image) => mangaImageUrl(image, _site))
        .where((image) => image.isNotEmpty)
        .toList(growable: false);
    if (pages.isEmpty) throw Exception('MangaTek: لم توجد صفحات لهذا الفصل.');
    return {
      'title': 'الفصل ${parts.$2}',
      'chapter_number': parts.$2,
      'pages': pages,
      'images': pages.map((page) => {'url': page}).toList(),
      'url': url,
    };
  }

  Map<String, dynamic> _item(
    String title,
    String url,
    String image, {
    String type = 'manga',
  }) => item(
        title: title.trim(),
        url: url,
        image: image.trim(),
        type: SourceValues.type(type),
      );

  String _typeFromData(Map<String, dynamic> data) => SourceValues.type([
        data['type'],
        data['seriesType'],
        data['series_type'],
        data['contentType'],
        data['content_type'],
        data['mangaType'],
        data['manga_type'],
        data['format'],
      ]);

  String _typeFromHtml(Document document) {
    for (final element in document.querySelectorAll(
      '[data-type], .manga-type, .series-type, .type-badge, .badge-type',
    )) {
      final value = element.attributes['data-type'] ?? mangaHtmlText(element);
      if (value.trim().isNotEmpty) return value.trim();
    }
    final label = RegExp(
      r'^(?:نوع العمل|النوع|type|format)\s*[:：-]\s*(.+)$',
      caseSensitive: false,
    );
    for (final element in document.querySelectorAll('p, li, dt, dd, span, div')) {
      final match = label.firstMatch(mangaHtmlText(element));
      if (match != null) return match.group(1)!.trim();
    }
    return '';
  }

  List<Map<String, dynamic>> _chapters(dynamic value, String slug) {
    if (value is! List) return const [];
    return value.map((entry) {
      final raw = entry is Map ? Map<String, dynamic>.from(entry) : <String, dynamic>{};
      final number = '${raw['chapter_number'] ?? raw['number'] ?? mangaChapterNumber('${raw['title'] ?? ''}') ?? ''}';
      final title = '${raw['title'] ?? 'الفصل $number'}'.trim();
      return <String, dynamic>{
        'title': title.isEmpty ? 'الفصل $number' : title,
        'number': num.tryParse(number) ?? number,
        'chapter_number': num.tryParse(number) ?? number,
        'release_date': '${raw['created_at'] ?? raw['createdAt'] ?? ''}',
        'date': '${raw['created_at'] ?? raw['createdAt'] ?? ''}',
        'url': 'mangatek://chapter?slug=${Uri.encodeQueryComponent(slug)}&number=${Uri.encodeQueryComponent(number)}',
      };
      }).where((entry) => entry['number'].toString().isNotEmpty).toList(growable: false);
  }

  List<Map<String, dynamic>> _chaptersFromHtml(Document document, String slug) =>
      document.querySelectorAll('div.manga-chapter a, div.grid a[href^="/reader/"]').map((element) {
        final href = element.attributes['href'] ?? '';
        final title = mangaHtmlText(element.querySelector('h3'));
        final number = mangaChapterNumber(title.isEmpty ? href : title);
        if (href.isEmpty || number == null) return <String, dynamic>{};
        return <String, dynamic>{
          'title': title.isEmpty ? 'الفصل $number' : title,
          'number': number,
          'chapter_number': number,
          'url': 'mangatek://chapter?slug=${Uri.encodeQueryComponent(slug)}&number=${Uri.encodeQueryComponent('$number')}',
        };
      }).where((entry) => entry.isNotEmpty).toList(growable: false);

  Future<Document> _document(String url) async {
    final response = await _client.get(Uri.parse(url), headers: const {
      'Accept': 'text/html,application/xhtml+xml',
      'Accept-Language': 'ar,en;q=0.8',
      'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/131 Mobile Safari/537.36',
    }).timeout(const Duration(seconds: 25));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('MangaTek: فشل طلب المصدر (${response.statusCode}).');
    }
    return html_parser.parse(utf8.decode(response.bodyBytes, allowMalformed: true));
  }

  Future<Map<String, dynamic>> _apiDetails(String value) async {
    final uri = Uri.tryParse(value);
    final slug = uri?.queryParameters['slug'] ?? _slug(_seriesUrl(value));
    var data = <String, dynamic>{};
    final id = uri?.queryParameters['id'];
    if (id != null && id.isNotEmpty) {
      data = _asMap((await _apiGet('/api/manga/$id'))['data']);
    } else {
      final response = await _apiGet('/api/manga', query: {'search': slug, 'page': '1', 'limit': '20'});
      final items = _asMap(response['data'])['mangas'];
      if (items is List) {
        for (final item in items.whereType<Map>()) {
          if ('${item['slug'] ?? ''}' == slug) {
            data = Map<String, dynamic>.from(item);
            break;
          }
        }
        if (data.isEmpty && items.isNotEmpty && items.first is Map) {
          data = Map<String, dynamic>.from(items.first as Map);
        }
      }
      if (data.isNotEmpty && data['id'] != null) {
        data = _asMap((await _apiGet('/api/manga/${data['id']}'))['data']);
      }
    }
    if (data.isEmpty) throw Exception('MangaTek: لم يتم العثور على تفاصيل المانجا.');
    final actualSlug = '${data['slug'] ?? slug}';
    final chapters = _chapters(data['MangaChapters'] ?? data['chapters'], actualSlug);
    final description = '${data['description'] ?? data['description_cool'] ?? data['description_sid'] ?? ''}';
    final cover = _coverUrl(_firstImageValue(data, const [
      'cover_image', 'cover', 'cover_url', 'coverUrl',
      'image', 'image_url', 'poster',
    ]));
    return _item(
      '${data['title_ar'] ?? data['title'] ?? ''}',
      'mangatek://series?slug=${Uri.encodeQueryComponent(actualSlug)}',
      cover,
      type: _typeFromData(data),
    )
      ..addAll({
        'description': description,
        'synopsis': description,
        'genres': _tagNames(data['Tags']),
        'author': '${data['author'] ?? ''}',
        'status': _status('${data['status'] ?? ''}'),
        'rating': SourceValues.rating(data['rating']),
        'total_chapters': chapters.length,
        'latest_chapter_number': chapters.isEmpty ? 0 : chapters.first['number'],
        'chapters': chapters,
      });
  }

  List<String> _tagNames(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((tag) => '${tag['name'] ?? ''}')
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> _apiGet(String path, {Map<String, String>? query}) async {
    final uri = Uri.parse('https://api.mangatek.com$path').replace(queryParameters: query);
    final response = await _client.get(uri, headers: const {'Accept': 'application/json', 'User-Agent': 'MangaPlus/1.1'}).timeout(const Duration(seconds: 25));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('MangaTek API: فشل الطلب (${response.statusCode}).');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true));
    return decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};
  }

  Map<String, dynamic> _astro(Document document, String key) {
    final element = document.querySelector('[props*=$key]');
    final raw = element?.attributes['props'];
    if (raw == null || raw.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      final unwrapped = _unwrap(decoded);
      return _asMap(unwrapped);
    } catch (_) {
      return {};
    }
  }

  dynamic _unwrap(dynamic value) {
    if (value is List && value.length == 2 && value.first is String) return _unwrap(value[1]);
    if (value is List) return value.map(_unwrap).toList();
    if (value is Map) return value.map((key, item) => MapEntry(key, _unwrap(item)));
    return value;
  }

  Map<String, dynamic> _asMap(dynamic value) => value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  String _seriesUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri?.scheme == 'mangatek') {
      return '$_site/manga/${Uri.encodeComponent(uri!.queryParameters['slug'] ?? '')}';
    }
    if (uri != null && uri.host.contains('mangatek.com')) return uri.toString();
    return '';
  }

  String _slug(String value) => Uri.parse(value).pathSegments.where((part) => part.isNotEmpty).last;

  (String, String)? _chapterParts(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'mangatek') return null;
    final slug = uri.queryParameters['slug'] ?? '';
    final number = uri.queryParameters['number'] ?? '';
    return slug.isEmpty || number.isEmpty ? null : (slug, number);
  }

  String _status(String value) => switch (value.toLowerCase()) {
        'ongoing' => 'ongoing',
        'completed' => 'completed',
        'hiatus' => 'on_hiatus',
        'cancelled' || 'dropped' => 'cancelled',
        _ => value,
      };

  String _coverUrl(dynamic value) {
    final raw = '$value'.trim();
    if (raw.isEmpty || raw == 'null') return '';
    final parsed = Uri.tryParse(raw);
    if (parsed?.hasScheme == true) return raw;
    return mangaAbsoluteUrl('https://api.mangatek.com/', raw);
  }

  dynamic _firstImageValue(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is Map) {
        final nested = _firstImageValue(Map<String, dynamic>.from(value), const [
          'url', 'src', 'original', 'large', 'desktop', 'mobile',
        ]);
        if (nested != null && '$nested'.trim().isNotEmpty) return nested;
      } else if (value is List) {
        for (final entry in value) {
          if ('$entry'.trim().isNotEmpty) return entry;
        }
      } else if (value != null && '$value'.trim().isNotEmpty && value != 'null') {
        return value;
      }
    }
    return '';
  }
}
