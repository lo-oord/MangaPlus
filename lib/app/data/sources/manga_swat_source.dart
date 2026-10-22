import 'dart:convert';
import 'package:http/http.dart' as http;
import 'episode_date_formatter.dart';
import 'source_base.dart';
import 'source_values.dart';

/// Manga Swat public API adapter (appswat.com / meshmanga).
class MangaSwatSource extends ContentSource {
  static const String _api = 'https://appswat.com/v2/api/v2';
  static final http.Client _client = http.Client();
  @override String get id => 'manga_swat';
  @override String get name => 'Manga Swat';
  @override String get kind => 'manga';
  @override List<String> get hosts => const ['appswat.com', 'meshmanga.com'];
  @override bool handles(String url) => url.startsWith('swat://') || super.handles(url);

  @override
  Future<List<Map<String, dynamic>>> search(String query) async =>
      query.trim().isEmpty ? const [] : _seriesList(await _json('$_api/series/?search=${Uri.encodeQueryComponent(query.trim())}&page=1'));

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) async =>
      _seriesList(await _json('$_api/series/?page=${page < 1 ? 1 : page}'));

  @override
  Future<List<Map<String, dynamic>>> nextPage({String query = '', int page = 2}) async =>
      query.trim().isEmpty
          ? await latest(page: page)
          : _seriesList(await _json('$_api/series/?search=${Uri.encodeQueryComponent(query.trim())}&page=$page'));

  @override
  Future<Map<String, dynamic>?> streams(String url) async => null;

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final id = _seriesId(url);
    if (id == null) throw Exception('Manga Swat: invalid series id');
    final data = await _json('$_api/series/$id/');
    if (data is! Map) throw Exception('Manga Swat: invalid series response');
    final poster = data['poster'];
    final image = poster is Map ? (poster['medium'] ?? poster['thumbnail'] ?? '').toString() : '';
    final genres = _genres(data['genres']);
    final description = _stripTags((data['story'] ?? '').toString());
    return {
      ...item(
        title: (data['title'] ?? '').toString(), url: _seriesUrl(id, (data['slug'] ?? '').toString()),
        image: image, type: _type(data['type']), genres: genres,
        description: description, rating: SourceValues.rating(data),
      ),
      'synopsis': description,
      'status': data['status'] is Map ? (data['status']['name'] ?? '').toString() : (data['status'] ?? '').toString(),
      'year': data['published'] ?? '',
      'author': data['author'] ?? '', 'artist': data['artist'] ?? '',
      'total_chapters': data['chapters_count'] ?? 0,
      'chapters': await _allChapters(id),
    };
  }

  @override
  Future<Map<String, dynamic>?> chapterImages(String url) async {
    final id = _chapterId(url);
    if (id == null) return null;
    final data = await _json('$_api/chapters/$id/images/');
    final raw = data is List ? data : data is Map ? (data['results'] ?? data['images'] ?? data['data'] ?? const []) : const [];
    if (raw is! List) return {'title': 'الفصل', 'images': <Map<String, String>>[], 'chapter_number': id};
    final images = <Map<String, String>>[];
    final sorted = raw.whereType<Map>().toList()
      ..sort((a, b) => ((a['order'] as num?) ?? 0).compareTo((b['order'] as num?) ?? 0));
    for (final image in sorted) {
      final src = (image['image'] ?? image['url'] ?? image['src'] ?? '').toString().trim();
      if (src.isNotEmpty) images.add({'url': src});
    }
    return {'title': 'الفصل', 'images': images, 'pages': images.map((entry) => entry['url']).toList(), 'chapter_number': id, 'url': url};
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
        final number = _chapterNumber('$rawNumber $title') ?? (chapters.length + 1);
        final releaseDate = _releaseDate(raw);
        chapters.add({
          'id': id, 'chapter_id': id, 'title': title.isEmpty ? 'الفصل $number' : title,
          'number': number, 'chapter_number': number, 'release_date': releaseDate,
          'date': releaseDate, 'url': 'swat://chapter/$id',
        });
      }
      final rawNext = data['next'];
      next = rawNext == null || rawNext.toString().isEmpty ? null : Uri.parse(next).resolve(rawNext.toString()).toString();
      if (visited.length > 1000) throw Exception('Manga Swat: pagination limit exceeded');
    }
    chapters.sort((a, b) => ((b['number'] as num).compareTo(a['number'] as num)));
    return chapters;
  }

  Future<dynamic> _json(String url) async {
    final response = await _client.get(Uri.parse(url), headers: const {'Accept': 'application/json', 'User-Agent': 'Mozilla/5.0 IWatch/1.0'}).timeout(const Duration(seconds: 25));
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('Manga Swat request failed (${response.statusCode})');
    return jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true));
  }
  List<Map<String, dynamic>> _seriesList(dynamic data) {
    if (data is! Map || data['results'] is! List) return const [];
    return (data['results'] as List).whereType<Map>().map((raw) {
      final id = raw['id'];
      final poster = raw['poster'];
      final image = poster is Map ? (poster['medium'] ?? poster['thumbnail'] ?? '').toString() : '';
      final latestChapter = raw['latest_chapter'] is Map ? Map<String, dynamic>.from(raw['latest_chapter']) : <String, dynamic>{};
      final releaseDate = _releaseDate(latestChapter.isNotEmpty ? latestChapter : raw);
      return item(
        title: (raw['title'] ?? '').toString(), url: _seriesUrl(id, (raw['slug'] ?? '').toString()),
        image: image, type: _type(raw['type']), genres: _genres(raw['genres']), rating: SourceValues.rating(raw),
      )..addAll({
        'manga_id': id,
        'status': raw['status'] is Map ? raw['status']['name'] : raw['status'],
        'total_chapters': raw['chapters_count'] ?? 0,
        'latest_chapter_number': raw['latest_chapter'] is Map
            ? raw['latest_chapter']['chapter'] ?? raw['latest_chapter']['number']
            : raw['latest_chapter'] ?? 0,
        if (releaseDate.isNotEmpty) 'latest_chapter_date': releaseDate,
        if ((latestChapter['title'] ?? '').toString().isNotEmpty)
          'latest_chapter_name': latestChapter['title'],
      });
    }).where((entry) => entry['title'].toString().trim().isNotEmpty).toList();
  }
  List<String> _genres(dynamic raw) => raw is List ? raw.map((entry) => entry is Map ? (entry['name'] ?? '').toString() : entry.toString()).where((name) => name.trim().isNotEmpty).toList() : const [];
  String _releaseDate(Map raw) {
    for (final key in const [
      'created_at', 'createdAt', 'published', 'published_at', 'publishedAt',
      'release_date', 'releaseDate', 'date', 'timestamp',
    ]) {
      final value = raw[key];
      if (value == null) continue;
      final date = EpisodeDateFormatter.normalize(value);
      if (date.isNotEmpty) return date;
    }
    return '';
  }
  String _type(dynamic value) => SourceValues.type(value);
  String _stripTags(String value) => value.replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  double? _chapterNumber(String value) {
    final match = RegExp(r'\d+(?:\.\d+)?').firstMatch(value);
    return match == null ? null : double.tryParse(match.group(0)!);
  }
  String _seriesUrl(dynamic id, String slug) => 'swat://series/$id/${slug.isEmpty ? id : slug}';
  int? _seriesId(String url) {
    final uri = Uri.tryParse(url);
    if (uri?.scheme == 'swat' && uri!.host == 'series' && uri.pathSegments.isNotEmpty) return int.tryParse(uri.pathSegments.first);
    final mesh = RegExp(r'(?:appswat\.com|meshmanga\.com)/series/(\d+)').firstMatch(url);
    if (mesh != null) return int.tryParse(mesh.group(1)!);
    return int.tryParse(url);
  }
  int? _chapterId(String url) {
    final uri = Uri.tryParse(url);
    if (uri?.scheme == 'swat' && uri!.host == 'chapter' && uri.pathSegments.isNotEmpty) return int.tryParse(uri.pathSegments.first);
    return int.tryParse(url);
  }
}
