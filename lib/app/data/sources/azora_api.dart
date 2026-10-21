import 'dart:convert';

import 'package:http/http.dart' as http;

/// Shared read-only transport and record predicates for Azora's distinct
/// manga and novel source adapters.
class AzoraApi {
  static const String _base = 'https://api.azorafly.com/api';
  static final http.Client _client = http.Client();

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

  static bool isNovel(Map<dynamic, dynamic> record) =>
      record['isNovel'] == true ||
      (record['seriesType'] ?? record['type'] ?? record['postType'] ?? '')
          .toString()
          .toUpperCase() ==
      'NOVEL';

  static bool isLocked(Map<dynamic, dynamic> record) =>
      record['isLocked'] == true ||
      record['isLockedByCoins'] == true ||
      record['isPermanentlyLocked'] == true ||
      record['isShortLinkLocked'] == true ||
      record['isAccessible'] == false;
}
