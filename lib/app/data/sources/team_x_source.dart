import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import 'manga_html_utils.dart';
import 'source_base.dart';
import 'source_values.dart';

// Adapted from IWatch-main/lib/sources/team_x_source.dart (GNU GPL-3.0).
// MangaPlus changes: Team X catalog filtering, validated chapter identifiers,
// chapter navigation metadata, and image request headers.
/// Read-only HTML adapter for the Arabic Team X manga catalog.
class TeamXSource extends ContentSource {
  TeamXSource({http.Client? client}) : _client = client ?? http.Client();

  static const String _site = 'https://olympustaff.com';
  static const Map<String, String> pageHeaders = {
    'Accept': 'text/html,application/xhtml+xml',
    'Accept-Language': 'ar,en;q=0.8',
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/131 Mobile Safari/537.36',
  };
  static const Map<String, String> imageHeaders = {
    'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
    'Referer': 'https://olympustaff.com/',
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/131 Mobile Safari/537.36',
  };
  static const int _latestFeedPageSize = 40;
  static const int _dateLookupConcurrency = 8;
  static final Map<String, List<Map<String, dynamic>>> _chapterCache = {};
  static final Map<String, Map<String, dynamic>> _seriesBriefCache = {};
  final http.Client _client;
  final Map<String, Map<String, dynamic>> _latestChapterMetadataCache = {};

