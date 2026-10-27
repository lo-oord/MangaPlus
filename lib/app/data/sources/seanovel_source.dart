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
  Future<List<Map<String, dynamic>>> search(String query) async {
    final value = query.trim().toLowerCase();
    if (value.isEmpty) return const [];
    final entries = await _searchIndex();
    return entries
        .where((entry) => _matches(value, entry))
        .map(_indexItem)
        .toList(growable: false);
  }

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) async {
    final entries = await _searchIndex();
    entries.sort((a, b) => _text(b['last_updated']).compareTo(_text(a['last_updated'])));
    return _page(entries, page).map(_indexItem).toList(growable: false);
  }

  @override
  Future<List<Map<String, dynamic>>> catalog({int page = 1}) => latest(page: page);

  @override
  Future<List<Map<String, dynamic>>> nextPage({
    String query = '',
    int page = 2,
  }) async {
    if (query.trim().isNotEmpty) return search(query);
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
    final cover = mangaImageUrl(document.querySelector('img.novel-cover'), _site);
    final description = mangaHtmlText(
      document.querySelector('.novel-description, [class*="description"]'),
    );
    final author = mangaHtmlText(
      document.querySelector('.novel-author, [class*="author"]'),
    );
    final status = mangaHtmlText(
      document.querySelector('.novel-status, [class*="status"]'),
    );
    final chapters = await _allChapters(slug);
    final metadata = (await _searchIndex()).cast<Map<String, dynamic>?>().firstWhere(
          (entry) => entry?['slug']?.toString() == slug,
          orElse: () => null,
        ) ??
        <String, dynamic>{};
    final type = SourceValues.type('novel');
    return item(
      title: title,
      url: novelUrl,
      image: cover,
      type: type,
      genres: _strings(metadata['genres']),
      description: description,
    )..addAll({
        'native_title': _text(document.querySelector('.novel-original-title')?.text),
        'synopsis': description,
        'author': author,
        'status': status,
        'total_chapters': chapters.length,
        'latest_chapter_number': chapters.isEmpty ? 0 : chapters.last['number'],
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
    if (segments.length != 4 || segments[0] != 'novels' || segments[2] != 'chapters') {
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
    final title = mangaHtmlText(document.querySelector('h1.reader-chapter-title'));
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
        final number = value['chapter_number'] ?? id;
        chapters.add({
          'title': _text(value['title']).ifEmpty('الفصل $number'),
          'number': number,
          'chapter_number': number,
          'url': '$_site/novels/$slug/chapters/$id',
          'date': _text(value['date']),
        });
      }
      offset += raw.length;
      if (data['hasMore'] != true && raw.length < limit) break;
    }
    final seen = <String>{};
    return chapters.where((chapter) => seen.add('${chapter['url']}')).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _searchIndex() async {
    final data = await _json('$_site/api/search-index');
    if (data is! List) return const [];
    return data.whereType<Map<String, dynamic>>().toList(growable: false);
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
      description: '',
    )..addAll({
        'status': _text(entry['status']),
        'author': _text(entry['author']),
        'total_chapters': entry['chapters_count'] ?? 0,
        'native_title': _text(entry['title_original']),
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

  List<Map<String, dynamic>> _page(List<Map<String, dynamic>> values, int page) {
    const size = 24;
    final start = ((page < 1 ? 1 : page) - 1) * size;
    if (start >= values.length) return const [];
    final end = (start + size).clamp(0, values.length);
    return values.sublist(start, end);
  }

  List<String> _strings(dynamic value) => value is List
      ? value.map(_text).where((entry) => entry.isNotEmpty).toList(growable: false)
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
    final response = await _client.get(Uri.parse(url), headers: _headers).timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('SeaNovel: فشل تحميل الصفحة (${response.statusCode}).');
    }
    return html_parser.parse(utf8.decode(response.bodyBytes, allowMalformed: true));
  }

  Future<dynamic> _json(String url) async {
    final response = await _client.get(Uri.parse(url), headers: _headers).timeout(_timeout);
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
