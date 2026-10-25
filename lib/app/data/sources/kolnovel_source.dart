import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import 'manga_html_utils.dart';
import 'source_base.dart';
import 'source_values.dart';

/// Read-only HTML adapter for the Arabic KolNovel novel catalog.
class KolNovelSource extends ContentSource {
  KolNovelSource({http.Client? client}) : _client = client ?? http.Client();

  static const String _site = 'https://kolnovel.com';
  static const Map<String, String> _headers = {
    'Accept': 'text/html,application/xhtml+xml',
    'Accept-Language': 'ar,en;q=0.8',
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/131 Mobile Safari/537.36',
  };
  static const Duration _requestTimeout = Duration(seconds: 35);
  static final Map<String, Map<String, dynamic>> _detailCache = {};
  static final Map<String, List<Map<String, dynamic>>> _chapterCache = {};

  final http.Client _client;

  @override
  String get id => 'kolnovel';

  @override
  String get name => 'KolNovel';

  @override
  String get kind => 'novel';

  @override
  List<String> get hosts => const ['kolnovel.com'];

  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return const [];
    final uri = Uri.parse(_site).replace(
      queryParameters: {'s': normalized, 'post_type': 'series'},
    );
    final document = await _document(uri.toString());
    return _archiveItems(document);
  }

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) async {
    final safePage = page < 1 ? 1 : page;
    final uri = Uri.parse('$_site/series/').replace(
      queryParameters: {
        'status': '',
        'type': '',
        'order': 'update',
        if (safePage > 1) 'paged': '$safePage',
      },
    );
    return _archiveItems(await _document(uri.toString()));
  }

  @override
  Future<List<Map<String, dynamic>>> catalog({int page = 1}) =>
      latest(page: page);

  @override
  Future<List<Map<String, dynamic>>> nextPage({
    String query = '',
    int page = 2,
  }) => query.trim().isEmpty ? latest(page: page) : search(query);

  Future<List<Map<String, dynamic>>> searchSuggestions({int limit = 8}) async {
    if (limit <= 0) return const [];
    final items = await latest(page: 1);
    return items.take(limit).toList(growable: false);
  }

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final seriesUrl = _seriesUrl(url);
    if (seriesUrl.isEmpty) throw Exception('KolNovel: رابط الرواية غير صالح.');
    final cached = _detailCache[seriesUrl];
    if (cached != null) return Map<String, dynamic>.from(cached);

    final document = await _document(seriesUrl);
    final title = mangaHtmlText(document.querySelector('h1.kol-series-editorial__title'));
    if (title.isEmpty) {
      throw Exception('KolNovel: لم يتم العثور على تفاصيل الرواية.');
    }
    final cover = mangaImageUrl(
      document.querySelector('.kol-series-editorial__cover img'),
      _site,
    );
    final description = mangaHtmlText(
      document.querySelector('.kol-series-editorial__prose[itemprop="description"]') ??
          document.querySelector('.kol-series-editorial__synopsis-preview'),
    );
    final author = mangaHtmlText(document.querySelector('.kol-series-editorial__byline a'));
    final status = mangaHtmlText(document.querySelector('.kol-series-editorial__status'));
    final type = mangaHtmlText(document.querySelector('.kol-series-editorial__facts dl dd a'));
    final genres = document
        .querySelectorAll('.kol-series-editorial__genres a')
        .map(mangaHtmlText)
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final totalChapters = _numberText(_factValue(document, 'الفصول'));
    final rating = _rating(document);
    final nativeTitle = document.querySelector('meta[property="og:title"]')
            ?.attributes['content'] ??
        '';
    final chapters = await _loadRecentChapters(seriesUrl, document);

    final item = this.item(
      title: title,
      url: seriesUrl,
      image: cover,
      type: SourceValues.type(type.isEmpty ? 'novel' : type),
      genres: genres,
      description: description,
      rating: rating,
    )
      ..addAll({
        'native_title': nativeTitle.replaceFirst(RegExp(r'\s*[–-].*$'), '').trim(),
        'synopsis': description,
        'author': author,
        'status': status,
        'release_year': '',
        'total_chapters': totalChapters,
        'latest_chapter_number': chapters.isEmpty ? 0 : chapters.first['number'],
        'chapters': chapters,
      });
    _detailCache[seriesUrl] = item;
    return Map<String, dynamic>.from(item);
  }

  @override
  Future<Map<String, dynamic>?> streams(String url) async => null;

  @override
  Future<Map<String, dynamic>?> chapterContent(String url) async {
    final chapterUrl = mangaAbsoluteUrl(_site, url);
    if (chapterUrl.isEmpty || Uri.tryParse(chapterUrl)?.host != 'kolnovel.com') {
      throw Exception('KolNovel: رابط الفصل غير صالح.');
    }
    final document = await _document(chapterUrl);
    final content = mangaHtmlToReadableText(
      document.querySelector('.epcontent.entry-content')?.innerHtml,
    );
    if (content.trim().isEmpty) {
      throw Exception('KolNovel: لم يتم العثور على نص الفصل.');
    }
    final title = mangaHtmlText(document.querySelector('.kol-chapter-context__title'));
    final previous = _navigation(document, 'السابق');
    final next = _navigation(document, 'التالي');
    return {
      'title': title,
      'content': content,
      'previous_chapter': previous,
      'next_chapter': next,
      'url': chapterUrl,
    };
  }

  List<Map<String, dynamic>> _archiveItems(Document document) {
    final results = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final coverLink in document.querySelectorAll(
      'a.kol-series-archive__cover',
    )) {
      final article = coverLink.parent?.parent;
      if (article == null) continue;
      final url = mangaAbsoluteUrl(_site, coverLink.attributes['href']);
      if (url.isEmpty || !seen.add(url)) continue;
      final title = mangaHtmlText(article.querySelector(
        '[data-kol-series-title-source], h3 a',
      ));
      if (title.isEmpty) continue;
      final image = mangaImageUrl(article.querySelector('img'), _site);
      final genres = article
          .querySelectorAll('.kol-series-archive__genres-list span')
          .where((span) => span.attributes['aria-hidden'] != 'true')
          .map(mangaHtmlText)
          .where((value) => value.isNotEmpty && value != '·')
          .toList(growable: false);
      final status = mangaHtmlText(article.querySelector('.kol-series-archive__status'));
      final rating = mangaHtmlText(article.querySelector('.kol-series-archive__rating'))
          .replaceAll('★', '')
          .trim();
      final synopsis = mangaHtmlText(article.querySelector('.kol-series-archive__excerpt'));
      final entry = item(
        title: title,
        url: url,
        image: image,
        type: 'novel',
        genres: genres,
        description: synopsis,
        rating: rating,
      );
      entry.addAll({
        'status': status,
        // The archive cards do not expose a chapter count; keep it empty
        // instead of accidentally treating the rating as a chapter number.
        'total_chapters': '',
        'native_title': title,
      });
      results.add(entry);
    }
    return results;
  }

  Future<List<Map<String, dynamic>>> _loadRecentChapters(
    String seriesUrl,
    Document baseDocument,
  ) async {
    final cached = _chapterCache[seriesUrl];
    if (cached != null) return cached;
    final chapters = <Map<String, dynamic>>[];
    final seen = <String>{};
    void collect(Document document) {
      for (final link in document.querySelectorAll(
        'a[data-kol-chapter-transition-link]',
      )) {
        final id = link.attributes['data-kol-chapter-id']?.trim() ?? '';
        final href = mangaAbsoluteUrl(_site, link.attributes['href']);
        final classes = link.attributes['class'] ?? '';
        if (id.isEmpty || href.isEmpty || classes.contains('--start')) continue;
        final parentClass = link.parent?.attributes['class'] ?? '';
        if (!parentClass.contains('kol-series-chapter') &&
            !parentClass.contains('chapter-shortcuts')) continue;
        if (!seen.add(id)) continue;
        final text = mangaHtmlText(link);
        final number = mangaChapterNumber(text) ?? mangaChapterNumber(id) ?? 0;
        chapters.add({
          'title': text.isEmpty ? 'الفصل $number' : text,
          'number': number,
          'chapter_number': number,
          'url': href,
          'release_date': _dateFromText(text),
          'date': _dateFromText(text),
        });
      }
    }

    collect(baseDocument);
    final latestVolume = baseDocument.querySelector('details[data-kol-chapter-volume]')
        ?.attributes['data-kol-chapter-volume'];
    if (latestVolume != null && latestVolume.isNotEmpty) {
      final uri = Uri.parse(seriesUrl).replace(
        queryParameters: {'chapter_volume': latestVolume, 'chapter_page': '1'},
      );
      try {
        collect(await _document(uri.toString()));
      } catch (_) {
        // The base page still contains the first and last chapter shortcuts.
      }
    }
    chapters.sort((left, right) =>
        (mangaChapterNumber('${right['number']}') ?? 0)
            .compareTo(mangaChapterNumber('${left['number']}') ?? 0));
    _chapterCache[seriesUrl] = chapters;
    return chapters;
  }

  String _seriesUrl(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.host != 'kolnovel.com') return '';
    final parts = uri.pathSegments.where((part) => part.isNotEmpty).toList();
    final index = parts.indexOf('series');
    if (index < 0 || index + 1 >= parts.length) return '';
    return Uri.parse(_site).replace(path: '/series/${parts[index + 1]}/').toString();
  }

  String _navigation(Document document, String label) {
    for (final link in document.querySelectorAll('a')) {
      if (mangaHtmlText(link) == label) return mangaAbsoluteUrl(_site, link.attributes['href']);
    }
    return '';
  }

  String _rating(Document document) {
    for (final element in document.querySelectorAll('[class*="rating"], [aria-label*="تقييم"]')) {
      final value = SourceValues.rating(mangaHtmlText(element));
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _factValue(Document document, String label) {
    for (final row in document.querySelectorAll('.kol-series-editorial__facts dl div')) {
      if (mangaHtmlText(row.querySelector('dt')) == label) {
        return mangaHtmlText(row.querySelector('dd'));
      }
    }
    return '';
  }

  String _numberText(String value) {
    final normalized = value
        .replaceAll('٠', '0').replaceAll('١', '1').replaceAll('٢', '2')
        .replaceAll('٣', '3').replaceAll('٤', '4').replaceAll('٥', '5')
        .replaceAll('٦', '6').replaceAll('٧', '7').replaceAll('٨', '8')
        .replaceAll('٩', '9');
    return RegExp(r'\d[\d٬,\.]*').firstMatch(normalized)?.group(0)
            ?.replaceAll(RegExp(r'[^0-9.]'), '') ??
        '';
  }

  String _dateFromText(String value) {
    final match = RegExp(r'\b\d{1,2}/\d{1,2}/\d{4}\b').firstMatch(value);
    return match?.group(0) ?? '';
  }

  Future<Document> _document(String url) async {
    final response = await _client
        .get(Uri.parse(url), headers: _headers)
        .timeout(_requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('KolNovel: فشل طلب المصدر (${response.statusCode}).');
    }
    return html_parser.parse(
      utf8.decode(response.bodyBytes, allowMalformed: true),
    );
  }
}
