import 'dart:convert';

import 'package:http/http.dart' as http;

import 'source_base.dart';
import 'source_values.dart';

/// Shared read-only adapter for the public Despair API.
abstract class DespairSource extends ContentSource {
  DespairSource({http.Client? client}) : _client = client ?? http.Client();

  static const String _site = 'https://despair-world.com';
  static const String _api = '$_site/supabase-api/rest/v1';
  // Public anonymous key used by the official Keiyoushi Despair extension.
  static const String _anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzkwMzczMDE4LCJleHAiOjE5NDgwNTMwMTh9.xYgAlC_9SuUCdzdff6wBYGWzYFmAI9apP_mk4DCPaVI';

  final http.Client _client;
  String get _workTable;
  String get _chapterTable;
  @override
  List<String> get hosts => const ['despair-world.com'];

  @override
  bool handles(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.toLowerCase().replaceFirst('www.', '') != 'despair-world.com') return false;
    final segments = uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
    final firstPath = segments.isEmpty ? '' : segments.first;
    final isNovelUrl = uri.queryParameters['mangaplus_source'] == 'despair_novels' ||
        firstPath == 'novels';
    return kind == 'novel'
        ? isNovelUrl && (firstPath == 'series' || firstPath == 'novels')
        : firstPath == 'series' && !isNovelUrl;
  }

  @override
  Future<List<Map<String, dynamic>>> search(String query) =>
      _works(page: 1, query: query);

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) =>
      _works(page: page, order: 'updated_at.desc');

  @override
  Future<List<Map<String, dynamic>>> catalog({int page = 1}) =>
      _works(page: page, order: 'views_count.desc');

  @override
  Future<List<Map<String, dynamic>>> nextPage({String query = '', int page = 2}) =>
      _works(page: page, query: query);

  Future<List<Map<String, dynamic>>> _works({
    required int page,
    String query = '',
    String order = 'views_count.desc',
  }) async {
    final safePage = page < 1 ? 1 : page;
    final term = query.trim().replaceAll('\\', '\\\\').replaceAll('"', '\\"');
    final stableOrder = order.contains(',') ? order : '$order,id.asc';
    final uri = Uri.parse('$_api/$_workTable').replace(queryParameters: {
      'select': '*',
      if (term.isNotEmpty)
        'or': '(title_ar.ilike."*$term*",title_en.ilike."*$term*")',
      'order': stableOrder,
      'limit': '24',
      'offset': '${(safePage - 1) * 24}',
    });
    final rows = await _getList(uri);
    final workIds = rows.map((row) => SourceValues.firstText([row['id'], row['slug']]));
    final ratings = kind == 'novel'
        ? await _ratingsByWorkIds(workIds)
        : const <String, double>{};
    return rows.map((row) {
      final id = SourceValues.firstText([row['id'], row['slug']]);
      return _mapWork(row, ratingOverride: ratings[id]);
    }).toList(growable: false);
  }

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final slug = _slug(url);
    if (slug.isEmpty) throw Exception('$name: رابط العمل غير صالح.');
    final work = await _work(slug);
    if (work == null) throw Exception('$name: لم يتم العثور على العمل.');
    final chapters = await _chapters('${work['id'] ?? ''}', slug);
    final workId = SourceValues.firstText([work['id'], work['slug']]);
    final ratings = kind == 'novel'
        ? await _ratingsByWorkIds([workId])
        : const <String, double>{};
    final item = _mapWork(work, ratingOverride: ratings[workId]);
    item['chapters'] = chapters;
    item['total_chapters'] = chapters.length;
    item['latest_chapter_number'] = chapters.isEmpty ? '' : chapters.first['number'];
    return item;
  }

  @override
  Future<Map<String, dynamic>?> streams(String url) async => null;

  @override
  Future<Map<String, dynamic>?> chapterImages(String url) async {
    if (kind != 'manga') return null;
    final parts = _chapterParts(url);
    if (parts == null) return null;
    final work = await _work(parts.$1);
    if (work == null) throw Exception('$name: تعذر العثور على العمل.');
    final chapter = await _chapter('${work['id'] ?? ''}', parts.$2);
    if (chapter == null) throw Exception('$name: تعذر العثور على الفصل.');
    final pages = chapter['pages'];
    if (pages is! List) return null;
    final images = pages.map((page) => '$page'.trim()).where((page) => page.startsWith('http')).toList(growable: false);
    if (images.isEmpty) throw Exception('$name: لا توجد صفحات لهذا الفصل.');
    final chapters = await _chapters('${work['id'] ?? ''}', parts.$1);
    final chapterIndex = chapters.indexWhere((entry) => '${entry['number']}' == parts.$2);
    return {
      'title': '${chapter['title'] ?? 'الفصل ${parts.$2}'}',
      'chapter_number': parts.$2,
      'url': url,
      'pages': images,
      'chapters': chapters,
      if (chapterIndex > 0) 'previous_chapter': chapters[chapterIndex - 1]['url'],
      if (chapterIndex >= 0 && chapterIndex + 1 < chapters.length)
        'next_chapter': chapters[chapterIndex + 1]['url'],
    };
  }

  @override
  Future<Map<String, dynamic>?> chapterContent(String url) async {
    if (kind != 'novel') return null;
    final parts = _chapterParts(url);
    if (parts == null) return null;
    final work = await _work(parts.$1);
    if (work == null) throw Exception('$name: تعذر العثور على الرواية.');
    final chapter = await _chapter('${work['id'] ?? ''}', parts.$2);
    if (chapter == null) throw Exception('$name: تعذر العثور على الفصل.');
    final content = '${chapter['content'] ?? ''}'.trim();
    if (content.isEmpty) throw Exception('$name: محتوى الفصل غير متاح.');
    final chapters = await _chapters('${work['id'] ?? ''}', parts.$1);
    final chapterIndex = chapters.indexWhere((entry) => '${entry['number']}' == parts.$2);
    return {
      'title': '${chapter['title'] ?? 'الفصل ${parts.$2}'}',
      'chapter_number': parts.$2,
      'url': url,
      'content': content,
      'chapters': chapters,
      if (chapterIndex > 0) 'previous_chapter': chapters[chapterIndex - 1]['url'],
      if (chapterIndex >= 0 && chapterIndex + 1 < chapters.length)
        'next_chapter': chapters[chapterIndex + 1]['url'],
    };
  }

  Future<Map<String, dynamic>?> _work(String slug) async {
    final escaped = slug.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
    final uri = Uri.parse('$_api/$_workTable').replace(queryParameters: {
      'select': '*',
      'or': '(slug.eq."$escaped",id.eq."$escaped")',
      'limit': '1',
    });
    final rows = await _getList(uri);
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> _chapters(String workId, String slug) async {
    if (workId.isEmpty) return const [];
    final uri = Uri.parse('$_api/$_chapterTable').replace(queryParameters: {
      'select': '*',
      'work_id': 'eq.$workId',
      'order': 'chapter_number.desc,id.desc',
    });
    final rows = await _getList(uri);
    final readableRows = kind == 'novel'
        ? rows.where((row) => '${row['content'] ?? ''}'.trim().isNotEmpty)
        : rows;
    return readableRows.map((row) {
      final number = row['chapter_number'] ?? '';
      final numberText = number is num && number == number.roundToDouble()
          ? number.toInt().toString()
          : '$number';
      final title = '${row['title'] ?? ''}'.trim();
      final chapterUrl = Uri.parse(
        '$_site/series/${Uri.encodeComponent(slug)}/main/ch/${Uri.encodeComponent(numberText)}',
      ).replace(
        queryParameters: kind == 'novel' ? {'mangaplus_source': 'despair_novels'} : null,
      ).toString();
      return <String, dynamic>{
        'id': '${row['id'] ?? ''}',
        'number': number,
        'title': title.isEmpty ? 'الفصل $numberText' : title,
        'release_date': '${row['created_at'] ?? ''}',
        'date': '${row['created_at'] ?? ''}',
        'url': chapterUrl,
      };
    }).toList(growable: false);
  }

  Future<Map<String, dynamic>?> _chapter(String workId, String number) async {
    if (workId.isEmpty) return null;
    final uri = Uri.parse('$_api/$_chapterTable').replace(queryParameters: {
      'select': '*',
      'work_id': 'eq.$workId',
      'chapter_number': 'eq.$number',
      'order': 'id.desc',
      'limit': '1',
    });
    final rows = await _getList(uri);
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, double>> _ratingsByWorkIds(Iterable<String> values) async {
    final ids = values.map((value) => value.trim()).where((value) => value.isNotEmpty).toSet();
    if (ids.isEmpty) return const {};
    final quotedIds = ids.map((id) => '"${id.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}"').join(',');
    final uri = Uri.parse('$_api/work_ratings').replace(queryParameters: {
      'select': 'work_id,stars',
      'work_id': 'in.($quotedIds)',
      'limit': '1000',
    });
    final rows = await _getList(uri);
    final totals = <String, double>{};
    final counts = <String, int>{};
    for (final row in rows) {
      final id = SourceValues.text(row['work_id']);
      final stars = double.tryParse('${row['stars'] ?? ''}');
      if (id.isEmpty || stars == null || !stars.isFinite || stars <= 0) continue;
      totals.update(id, (total) => total + stars, ifAbsent: () => stars);
      counts.update(id, (count) => count + 1, ifAbsent: () => 1);
    }
    return {
      for (final id in totals.keys) id: totals[id]! / counts[id]!,
    };
  }

  Future<List<Map<String, dynamic>>> _getList(Uri uri) async {
    final response = await _client.get(uri, headers: {
      'apikey': _anonKey,
      'Authorization': 'Bearer $_anonKey',
      'Accept': 'application/json',
      'User-Agent': 'MangaPlus Android',
    }).timeout(const Duration(seconds: 25));
    // PostgREST answers with 416 when offset reaches beyond the final row;
    // treat that as the natural end of infinite scrolling, not a retry error.
    if (response.statusCode == 416) return const [];
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('$name: فشل الاتصال بالمصدر (${response.statusCode}).');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true));
    if (decoded is! List) return const [];
    return decoded.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList(growable: false);
  }

  Map<String, dynamic> _mapWork(Map<String, dynamic> raw, {double? ratingOverride}) {
    final slug = SourceValues.firstText([raw['slug'], raw['id']]);
    final titleAr = '${raw['title_ar'] ?? ''}'.trim();
    final titleEn = '${raw['title_en'] ?? ''}'.trim();
    final title = titleAr.isNotEmpty ? titleAr : titleEn;
    final url = Uri.parse('$_site/series/${Uri.encodeComponent(slug)}').replace(
      queryParameters: kind == 'novel' ? {'mangaplus_source': 'despair_novels'} : null,
    ).toString();
    final rawChapterCount = raw['chapters_count'];
    final chapterCount = rawChapterCount is num && rawChapterCount > 0
        ? rawChapterCount
        : null;
    final genres = raw['genres'] is List ? (raw['genres'] as List).map((value) => '$value').where((value) => value.trim().isNotEmpty).toList() : <String>[];
    final synopsis = '${raw['synopsis'] ?? ''}'.trim();
    final item = this.item(
      title: title.isEmpty ? slug : title,
      url: url,
      image: SourceValues.imageUrl(raw['cover_url'] ?? raw['thumbnail_url'], baseUrl: _site),
      type: kind,
      genres: genres,
      description: synopsis,
      rating: SourceValues.rating(ratingOverride ?? raw['rating_avg'] ?? raw['rating']),
    );
    item.addAll({
      'native_title': titleEn,
      'alternate_titles': titleEn.isNotEmpty && titleEn != title ? [titleEn] : const <String>[],
      'author': '${raw['author_or_studio'] ?? ''}',
      'status': '${raw['status'] ?? ''}',
      'release_year': '${raw['release_year'] ?? ''}',
      'updated_on': '${raw['updated_at'] ?? ''}',
      'total_chapters': chapterCount,
      'latest_chapter_number': '',
      'synopsis': synopsis,
    });
    return item;
  }

  String _slug(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !handles(url)) return '';
    final segments = uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
    if (segments.isEmpty) return '';
    final seriesIndex = segments.indexOf('series');
    final legacyNovelsIndex = segments.indexOf('novels');
    final workIndex = seriesIndex >= 0 ? seriesIndex : legacyNovelsIndex;
    if (workIndex < 0 || workIndex + 1 >= segments.length) return '';
    return Uri.decodeComponent(segments[workIndex + 1]);
  }

  (String, String)? _chapterParts(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !handles(url)) return null;
    final segments = uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
    final seriesIndex = segments.indexOf('series');
    final legacyNovelsIndex = segments.indexOf('novels');
    final workIndex = seriesIndex >= 0 ? seriesIndex : legacyNovelsIndex;
    if (workIndex < 0 || workIndex + 1 >= segments.length) return null;
    final marker = segments.indexOf('ch', workIndex + 2);
    if (marker < 0 || marker + 1 >= segments.length) return null;
    return (Uri.decodeComponent(segments[workIndex + 1]), Uri.decodeComponent(segments[marker + 1]));
  }
}

class DespairMangaSource extends DespairSource {
  DespairMangaSource({super.client});
  @override
  String get id => 'despair_manga';
  @override
  String get name => 'Despair Manga';
  @override
  String get kind => 'manga';
  @override
  String get _workTable => 'manga_works';
  @override
  String get _chapterTable => 'chapters';
}

class DespairNovelsSource extends DespairSource {
  DespairNovelsSource({super.client});
  @override
  String get id => 'despair_novels';
  @override
  String get name => 'Despair Novels';
  @override
  String get kind => 'novel';
  @override
  String get _workTable => 'novel_works';
  @override
  String get _chapterTable => 'novel_chapters';
}
