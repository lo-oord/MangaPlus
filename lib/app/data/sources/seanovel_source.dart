import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import 'manga_html_utils.dart';
import 'source_base.dart';
import 'source_values.dart';

/// API/HTML adapter for SeaNovel's Arabic novel catalogue.
class SeanovelSource extends ContentSource {
  SeanovelSource({http.Client? client}) : _client = client ?? http.Client();

  static const String _site = 'https://seanovel.org';
  static const Map<String, String> _headers = {
    'Accept': 'text/html,application/xhtml+xml,application/json',
    'Accept-Language': 'ar,en;q=0.8',
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/131 Mobile Safari/537.36',
  };
  static const Duration _timeout = Duration(seconds: 35);
  static final Map<String, ({DateTime at, Map<String, dynamic> values})>
      _novelMetadataCache = {};
  static final Map<String, Future<Map<String, dynamic>>>
      _novelMetadataRequests = {};

  final http.Client _client;

  @override
  String get id => 'seanovel';

  @override
  String get name => 'SeaNovel';

  @override
  String get kind => 'novel';

  @override
  List<String> get hosts => const ['seanovel.org'];

  @override
  Future<List<Map<String, dynamic>>> search(String query) =>
      _searchPage(query, page: 1);

  Future<List<Map<String, dynamic>>> _searchPage(
    String query, {
    required int page,
  }) async {
    final value = query.trim().toLowerCase();
    if (value.isEmpty) return const [];
    final entries = await _searchIndex();
    final matches = entries.where((entry) => _matches(value, entry)).toList();
    return _itemsWithMetadata(_page(matches, page));
  }

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) async {
    final entries = await _searchIndex();
    entries.sort(
        (a, b) => _text(b['last_updated']).compareTo(_text(a['last_updated'])));
    return _itemsWithMetadata(_page(entries, page));
  }

  @override
  Future<List<Map<String, dynamic>>> catalog({int page = 1}) =>
      latest(page: page);

  @override
  Future<List<Map<String, dynamic>>> nextPage({
    String query = '',
    int page = 2,
  }) async {
    if (query.trim().isNotEmpty) return _searchPage(query, page: page);
    return latest(page: page);
  }

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final slug = _slug(url);
    if (slug.isEmpty) throw Exception('SeaNovel: رابط الرواية غير صالح.');
    final novelUrl = '$_site/novels/$slug';
    final document = await _document(novelUrl);
    final title = mangaHtmlText(document.querySelector('h1.novel-title'));
    if (title.isEmpty) throw Exception('SeaNovel: لم يتم العثور على الرواية.');
    final cover =
        mangaImageUrl(document.querySelector('img.novel-cover'), _site);
    final author = mangaHtmlText(
      document.querySelector('.novel-author, [class*="author"]'),
    );
    final status = mangaHtmlText(
      document.querySelector('.novel-status, [class*="status"]'),
    );
    final chapters = await _allChapters(slug);
    Map<String, dynamic> metadata;
    try {
      metadata = await _novelMetadata(slug);
    } catch (_) {
      metadata = (await _searchIndex())
              .cast<Map<String, dynamic>?>()
              .firstWhere(
                (entry) => entry?['slug']?.toString() == slug,
                orElse: () => null,
              ) ??
          <String, dynamic>{};
    }
    final type = SourceValues.type('novel');
    final latestDate = SourceValues.firstText([
      metadata['last_updated'],
      chapters.isEmpty ? '' : chapters.last['release_date'],
    ]);
    final description = SourceValues.firstText([
      mangaHtmlText(
        document.querySelector('.novel-description, [class*="description"]'),
      ),
      metadata['description'],
    ]);
    return item(
      title: title,
      url: novelUrl,
      image: cover,
      type: type,
      genres: _strings(metadata['genres']),
      description: description,
      rating: SourceValues.rating(metadata['rating']),
    )..addAll({
        'native_title':
            _text(document.querySelector('.novel-original-title')?.text),
        'synopsis': description,
        'author': author.isEmpty ? _text(metadata['author']) : author,
        'status': status.isEmpty ? _text(metadata['status']) : status,
        'total_chapters': chapters.isEmpty
            ? metadata['chapters_count'] ?? 0
            : chapters.length,
        'latest_chapter_number':
            chapters.isEmpty ? '' : chapters.last['number'] ?? '',
        'latest_chapter_date': latestDate,
        'updated_on': latestDate,
        'first_published_at': _text(metadata['first_published_at']),
        'release_year': SourceValues.year(metadata['first_published_at']),
        'chapters': chapters,
      });
  }

  @override
  Future<Map<String, dynamic>?> streams(String url) async => null;

  @override
  Future<Map<String, dynamic>?> chapterContent(String url) async {
    final parsed = Uri.tryParse(mangaAbsoluteUrl(_site, url));
    if (parsed == null || parsed.host != 'seanovel.org') {
      throw Exception('SeaNovel: رابط الفصل غير صالح.');
    }
    final segments = parsed.pathSegments;
    if (segments.length != 4 ||
        segments[0] != 'novels' ||
        segments[2] != 'chapters') {
      throw Exception('SeaNovel: رابط الفصل غير صالح.');
    }
    final chapterUrl = Uri.https('seanovel.org', parsed.path).toString();
    final document = await _document(chapterUrl);
    final contentElement = document.querySelector('.reader-content');
    if (contentElement == null) {
      throw Exception('SeaNovel: لم يتم العثور على محتوى الفصل.');
    }
    final paragraphs = contentElement
        .querySelectorAll('p')
        .where((element) => !(element.classes.contains('sr-only')))
        .map((element) => element.outerHtml)
        .join();
    final content = mangaHtmlToReadableText(
      paragraphs.isEmpty ? contentElement.innerHtml : paragraphs,
    );
    if (content.isEmpty) throw Exception('SeaNovel: محتوى الفصل فارغ.');
    final number = num.tryParse(segments.last) ?? segments.last;
    final title =
        mangaHtmlText(document.querySelector('h1.reader-chapter-title'));
    final previous = _navigation(document, 'chapter-nav-prev');
    final next = _navigation(document, 'chapter-nav-next');
    return {
      'title': title,
      'content': content,
      'chapter_number': number,
      'previous_chapter': previous,
      'next_chapter': next,
      'url': chapterUrl,
    };
  }

  Future<List<Map<String, dynamic>>> _allChapters(String slug) async {
    final chapters = <Map<String, dynamic>>[];
    var offset = 0;
    const limit = 100;
    while (true) {
      final uri = Uri.parse('$_site/api/novel/$slug/chapters').replace(
        queryParameters: {
          'offset': '$offset',
          'limit': '$limit',
          'sort': 'asc',
        },
      );
      final data = await _json(uri.toString());
      final raw = data['chapters'];
      if (raw is! List || raw.isEmpty) break;
      for (final value in raw) {
        if (value is! Map) continue;
        final id = value['id'];
        if (id == null) continue;
        final title = _text(value['title']);
        final number = value['chapter_number'] ?? mangaChapterNumber(title);
        final rawDate = _text(value['date']);
        final releaseDate = mangaDateFromUnixSeconds(rawDate);
        chapters.add({
          'title': title.ifEmpty(number == null ? 'فصل' : 'الفصل $number'),
          'number': number,
          'chapter_number': number ?? '',
          'url': '$_site/novels/$slug/chapters/$id',
          'release_date': releaseDate,
          'date': releaseDate,
        });
      }
      offset += raw.length;
      if (data['hasMore'] != true && raw.length < limit) break;
    }
    final seen = <String>{};
    return chapters
        .where((chapter) => seen.add('${chapter['url']}'))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _searchIndex() async {
    final data = await _json('$_site/api/search-index');
    if (data is! List) return const [];
    return data.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _itemsWithMetadata(
    List<Map<String, dynamic>> entries,
  ) async {
    final results = <Map<String, dynamic>>[];
    const batchSize = 6;
    for (var start = 0; start < entries.length; start += batchSize) {
      final end = start + batchSize > entries.length
          ? entries.length
          : start + batchSize;
      final batch = await Future.wait([
        for (final entry in entries.skip(start).take(end - start))
          () async {
            final enriched = Map<String, dynamic>.from(entry);
            final slug = _text(entry['slug']);
            if (slug.isNotEmpty) {
              try {
                final metadata = await _novelMetadata(slug);
                for (final key in const [
                  'rating',
                  'last_updated',
                  'first_published_at',
                  'description',
                  'author',
                  'status',
                  'genres',
                  'chapters_count',
                  'cover_version',
                ]) {
                  if (metadata[key] != null) enriched[key] = metadata[key];
                }
              } catch (_) {
                // Keep the searchable index data if one novel's API call fails.
              }
            }
            return _indexItem(enriched);
          }(),
      ]);
      results.addAll(batch);
    }
    return results;
  }

  Future<Map<String, dynamic>> _novelMetadata(String slug) async {
    final key = slug.trim();
    if (key.isEmpty) return const {};
    final cached = _novelMetadataCache[key];
    if (cached != null &&
        DateTime.now().difference(cached.at) < const Duration(minutes: 10)) {
      return cached.values;
    }
    final inFlight = _novelMetadataRequests[key];
    if (inFlight != null) return inFlight;
    final request = _fetchNovelMetadata(key);
    _novelMetadataRequests[key] = request;
    try {
      final values = await request;
      _novelMetadataCache[key] = (at: DateTime.now(), values: values);
      return values;
    } finally {
      if (identical(_novelMetadataRequests[key], request)) {
        _novelMetadataRequests.remove(key);
      }
    }
  }

  Future<Map<String, dynamic>> _fetchNovelMetadata(String slug) async {
    final payload = await _json(
      Uri.https('seanovel.org', '/api/novel/$slug').toString(),
    );
    if (payload is! Map) return const {};
    return Map<String, dynamic>.from(payload);
  }

  Map<String, dynamic> _indexItem(Map<String, dynamic> entry) {
    final slug = _text(entry['slug']);
    final version = _text(entry['cover_version']).ifEmpty('1');
    final cover = '$_site/api/novel/$slug/cover?type=webp&v=$version';
    return item(
      title: _text(entry['title_ar']).ifEmpty(_text(entry['title_original'])),
      url: '$_site/novels/$slug',
      image: cover,
      type: 'novel',
      genres: _strings(entry['genres']),
      description: _text(entry['description']),
      rating: SourceValues.rating(entry['rating']),
    )..addAll({
        'status': _text(entry['status']),
        'author': _text(entry['author']),
        'total_chapters': entry['chapters_count'] ?? 0,
        'native_title': _text(entry['title_original']),
        'latest_chapter_date': _text(entry['last_updated']),
        'updated_on': _text(entry['last_updated']),
        'first_published_at': _text(entry['first_published_at']),
        'release_year': SourceValues.year(entry['first_published_at']),
      });
  }

  bool _matches(String query, Map<String, dynamic> entry) {
    final values = [
      _text(entry['title_ar']),
      _text(entry['title_original']),
      _text(entry['slug']),
      _text(entry['author']),
    ].join(' ').toLowerCase();
    return values.contains(query);
  }

  List<Map<String, dynamic>> _page(
      List<Map<String, dynamic>> values, int page) {
    const size = 24;
    final start = ((page < 1 ? 1 : page) - 1) * size;
    if (start >= values.length) return const [];
    final end = (start + size).clamp(0, values.length);
    return values.sublist(start, end);
  }

  List<String> _strings(dynamic value) => value is List
      ? value
          .map(_text)
          .where((entry) => entry.isNotEmpty)
          .toList(growable: false)
      : const [];

  String _slug(String raw) {
    final absolute = mangaAbsoluteUrl(_site, raw);
    final uri = Uri.tryParse(absolute);
    if (uri == null || uri.host != 'seanovel.org') return '';
    final segments = uri.pathSegments;
    if (segments.length != 2 || segments.first != 'novels') return '';
    return segments.last;
  }

  String _navigation(Document document, String className) {
    final href = document.querySelector('a.$className')?.attributes['href'];
    return href == null ? '' : mangaAbsoluteUrl(_site, href);
  }

  Future<Document> _document(String url) async {
    final response =
        await _client.get(Uri.parse(url), headers: _headers).timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('SeaNovel: فشل تحميل الصفحة (${response.statusCode}).');
    }
    return html_parser
        .parse(utf8.decode(response.bodyBytes, allowMalformed: true));
  }

  Future<dynamic> _json(String url) async {
    final response =
        await _client.get(Uri.parse(url), headers: _headers).timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('SeaNovel: فشل طلب API (${response.statusCode}).');
    }
    return jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true));
  }

  String _text(dynamic value) => value is String
      ? value.replaceAll(RegExp(r'\s+'), ' ').trim()
      : value == null
          ? ''
          : '$value'.trim();
}

extension on String {
  String ifEmpty(String fallback) => trim().isEmpty ? fallback : this;
}
