import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import 'manga_html_utils.dart';
import 'source_base.dart';
import 'source_values.dart';

class CeneleNovelSource extends CeneleSource {
  CeneleNovelSource() : super(isMangaSection: false);
}

class CeneleMangaSource extends CeneleSource {
  CeneleMangaSource() : super(isMangaSection: true);
}

/// Cenele's manga category contains text chapters, so both adapters use the
/// novel reader while remaining separate sources in the app.
abstract class CeneleSource extends ContentSource {
  CeneleSource({required this.isMangaSection});

  static const String _site = 'https://cenele.com';
  static const String _ajax = 'https://cenele.com/wp-admin/admin-ajax.php';
  static final http.Client _client = http.Client();
  static final Map<String, ({DateTime at, List<Map<String, dynamic>> items})>
      _catalogCache = {};
  static final Map<String, Future<List<Map<String, dynamic>>>> _catalogRequests = {};

  final bool isMangaSection;

  String get _scheme => isMangaSection ? 'cenele-manga' : 'cenele-novel';
  String get _catalogPath => isMangaSection
      ? '/cont-genre/%D9%85%D8%A7%D9%86%D8%AC%D8%A7/'
      : '/cont/';

  @override
  String get id => isMangaSection ? 'cenele_manga' : 'cenele_novels';

  @override
  String get name => isMangaSection ? 'Cenele Manga' : 'Cenele Novels';

  @override
  String get kind => isMangaSection ? 'manga' : 'novel';

  @override
  List<String> get hosts => const ['cenele.com'];

  @override
  bool handles(String url) => url.startsWith('$_scheme://') || false;

  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return catalog(page: 1);

