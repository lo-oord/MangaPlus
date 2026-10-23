import 'dart:convert';

import 'package:http/http.dart' as http;

/// Shared read-only transport and record predicates for Azora's distinct
/// manga and novel source adapters.
class AzoraApi {
  static const String _base = 'https://api.azorafly.com/api';
  static final http.Client _client = http.Client();
  static final Map<String, Future<bool>> _novelLookups = {};

  static Future<Map<String, dynamic>> getJson(
    String endpoint,
    Map<String, String> parameters,
  ) async {
    final uri = Uri.parse('$_base/$endpoint').replace(queryParameters: parameters);
    final response = await _client.get(uri, headers: const {
      'Accept': 'application/json',
      'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/131 Mobile Safari/537.36',
    }).timeout(const Duration(seconds: 25));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('تعذر الاتصال بمصدر أزورا (${response.statusCode}).');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true));
    if (decoded is! Map) throw Exception('استجابة واجهة أزورا غير صالحة.');
    return Map<String, dynamic>.from(decoded);
  }

  static bool isNovel(Map<dynamic, dynamic> record) {
    if (record['isNovel'] == true) return true;
    const novelKinds = {'NOVEL', 'LIGHT NOVEL', 'رواية'};
    return [
      record['seriesType'],
      record['type'],
      record['postType'],
      record['contentType'],
      record['content_type'],
      record['format'],
    ].any((value) => novelKinds.contains('$value'.trim().toUpperCase()));
  }

  static Future<bool> isNovelPost(Map<String, dynamic> record) {
    if (record.containsKey('isNovel') ||
        record.containsKey('seriesType') ||
        record.containsKey('type') ||
        record.containsKey('postType')) {
      if (isNovel(record)) return Future.value(true);
    }
    final slug = '${record['slug'] ?? ''}'.trim();
    final id = '${record['id'] ?? ''}'.trim();
    final key = slug.isNotEmpty ? slug : id;
    if (key.isEmpty) return Future.value(isNovel(record));
    return _novelLookups.putIfAbsent(key, () async {
      try {
        final response = await getJson('post', {
          if (slug.isNotEmpty) 'postSlug': slug else 'postId': id,
        });
        final post = response['post'];
        return post is Map && isNovel(post);
      } catch (_) {
        return isNovel(record);
      }
    });
  }

  static bool isLocked(Map<dynamic, dynamic> record) =>
      record['isLocked'] == true ||
      record['isLockedByCoins'] == true ||
      record['isPermanentlyLocked'] == true ||
      record['isShortLinkLocked'] == true ||
      record['isAccessible'] == false;
}
