import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import 'manga_html_utils.dart';
import 'source_base.dart';
import 'source_values.dart';

/// Read-only adapter for Galaxy Novels, based on its LNReader v3 plugin.
class GalaxyNovelsSource extends ContentSource {
  GalaxyNovelsSource({http.Client? client}) : _client = client ?? http.Client();

  static const String _site = 'https://galaxynovels.com';
  static const String version = '1.1.1';
  static const String iconUrl =
      'https://raw.githubusercontent.com/lnreader/lnreader-plugins/plugins/v3.0.0/public/static/src/ar/galaxynovels/icon.png';
  static const String _searchManifest =
      '$_site/wp-content/uploads/wor-reader-cache/search/manifest.json';
  static const Map<String, String> _headers = {
    'Accept': 'text/html,application/xhtml+xml,application/json',
    'Accept-Language': 'ar,en;q=0.8',
    'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/131 Mobile Safari/537.36',
  };
  static const Duration _timeout = Duration(seconds: 35);
  static const int _searchPageSize = 20;
  static final Map<String, ({DateTime at, Map<String, dynamic> values})>
  _latestMetadataCache = {};
  static final Map<String, Future<Map<String, dynamic>>>
  _latestMetadataRequests = {};

  final http.Client _client;

  @override
  String get id => 'galaxynovels';

  @override
  String get name => 'Galaxy Novels';

  @override
  String get kind => 'novel';

  @override
  List<String> get hosts => const ['galaxynovels.com'];

  @override
  Future<List<Map<String, dynamic>>> search(String query) =>
      _search(query, page: 1);

  @override
  Future<List<Map<String, dynamic>>> nextPage({
    String query = '',
    int page = 2,
  }) => query.trim().isEmpty ? latest(page: page) : _search(query, page: page);

  Future<List<Map<String, dynamic>>> _search(
    String query, {
    required int page,
  }) async {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return const [];
    final manifest = await _json(_searchManifest);
    final indexUrl = _absoluteUrl(_site, '${manifest['index'] ?? ''}');
    if (indexUrl.isEmpty) return const [];
    final index = await _json(indexUrl);
    final rawItems = index['items'];
    if (rawItems is! List) return const [];

    final matching = rawItems
        .whereType<Map>()
        .where((raw) {
          final searchable = [
            raw['t'],
            raw['o'],
            raw['a'],
            raw['s'],
          ].map(SourceValues.text).join(' ').toLowerCase();
          return searchable.contains(needle);
        })
        .toList(growable: false);
    final safePage = page < 1 ? 1 : page;
    final start = (safePage - 1) * _searchPageSize;
    if (start >= matching.length) return const [];
    return matching
        .skip(start)
        .take(_searchPageSize)
        .map((raw) {
          final url = _absoluteUrl(_site, '${raw['u'] ?? ''}');
          if (url.isEmpty) return null;
          final genres = raw['g'] is List
              ? raw['g'] as List
              : const <dynamic>[];
          final result = item(
            title: SourceValues.firstText([raw['t'], raw['o']]),
            url: url,
            image: _absoluteUrl(_site, '${raw['c'] ?? ''}'),
            type: 'novel',
            genres: genres,
            description: '',
          );
          result.addAll({
            'native_title': SourceValues.text(raw['o']),
            'status': SourceValues.text(raw['st']),
            'total_chapters': raw['n'] ?? '',
            // The index's `r` field is its search/ranking score, not a user rating.
          });
          return result;
        })
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) async {
    final safePage = page < 1 ? 1 : page;
    final uri = Uri.parse('$_site/novels/')
        .replace(queryParameters: {'sort': 'new', 'page': '$safePage'});
    return _withLatestMetadata(_archiveItems(await _document(uri.toString())));
  }

