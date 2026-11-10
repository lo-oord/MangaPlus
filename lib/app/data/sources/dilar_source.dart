import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;

import 'source_base.dart';
import 'source_values.dart';

/// Read-only adapter for Dilar's Arabic manga catalogue API.
///
/// Dilar exposes JSON endpoints for catalogue data and decrypts chapter page
/// manifests in its reader JavaScript. The reader adapter captures that
/// decrypted manifest instead of substituting the chapter thumbnail.
class DilarSource extends ContentSource {
  DilarSource({http.Client? client}) : _client = client ?? http.Client();

  static const String _site = 'https://dilar.tube';
  static const String _novelTypeId = '99';
  static const Map<String, String> _headers = {
    'Accept': 'application/json, text/plain, */*',
    'Accept-Language': 'ar,en;q=0.8',
    'Content-Type': 'application/json',
    'Origin': _site,
    'Referer': '$_site/',
    'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/131.0.0.0 Mobile Safari/537.36',
    'X-Requested-With': 'XMLHttpRequest',
  };

  final http.Client _client;

  @override
  String get id => 'dilar';

  @override
  String get name => 'Dilar';

  @override
  String get kind => 'manga';

  @override
  List<String> get hosts => const ['dilar.tube'];

  @override
  bool handles(String url) {
    if (url.toLowerCase().startsWith('dilar://')) return true;
    return super.handles(url);
  }

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
    final normalized = query.trim();
    if (normalized.isEmpty) return const [];
    if (page > 1) return _searchFilter(normalized, page: page);
    final response = await _postValue('/api/search/quick_search', {
      'query': normalized,
      'includes': const ['Manga'],
      'lite': false,
      'synonyms': 'matched',
    });
    if (response is! List) return const [];
    final rows = <Map<String, dynamic>>[];
    for (final group in response.whereType<Map>()) {
      if (_text(group['class']) != 'Manga' || group['data'] is! List) continue;
      rows.addAll(
        (group['data'] as List)
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .where((row) => !_isNovel(row)),
      );
    }
    final results = <Map<String, dynamic>>[];
    for (var start = 0; start < rows.length && start < 10; start += 5) {
      final end = start + 5 < rows.length ? start + 5 : rows.length;
      results.addAll(
        await Future.wait(rows.sublist(start, end).map(_enrichSearchResult)),
      );
    }
    return results
        .where((item) => item['title'].toString().isNotEmpty)
        .toList();
  }

  Future<Map<String, dynamic>> _enrichSearchResult(
    Map<String, dynamic> row,
  ) async {
    final id = _text(row['id']);
    if (id.isNotEmpty) {
      try {
        return _seriesItem(
          await _get('/api/series/${Uri.encodeComponent(id)}'),
        );
      } catch (_) {
        // Keep the quick-search result usable when rating/details are throttled.
      }
    }
    return _seriesItem(row);
  }

  Future<List<Map<String, dynamic>>> _searchFilter(
    String normalized, {
    required int page,
  }) async {
    final response = await _post('/api/search/filter', {
      'query': normalized,
      'page': page,
      'seriesType': {
        'include': <String>[],
        'exclude': <String>[_novelTypeId],
      },
      'categories': {'include': <int>[], 'exclude': <int>[]},
      'oneshot': false,
      'storyStatus': {'include': <String>[], 'exclude': <String>[]},
      'translationStatus': {'include': <String>[], 'exclude': <String>[]},
      'over17': null,
    });
    final rows = response['rows'];
    if (rows is! List) return const [];
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .where((row) => !_isNovel(row))
        .map(_seriesItem)
        .where((item) => item['title'].toString().isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) async {
    final response = await _get(
      '/api/series',
      query: {'page': '${page < 1 ? 1 : page}'},
    );
    final rows = response['series'];
    if (rows is! List) return const [];
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .where((row) => !_isNovel(row))
        .map(_seriesItem)
        .where((item) => item['title'].toString().isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<List<Map<String, dynamic>>> catalog({int page = 1}) async {
    if (page > 1) return latest(page: page);
    final response = await _get('/api/rankings');
    final rows = response['topSeries'];
    if (rows is! List) return latest(page: page);
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .where((row) => !_isNovel(row))
        .map(_seriesItem)
        .where((item) => item['title'].toString().isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final id = _seriesId(url);
    if (id.isEmpty) {
      throw ArgumentError.value(url, 'url', 'Dilar series URL is invalid');
    }
    final series = await _get('/api/series/${Uri.encodeComponent(id)}');
    final chaptersResponse = await _get(
      '/api/series/${Uri.encodeComponent(id)}/chapters',
    );
    final chapterGroups = chaptersResponse['chapters'];
    final chapters = <Map<String, dynamic>>[];
    if (chapterGroups is List) {
      for (final rawGroup in chapterGroups.whereType<Map>()) {
        final group = Map<String, dynamic>.from(rawGroup);
        final releases = group['releases'];
        if (releases is! List || releases.isEmpty) {
          final chapter = _chapter(
            group,
            const <String, dynamic>{},
            id,
            series,
          );
          if (chapter != null) chapters.add(chapter);
          continue;
        }
        for (final rawRelease in releases.whereType<Map>()) {
          final chapter = _chapter(
            group,
            Map<String, dynamic>.from(rawRelease),
            id,
            series,
          );
          if (chapter != null) chapters.add(chapter);
        }
      }
    }
    chapters.sort((a, b) => _chapterNumber(b).compareTo(_chapterNumber(a)));
    final result = _seriesItem(series);
    final latestReleaseDate = chapters.isEmpty
        ? _text(series['updated_at'])
        : _text(chapters.first['release_date']);
    result.addAll({
      'url': _seriesUrl(id, series['title']),
      'manga_id': id,
      'series_id': id,
      'synopsis': _text(series['summary']),
      'native_title': _nativeTitle(series),
      'alternate_titles': _alternateTitles(series['synonyms']),
      'author': _staffNames(series['staff'], 'Author'),
      'artist': _staffNames(series['staff'], 'Artist'),
      'publisher': _text(_map(series['publisher'])?['name']),
      'release_year': _text(series['s_date']).length >= 4
          ? _text(series['s_date']).substring(0, 4)
          : '',
      'total_chapters': chapters.isNotEmpty
          ? chapters.length
          : (series['chapterCount'] ?? series['total_chapters'] ?? 0),
      'latest_chapter_number': chapters.isEmpty
          ? _text(_map(series['latestChapter'])?['chapter'])
          : chapters.first['number'],
      'latest_chapter_date': latestReleaseDate,
      'updated_at': _text(series['updated_at']),
      'chapters': chapters,
    });
    return result;
  }

  @override
  Future<Map<String, dynamic>?> streams(String url) async => null;

  @override
  Future<Map<String, dynamic>?> chapterImages(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !handles(url)) return null;
    final releaseId = _text(uri.queryParameters['release']);
    if (releaseId.isEmpty) {
      throw const FormatException('Dilar: رابط الفصل لا يحتوي على release id.');
    }
    final result = Completer<Map<String, dynamic>>();
    final script = _manifestCaptureScript(releaseId);
    final reader = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(uri.toString())),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
        supportZoom: false,
      ),
      initialUserScripts: UnmodifiableListView<UserScript>([
        UserScript(
          source: script,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
          forMainFrameOnly: true,
        ),
      ]),
      onWebViewCreated: (controller) {
        controller.addJavaScriptHandler(
          handlerName: 'dilarPageManifest',
          callback: (arguments) {
            if (result.isCompleted || arguments.isEmpty) return null;
            try {
              final raw = arguments.first;
              final decoded = raw is String ? jsonDecode(raw) : raw;
              if (decoded is! Map) {
                throw const FormatException('Dilar: صيغة بيانات صفحات الفصل غير صالحة.');
              }
              final manifest = Map<String, dynamic>.from(decoded);
              final pages = pageUrlsFromManifest(manifest);
              if (pages.isEmpty) {
                throw const FormatException('Dilar: لم تُعثر على صور صالحة للفصل.');
              }
              result.complete({
                'title': 'الفصل ${_displayChapterNumber(_chapterLabel(uri))}',
                'chapter_number': _displayChapterNumber(_chapterLabel(uri)),
                'url': uri.toString(),
                'pages': pages,
                'images': pages
                    .map((page) => {'url': page})
                    .toList(growable: false),
              });
            } catch (error, stackTrace) {
              if (!result.isCompleted) result.completeError(error, stackTrace);
            }
            return null;
          },
        );
      },
    );
    try {
      await reader.run();
      return await result.future.timeout(const Duration(seconds: 45));
    } on TimeoutException {
      throw Exception('Dilar: انتهت مهلة تحميل صفحات الفصل.');
    } finally {
      await reader.dispose();
    }
  }

  static String _manifestCaptureScript(String releaseId) {
    final releaseLiteral = jsonEncode(releaseId);
    return '''
      (() => {
        const originalParse = JSON.parse;
        const targetRelease = $releaseLiteral;
        const capture = (root) => {
          const pending = [root];
          const visited = new Set();
          while (pending.length) {
            const value = pending.shift();
            if (!value || typeof value !== 'object' || visited.has(value)) continue;
            visited.add(value);
            const release = value.id ?? value.release_id ?? value.releaseId;
            const storageKey = value.storage_key ?? value.storageKey;
            const mediaToken = value.media_token ?? value.mediaToken;
            if (String(release) === targetRelease && storageKey && mediaToken &&
                Array.isArray(value.pages) && value.pages.length && !value.__dilarCaptured) {
              value.__dilarCaptured = true;
              const payload = JSON.stringify({
                storage_key: storageKey, media_token: mediaToken, pages: value.pages
              });
              const send = (attempt) => {
                const bridge = window.flutter_inappwebview;
                if (bridge && bridge.callHandler) {
                  bridge.callHandler('dilarPageManifest', payload);
                } else if (attempt < 40) {
                  setTimeout(() => send(attempt + 1), 100);
                }
              };
              send(0);
              return;
            }
            for (const key of Object.keys(value)) {
              if (value[key] && typeof value[key] === 'object') pending.push(value[key]);
            }
          }
        };
        JSON.parse = function () {
          const value = originalParse.apply(this, arguments);
          try { capture(value); } catch (_) {}
          return value;
        };
      })();
    ''';
  }

  /// Converts Dilar's decrypted manifest to ordered, signed image URLs.
  static List<String> pageUrlsFromManifest(Map<String, dynamic> manifest) {
    final storageKey = _text(manifest['storage_key'] ?? manifest['storageKey']);
    final token = _text(manifest['media_token'] ?? manifest['mediaToken']);
    final rawPages = manifest['pages'];
    if (storageKey.isEmpty || token.isEmpty || rawPages is! List) {
      return const [];
    }
    // Keys and page paths become URL path segments; reject traversal, query
    // fragments and absolute URLs rather than constructing unsafe/bogus paths.
    if (storageKey.contains('/') || storageKey == '.' || storageKey == '..') {
      return const [];
    }
    final entries = <({Map<String, dynamic> page, int index})>[];
    for (var i = 0; i < rawPages.length; i++) {
      final raw = rawPages[i];
      if (raw is! Map) continue;
      final page = Map<String, dynamic>.from(raw);
      final path = _text(page['url'] ?? page['path']);
      final parsed = Uri.tryParse(path);
      if (path.isEmpty || parsed == null || parsed.hasScheme || parsed.hasAuthority ||
          path.startsWith('/') || path.contains('\\') ||
          path.split('/').any((part) => part == '.' || part == '..') ||
          path.contains('?') || path.contains('#')) {
        continue;
      }
      entries.add((page: page, index: i));
    }
    entries.sort((a, b) {
      final orderA = num.tryParse(_text(a.page['order'])) ?? a.index;
      final orderB = num.tryParse(_text(b.page['order'])) ?? b.index;
      final byOrder = orderA.compareTo(orderB);
      return byOrder != 0 ? byOrder : a.index.compareTo(b.index);
    });
    return entries.map((entry) {
      final rawPath = _text(entry.page['url'] ?? entry.page['path']);
      return Uri(
        scheme: 'https',
        host: 'dilar.tube',
        pathSegments: [
          'uploads', 'releases', storageKey, 'hq',
          ...rawPath.split('/').where((part) => part.isNotEmpty),
        ],
        queryParameters: {'t': token},
      ).toString();
    }).toList(growable: false);
  }
  static String _chapterLabel(Uri uri) {
    final segments = uri.pathSegments.where((part) => part.isNotEmpty).toList();
    return segments.isEmpty ? '' : segments.last;
  }

  static String _displayChapterNumber(dynamic value) {
    final number = _text(value);
    return number.endsWith('.00')
        ? number.substring(0, number.length - 3)
        : number;
  }

  Map<String, dynamic> _seriesItem(Map<String, dynamic> raw) {
    final id = _text(raw['id']);
    final title = _text(raw['title']);
    final cover = _coverUrl(id, _text(raw['cover']));
    final categories = _strings(raw['categories']);
    final typeMap = _map(raw['seriesType']) ?? _map(raw['series_type']);
    final type = _text(typeMap?['title']).isEmpty
        ? (id.isNotEmpty && _text(raw['series_type_id']) == _novelTypeId
              ? 'novel'
              : kind)
        : _text(typeMap?['title']);
    final updatedAt = _text(raw['updated_at']);
    final latestChapter = _map(raw['latestChapter']);
    final latestRelease = _map(raw['latestRelease']);
    final releaseDate = _text(latestRelease?['created_at']).isNotEmpty
        ? _text(latestRelease?['created_at'])
        : updatedAt;
    final item = this.item(
      title: title,
      url: _seriesUrl(id, title),
      image: cover,
      type: type,
      genres: categories,
      description: _text(raw['summary']),
      rating: SourceValues.rating(raw['rating']),
    );
    item.addAll({
      'manga_id': id,
      'series_id': id,
      'native_title': _nativeTitle(raw),
      'alternate_titles': _alternateTitles(raw['synonyms']),
      'author': _staffNames(raw['staff'], 'Author'),
      'artist': _staffNames(raw['staff'], 'Artist'),
      'synopsis': _text(raw['summary']),
      'status': _status(raw['translation_status'], raw['story_status']),
      'story_status': _status(raw['story_status'], raw['translation_status']),
      'translation_status': _status(
        raw['translation_status'],
        raw['story_status'],
      ),
      'release_year': _text(raw['s_date']).length >= 4
          ? _text(raw['s_date']).substring(0, 4)
          : '',
      'total_chapters': raw['chapterCount'] ?? raw['total_chapters'] ?? 0,
      'latest_chapter_number': _displayChapterNumber(latestChapter?['chapter']),
      'latest_chapter_date': releaseDate,
      'updated_at': updatedAt,
      'over17': raw['over17'] == true,
      'is_oneshot': raw['is_oneshot'] == true,
    });
    return item;
  }

  Map<String, dynamic>? _chapter(
    Map<String, dynamic> group,
    Map<String, dynamic> release,
    String seriesId,
    Map<String, dynamic> series,
  ) {
    final number = _text(group['chapter']);
    final releaseId = _text(release['id']);
    final chapterId = _text(group['id']);
    if (number.isEmpty || (releaseId.isEmpty && chapterId.isEmpty)) return null;
    final title = _text(group['title']);
    final chapterNumber = number.endsWith('.00')
        ? number.substring(0, number.length - 3)
        : number;
    final slug = _slug(_text(series['title']));
    final path =
        '/reader/${Uri.encodeComponent(seriesId)}/'
        '${Uri.encodeComponent(slug)}/${Uri.encodeComponent(chapterNumber)}';
    final uri = Uri.parse(_site).replace(
      path: path,
      queryParameters: releaseId.isEmpty ? null : {'release': releaseId},
    );
    final thumbnailPath = _text(_map(release['thumbnail_meta'])?['path']);
    final thumbnailName = _text(release['thumbnail']);
    final teamId = _text(release['init_team_id']).isEmpty
        ? '1'
        : _text(release['init_team_id']);
    final thumbnailUrl = thumbnailPath.isNotEmpty
        ? '$_site$thumbnailPath'
        : thumbnailName.isEmpty || releaseId.isEmpty
        ? ''
        : '$_site/uploads/thumbnail/$teamId/$seriesId/$releaseId/$thumbnailName';
    final chapter = <String, dynamic>{
      'url': uri.toString(),
      'chapter_url': uri.toString(),
      'number': num.tryParse(chapterNumber) ?? chapterNumber,
      'chapter_number': chapterNumber,
      'title': 'الفصل $chapterNumber${title.isEmpty ? '' : ' - $title'}',
      'release_date': _text(release['created_at']).isNotEmpty
          ? _text(release['created_at'])
          : _text(group['created_at']),
      'chapter_id': chapterId,
      if (releaseId.isNotEmpty) 'release_id': releaseId,
      'thumbnail': thumbnailUrl,
    };
    return chapter;
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, String>? query,
  }) async {
    final uri = Uri.parse('$_site$path').replace(queryParameters: query);
    final response = await _client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 25));
    return _decodeResponse(response, uri);
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('$_site$path');
    final response = await _client
        .post(uri, headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 25));
    return _decodeResponse(response, uri);
  }

  Future<dynamic> _postValue(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$_site$path');
    final response = await _client
        .post(uri, headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 25));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Dilar: فشل طلب المصدر (${response.statusCode}).');
    }
    return jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true));
  }

  Map<String, dynamic> _decodeResponse(http.Response response, Uri uri) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Dilar: فشل طلب المصدر (${response.statusCode}).');
    }
    final decoded = jsonDecode(
      utf8.decode(response.bodyBytes, allowMalformed: true),
    );
    if (decoded is! Map) {
      throw const FormatException('Dilar: استجابة API غير صالحة.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  static String _seriesId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return '';
    final segments = uri.pathSegments.where((part) => part.isNotEmpty).toList();
    if (segments.isEmpty) return '';
    final seriesIndex = segments.indexOf('series');
    final readerIndex = segments.indexOf('reader');
    final index = seriesIndex >= 0
        ? seriesIndex + 1
        : readerIndex >= 0
        ? readerIndex + 1
        : -1;
    if (index >= 0 && index < segments.length) return segments[index];
    if (uri.scheme == 'dilar' && segments.length >= 2) return segments[1];
    return '';
  }

  static String _seriesUrl(String id, dynamic title) =>
      '$_site/series/${Uri.encodeComponent(id)}/${Uri.encodeComponent(_slug(_text(title)))}';

  static String _coverUrl(String id, String cover) {
    if (id.isEmpty || cover.isEmpty) return '';
    final basename = cover.split('/').last;
    final stem = basename.contains('.')
        ? basename.substring(0, basename.lastIndexOf('.'))
        : basename;
    return '$_site/uploads/manga/cover/${Uri.encodeComponent(id)}/large_${Uri.encodeComponent(stem)}.webp';
  }

  static String _status(dynamic primary, dynamic secondary) {
    final raw = SourceValues.firstText([primary, secondary]).toLowerCase();
    switch (raw) {
      case 'ongoing':
      case 'مستمر':
        return SourceValues.statusOngoing;
      case 'completed':
      case 'complete':
      case 'مكتمل':
        return SourceValues.statusCompleted;
      case 'hiatus':
      case 'متوقف':
        return SourceValues.statusHiatus;
      case 'dropped':
      case 'cancelled':
      case 'canceled':
      case 'ملغي':
      case 'ملغية':
        return SourceValues.statusCancelled;
      case 'upcoming':
      case 'قادم':
        return SourceValues.statusUpcoming;
      default:
        return raw;
    }
  }

  static bool _isNovel(Map<String, dynamic> raw) {
    final type = _map(raw['seriesType']) ?? _map(raw['series_type']);
    final typeId = _text(raw['series_type_id']).isNotEmpty
        ? _text(raw['series_type_id'])
        : _text(type?['id']);
    final typeTitle = _text(type?['title']).toLowerCase();
    return typeId == _novelTypeId ||
        SourceValues.isNovelType(typeTitle) ||
        typeTitle.contains('رواي') ||
        typeTitle.contains('novel');
  }

  static Map<String, dynamic>? _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : null;

  static String _text(dynamic value) => SourceValues.text(value);

  static List<String> _strings(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => _text(item['name']))
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  static String _staffNames(dynamic value, String role) {
    if (value is! List) return '';
    return value
        .whereType<Map>()
        .where((entry) {
          final details = _map(entry['Staff']);
          return _text(details?['role']).toLowerCase() == role.toLowerCase();
        })
        .map((entry) => _text(entry['name']))
        .where((name) => name.isNotEmpty)
        .toSet()
        .join(', ');
  }

  static String _nativeTitle(Map<String, dynamic> series) {
    final synonyms = _map(series['synonyms']);
    final arabic = synonyms?['arabic'];
    if (arabic is List) {
      return arabic
          .map(_text)
          .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    }
    return '';
  }

  static List<String> _alternateTitles(dynamic value) {
    if (value is List) {
      return value
          .map(_text)
          .where((title) => title.isNotEmpty)
          .toSet()
          .toList(growable: false);
    }
    final synonyms = _map(value);
    if (synonyms == null) return const [];
    final titles = <String>[];
    for (final entry in synonyms.entries) {
      final raw = entry.value;
      if (raw is List) titles.addAll(raw.map(_text));
      if (raw is String) titles.add(_text(raw));
    }
    return titles
        .where((title) => title.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  static String _slug(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\u0600-\u06ff]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  static double _chapterNumber(Map<String, dynamic> chapter) =>
      double.tryParse('${chapter['number']}') ?? -1;
}