    final document = await _document(_catalogUri(page: 1).toString());
    final nonce = _nonce(document);
    final response = await _post({
      'action': 'nhv_manga_suggest',
      'term': normalized,
      'nonce': nonce,
    });
    final decoded = jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true));
    final rawItems = decoded is Map && decoded['success'] == true &&
            decoded['data'] is Map && decoded['data']['items'] is List
        ? decoded['data']['items'] as List
        : const <dynamic>[];
    final matches = rawItems.whereType<Map>().map((raw) {
      final item = Map<String, dynamic>.from(raw);
      return _item(
        title: '${item['title'] ?? ''}',
        url: '${item['url'] ?? ''}',
        image: '${item['thumb'] ?? ''}',
      );
    }).where((item) => '${item['title']}'.trim().isNotEmpty &&
        '${item['url']}'.trim().isNotEmpty).toList(growable: false);
    if (matches.isNotEmpty) return matches;

    // The site's AJAX search is suggestion-based. This fallback keeps Latin
    // title searches working by filtering the source catalog.
    final works = await _loadCatalog();
    final needle = normalized.toLowerCase();
    return works.where((item) {
      final haystack = [item['title'], item['description'], ...((item['genres'] as List?) ?? const [])]
          .join(' ')
          .toLowerCase();
      return haystack.contains(needle);
    }).toList(growable: false);
  }

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) => catalog(page: page);

  @override
  Future<List<Map<String, dynamic>>> catalog({int page = 1}) async {
    final works = await _loadCatalog();
    final safePage = page < 1 ? 1 : page;
    final start = (safePage - 1) * 24;
    if (start >= works.length) return const [];
    return works.skip(start).take(24).toList(growable: false);
  }

  @override
  Future<List<Map<String, dynamic>>> nextPage({String query = '', int page = 2}) =>
      query.trim().isEmpty ? catalog(page: page) : search(query);

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final target = _targetUrl(url);
    if (target.isEmpty) throw Exception('$name: رابط العمل غير صالح.');
    final response = await _request(target);
    final html = utf8.decode(response.bodyBytes, allowMalformed: true);
    final document = html_parser.parse(html);
    final title = mangaHtmlText(document.querySelector('.nhv-novel-title, h1.entry-title'));
    if (title.isEmpty) throw Exception('$name: لم يتم العثور على تفاصيل العمل.');

    final chapters = await _chapters(document, html, target);
    final description = mangaHtmlText(document.querySelector('.nhv-novel-synopsis, .description-summary'));
    final genres = document.querySelectorAll('.nhv-novel-genres a').map(mangaHtmlText)
        .where((value) => value.isNotEmpty).toSet().toList(growable: false);
    final image = mangaImageUrl(document.querySelector('.nhv-novel-cover img, img.wp-post-image'), _site);
    final rating = SourceValues.rating(
      mangaHtmlText(document.querySelector('.nhv-simple-rating__avg, [itemprop=ratingValue]')),
    );
    return _item(title: title, url: target, image: image, genres: genres, rating: rating)
      ..addAll({
        'description': description,
        'synopsis': description,
        'genres': genres,
        'status': _metaValue(document, 'الحالة'),
        'author': _metaValue(document, 'المؤلف'),
        'artist': _metaValue(document, 'المترجم'),
        'total_chapters': chapters.length,
        'latest_chapter_number': chapters.isEmpty ? 0 : chapters.first['number'],
        'chapters': chapters,
      });
  }

  @override
  Future<Map<String, dynamic>?> streams(String url) async => null;

  @override
  Future<Map<String, dynamic>?> chapterContent(String url) async {
    final target = _targetUrl(url);
    if (target.isEmpty) throw Exception('$name: رابط الفصل غير صالح.');
    final response = await _request(target);
    final document = html_parser.parse(utf8.decode(response.bodyBytes, allowMalformed: true));
    final paragraphs = document
        .querySelectorAll('.reading-content story-layer > p')
        .map(mangaHtmlText)
        .where((value) => value.isNotEmpty && value != '*****')
        .toList(growable: false);
    if (paragraphs.isEmpty) throw Exception('$name: لم يتم العثور على نص الفصل.');
    final chapterTitle = mangaHtmlText(document.querySelector('.chapter-name'));
    final previous = _internalChapter(document.querySelector('.nhv-chapter-nav a.prev_page')?.attributes['href']);
    final next = _internalChapter(document.querySelector('.nhv-chapter-nav a.next_page')?.attributes['href']);
    return {
      'title': chapterTitle.isEmpty ? 'الفصل' : chapterTitle,
      'chapter_number': mangaChapterNumber(chapterTitle) ?? '',
      'content': paragraphs.join('\n\n'),
      'previousChapter': previous,
      'nextChapter': next,
      'chapters': const <Map<String, dynamic>>[],
      'url': url,
    };
  }

  Future<List<Map<String, dynamic>>> _loadCatalog() async {
    final cached = _catalogCache[id];
    if (cached != null && DateTime.now().difference(cached.at) < const Duration(minutes: 10)) {
      return cached.items;
    }
    final inFlight = _catalogRequests[id];
    if (inFlight != null) return inFlight;
    final request = _fetchCatalog();
    _catalogRequests[id] = request;
    try {
      final items = await request;
      _catalogCache[id] = (at: DateTime.now(), items: items);
      return items;
    } finally {
      if (identical(_catalogRequests[id], request)) _catalogRequests.remove(id);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchCatalog() async {
    final first = await _document(_catalogUri(page: 1).toString());
    final pages = _pageCount(first);
    final documents = <Document>[first];
    if (pages > 1) {
      documents.addAll(await Future.wait([
        for (var page = 2; page <= pages && page <= 100; page++)
          _document(_catalogUri(page: page).toString()),
      ]));
    }
    final seen = <String>{};
    final results = <Map<String, dynamic>>[];
    for (final document in documents) {
      for (final card in document.querySelectorAll('article.nhv-library-card')) {
        final anchor = card.querySelector('.nhv-library-card__cover, .nhv-library-card__title a');
        final href = anchor?.attributes['href'] ?? '';
        final title = mangaHtmlText(card.querySelector('.nhv-library-card__title a'));
        final image = mangaImageUrl(card.querySelector('img.wp-post-image'), _site);
        if (title.isEmpty || href.isEmpty || !seen.add(href)) continue;
        final genres = card.querySelectorAll('.nhv-library-card__genres a').map(mangaHtmlText)
            .where((value) => value.isNotEmpty).toList(growable: false);
        results.add(_item(
          title: title,
          url: href,
          image: image,
          genres: genres,
          description: mangaHtmlText(card.querySelector('.nhv-library-card__excerpt')),
        ));
      }
    }
    return results;
  }

  Future<List<Map<String, dynamic>>> _chapters(
    Document document,
    String html,
    String seriesUrl,
  ) async {
    final config = _frontConfig(html);
    if (config == null) return _visibleChapters(document, seriesUrl);
    try {
      final metadataResponse = await _post({
        'action': 'nhv_manga_single_chapters_page',
        'nonce': '${config['chaptersNonce'] ?? ''}',
        'manga_id': '${config['postId'] ?? ''}',
        'volume': '-1',
        'page': '1',
        'per_page': '50',
        'meta_only': '1',
        'order': 'desc',
      });
      final metadata = jsonDecode(utf8.decode(metadataResponse.bodyBytes, allowMalformed: true));
      final volumes = metadata is Map && metadata['volumes'] is List
          ? (metadata['volumes'] as List).whereType<Map>().toList()
          : const <Map>[];
      final chapters = <Map<String, dynamic>>[];
      for (final volume in volumes) {
        final number = '${volume['num'] ?? 0}';
        for (var page = 1; page <= 100; page++) {
          final response = await _post({
            'action': 'nhv_manga_single_chapters_page',
            'nonce': '${config['chaptersNonce'] ?? ''}',
            'manga_id': '${config['postId'] ?? ''}',
            'volume': number,
            'page': '$page',
            'per_page': '50',
            'order': 'desc',
          });
          final decoded = jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true));
          if (decoded is! Map || decoded['success'] != true) break;
          final htmlFragment = '${decoded['html'] ?? ''}';
          if (htmlFragment.trim().isEmpty) break;
          final fragment = html_parser.parseFragment(htmlFragment);
          for (final row in fragment.querySelectorAll('li.wp-manga-chapter')) {
            final anchor = row.querySelector('a');
            final rawUrl = anchor?.attributes['href'] ?? '';
            final webUrl = _absoluteUrl(rawUrl);
            if (webUrl.isEmpty) continue;
            final label = mangaHtmlText(anchor);
            final title = mangaHtmlText(row.querySelector('.nhv-chapter-name'));
            final numberValue = mangaChapterNumber(label) ?? mangaChapterNumber(rawUrl) ?? (chapters.length + 1);
            chapters.add({
              'id': row.attributes['data-chapter-id'] ?? '',
              'title': title.isEmpty ? 'الفصل $numberValue' : 'الفصل $numberValue - $title',
              'number': numberValue,
              'chapter_number': numberValue,
              'release_date': mangaHtmlText(row.querySelector('.chapter-release-date')),
              'date': mangaHtmlText(row.querySelector('.chapter-release-date')),
              'url': _internalChapter(webUrl),
            });
          }
          if (decoded['has_more'] != true) break;
        }
      }
      final seen = <String>{};
      return chapters.where((chapter) => seen.add('${chapter['url']}')).toList(growable: false);
    } catch (_) {
      return _visibleChapters(document, seriesUrl);
    }
  }

  List<Map<String, dynamic>> _visibleChapters(Document document, String seriesUrl) =>
      document.querySelectorAll('li.wp-manga-chapter').map((row) {
        final anchor = row.querySelector('a');
        final rawUrl = _absoluteUrl(anchor?.attributes['href'] ?? '');
        final label = mangaHtmlText(anchor);
        final number = mangaChapterNumber(label) ?? mangaChapterNumber(rawUrl) ?? 0;
        final name = mangaHtmlText(row.querySelector('.nhv-chapter-name'));
        return <String, dynamic>{
          'title': name.isEmpty ? 'الفصل $number' : 'الفصل $number - $name',
          'number': number,
          'chapter_number': number,
          'release_date': mangaHtmlText(row.querySelector('.chapter-release-date')),
          'date': mangaHtmlText(row.querySelector('.chapter-release-date')),
          'url': _internalChapter(rawUrl),
        };
      }).where((chapter) => '${chapter['url']}'.isNotEmpty).toList(growable: false);

  Map<String, dynamic> _item({
    required String title,
    required String url,
    String image = '',
    List<String> genres = const [],
    String description = '',
    String rating = '',
  }) => item(
        title: title.trim(),
        url: _internalSeries(url),
        image: image,
        type: 'novel',
        genres: genres,
        description: description,
        rating: rating,
      );

  Uri _catalogUri({required int page}) {
    final path = page <= 1 ? _catalogPath : '${_catalogPath}page/$page/';
    return Uri.parse('$_site$path').replace(queryParameters: {'m_orderby': 'latest'});
  }

  int _pageCount(Document document) {
    final values = document.querySelectorAll('.page-numbers').map(mangaHtmlText)
        .map(int.tryParse).whereType<int>();
    return values.fold(1, (largest, value) => value > largest ? value : largest);
  }

  String _metaValue(Document document, String label) {
    for (final row in document.querySelectorAll('.nhv-novel-meta > div')) {
      final spans = row.querySelectorAll('span');
      final strong = row.querySelector('strong');
      if (spans.any((span) => mangaHtmlText(span).contains(label))) return mangaHtmlText(strong);
    }
    return '';
  }

  Map<String, dynamic>? _frontConfig(String html) {
    final match = RegExp(r'var nhvNovelV2 = (\{.*?\});', dotAll: true).firstMatch(html);
    if (match == null) return null;
    try {
      final decoded = jsonDecode(match.group(1)!);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  String _nonce(Document document) {
    final script = document.querySelector('#nhv-library-js-extra')?.text ?? '';
    final match = RegExp(r'"nonce":"([^"]+)"').firstMatch(script);
    return match?.group(1) ?? '';
  }

  String _internalSeries(String raw) => '$_scheme://series?url=${Uri.encodeQueryComponent(_absoluteUrl(raw))}';

  String _internalChapter(String? raw) {
    final url = _absoluteUrl(raw ?? '');
    return url.isEmpty ? '' : '$_scheme://chapter?url=${Uri.encodeQueryComponent(url)}';
  }

  String _targetUrl(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null) return '';
    if (uri.scheme == _scheme) return _absoluteUrl(uri.queryParameters['url'] ?? '');
    return uri.host == 'cenele.com' || uri.host == 'www.cenele.com' ? uri.toString() : '';
  }

  String _absoluteUrl(String raw) {
    if (raw.trim().isEmpty) return '';
    final value = raw.trim();
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) return uri.toString();
    return Uri.parse(_site).resolve(value).toString();
  }

  Future<Document> _document(String url) async {
    final response = await _request(url);
    return html_parser.parse(utf8.decode(response.bodyBytes, allowMalformed: true));
  }

  Future<http.Response> _request(String url) async {
    final response = await _client.get(Uri.parse(url), headers: _headers).timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('$name: فشل طلب المصدر (${response.statusCode}).');
    }
    return response;
  }

  Future<http.Response> _post(Map<String, String> data) async {
    final response = await _client.post(
      Uri.parse(_ajax),
      headers: {..._headers, 'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8'},
      body: data,
    ).timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('$name: فشل طلب البحث أو الفصول (${response.statusCode}).');
    }
    return response;
  }

  Map<String, String> get _headers => const {
        'Accept': 'text/html,application/xhtml+xml,application/json',
        'Accept-Language': 'ar,en;q=0.8',
        'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/131 Mobile Safari/537.36',
      };
}