  @override
  Future<List<Map<String, dynamic>>> catalog({int page = 1}) =>
      latest(page: page);

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final target = _workUrl(url);
    if (target.isEmpty) throw Exception('$name: رابط الرواية غير صالح.');
    final document = await _document(target);
    final title = mangaHtmlText(document.querySelector('h1'));
    if (title.isEmpty) throw Exception('$name: لم يتم العثور على الرواية.');

    final cover = mangaImageUrl(
      document.querySelector('img.wor-cover-img'),
      _site,
    );
    final author = mangaHtmlText(
      document.querySelector('p.wor-single-hero__meta-text span'),
    );
    final summary = mangaHtmlText(
      document.querySelector('.wor-single-summary__text'),
    );
    final genres = document
        .querySelectorAll('a.wor-tag-pill')
        .map(mangaHtmlText)
        .where((genre) => genre.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final status = _status(document);
    final rating = _rating(
      document.querySelectorAll('[data-current-average]'),
      document.querySelectorAll('[class*="rating"]'),
    );
    final chaptersResult = await _chapters(document, target);
    final chapters = chaptersResult.chapters;
    final latestChapter = chapters.isEmpty ? null : chapters.first;
    final nativeTitle =
        document
            .querySelector('meta[property="og:title"]')
            ?.attributes['content'] ??
        '';

    final result = item(
      title: title,
      url: target,
      image: cover,
      type: 'novel',
      genres: genres,
      description: summary,
      rating: rating,
    );
    result.addAll({
      'native_title': nativeTitle
          .replaceFirst(RegExp(r'\s*[–-].*$'), '')
          .trim(),
      'synopsis': summary,
      'author': author.isEmpty ? 'Unknown' : author,
      'status': status,
      'release_year': _releaseYear(document),
      'total_chapters': chaptersResult.total > 0
          ? chaptersResult.total
          : chapters.length,
      'latest_chapter_number': latestChapter?['number'] ?? '',
      'latest_chapter_date': latestChapter?['release_date'] ?? '',
      'updated_on': latestChapter?['release_date'] ?? '',
      'chapters': chapters,
    });
    return result;
  }

  @override
  Future<Map<String, dynamic>?> streams(String url) async => null;

  @override
  Future<Map<String, dynamic>?> chapterContent(String url) async {
    final target = _chapterUrl(url);
    if (target.isEmpty) throw Exception('$name: رابط الفصل غير صالح.');
    final number = _chapterNumber(target);

    if (number != null) {
      try {
        final payload = await _json(
          '$_site/wp-json/wor-reader-app/v1/chapters/$number',
        );
        final data = payload['data'] is Map
            ? Map<String, dynamic>.from(payload['data'] as Map)
            : payload;
        final rawContent = SourceValues.firstText([
          data['content_html'],
          data['content'],
        ]);
        final content = mangaHtmlToReadableText(rawContent);
        if (content.isNotEmpty) {
          return {
            'title': SourceValues.firstText([data['title'], 'الفصل $number']),
            'content': content,
            'previousChapter': '',
            'nextChapter': '',
            'chapters': const <Map<String, dynamic>>[],
            'url': target,
          };
        }
      } catch (_) {
        // The site's reader endpoint can be unavailable to some clients; use
        // the public chapter page as the same fallback used by the plugin.
      }
    }

    final document = await _document(target);
    document
        .querySelectorAll('[data-wor-decoy], [hidden]')
        .forEach((e) => e.remove());
    final contentElement = document.querySelector(
      '.wor-reader-text-surface, article.wor-chapter-content, '
      '.wor-chapter-text, .entry-content',
    );
    final content = mangaHtmlToReadableText(contentElement?.innerHtml);
    if (content.isEmpty) throw Exception('$name: لم يتم العثور على نص الفصل.');
    return {
      'title': mangaHtmlText(document.querySelector('h1')),
      'content': content,
      'previousChapter': _navigation(document, const ['السابق', 'Previous']),
      'nextChapter': _navigation(document, const ['التالي', 'Next']),
      'chapters': const <Map<String, dynamic>>[],
      'url': target,
    };
  }

