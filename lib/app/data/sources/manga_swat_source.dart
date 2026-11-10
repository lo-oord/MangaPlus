import 'dart:convert';
import 'package:http/http.dart' as http;
import 'episode_date_formatter.dart';
import 'source_base.dart';
import 'source_values.dart';

/// Manga Swat public API adapter (appswat.com / meshmanga).
class MangaSwatSource extends ContentSource {
  MangaSwatSource({http.Client? client}) : _client = client ?? http.Client();

  static const String _api = 'https://appswat.com/v2/api/v2';
  final http.Client _client;
  @override
  String get id => 'manga_swat';
  @override
  String get name => 'Manga Swat';
  @override
  String get kind => 'manga';
  @override
  List<String> get hosts => const ['appswat.com', 'meshmanga.com'];
  @override
  bool handles(String url) => url.startsWith('swat://') || super.handles(url);

  @override
  Future<List<Map<String, dynamic>>> search(String query) async => query
          .trim()
          .isEmpty
      ? const []
      : _seriesList(await _json(
          '$_api/series/?search=${Uri.encodeQueryComponent(query.trim())}&page=1'));

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) async {
    final items =
        _seriesList(await _json('$_api/series/?page=${page < 1 ? 1 : page}'));
    return _populateLatestChapterData(items);
  }

  @override
  Future<List<Map<String, dynamic>>> nextPage({
    String query = '',
    int page = 2,
  }) async {
    if (query.trim().isEmpty) return latest(page: page);
    return _seriesList(await _json(
      '$_api/series/?search=${Uri.encodeQueryComponent(query.trim())}&page=$page',
    ));
  }

  @override
  Future<Map<String, dynamic>?> streams(String url) async => null;

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final id = _seriesId(url);
    if (id == null) throw Exception('Manga Swat: invalid series id');
    final data = await _json('$_api/series/$id/');
    if (data is! Map) throw Exception('Manga Swat: invalid series response');
    final poster = data['poster'];
    final image = poster is Map
        ? (poster['medium'] ?? poster['thumbnail'] ?? '').toString()
        : '';
    final genres = _genres(data['genres']);
    final description = _stripTags((data['story'] ?? '').toString());
    final chapters = await _allChapters(id);
    return {
      ...item(
        title: (data['title'] ?? '').toString(),
        url: _seriesUrl(id, (data['slug'] ?? '').toString()),
        image: image,
        type: _type(data['type']),
        genres: genres,
        description: description,
        rating: SourceValues.rating(data),
      ),
      'synopsis': description,
      'status': data['status'] is Map
          ? (data['status']['name'] ?? '').toString()
          : (data['status'] ?? '').toString(),
      'year': data['published'] ?? '',
      'author': data['author'] ?? '', 'artist': data['artist'] ?? '',
      // The fetched list is the source of truth; the API counter is only a
      // fallback when the list itself is empty.
      'total_chapters':
          chapters.isEmpty ? data['chapters_count'] ?? 0 : chapters.length,
      'chapters': chapters,
    };
  }

  @override
  Future<Map<String, dynamic>?> chapterImages(String url) async {
    final id = _chapterId(url);
    if (id == null) return null;
    final data = await _json('$_api/chapters/$id/images/');
    final raw = data is List
        ? data
        : data is Map
            ? (data['results'] ?? data['images'] ?? data['data'] ?? const [])
            : const [];
    if (raw is! List)
      return {
        'title': 'الفصل',
        'images': <Map<String, String>>[],
        'chapter_number': id
      };
    final images = <Map<String, String>>[];
    final sorted = raw.whereType<Map>().toList()
      ..sort((a, b) =>
          ((a['order'] as num?) ?? 0).compareTo((b['order'] as num?) ?? 0));
    for (final image in sorted) {
      final src = (image['image'] ?? image['url'] ?? image['src'] ?? '')
          .toString()
          .trim();
      if (src.isNotEmpty) images.add({'url': src});
    }
    return {
      'title': 'الفصل',
      'images': images,
      'pages': images.map((entry) => entry['url']).toList(),
      'chapter_number': id,
      'url': url
    };
  }

  Future<List<Map<String, dynamic>>> _allChapters(int seriesId) async {
    final chapters = <Map<String, dynamic>>[];
    final visited = <String>{};
    String? next = '$_api/series/$seriesId/chapters/';
    while (next != null && next.isNotEmpty && visited.add(next)) {
      final uri = Uri.parse(next);
      if (uri.host.isEmpty) next = Uri.parse('$_api/').resolve(next).toString();
      final data = await _json(next);
      if (data is! Map) break;
      final results = data['results'];
      if (results is! List) break;
      for (final raw in results.whereType<Map>()) {
        final id = raw['id'];
        if (id == null) continue;
        final title = (raw['title'] ?? '').toString();
        final rawNumber = (raw['chapter'] ?? '').toString();
        final number = _chapterNumber('$rawNumber $title');
        final releaseDate = _releaseDate(raw);
        chapters.add({
          'id': id,
          'chapter_id': id,
          'title': title.isEmpty
              ? (number == null ? 'فصل' : 'الفصل $number')
              : title,
          'number': number,
          'chapter_number': number ?? rawNumber,
          'release_date': releaseDate,
          'date': releaseDate,
          'url': 'swat://chapter/$id',
        });
      }
      final rawNext = data['next'];
      next = rawNext == null || rawNext.toString().isEmpty
          ? null
          : Uri.parse(next).resolve(rawNext.toString()).toString();
      if (visited.length > 1000)
        throw Exception('Manga Swat: pagination limit exceeded');
    }
    chapters.sort((a, b) {
      final left =
          _chapterNumber('${a['number'] ?? a['chapter_number'] ?? ''}');
      final right =
          _chapterNumber('${b['number'] ?? b['chapter_number'] ?? ''}');
      if (left == null) return right == null ? 0 : 1;
      if (right == null) return -1;
      return right.compareTo(left);
    });
    return chapters;
  }

  Future<dynamic> _json(String url) async {
    final response = await _client.get(Uri.parse(url), headers: const {
      'Accept': 'application/json',
      'User-Agent': 'Mozilla/5.0 IWatch/1.0'
    }).timeout(const Duration(seconds: 25));
    if (response.statusCode < 200 || response.statusCode >= 300)
      throw Exception('Manga Swat request failed (${response.statusCode})');
    return jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true));
  }

  Future<List<Map<String, dynamic>>> _populateLatestChapterData(
    List<Map<String, dynamic>> items,
  ) async {
    // The series listing often omits latest_chapter entirely. Fetch one chapter
    // per series in small concurrent batches instead of downloading every page.
    for (var start = 0; start < items.length; start += 4) {
      final batch = items.skip(start).take(4);
      await Future.wait(batch.map(_populateLatestChapterDataForItem));
    }
    return items;
  }

  Future<void> _populateLatestChapterDataForItem(
    Map<String, dynamic> item,
  ) async {
    final id = int.tryParse('${item['manga_id'] ?? ''}');
    if (id == null ||
        ('${item['latest_chapter_date'] ?? ''}'.isNotEmpty &&
            item['latest_chapter_number'] != null)) {
      return;
    }
    try {
      final uri = Uri.parse('$_api/series/$id/chapters/').replace(
        queryParameters: const {'page_size': '1'},
      );
      final data = await _json(uri.toString());
      if (data is! Map || data['results'] is! List) return;
      final results = data['results'] as List;
      if (results.isEmpty || results.first is! Map) return;
      final chapter = Map<String, dynamic>.from(results.first as Map);
      final date = _releaseDate(chapter);
      if (date.isNotEmpty &&
          '${item['latest_chapter_date'] ?? ''}'.isEmpty) {
        item['latest_chapter_date'] = date;
      }
      final number = chapter['chapter'] ?? chapter['number'];
      if (number != null && item['latest_chapter_number'] == null) {
        item['latest_chapter_number'] = number;
      }
      final title = '${chapter['title'] ?? ''}'.trim();
      if (title.isNotEmpty &&
          '${item['latest_chapter_name'] ?? ''}'.isEmpty) {
        item['latest_chapter_name'] = title;
      }
    } catch (_) {
      // Keep the series visible if its chapter metadata endpoint is unavailable.
    }
  }

  List<Map<String, dynamic>> _seriesList(dynamic data) {
    if (data is! Map || data['results'] is! List) return const [];
    return (data['results'] as List)
        .whereType<Map>()
        .map((raw) {
          final id = raw['id'];
          final poster = raw['poster'];
          final image = poster is Map
              ? (poster['medium'] ?? poster['thumbnail'] ?? '').toString()
              : '';
          final latestChapter = raw['latest_chapter'] is Map
              ? Map<String, dynamic>.from(raw['latest_chapter'])
              : <String, dynamic>{};
          final releaseDate = _releaseDate(latestChapter);
          final latestNumber = latestChapter.isNotEmpty
              ? latestChapter['chapter'] ?? latestChapter['number']
              : raw['latest_chapter'];
          return item(
            title: (raw['title'] ?? '').toString(),
            url: _seriesUrl(id, (raw['slug'] ?? '').toString()),
            image: image,
            type: _type(raw['type']),
            genres: _genres(raw['genres']),
            rating: SourceValues.rating(raw),
          )..addAll({
              'manga_id': id,
              'status':
                  raw['status'] is Map ? raw['status']['name'] : raw['status'],
              'total_chapters': raw['chapters_count'] ?? 0,
              if (latestNumber != null) 'latest_chapter_number': latestNumber,
              if (releaseDate.isNotEmpty) 'latest_chapter_date': releaseDate,
              if ((latestChapter['title'] ?? '').toString().isNotEmpty)
                'latest_chapter_name': latestChapter['title'],
            });
        })
        .where((entry) => entry['title'].toString().trim().isNotEmpty)
        .toList();
  }

  List<String> _genres(dynamic raw) => raw is List
      ? raw
          .map((entry) => entry is Map
              ? (entry['name'] ?? '').toString()
              : entry.toString())
          .where((name) => name.trim().isNotEmpty)
          .toList()
      : const [];
  String _releaseDate(Map raw) {
    for (final key in const [
      'created_at',
      'createdAt',
      'published',
      'published_at',
      'publishedAt',
      'release_date',
      'releaseDate',
      'date',
      'timestamp',
    ]) {
      final value = raw[key];
      if (value == null) continue;
      final date = EpisodeDateFormatter.normalize(value);
      if (date.isNotEmpty) return date;
    }
    return '';
  }

  String _type(dynamic value) => SourceValues.type(value);
  String _stripTags(String value) => value
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  double? _chapterNumber(String value) {
    final match = RegExp(r'\d+(?:\.\d+)?').firstMatch(value);
    return match == null ? null : double.tryParse(match.group(0)!);
  }

  String _seriesUrl(dynamic id, String slug) =>
      'swat://series/$id/${slug.isEmpty ? id : slug}';
  int? _seriesId(String url) {
    final uri = Uri.tryParse(url);
    if (uri?.scheme == 'swat' &&
        uri!.host == 'series' &&
        uri.pathSegments.isNotEmpty)
      return int.tryParse(uri.pathSegments.first);
    final mesh =
        RegExp(r'(?:appswat\.com|meshmanga\.com)/series/(\d+)').firstMatch(url);
    if (mesh != null) return int.tryParse(mesh.group(1)!);
    return int.tryParse(url);
  }

  int? _chapterId(String url) {
    final uri = Uri.tryParse(url);
    if (uri?.scheme == 'swat' &&
        uri!.host == 'chapter' &&
        uri.pathSegments.isNotEmpty)
      return int.tryParse(uri.pathSegments.first);
    return int.tryParse(url);
  }
}
