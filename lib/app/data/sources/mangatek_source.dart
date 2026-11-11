import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import 'manga_html_utils.dart';
import 'mangatek_bundle_seeds.dart';
import 'mangatek_fingerprint.dart';
import 'mangatek_overlay_crypto.dart';
import 'source_base.dart';
import 'source_values.dart';

/// Adapter for the Arabic MangaTek extension (Keiyoushi).
class MangaTekSource extends ContentSource {
  static const _site = 'https://mangatek.com';
  MangaTekSource({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final Map<String, Future<MangatekBundleSeeds>> _readerSeedCache = {};

  @override
  String get id => 'mangatek';
  @override
  String get name => 'MangaTek';
  @override
  String get kind => 'manga';
  @override
  List<String> get hosts => const ['mangatek.com'];
  @override
  bool handles(String url) =>
      url.startsWith('mangatek://') || super.handles(url);

  @override
  Future<List<Map<String, dynamic>>> search(String query) =>
      _list(page: 1, query: query);

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) =>
      _list(page: page);

  @override
  Future<List<Map<String, dynamic>>> nextPage(
          {String query = '', int page = 2}) =>
      _list(page: page, query: query);

  Future<List<Map<String, dynamic>>> _list(
      {required int page, String query = ''}) async {
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
    return document
        .querySelectorAll('.flex-grow .grid a')
        .map((anchor) {
          final title = (anchor.querySelector('h3')?.attributes['title'] ??
                  mangaHtmlText(anchor.querySelector('h3')))
              .trim();
          final url = mangaAbsoluteUrl(_site, anchor.attributes['href']);
          final image = mangaImageUrl(anchor.querySelector('img'), _site);
          return _item(title, url, image);
        })
        .where((item) =>
            item['title'].toString().isNotEmpty &&
            item['url'].toString().isNotEmpty)
        .toList(growable: false);
  }

  Map<String, dynamic> _apiItem(Map<String, dynamic> manga) {
    final slug = '${manga['slug'] ?? ''}'.trim();
    final title = '${manga['title_ar'] ?? manga['title'] ?? ''}'.trim();
    final result = _item(
      title,
      'mangatek://series?slug=${Uri.encodeQueryComponent(slug)}',
      _coverUrl(_firstImageValue(manga, const [
        'cover_image',
        'cover',
        'cover_url',
        'coverUrl',
        'image',
        'image_url',
        'poster',
      ])),
      type: _typeFromData(manga),
    );
    result.addAll({
      'native_title': '${manga['title'] ?? ''}',
      'alternate_titles': manga['alternative_titles'] ?? '',
      'author': '${manga['author'] ?? ''}',
      'status': _status('${manga['status'] ?? ''}'),
      'total_chapters': manga['chapters_count'] ?? manga['chapter_count'] ?? 0,
      if (_dateValue(manga['latest_chapter_at'] ??
              manga['latest_chapter_date'] ??
              manga['updated_at'] ??
              manga['updatedAt'])
          .isNotEmpty)
        'latest_chapter_date': _dateValue(manga['latest_chapter_at'] ??
            manga['latest_chapter_date'] ??
            manga['updated_at'] ??
            manga['updatedAt']),
      if (manga['latest_chapter_number'] != null &&
          '${manga['latest_chapter_number']}' != '0')
        'latest_chapter_number': manga['latest_chapter_number'],
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
      final description = mangaHtmlText(document.querySelector(
          'div.grid p, p.text-gray-300, div.description, div.synopsis'));
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
      )..addAll({
          'description': description,
          'synopsis': description,
          'genres': document
              .querySelectorAll('div.flex.gap-2 span.text-gray-300')
              .map(mangaHtmlText)
              .where((tag) => tag.isNotEmpty)
              .toList(),
          'status': mangaHtmlText(document.querySelector('span.border')),
          'rating': _htmlRating(document),
          'total_chapters': chapters.length,
          'latest_chapter_number':
              chapters.isEmpty ? '' : chapters.first['number'] ?? '',
          'latest_chapter_date':
              chapters.isEmpty ? '' : chapters.first['release_date'] ?? '',
          'chapters': chapters,
        });
    }
    final chapters =
        _chapters(manga['MangaChapters'] ?? manga['chapters'], slug);
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
        'cover_image',
        'cover',
        'cover_url',
        'coverUrl',
        'image',
        'image_url',
        'poster',
      ])),
      type: _typeFromData(manga),
    )..addAll({
        'description': description,
        'synopsis': description,
        'genres': genres,
        'author': '${manga['author'] ?? ''}',
        'status': _status('${manga['status'] ?? ''}'),
        'rating': SourceValues.rating(manga['rating'] ??
            manga['rating_score'] ??
            manga['average_rating'] ??
            manga['score']),
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
    final readerUrl =
        '$_site/reader/${Uri.encodeComponent(parts.$1)}/${Uri.encodeComponent(parts.$2)}';
    final document = await _document(readerUrl);
    final props = _astroValue(document, 'imageUrls');
    if (props is Map) {
      final propsMap = Map<String, dynamic>.from(props);
      final embedded = _readerImages(propsMap['imageUrls']);
      final hasPendingPages = embedded.any((image) => image['pending'] == true);
      final hasReaderApiCredentials = propsMap['chapterId'] != null &&
          '${propsMap['unlockToken'] ?? ''}'.isNotEmpty;
      final requiresCompleteReaderApi =
          hasPendingPages || hasReaderApiCredentials;
      var fetched = const <Map<String, dynamic>>[];
      if (requiresCompleteReaderApi) {
        // If the reader advertised server-backed credentials, its embedded
        // list cannot be assumed complete. Fail closed rather than silently
        // hiding chapter pages when that endpoint is unavailable.
        fetched = await _fetchReaderImages(document, propsMap, parts);
      }
      if (requiresCompleteReaderApi && fetched.isEmpty) {
        throw Exception(
          'MangaTek: تعذر جلب جميع صفحات الفصل؛ لن تُعرض قائمة ناقصة.',
        );
      }
      // Prefer the endpoint's complete chapter list whenever available.
      final images = fetched.isNotEmpty
          ? fetched
          : embedded.where((image) => image['pending'] != true).toList();
      if (images.any((image) => image['pending'] == true)) {
        throw Exception('MangaTek: استجابة صفحات الفصل ما زالت غير مكتملة.');
      }
      final pages = images
          .where((image) => image['isTrap'] != true)
          .map((image) => '${image['url'] ?? ''}')
          .where((image) => image.isNotEmpty)
          .toList(growable: false);
      if (pages.isNotEmpty) {
        final overlays = await _overlayPages(propsMap, document);
        final pagesWithOverlays = pages.asMap().entries.map((entry) {
          final bubbleList = overlays[entry.key];
          if (bubbleList == null || bubbleList.isEmpty) return entry.value;
          return Uri.parse(entry.value)
              .replace(
                fragment: jsonEncode(bubbleList),
              )
              .toString();
        }).toList(growable: false);
        return {
          'title': 'الفصل ${parts.$2}',
          'chapter_number': parts.$2,
          'pages': pagesWithOverlays,
          'images': pagesWithOverlays.map((page) => {'url': page}).toList(),
          'url': url,
        };
      }
    }
    // The working MangaPeak parser reads the rendered reader images directly.
    // MangaTek does not consistently expose an Astro imageUrls payload.
    final seen = <String>{};
    final pages = document
        .querySelectorAll([
          'div.manga-page img[src]',
          'div.manga-page img[data-url]',
          'div.manga-page img[data-zoom-src]',
          'div.manga-page img[data-src]',
          'div.manga-page img[srcset]',
          'div.manga-page img[data-srcset]',
          'div.manga-page source[srcset]',
          '.reader-content img[src]',
          '.reader-content img[data-url]',
          '.reader-content img[data-zoom-src]',
          '.reader-content img[data-src]',
          '.reader-content img[srcset]',
          '.reader-content source[srcset]',
          '.reader-content img[data-lazy-src]',
          '.reader-content img[data-lazy-srcset]',
          '.reader-content source[data-srcset]',
          '.reader-content source[data-lazy-srcset]',
          'div.manga-page img[data-lazy-src]',
          'div.manga-page img[data-lazy-srcset]',
          'div.manga-page source[data-srcset]',
          'div.manga-page source[data-lazy-srcset]',
          '[data-page] img[src]',
          '[data-page] img[data-url]',
          '[data-page] img[data-zoom-src]',
          '[data-page] img[data-src]',
        ].join(', '))
        .map((image) => mangaImageUrl(image, _site))
        .where((image) => image.isNotEmpty && seen.add(image))
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

  List<Map<String, dynamic>> _readerImages(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((entry) {
          if (entry is String) {
            return {'url': entry, 'pending': false, 'isTrap': false};
          }
          if (entry is Map) {
            final raw = Map<String, dynamic>.from(entry);
            return {
              'url': '${raw['url'] ?? ''}',
              'pending': raw['pending'] == true,
              'isTrap': raw['isTrap'] == true,
            };
          }
          return <String, dynamic>{};
        })
        .where((entry) =>
            '${entry['url'] ?? ''}'.isNotEmpty || entry['pending'] == true)
        .toList();
  }

  Future<List<Map<String, dynamic>>> _fetchReaderImages(
    Document document,
    Map<String, dynamic> props,
    (String, String) parts,
  ) async {
    final chapterId = props['chapterId'];
    final token = '${props['unlockToken'] ?? ''}';
    final mangaSlug = '${props['mangaSlug'] ?? parts.$1}';
    final chapterRef = '${props['chapterRef'] ?? parts.$2}';
    if (chapterId == null || token.isEmpty) {
      throw Exception('MangaTek: بيانات اعتماد صفحات القارئ غير مكتملة.');
    }
    final seeds = await _readerSeeds(document);
    final proof = MangaTekOverlayCrypto.proof(
      seeds.proofSalt,
      token,
      chapterId,
    );
    final fingerprint = await MangaTekFingerprint.create();
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Origin': _site,
      'Referer':
          '$_site/reader/${Uri.encodeComponent(parts.$1)}/${Uri.encodeComponent(parts.$2)}',
      'User-Agent': MangaTekFingerprint.userAgent,
      if (fingerprint != null) ...fingerprint.headers,
    };
    final response = await _client
        .post(
          Uri.parse('https://api.mangatek.com/api/reader/pages'),
          headers: headers,
          body: jsonEncode({
            'chapterId': chapterId,
            'mangaSlug': mangaSlug,
            'chapterNumber': chapterRef,
            'token': token,
            'proof': proof,
          }),
        )
        .timeout(const Duration(seconds: 25));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'MangaTek: فشل جلب جميع صفحات الفصل (${response.statusCode}).',
      );
    }
    final decoded =
        jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true));
    final data = decoded is Map ? decoded['data'] : null;
    final images = _readerImages(data);
    if (images.isEmpty || images.any((image) => image['pending'] == true)) {
      throw Exception('MangaTek: أعاد API صفحات غير مكتملة للفصل.');
    }
    return images;
  }

  Future<Map<int, List<Map<String, dynamic>>>> _overlayPages(
    Map<String, dynamic> props,
    Document document,
  ) async {
    final blob = '${props['overlayBlob'] ?? ''}';
    String? decodedOverlay;
    if (blob.isNotEmpty && blob.contains(':')) {
      try {
        decodedOverlay = await MangaTekOverlayCrypto.decryptHexBlob(blob);
      } catch (_) {
        // Newer reader bundles may provide an envelope through unlock below.
      }
    }
    if (decodedOverlay == null && props['textMode'] == 'overlay') {
      try {
        decodedOverlay = await _unlockOverlay(document, props);
      } catch (_) {
        // Keep the image pages readable if the site's optional text layer is
        // denied or requires an interactive challenge unavailable to the app.
        return const {};
      }
    }
    if (decodedOverlay == null || decodedOverlay.isEmpty) return const {};
    try {
      final decoded = jsonDecode(decodedOverlay);
      final pages = decoded is Map ? decoded['pages'] : null;
      if (pages is! List) return const {};
      final offset = int.tryParse('${props['overlayPageOffset'] ?? 0}') ?? 0;
      return {
        for (final page in pages.whereType<Map>())
          offset +
              (int.tryParse(
                      '${page['page_number'] ?? page['pageNumber'] ?? 0}') ??
                  0) -
              1: (page['overlays']
                  is List
              ? page['overlays']
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList()
              : const <Map<String, dynamic>>[]),
      };
    } catch (_) {
      return const {};
    }
  }

  Future<String?> _unlockOverlay(
    Document document,
    Map<String, dynamic> props,
  ) async {
    final chapterId = props['chapterId'];
    final token = '${props['unlockToken'] ?? ''}';
    if (chapterId == null || token.isEmpty) return null;
    final seeds = await _readerSeeds(document);
    final fingerprint = await MangaTekFingerprint.create();
    if (fingerprint == null) return null;
    final proof = MangaTekOverlayCrypto.proof(
      seeds.proofSalt,
      token,
      chapterId,
    );
    final body = <String, dynamic>{
      'chapterId': chapterId,
      'token': token,
      'proof': proof,
      'esid': MangaTekOverlayCrypto.esid(seeds.readerSeed),
      'fpc': fingerprint.fpc,
    };
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Origin': _site,
      'Referer': _site,
      'User-Agent': MangaTekFingerprint.userAgent,
      ...fingerprint.headers,
    };
    var response = await _postReaderJson(
      'https://api.mangatek.com/api/reader/unlock',
      body,
      headers,
    );
    if (response['needs_challenge'] == true) {
      final nonce = '${response['nonce'] ?? ''}';
      final powBits = int.tryParse('${response['pow_bits'] ?? ''}') ?? 0;
      if (nonce.isEmpty || powBits <= 0) return null;
      final pow = await _proofOfWork(nonce, powBits);
      if (pow == null) return null;
      if (response['turnstile_required'] == true) {
        // Do not forge or bypass a Turnstile challenge. A browser-based token
        // flow can be added independently if MangaTek requires it here.
        return null;
      }
      body.addAll({'nonce': nonce, 'pow': pow});
      response = await _postReaderJson(
        'https://api.mangatek.com/api/reader/unlock',
        body,
        headers,
      );
    }
    if (response['denied'] == true) return null;
    final encrypted = '${response['overlay'] ?? ''}';
    if (encrypted.isEmpty) return null;
    final keySeed = response['ks'] == null ? null : '${response['ks']}';
    final key = response['key'] == null ? null : '${response['key']}';
    if (keySeed != null) {
      return MangaTekOverlayCrypto.decryptEnvelope(
        readerSeed: seeds.readerSeed,
        overlay: encrypted,
        keySeed: keySeed,
        token: token,
        chapterId: chapterId,
      );
    }
    if (key != null) {
      return MangaTekOverlayCrypto.decryptHexBlob(encrypted, keyHex: key);
    }
    return null;
  }

  Future<Map<String, dynamic>> _postReaderJson(
    String url,
    Map<String, dynamic> body,
    Map<String, String> headers,
  ) async {
    final response = await _client
        .post(Uri.parse(url), headers: headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 25));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('MangaTek reader API failed (${response.statusCode}).');
    }
    final decoded =
        jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true));
    if (decoded is! Map) {
      throw const FormatException('Invalid reader API response.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<String?> _proofOfWork(String nonce, int bits) async {
    if (bits <= 0) return null;
    for (var counter = 0; counter < 5000000; counter++) {
      final answer = counter.toRadixString(36);
      final digest = sha256.convert(utf8.encode('$nonce:$answer')).bytes;
      var zeroBits = 0;
      for (final byte in digest) {
        if (byte == 0) {
          zeroBits += 8;
          continue;
        }
        var mask = 0x80;
        while ((byte & mask) == 0) {
          zeroBits++;
          mask >>= 1;
        }
        break;
      }
      if (zeroBits >= bits) return answer;
      if (counter % 10000 == 0) {
        await Future<void>.delayed(Duration.zero);
      }
    }
    return null;
  }

  Future<MangatekBundleSeeds> _readerSeeds(Document document) async {
    final component = document
        .querySelector('astro-island[component-url*="ChapterImageViewer"]')
        ?.attributes['component-url'];
    if (component == null || component.isEmpty) {
      throw const MangatekBundleSeedsException(
        'Unable to locate the MangaTek reader bundle.',
      );
    }
    final bundleUrl = mangaAbsoluteUrl(_site, component);
    if (bundleUrl.isEmpty) {
      throw const MangatekBundleSeedsException('Invalid reader bundle URL.');
    }
    final pending = _readerSeedCache.putIfAbsent(bundleUrl, () async {
      final response = await _client.get(Uri.parse(bundleUrl), headers: const {
        'Accept': 'application/javascript',
        'User-Agent': MangaTekFingerprint.userAgent,
      }).timeout(const Duration(seconds: 25));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw MangatekBundleSeedsException(
          'Could not load reader bundle (${response.statusCode}).',
        );
      }
      final script = utf8.decode(response.bodyBytes, allowMalformed: true);
      return extractMangatekBundleSeeds(script);
    });
    try {
      return await pending;
    } catch (_) {
      _readerSeedCache.remove(bundleUrl);
      rethrow;
    }
  }

  Map<String, dynamic> _item(
    String title,
    String url,
    String image, {
    String type = 'manga',
  }) =>
      item(
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
    for (final element
        in document.querySelectorAll('p, li, dt, dd, span, div')) {
      final match = label.firstMatch(mangaHtmlText(element));
      if (match != null) return match.group(1)!.trim();
    }
    return '';
  }

  List<Map<String, dynamic>> _chapters(dynamic value, String slug) {
    if (value is! List) return const [];
    final chapters = value
        .map((entry) {
          final raw = entry is Map
              ? Map<String, dynamic>.from(entry)
              : <String, dynamic>{};
          final number =
              '${raw['chapter_number'] ?? raw['number'] ?? mangaChapterNumber('${raw['title'] ?? ''}') ?? ''}';
          final title = '${raw['title'] ?? 'الفصل $number'}'.trim();
          final releaseDate = _dateValue(raw['created_at'] ??
              raw['createdAt'] ??
              raw['release_date'] ??
              raw['releaseDate'] ??
              raw['published_at'] ??
              raw['publishedAt']);
          return <String, dynamic>{
            'title': title.isEmpty ? 'الفصل $number' : title,
            'number': num.tryParse(number) ?? number,
            'chapter_number': num.tryParse(number) ?? number,
            'release_date': releaseDate,
            'date': releaseDate,
            'url':
                'mangatek://chapter?slug=${Uri.encodeQueryComponent(slug)}&number=${Uri.encodeQueryComponent(number)}',
          };
        })
        .where((entry) => entry['number'].toString().isNotEmpty)
        .toList();
    chapters.sort((left, right) {
      final leftDate = DateTime.tryParse('${left['release_date'] ?? ''}');
      final rightDate = DateTime.tryParse('${right['release_date'] ?? ''}');
      if (leftDate != null && rightDate != null) {
        final byDate = rightDate.compareTo(leftDate);
        if (byDate != 0) return byDate;
      }
      final leftNumber = mangaChapterNumber('${left['number']}');
      final rightNumber = mangaChapterNumber('${right['number']}');
      if (leftNumber == null) return rightNumber == null ? 0 : 1;
      if (rightNumber == null) return -1;
      return rightNumber.compareTo(leftNumber);
    });
    return chapters;
  }

  List<Map<String, dynamic>> _chaptersFromHtml(Document document, String slug) {
    final chapters = document
        .querySelectorAll('div.manga-chapter a, div.grid a[href^="/reader/"]')
        .map((element) {
          final href = element.attributes['href'] ?? '';
          final title = mangaHtmlText(element.querySelector('h3'));
          final number = mangaChapterNumber(title.isEmpty ? href : title);
          if (href.isEmpty || number == null) return <String, dynamic>{};
          final dateNode =
              element.querySelector('time[datetime], .chapter-date, .date') ??
                  element.parent
                      ?.querySelector('time[datetime], .chapter-date, .date');
          final releaseDate = mangaDateFromUnixSeconds(
            dateNode?.attributes['datetime'] ?? mangaHtmlText(dateNode),
          );
          return <String, dynamic>{
            'title': title.isEmpty ? 'الفصل $number' : title,
            'number': number,
            'chapter_number': number,
            'release_date': releaseDate,
            'date': releaseDate,
            'url':
                'mangatek://chapter?slug=${Uri.encodeQueryComponent(slug)}&number=${Uri.encodeQueryComponent('$number')}',
          };
        })
        .where((entry) => entry.isNotEmpty)
        .toList();
    chapters.sort((left, right) {
      final leftDate = DateTime.tryParse('${left['release_date'] ?? ''}');
      final rightDate = DateTime.tryParse('${right['release_date'] ?? ''}');
      if (leftDate != null && rightDate != null) {
        final byDate = rightDate.compareTo(leftDate);
        if (byDate != 0) return byDate;
      }
      final leftNumber = mangaChapterNumber('${left['number'] ?? ''}');
      final rightNumber = mangaChapterNumber('${right['number'] ?? ''}');
      if (leftNumber == null) return rightNumber == null ? 0 : 1;
      if (rightNumber == null) return -1;
      return rightNumber.compareTo(leftNumber);
    });
    return chapters;
  }

  String _dateValue(dynamic value) =>
      mangaDateFromUnixSeconds(SourceValues.text(value));

  String _htmlRating(Document document) {
    final raw = document
            .querySelector('[itemprop=ratingValue]')
            ?.attributes['content'] ??
        document.querySelector('[data-rating]')?.attributes['data-rating'] ??
        mangaHtmlText(
            document.querySelector('.rating, .rate, .rating-value, #rating'));
    return SourceValues.rating(raw);
  }

  Future<Document> _document(String url) async {
    final response = await _client.get(Uri.parse(url), headers: const {
      'Accept': 'text/html,application/xhtml+xml',
      'Accept-Language': 'ar,en;q=0.8',
      'User-Agent': MangaTekFingerprint.userAgent,
    }).timeout(const Duration(seconds: 25));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('MangaTek: فشل طلب المصدر (${response.statusCode}).');
    }
    return html_parser
        .parse(utf8.decode(response.bodyBytes, allowMalformed: true));
  }

  Future<Map<String, dynamic>> _apiDetails(String value) async {
    final uri = Uri.tryParse(value);
    final slug = uri?.queryParameters['slug'] ?? _slug(_seriesUrl(value));
    var data = <String, dynamic>{};
    final id = uri?.queryParameters['id'];
    if (id != null && id.isNotEmpty) {
      data = _asMap((await _apiGet('/api/manga/$id'))['data']);
    } else {
      final response = await _apiGet('/api/manga',
          query: {'search': slug, 'page': '1', 'limit': '20'});
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
    if (data.isEmpty) {
      throw Exception('MangaTek: لم يتم العثور على تفاصيل المانجا.');
    }
    final actualSlug = '${data['slug'] ?? slug}';
    final chapters =
        _chapters(data['MangaChapters'] ?? data['chapters'], actualSlug);
    final description =
        '${data['description'] ?? data['description_cool'] ?? data['description_sid'] ?? ''}';
    final cover = _coverUrl(_firstImageValue(data, const [
      'cover_image',
      'cover',
      'cover_url',
      'coverUrl',
      'image',
      'image_url',
      'poster',
    ]));
    return _item(
      '${data['title_ar'] ?? data['title'] ?? ''}',
      'mangatek://series?slug=${Uri.encodeQueryComponent(actualSlug)}',
      cover,
      type: _typeFromData(data),
    )..addAll({
        'description': description,
        'synopsis': description,
        'genres': _tagNames(data['Tags']),
        'author': '${data['author'] ?? ''}',
        'status': _status('${data['status'] ?? ''}'),
        'rating': SourceValues.rating(data['rating'] ??
            data['rating_score'] ??
            data['average_rating'] ??
            data['score']),
        'total_chapters': chapters.length,
        'latest_chapter_number':
            chapters.isEmpty ? '' : chapters.first['number'] ?? '',
        'latest_chapter_date':
            chapters.isEmpty ? '' : chapters.first['release_date'] ?? '',
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

  Future<Map<String, dynamic>> _apiGet(String path,
      {Map<String, String>? query}) async {
    final uri = Uri.parse('https://api.mangatek.com$path')
        .replace(queryParameters: query);
    final response = await _client.get(uri, headers: const {
      'Accept': 'application/json',
      'User-Agent': 'MangaPlus/1.1'
    }).timeout(const Duration(seconds: 25));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('MangaTek API: فشل الطلب (${response.statusCode}).');
    }
    final decoded =
        jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true));
    return decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
  }

  Map<String, dynamic> _astro(Document document, String key) {
    final value = _astroValue(document, key);
    return _asMap(value);
  }

  dynamic _astroValue(Document document, String key) {
    final element = document.querySelector('[props*=$key]');
    final raw = element?.attributes['props'];
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return _unwrap(decoded);
    } catch (_) {
      return null;
    }
  }

  dynamic _unwrap(dynamic value) {
    if (value is List && value.length == 2 && value.first is String) {
      return _unwrap(value[1]);
    }
    if (value is List) return value.map(_unwrap).toList();
    if (value is Map) {
      return value.map((key, item) => MapEntry(key, _unwrap(item)));
    }
    return value;
  }

  Map<String, dynamic> _asMap(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  String _seriesUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri?.scheme == 'mangatek') {
      return '$_site/manga/${Uri.encodeComponent(uri!.queryParameters['slug'] ?? '')}';
    }
    if (uri != null && uri.host.contains('mangatek.com')) return uri.toString();
    return '';
  }

  String _slug(String value) =>
      Uri.parse(value).pathSegments.where((part) => part.isNotEmpty).last;

  (String, String)? _chapterParts(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'mangatek') return null;
    final slug = uri.queryParameters['slug'] ?? '';
    final number = uri.queryParameters['number'] ?? '';
    return slug.isEmpty || number.isEmpty ? null : (slug, number);
  }

  String _status(String value) => SourceValues.status(value);

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
        final nested =
            _firstImageValue(Map<String, dynamic>.from(value), const [
          'url',
          'src',
          'original',
          'large',
          'desktop',
          'mobile',
        ]);
        if (nested != null && '$nested'.trim().isNotEmpty) return nested;
      } else if (value is List) {
        for (final entry in value) {
          if ('$entry'.trim().isNotEmpty) return entry;
        }
      } else if (value != null &&
          '$value'.trim().isNotEmpty &&
          value != 'null') {
        return value;
      }
    }
    return '';
  }
}