  List<Map<String, dynamic>> _archiveItems(Document document) {
    final results = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final card in document.querySelectorAll('article.wor-novel-card')) {
      final anchor = card.querySelector('a.wor-novel-card__cover');
      final url = _absoluteUrl(_site, anchor?.attributes['href'] ?? '');
      final title = mangaHtmlText(card.querySelector('h3 a'));
      if (url.isEmpty || title.isEmpty || !seen.add(url)) continue;
      final genres = card
          .querySelectorAll('a.wor-tag-pill')
          .map(mangaHtmlText)
          .where((value) => value.isNotEmpty)
          .toList(growable: false);
      final chapterTime =
          card.querySelector('time[datetime]')?.attributes['datetime'] ?? '';
      final entry = item(
        title: title,
        url: url,
        image: mangaImageUrl(card.querySelector('img.wor-cover-img'), _site),
        type: 'novel',
        genres: genres,
        description: mangaHtmlText(
          card.querySelector('.wor-single-summary__text'),
        ),
        rating: _rating(
          card.querySelectorAll('[data-current-average]'),
          card.querySelectorAll('[class*="rating"]'),
        ),
      );
      entry.addAll({
        'native_title': title,
        'status': SourceValues.firstText([
          mangaHtmlText(card.querySelector('.wor-novel-card__status')),
          mangaHtmlText(card.querySelector('span.wor-cover-status')),
        ]),
        'latest_chapter_date': chapterTime,
        'updated_on': chapterTime,
        'total_chapters': '',
      });
      results.add(entry);
    }
    return results;
  }

  Future<List<Map<String, dynamic>>> _withLatestMetadata(
    List<Map<String, dynamic>> items,
  ) async {
    final enriched = items.map(Map<String, dynamic>.from).toList();
    const batchSize = 5;
    for (var start = 0; start < enriched.length; start += batchSize) {
      final end = start + batchSize > enriched.length
          ? enriched.length
          : start + batchSize;
      final values = await Future.wait([
        for (final entry in enriched.skip(start).take(end - start))
          _latestMetadata('${entry['url'] ?? ''}')
              .catchError((_) => <String, dynamic>{}),
      ]);
      for (var index = 0; index < values.length; index++) {
        enriched[start + index].addAll(values[index]);
      }
    }
    return enriched;
  }

  Future<Map<String, dynamic>> _latestMetadata(String rawUrl) async {
    final url = _workUrl(rawUrl);
    if (url.isEmpty) return const {};
    final cached = _latestMetadataCache[url];
    if (cached != null &&
        DateTime.now().difference(cached.at) < const Duration(minutes: 10)) {
      return cached.values;
    }
    final inFlight = _latestMetadataRequests[url];
    if (inFlight != null) return inFlight;
    final request = _fetchLatestMetadata(url);
    _latestMetadataRequests[url] = request;
    try {
      final values = await request;
      _latestMetadataCache[url] = (at: DateTime.now(), values: values);
      return values;
    } finally {
      if (identical(_latestMetadataRequests[url], request)) {
        _latestMetadataRequests.remove(url);
      }
    }
  }

  Future<Map<String, dynamic>> _fetchLatestMetadata(String url) async {
    final document = await _document(url);
    final rating = _rating(
      document.querySelectorAll(
        '[data-current-average], [itemprop="ratingValue"], [data-rating]',
      ),
      document.querySelectorAll('[class*="rating"]'),
    );
    final chapterTime = SourceValues.firstText([
      document
          .querySelector('article.wor-novel-chapter-item time[datetime]')
          ?.attributes['datetime'],
      document
          .querySelector('time[data-wor-relative-time][datetime]')
          ?.attributes['datetime'],
      document.querySelector('time[datetime]')?.attributes['datetime'],
    ]);
    final status = _status(document);
    return {
      if (rating.isNotEmpty) 'rating': rating,
      if (status.isNotEmpty) 'status': status,
      if (chapterTime.isNotEmpty) 'latest_chapter_date': chapterTime,
      if (chapterTime.isNotEmpty) 'updated_on': chapterTime,
    };
  }

  String _status(Document document) {
    final coverStatus = mangaHtmlText(
      document.querySelector('span.wor-cover-status'),
    );
    if (coverStatus.isNotEmpty) return coverStatus;
    final identity = document.querySelector(
      '.wor-single-identity__item--status',
    );
    if (identity == null) return '';
    final value = mangaHtmlText(
      identity.querySelector('strong, b, [data-status]'),
    );
    if (value.isNotEmpty) return value;
    return mangaHtmlText(identity).replaceFirst(
      RegExp(r'^(?:الحالة|status)\s*[:：]?\s*', caseSensitive: false),
      '',
    );
  }

  Future<({List<Map<String, dynamic>> chapters, int total})> _chapters(
    Document document,
    String seriesUrl,
  ) async {
    final container = document.querySelector('[data-wor-chapters-container]');
    var total =
        int.tryParse(container?.attributes['data-rendered-total'] ?? '') ?? 0;
    final manifestUrl = _absoluteUrl(
      _site,
      container?.attributes['data-manifest-url'] ?? '',
    );
    if (manifestUrl.isNotEmpty) {
      try {
        final manifest = await _json(manifestUrl);
        total = int.tryParse('${manifest['total'] ?? ''}') ?? total;
        dynamic chapterData = manifest;
        if (manifest['chapters'] is! List) {
          final packUrl = _absoluteUrl(_site, '${manifest['pack_url'] ?? ''}');
          if (packUrl.isNotEmpty) chapterData = await _json(packUrl);
        }
        final rawChapters = chapterData is Map
            ? chapterData['chapters']
            : chapterData;
        if (rawChapters is List) {
          final parsed = rawChapters
              .whereType<Map>()
              .map((entry) => _chapterEntry(entry, seriesUrl))
              .whereType<Map<String, dynamic>>()
              .toList();
          if (parsed.isNotEmpty) {
            parsed.sort(_compareChaptersNewestFirst);
            return (chapters: parsed, total: total > 0 ? total : parsed.length);
          }
        }
      } catch (_) {
        // The rendered list remains useful if the manifest/cache is offline.
      }
    }

    final chapters = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final row in document.querySelectorAll(
      'article.wor-novel-chapter-item',
    )) {
      final anchor = row.querySelector('h3 a, a.wor-novel-chapter-item__num');
      final chapterUrl = _chapterUrl(
        _absoluteUrl(_site, anchor?.attributes['href'] ?? ''),
      );
      if (chapterUrl.isEmpty || !seen.add(chapterUrl)) continue;
      final text = mangaHtmlText(anchor);
      final number = _chapterNumber(chapterUrl) ?? mangaChapterNumber(text);
      final time =
          row.querySelector('time[datetime]')?.attributes['datetime'] ?? '';
      chapters.add({
        'title': text.isEmpty ? 'الفصل ${number ?? ''}' : text,
        'number': number ?? '',
        'chapter_number': number ?? '',
        'url': chapterUrl,
        'release_date': time,
        'date': time,
      });
    }
    chapters.sort(_compareChaptersNewestFirst);
    return (chapters: chapters, total: total > 0 ? total : chapters.length);
  }

  Map<String, dynamic>? _chapterEntry(Map raw, String seriesUrl) {
    final rawUrl = SourceValues.firstText([raw['url']]);
    final chapterUrl = _chapterUrl(_absoluteUrl(seriesUrl, rawUrl));
    if (chapterUrl.isEmpty) return null;
    final number = SourceValues.firstText([
      raw['number'],
      raw['position'],
      _chapterNumber(chapterUrl),
    ]);
    final label = SourceValues.firstText([raw['label'], raw['name']]);
    final title = SourceValues.firstText([raw['title']]);
    final chapterTitle = title.isEmpty
        ? (label.isEmpty ? 'الفصل $number' : label)
        : (label.isEmpty ? title : '$label: $title');
    final releaseDate = SourceValues.firstText([
      raw['date_iso'],
      raw['published_at'],
      raw['updated_at'],
      raw['date'],
    ]);
    return {
      'title': chapterTitle,
      'number': num.tryParse(number) ?? number,
      'chapter_number': num.tryParse(number) ?? number,
      'url': chapterUrl,
      'release_date': releaseDate,
      'date': releaseDate,
    };
  }

  int _compareChaptersNewestFirst(
    Map<String, dynamic> left,
    Map<String, dynamic> right,
  ) {
    final l = num.tryParse('${left['number'] ?? ''}') ?? 0;
    final r = num.tryParse('${right['number'] ?? ''}') ?? 0;
    return r.compareTo(l);
  }

  String _rating(Iterable<Element> values, Iterable<Element> labels) {
    for (final element in values) {
      final value = SourceValues.rating(
        SourceValues.firstText([
          element.attributes['data-current-average'],
          element.attributes['data-rating'],
          element.attributes['content'],
          element.text,
        ]),
      );
      if (value.isNotEmpty) return value;
    }
    for (final element in labels) {
      final value = SourceValues.rating(mangaHtmlText(element));
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _releaseYear(Document document) {
    final published =
        document
            .querySelector('meta[property="article:published_time"]')
            ?.attributes['content'] ??
        '';
    if (published.isNotEmpty) return SourceValues.year(published);
    return '';
  }

  String _navigation(Document document, List<String> labels) {
    for (final link in document.querySelectorAll('a[href]')) {
      final text = mangaHtmlText(link);
      final aria = link.attributes['aria-label']?.trim() ?? '';
      if (labels.any((label) => text.contains(label) || aria.contains(label))) {
        return _chapterUrl(_absoluteUrl(_site, link.attributes['href'] ?? ''));
      }
    }
    return '';
  }

  int? _chapterNumber(String url) {
    final match = RegExp(r'/chapter-(\d+)(?:/|$)').firstMatch(url);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  String _workUrl(String raw) {
    final url = _absoluteUrl(_site, raw);
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !_isGalaxyHost(uri.host) ||
        !uri.pathSegments.contains('novel'))
      return '';
    return uri.replace(host: Uri.parse(_site).host).removeFragment().toString();
  }

  String _chapterUrl(String raw) {
    final url = _absoluteUrl(_site, raw);
    final uri = Uri.tryParse(url);
    if (uri == null || !_isGalaxyHost(uri.host) || _chapterNumber(url) == null)
      return '';
    return uri.replace(host: Uri.parse(_site).host).removeFragment().toString();
  }

  bool _isGalaxyHost(String host) {
    final normalized = host.toLowerCase();
    return normalized == 'galaxynovels.com' ||
        normalized == 'www.galaxynovels.com';
  }

  String _absoluteUrl(String base, String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    final uri = Uri.tryParse(value);
    if (uri == null) return '';
    final resolved = uri.hasScheme ? uri : Uri.parse(base).resolveUri(uri);
    if ((resolved.scheme != 'http' && resolved.scheme != 'https') ||
        resolved.host.isEmpty)
      return '';
    return resolved.toString();
  }

  Future<Document> _document(String url) async => html_parser.parse(
    utf8.decode((await _response(url)).bodyBytes, allowMalformed: true),
  );

  Future<Map<String, dynamic>> _json(String url) async {
    final response = await _response(url);
    final decoded = jsonDecode(
      utf8.decode(response.bodyBytes, allowMalformed: true),
    );
    if (decoded is! Map) throw Exception('$name: استجابة JSON غير صالحة.');
    return Map<String, dynamic>.from(decoded);
  }

  Future<http.Response> _response(String url) async {
    final response = await _client
        .get(Uri.parse(url), headers: _headers)
        .timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('$name: فشل طلب المصدر (${response.statusCode}).');
    }
    return response;
  }
}
