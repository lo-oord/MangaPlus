import 'dart:convert';

import 'package:http/http.dart' as http;

import 'manga_html_utils.dart';
import 'source_base.dart';
import 'source_values.dart';

/// Adapter for the Arabic MangaCloud extension (Keiyoushi Firestore backend).
class MangaCloudSource extends ContentSource {
  static const _site = 'https://mangacloud.online';
  static const _apiKey = 'AIzaSyAvdmgz_r_d89Eo8JB9sV9sAjJR451bMYU';
  static const _firestore =
      'https://firestore.googleapis.com/v1/projects/ninja-brew-crew-4d79c/databases/(default)/documents/cloudmangas';
  static final http.Client _client = http.Client();
  final Map<int, String> _catalogPageTokens = {1: ''};

  @override
  String get id => 'manga_cloud';
  @override
  String get name => 'MangaCloud';
  @override
  String get kind => 'manga';
  @override
  List<String> get hosts => const ['mangacloud.online', 'mangacloud.org'];
  @override
  bool handles(String url) => url.startsWith('mangacloud://') || super.handles(url);

  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return const [];
    var token = '';
    do {
      final queryParameters = <String, String>{
        'pageSize': '300',
        'key': _apiKey,
        'orderBy': 'updatedAt desc',
        if (token.isNotEmpty) 'pageToken': token,
      };
      final response = await _get(_firestore, query: queryParameters);
      final decoded = jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true));
      final matches = <Map<String, dynamic>>[];
      final docs = decoded is Map && decoded['documents'] is List
          ? decoded['documents'] as List
          : const [];
      for (final document in docs.whereType<Map>()) {
        final name = '${document['name'] ?? ''}';
        final id = name.split('/').last;
        final item = _itemFromFields(id, _documentFields(document));
        final haystack = [
          item['title'],
          ...(item['alternative_titles'] as List? ?? const []),
          ...(item['genres'] as List? ?? const []),
          item['description'],
        ].join(' ').toLowerCase();
        if (haystack.contains(normalized)) matches.add(item);
      }
      if (matches.isNotEmpty) return matches;
      token = decoded is Map ? '${decoded['nextPageToken'] ?? ''}' : '';
    } while (token.isNotEmpty);
    return const [];
  }

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) async {
    final safePage = page < 1 ? 1 : page;
    if (safePage == 1) {
      _catalogPageTokens.clear();
      _catalogPageTokens[1] = '';
    }
    final token = _catalogPageTokens[safePage];
    if (token == null) return const [];
    final response = await _get(_firestore, query: {
      'pageSize': '30',
      'key': _apiKey,
      'orderBy': 'updatedAt desc',
      if (token.isNotEmpty) 'pageToken': token,
    });
    final decoded = jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true));
    if (decoded is! Map) return const [];
    final documents = decoded['documents'];
    final items = documents is List
        ? documents.whereType<Map>().map((document) {
            final id = '${document['name'] ?? ''}'.split('/').last;
            return _itemFromFields(id, _documentFields(document));
          }).where((item) => '${item['url'] ?? ''}'.isNotEmpty).toList(growable: false)
        : const <Map<String, dynamic>>[];
    final nextToken = '${decoded['nextPageToken'] ?? ''}';
    if (nextToken.isNotEmpty) {
      _catalogPageTokens[safePage + 1] = nextToken;
    } else {
      _catalogPageTokens.remove(safePage + 1);
    }
    return items;
  }

  @override
  Future<List<Map<String, dynamic>>> nextPage({String query = '', int page = 2}) =>
      query.trim().isEmpty ? latest(page: page) : search(query);

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final id = _mangaId(url);
    if (id.isEmpty) throw Exception('MangaCloud: رابط المانجا غير صالح.');
    final response = await _get('$_firestore/${Uri.encodeComponent(id)}');
    final raw = _document(response);
    if (raw.isEmpty) throw Exception('MangaCloud: لم يتم العثور على المانجا.');
    final result = _itemFromFields(id, raw);
    final chapters = await _chapters(id);
    result['chapters'] = chapters;
    result['total_chapters'] = chapters.length;
    result['latest_chapter_number'] = chapters.isEmpty ? 0 : chapters.first['number'];
    return result;
  }

  @override
  Future<Map<String, dynamic>?> streams(String url) async => null;

  @override
  Future<Map<String, dynamic>?> chapterImages(String url) async {
    final chapterPath = _chapterPath(url);
    if (chapterPath.isEmpty) return null;
    final encodedPath = chapterPath.split('/').map(Uri.encodeComponent).join('/');
    final response = await _get('$_firestore/$encodedPath');
    final fields = _documentFields(response);
    final pages = _stringArray(fields['pages']).where((page) => page.startsWith('http')).toList(growable: false);
    if (pages.isEmpty) throw Exception('MangaCloud: لا توجد صفحات لهذا الفصل.');
    final query = Uri.tryParse(url)?.queryParameters ?? const <String, String>{};
    final number = query['number'] ?? query['chapter'] ?? chapterPath.split('/').last;
    return {
      'title': 'الفصل $number',
      'chapter_number': number,
      'pages': pages,
      'images': pages.map((page) => {'url': page}).toList(),
      'url': url,
    };
  }

  Future<List<Map<String, dynamic>>> _allManga({String? orderBy}) async {
    var pageToken = '';
    final result = <Map<String, dynamic>>[];
    do {
      final query = <String, String>{
        'pageSize': '300',
        'key': _apiKey,
        if (orderBy != null) 'orderBy': orderBy,
        if (pageToken.isNotEmpty) 'pageToken': pageToken,
      };
      final response = await _get(_firestore, query: query);
      final decoded = jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true));
      final docs = decoded is Map && decoded['documents'] is List ? decoded['documents'] as List : const [];
      for (final document in docs.whereType<Map>()) {
        final name = '${document['name'] ?? ''}';
        final id = name.split('/').last;
        final fields = _documentFields(document);
        if (id.isNotEmpty) result.add(_itemFromFields(id, fields));
      }
      pageToken = decoded is Map ? '${decoded['nextPageToken'] ?? ''}' : '';
    } while (pageToken.isNotEmpty && result.length < 3000);
    return result;
  }

  Future<List<Map<String, dynamic>>> _chapters(String id) async {
    var token = '';
    final result = <Map<String, dynamic>>[];
    do {
      final query = <String, String>{
        'pageSize': '1000',
        'key': _apiKey,
        'orderBy': 'index',
        if (token.isNotEmpty) 'pageToken': token,
      };
      final response = await _get('$_firestore/${Uri.encodeComponent(id)}/chapters', query: query);
      final decoded = jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true));
      final docs = decoded is Map && decoded['documents'] is List ? decoded['documents'] as List : const [];
      for (final doc in docs.whereType<Map>()) {
        final name = '${doc['name'] ?? ''}';
        final path = name.split('cloudmangas/').last;
        final pathParts = path.split('/');
        final mangaId = pathParts.isNotEmpty ? pathParts.first : id;
        final chapterId = pathParts.length >= 3 ? pathParts.last : '';
        final chapterNumber = num.tryParse(chapterId) ?? mangaChapterNumber(path) ?? 0;
        result.add({
          'title': 'الفصل $chapterNumber',
          'number': chapterNumber,
          'chapter_number': chapterNumber,
          'url': 'mangacloud://chapter?id=${Uri.encodeQueryComponent(mangaId)}&chapter=${Uri.encodeQueryComponent(chapterId.isEmpty ? '$chapterNumber' : chapterId)}&number=$chapterNumber',
        });
      }
      token = decoded is Map ? '${decoded['nextPageToken'] ?? ''}' : '';
    } while (token.isNotEmpty);
    result.sort((a, b) => (b['number'] as num).compareTo(a['number'] as num));
    return result;
  }

  Map<String, dynamic> _itemFromFields(String id, Map<String, dynamic> fields) {
    final genres = _stringArray(fields['genres']);
    final status = '${fields['status'] ?? ''}';
    final description = '${fields['description'] ?? ''}';
    return item(
      title: '${fields['title'] ?? ''}',
      url: 'mangacloud://manga?id=${Uri.encodeQueryComponent(id)}',
      image: '${fields['coverImage'] ?? ''}',
      type: 'manga',
      genres: genres,
      description: description,
      rating: SourceValues.rating(fields['rating']),
    )..addAll({
        'synopsis': description,
        'author': '${fields['author'] ?? ''}',
        'artist': '${fields['artist'] ?? ''}',
        'status': status,
        'alternative_titles': _stringArray(fields['alternativeTitles']),
        'release_year': '${fields['year'] ?? ''}',
      });
  }

  Future<http.Response> _get(String url, {Map<String, String>? query}) async {
    final uri = Uri.parse(url).replace(queryParameters: {
      ...?query,
      if (!(query?.containsKey('key') ?? false)) 'key': _apiKey,
    });
    final response = await _client.get(uri, headers: const {
      'Accept': 'application/json',
      'User-Agent': 'MangaPlus/1.1',
    }).timeout(const Duration(seconds: 25));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('MangaCloud: فشل الطلب (${response.statusCode}).');
    }
    return response;
  }

  Map<String, dynamic> _document(http.Response response) {
    final decoded = jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true));
    return _documentFields(decoded);
  }

  Map<String, dynamic> _documentFields(dynamic document) => document is Map && document['fields'] is Map
      ? _decodeFields(Map<String, dynamic>.from(document['fields']))
      : document is Map ? _decodeFields(Map<String, dynamic>.from(document)) : <String, dynamic>{};

  Map<String, dynamic> _decodeFields(Map<String, dynamic> fields) => fields.map((key, value) => MapEntry(key, _decodeValue(value)));

  dynamic _decodeValue(dynamic value) {
    if (value is! Map) return value;
    if (value.containsKey('stringValue')) return value['stringValue'];
    if (value.containsKey('integerValue')) return num.tryParse('${value['integerValue']}') ?? 0;
    if (value.containsKey('doubleValue')) return value['doubleValue'];
    if (value.containsKey('booleanValue')) return value['booleanValue'];
    if (value['arrayValue'] is Map) return ((value['arrayValue']['values'] as List?) ?? const []).map(_decodeValue).toList();
    if (value['mapValue'] is Map) return _decodeFields(Map<String, dynamic>.from(value['mapValue']['fields'] ?? {}));
    return value;
  }

  List<String> _stringArray(dynamic value) => value is List ? value.map((entry) => '$entry'.trim()).where((entry) => entry.isNotEmpty).toList() : const [];

  String _mangaId(String value) {
    final uri = Uri.tryParse(value);
    if (uri?.scheme == 'mangacloud') return uri!.queryParameters['id'] ?? '';
    if (uri != null && hosts.contains(uri.host)) return uri.pathSegments.last;
    return '';
  }

  String _chapterPath(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) return '';
    final query = uri.queryParameters;
    final path = query['path']?.trim() ?? '';
    if (path.isNotEmpty) return path;
    final id = query['id']?.trim() ?? '';
    final chapter = (query['chapter'] ?? query['number'] ?? '').trim();
    if (id.isEmpty || chapter.isEmpty) return '';
    return '$id/chapters/$chapter';
  }
}