  @override
  String get id => 'team_x_manga';
  @override
  String get name => 'Team X';
  @override
  String get kind => 'manga';
  @override
  List<String> get hosts => const ['olympustaff.com'];
  @override
  bool handles(String url) => url.startsWith('teamx://') || super.handles(url);

  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return const [];
    final uri = Uri.parse('$_site/search').replace(queryParameters: {'keyword': normalized});
    final document = await _document(uri.toString());
    final items = document.querySelectorAll('div.tx-grid a.tx-card').map((anchor) {
      final title = mangaHtmlText(anchor.querySelector('h3'));
      final url = mangaAbsoluteUrl(_site, anchor.attributes['href']);
      final image = mangaImageUrl(anchor.querySelector('img'), _site)
          .replaceFirst('thumbnail_', '');
      final item = _seriesItem(title, url, image);
      final chapterCount = mangaChapterNumber(
        mangaHtmlText(anchor.querySelector('.tx-badge')),
      );
      final type = mangaHtmlText(anchor.querySelector('.tx-type'));
      if (chapterCount != null) item['total_chapters'] = chapterCount;
      if (type.isNotEmpty) item['type'] = type;
      return item;
    }).where(_validItem).toList();
    return _withSeriesBriefs(items);
  }

  Future<List<Map<String, dynamic>>> searchSuggestions({int limit = 6}) async {
    final safeLimit = limit.clamp(1, 8).toInt();
    final items = (await latest(page: 1)).take(safeLimit).toList();
    return _withSeriesBriefs(items);
  }

  Future<List<Map<String, dynamic>>> _withSeriesBriefs(
    List<Map<String, dynamic>> items,
  ) async {
    final enriched = <Map<String, dynamic>>[];
    for (var start = 0; start < items.length; start += _dateLookupConcurrency) {
      final end = start + _dateLookupConcurrency < items.length
          ? start + _dateLookupConcurrency
          : items.length;
      enriched.addAll(await Future.wait(items.sublist(start, end).map((item) async {
        final seriesUrl = _seriesUrl('${item['url'] ?? ''}');
        if (seriesUrl.isEmpty) return item;
        final cached = _seriesBriefCache[seriesUrl];
        if (cached != null) return {...item, ...cached};
        try {
          final brief = _seriesBrief(await _document(seriesUrl));
          _seriesBriefCache[seriesUrl] = brief;
          if (_seriesBriefCache.length > 400) {
            for (final key in _seriesBriefCache.keys.take(200).toList()) {
              _seriesBriefCache.remove(key);
            }
          }
          return {...item, ...brief};
        } catch (_) {
          return item;
        }
      })));
    }
    return enriched;
  }

  Map<String, dynamic> _seriesBrief(Document document) {
    final genres = document
        .querySelectorAll('a[href*="genre="]')
        .map(mangaHtmlText)
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final status = _fieldValue(document, 'الحالة');
    final type = _fieldValue(document, 'النوع');
    final rating = SourceValues.rating(
      mangaHtmlText(document.querySelector('#average_rating')),
    );
    final totalChapters = _chapterCount(document);
    return {
      if (genres.isNotEmpty) 'genres': genres,
      if (status.isNotEmpty) 'status': status,
      if (type.isNotEmpty) 'type': type,
      if (rating.isNotEmpty) 'rating': rating,
      if (totalChapters != null) 'total_chapters': totalChapters,
    };
  }

  num? _chapterCount(Document document) {
    for (final element in document.querySelectorAll(
      '.nav-tabs a, .tabs a, .nav-item a, .chapter-controls',
    )) {
      final text = mangaHtmlText(element);
      if (text.contains('فصول') || text.toLowerCase().contains('chapter')) {
        final count = mangaChapterNumber(text);
        if (count != null) return count;
      }
    }
    return null;
  }

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) async {
    final safePage = page < 1 ? 1 : page;
    final url = safePage == 1 ? '$_site/' : '$_site/?page=$safePage';
    final document = await _document(url);
    return document.querySelectorAll('div.last-chapter div.box').map((box) {
      final anchor = box.querySelector('div.info a');
      final title = mangaHtmlText(anchor?.querySelector('h3'));
      final seriesUrl = mangaAbsoluteUrl(_site, anchor?.attributes['href']);
      final image = mangaImageUrl(box.querySelector('div.imgu img'), _site)
          .replaceFirst('thumbnail_', '');
      final chapterAnchor = box.querySelector('div.info ul a[href]');
      final chapterUrl = mangaAbsoluteUrl(_site, chapterAnchor?.attributes['href']);
      final chapterNumber = mangaChapterNumber(mangaHtmlText(chapterAnchor)) ??
          (chapterUrl.isEmpty
              ? null
              : mangaChapterNumber(Uri.parse(chapterUrl).pathSegments.last));
      final item = _seriesItem(title, seriesUrl, image);
      if (chapterNumber != null) item['latest_chapter_number'] = chapterNumber;
      if (chapterUrl.isNotEmpty) {
        item['latest_chapter_url'] = _internalChapter(
          chapterUrl,
          seriesUrl: seriesUrl,
          title: chapterNumber == null ? 'الفصل' : 'الفصل $chapterNumber',
        );
      }
      return item;
    }).where(_validItem).toList();
  }

  Future<List<Map<String, dynamic>>> latestWithChapterDates({int page = 1}) async {
    final items = (await latest(page: page)).take(_latestFeedPageSize).toList();
    final enriched = <Map<String, dynamic>>[];
    for (var start = 0; start < items.length; start += _dateLookupConcurrency) {
      final end = start + _dateLookupConcurrency < items.length
          ? start + _dateLookupConcurrency
          : items.length;
      enriched.addAll(await Future.wait(
        items.sublist(start, end).map(_withLatestChapterDate),
      ));
    }
    return _sortByLatestChapterDate(enriched);
  }

  List<Map<String, dynamic>> _sortByLatestChapterDate(
    List<Map<String, dynamic>> items,
  ) {
    final indexed = items.asMap().entries.toList();
    indexed.sort((leftEntry, rightEntry) {
      final left = DateTime.tryParse(
        '${leftEntry.value['latest_chapter_date'] ?? ''}'.trim(),
      );
      final right = DateTime.tryParse(
        '${rightEntry.value['latest_chapter_date'] ?? ''}'.trim(),
      );
      if (left == null) {
        return right == null ? leftEntry.key.compareTo(rightEntry.key) : 1;
      }
      if (right == null) return -1;
      final byDate = right.compareTo(left);
      return byDate == 0 ? leftEntry.key.compareTo(rightEntry.key) : byDate;
    });
    return indexed.map((entry) => entry.value).toList(growable: false);
  }

  Future<Map<String, dynamic>> _withLatestChapterDate(
    Map<String, dynamic> item,
  ) async {
    if ('${item['latest_chapter_date'] ?? ''}'.isNotEmpty) return item;
    final seriesUrl = _seriesUrl('${item['url'] ?? ''}');
    if (seriesUrl.isEmpty) return item;
    final chapterNumber = item['latest_chapter_number'] is num
        ? item['latest_chapter_number'] as num
        : mangaChapterNumber('${item['latest_chapter_number'] ?? ''}');
    final cacheKey = '$seriesUrl|${chapterNumber ?? 'latest'}';
    final cached = _latestChapterMetadataCache[cacheKey];
    if (cached != null) return {...item, ...cached};

    try {
      final metadata = await _latestChapterMetadata(seriesUrl, chapterNumber);
      if (metadata == null) return item;
      if ('${metadata['latest_chapter_date'] ?? ''}'.isNotEmpty) {
        _latestChapterMetadataCache[cacheKey] = metadata;
        if (_latestChapterMetadataCache.length > 600) {
          final oldKeys = _latestChapterMetadataCache.keys.take(300).toList();
          for (final key in oldKeys) {
            _latestChapterMetadataCache.remove(key);
          }
        }
      }
      return {...item, ...metadata};
    } catch (_) {
      // Keep the listing usable when one series page is unavailable.
      return item;
    }
  }

  Future<Map<String, dynamic>?> _latestChapterMetadata(
    String seriesUrl,
    num? targetNumber,
  ) async {
    final firstPage = await _document(seriesUrl);
    final seriesMetadata = _seriesBriefCache.putIfAbsent(
      seriesUrl,
      () => _seriesBrief(firstPage),
    );
    if (targetNumber != null) {
      final exact = _chapterCard(firstPage, targetNumber);
      if (exact != null) return {..._chapterMetadata(exact), ...seriesMetadata};
    }

    final lastPage = _lastChapterPage(firstPage);
    if (lastPage > 1 && lastPage <= 100) {
      final uri = Uri.parse(seriesUrl);
      final lastPageUrl = uri.replace(
        queryParameters: {...uri.queryParameters, 'page': '$lastPage'},
      );
      final document = await _document(lastPageUrl.toString());
      final card = _chapterCard(document, targetNumber) ??
          (targetNumber == null ? _chapterCard(document, null) : null);
      if (card != null) return {..._chapterMetadata(card), ...seriesMetadata};
    }

    final fallback = _chapterCard(firstPage, null);
    if (fallback != null) return {..._chapterMetadata(fallback), ...seriesMetadata};
    return seriesMetadata.isEmpty ? null : seriesMetadata;
  }

  Element? _chapterCard(Document document, num? targetNumber) {
    Element? latest;
    num? latestNumber;
    for (final card in document.querySelectorAll(
      'div.chapter-card, .chapter-list .chapter-item, .chapters-list .chapter-item, [data-number].chapter',
    )) {
      final number = mangaChapterNumber(
        card.attributes['data-number'] ??
            card.attributes['data-chapter-number'] ??
            card.attributes['data-chapter'] ??
            mangaHtmlText(card.querySelector('.chapter-number, .chapter-num, [data-number]')),
      );
      if (number == null) continue;
      if (targetNumber != null && number == targetNumber) return card;
      if (latestNumber == null || number > latestNumber) {
        latest = card;
        latestNumber = number;
      }
    }
    return targetNumber == null ? latest : null;
  }

  int _lastChapterPage(Document document) => document
      .querySelectorAll('ul.pagination a.page-link')
      .map((anchor) => int.tryParse(mangaHtmlText(anchor)))
      .whereType<int>()
      .fold<int>(1, (largest, value) => value > largest ? value : largest);

  Map<String, dynamic> _chapterMetadata(Element card) {
    final number = mangaChapterNumber(
      card.attributes['data-number'] ??
          mangaHtmlText(card.querySelector('.chapter-number')),
    );
    final rawDate = card.attributes['data-date'] ??
        card.attributes['data-published-at'] ??
        card.attributes['data-created-at'] ??
        card.querySelector('time[datetime]')?.attributes['datetime'] ??
        mangaHtmlText(card.querySelector('.chapter-date, .date, time'));
    final releaseDate = mangaDateFromUnixSeconds(rawDate);
    final title = mangaHtmlText(card.querySelector('.chapter-info .chapter-title, .chapter-title, h3'));
    return {
      if (number != null) 'latest_chapter_number': number,
      if (title.isNotEmpty) 'latest_chapter_name': title,
      'latest_chapter_date': releaseDate,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> catalog({int page = 1}) async {
    return (await catalogPage(page: page)).items;
  }

  Future<TeamXCatalogPage> catalogPage({
    int page = 1,
    String genre = '',
  }) async {
    final safePage = page < 1 ? 1 : page;
    final query = <String, String>{};
    if (genre.trim().isNotEmpty) query['genre'] = genre.trim();
    if (safePage > 1) query['page'] = '$safePage';
    final uri = Uri.parse('$_site/series/').replace(
      queryParameters: query.isEmpty ? null : query,
    );
    final document = await _document(uri.toString());
    final items = document.querySelectorAll('div.listupd div.bsx').map((box) {
      final anchor = box.querySelector('a');
      final title = (anchor?.attributes['title'] ?? '').trim().isNotEmpty
          ? anchor!.attributes['title']!.trim()
          : mangaHtmlText(anchor);
      final seriesUrl = mangaAbsoluteUrl(_site, anchor?.attributes['href']);
      final image = mangaImageUrl(box.querySelector('img'), _site)
          .replaceFirst('thumbnail_', '');
      return _seriesItem(title, seriesUrl, image);
    }).where(_validItem).toList();
    final lastPage = document
        .querySelectorAll('ul.pagination a.page-link')
        .map((anchor) => int.tryParse(mangaHtmlText(anchor)))
        .whereType<int>()
        .fold<int>(safePage, (largest, value) => value > largest ? value : largest);
    return TeamXCatalogPage(
      items: items,
      currentPage: safePage,
      nextPage: safePage < lastPage ? safePage + 1 : null,
    );
  }

  Future<List<Map<String, dynamic>>> genres() async {
    final document = await _document('$_site/series/');
    return document.querySelectorAll('#select_genre option').map((option) {
      final value = (option.attributes['value'] ?? '').trim();
      return {'name': mangaHtmlText(option), 'value': value};
    }).where((entry) =>
        (entry['name']?.toString().isNotEmpty ?? false) &&
        (entry['value']?.toString().isNotEmpty ?? false)).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> nextPage({String query = '', int page = 2}) =>
      query.trim().isEmpty
          ? latest(page: page)
          : page <= 1
              ? search(query)
              : Future.value(const <Map<String, dynamic>>[]);

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final seriesUrl = _seriesUrl(url);
    if (seriesUrl.isEmpty) throw Exception('Team X: رابط المانجا غير صالح.');
    final document = await _document(seriesUrl);
    final title = mangaHtmlText(document.querySelector('div.author-info-title h1'));
    if (title.isEmpty) throw Exception('Team X: لم يتم العثور على تفاصيل هذه المانجا.');

    var description = mangaHtmlText(document.querySelector('div.review-content'));
    if (description.isEmpty) {
      description = mangaHtmlText(document.querySelector('div.review-content p'));
    }
    final genres = document
        .querySelectorAll('div.review-author-info a')
        .map(mangaHtmlText)
        .where((value) => value.isNotEmpty)
        .toList();
    final image = mangaImageUrl(document.querySelector('div.text-right img'), _site)
        .replaceFirst('thumbnail_', '');
    final statusLabel = _fieldValue(document, 'الحالة');
    final artistLabel = _fieldValue(document, 'الرسام');
    final rating = SourceValues.rating(
      mangaHtmlText(document.querySelector('#average_rating')),
    );
    final chapters = await _chapters(document, seriesUrl);
    final latestDate = chapters.isEmpty
        ? ''
        : '${chapters.first['release_date'] ?? ''}';
    final result = _seriesItem(title, seriesUrl, image)
      ..addAll({
        'description': description,
        'synopsis': description,
        'genres': genres,
        'status': statusLabel,
        'artist': artistLabel,
        'updated_on': latestDate,
        if (rating.isNotEmpty) 'rating': rating,
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
    final identifier = Uri.tryParse(url);
    final seriesUrl = _seriesUrl(identifier?.queryParameters['series'] ?? '');
    final document = await _document(chapterUrl);
    final pages = document
        .querySelectorAll('div.image_list canvas, div.image_list img')
        .map((element) => mangaImageUrl(element, _site))
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (pages.isEmpty) throw Exception('Team X: لا توجد صور قراءة في صفحة الفصل.');
    var previousChapter = '';
    String? nextChapter;
    List<Map<String, dynamic>> chapterEntries = const [];
    if (seriesUrl.isNotEmpty) {
      final chapters = _chapterCache[seriesUrl] ??
          await _chapters(await _document(seriesUrl), seriesUrl);
      chapterEntries = chapters
          .map((chapter) => {
                'chapterId': '${chapter['url'] ?? ''}',
                'title': '${chapter['title'] ?? ''}',
                'url': '${chapter['url'] ?? ''}',
              })
          .where((chapter) => '${chapter['chapterId']}'.isNotEmpty)
          .toList(growable: false);
      final index = chapters.indexWhere(
        (chapter) => _chapterUrl('${chapter['url'] ?? ''}') == chapterUrl,
      );
      if (index >= 0 && index + 1 < chapters.length) {
        previousChapter = '${chapters[index + 1]['url']}';
      }
      if (index > 0) nextChapter = '${chapters[index - 1]['url']}';
    }
    final pageTitle = mangaHtmlText(
      document.querySelector('h1, .chapter-title, .head_chapter_name'),
    );
    final requestedTitle = identifier?.queryParameters['title']?.trim() ?? '';
    return {
      'title': pageTitle.isNotEmpty
          ? pageTitle
          : requestedTitle.isNotEmpty
              ? requestedTitle
              : 'الفصل',
      'pages': pages,
      'images': pages.map((image) => {'url': image}).toList(),
      'url': chapterUrl,
      'previousChapter': previousChapter,
      'nextChapter': nextChapter,
      'chapters': chapterEntries,
    };
  }

  Future<List<Map<String, dynamic>>> _chapters(
    Document firstDocument,
    String seriesUrl,
  ) async {
    final pagesToRead = <Document>[firstDocument];
    final lastPage = firstDocument
        .querySelectorAll('ul.pagination a.page-link')
        .map((anchor) => int.tryParse(mangaHtmlText(anchor)))
        .whereType<int>()
        .fold<int>(1, (largest, value) => value > largest ? value : largest);
    if (lastPage > 100) {
      throw Exception('Team X: عدد صفحات الفصول تجاوز حد الأمان.');
    }
    for (var firstPage = 2; firstPage <= lastPage; firstPage += 5) {
      final endPage = firstPage + 4 > lastPage ? lastPage : firstPage + 4;
      final pageUrls = [
        for (var page = firstPage; page <= endPage; page++)
          Uri.parse(seriesUrl).replace(
            queryParameters: {...Uri.parse(seriesUrl).queryParameters, 'page': '$page'},
          ),
      ];
      pagesToRead.addAll(await Future.wait(pageUrls.map((uri) => _document(uri.toString()))));
    }

    final chapters = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final document in pagesToRead) {
      for (final card in document.querySelectorAll(
      'div.chapter-card, .chapter-list .chapter-item, .chapters-list .chapter-item, [data-number].chapter',
    )) {
        if (card.querySelector('span.locked') != null) continue;
        final anchor = card.querySelector('a[href]');
        final rawUrl = (anchor?.attributes['href'] ?? '').trim();
        if (rawUrl.isEmpty || rawUrl == '#') continue;
        final chapterUrl = _validatedSiteUrl(
          mangaAbsoluteUrl(_site, rawUrl),
          series: false,
        );
        if (chapterUrl.isEmpty || !seen.add(chapterUrl)) continue;
        final rawNumber = (card.attributes['data-number'] ?? '').trim();
        final number = mangaChapterNumber(rawNumber) ??
            mangaChapterNumber(mangaHtmlText(card.querySelector('.chapter-title'))) ??
            (chapters.length + 1);
        final chapterTitle = mangaHtmlText(card.querySelector('div.chapter-info div.chapter-title'));
        final releaseDate = mangaDateFromUnixSeconds(card.attributes['data-date'] ?? '');
        chapters.add({
          'title': chapterTitle.isEmpty || chapterTitle == rawNumber
              ? 'الفصل $number'
              : 'الفصل $number - $chapterTitle',
          'number': number,
          'chapter_number': number,
          'release_date': releaseDate,
          'date': releaseDate,
          'source_url': chapterUrl,
        });
      }
    }
    chapters.sort((left, right) =>
        (right['number'] as num).compareTo(left['number'] as num));
    for (final chapter in chapters) {
      chapter['url'] = _internalChapter(
        '${chapter.remove('source_url')}',
        seriesUrl: seriesUrl,
        title: '${chapter['title']}',
      );
    }
    _chapterCache[seriesUrl] = chapters;
    if (_chapterCache.length > 30) _chapterCache.remove(_chapterCache.keys.first);
    return chapters;
  }

  Future<Document> _document(String url) async {
    final response = await _client
        .get(Uri.parse(url), headers: pageHeaders)
        .timeout(const Duration(seconds: 25));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Team X: فشل طلب المصدر (${response.statusCode}).');
    }
    return html_parser.parse(response.body);
  }

  Map<String, dynamic> _seriesItem(String title, String url, String image) => item(
        title: title,
        url: _internalSeries(url),
        image: image,
        type: 'manga',
      );

  bool _validItem(Map<String, dynamic> entry) =>
      (entry['title']?.toString().trim().isNotEmpty ?? false) &&
      (entry['url']?.toString().isNotEmpty ?? false);

  String _fieldValue(Document document, String label) {
    final fields = document.querySelectorAll('.full-list-info small');
    for (var index = 0; index + 1 < fields.length; index++) {
      if (mangaHtmlText(fields[index]).contains(label)) {
        return mangaHtmlText(fields[index + 1]);
      }
    }
    return '';
  }

  String _seriesUrl(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null) return '';
    if (uri.scheme == 'teamx') {
      final target = uri.queryParameters['url'];
      if (target != null) return _validatedSiteUrl(target, series: true);
      return '';
    }
    return _validatedSiteUrl(raw, series: true);
  }

  String _chapterUrl(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null) return '';
    if (uri.scheme == 'teamx') {
      final target = uri.queryParameters['url'];
      if (target != null) return _validatedSiteUrl(target, series: false);
    }
    if (uri.scheme == 'teamx') return '';
    return _validatedSiteUrl(raw, series: false);
  }

  String _validatedSiteUrl(String raw, {required bool series}) {
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme != 'https' || uri.host.toLowerCase() != 'olympustaff.com') {
      return '';
    }
    if (series && !(uri.pathSegments.length >= 2 && uri.pathSegments.first == 'series')) return '';
    if (!series && !(uri.pathSegments.length >= 3 && uri.pathSegments.first == 'series')) return '';
    return uri.toString();
  }

  String _internalSeries(String url) {
    final validated = _validatedSiteUrl(url, series: true);
    if (validated.isEmpty) return '';
    return Uri(
      scheme: 'teamx',
      host: 'series',
      queryParameters: {'url': validated},
    ).toString();
  }

  String _internalChapter(
    String url, {
    String? seriesUrl,
    String? title,
  }) {
    final validated = _validatedSiteUrl(url, series: false);
    if (validated.isEmpty) return '';
    return Uri(
      scheme: 'teamx',
      host: 'chapter',
      queryParameters: {
        'url': validated,
        if (seriesUrl != null && seriesUrl.isNotEmpty) 'series': seriesUrl,
        if (title != null && title.isNotEmpty) 'title': title,
      },
    ).toString();
  }

  String resolveChapterUrl(String value) => _chapterUrl(value);

  Map<String, String> get imageRequestHeaders => imageHeaders;
}

class TeamXCatalogPage {
  final List<Map<String, dynamic>> items;
  final int currentPage;
  final int? nextPage;

  const TeamXCatalogPage({
    required this.items,
    required this.currentPage,
    required this.nextPage,
  });
}
