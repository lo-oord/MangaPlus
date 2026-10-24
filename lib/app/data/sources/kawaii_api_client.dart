import 'dart:convert';

import 'package:http/http.dart' as http;

/// Read-only client for KawaiiManga's public app API.
///
/// The app key is already shipped in the site's public JavaScript bundle. The
/// short-lived API token is fetched at runtime and is never persisted.
class KawaiiApiClient {
  KawaiiApiClient._();

  static const String _appKey = 'km_2026_live';
  static const String _userAgent = 'MangaPlus/1.0';
  static const String _baseUrl =
      'https://manga-api.kawaii-anime.com/api/manga';
  static final http.Client _client = http.Client();

  static String? _token;
  static DateTime? _tokenExpiresAt;
  static Future<String?>? _tokenRequest;

  static Future<Map<String, dynamic>> getJson(
    String action, [
    Map<String, String> parameters = const {},
  ]) async {
    final uri = Uri.parse('$_baseUrl/own').replace(queryParameters: {
      'action': action,
      ...parameters,
    });
    var response = await _send(uri);
    if (response.statusCode == 401) {
      _token = null;
      _tokenExpiresAt = null;
      response = await _send(uri, refreshToken: true);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Kawaii API $action: HTTP ${response.statusCode}.');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true));
    if (decoded is! Map) {
      throw FormatException('Kawaii API $action returned an invalid response.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  static Future<http.Response> _send(
    Uri uri, {
    bool refreshToken = false,
  }) async {
    final token = await _getToken(refresh: refreshToken);
    final headers = <String, String>{
      'Accept': 'application/json',
      'x-app-key': _appKey,
      'User-Agent': _userAgent,
    };
    if (token != null && token.isNotEmpty) headers['x-app-token'] = token;
    return _client.get(uri, headers: headers).timeout(const Duration(seconds: 90));
  }

  static Future<String?> _getToken({bool refresh = false}) async {
    final current = _token;
    final expiresAt = _tokenExpiresAt;
    if (!refresh && current != null && expiresAt != null &&
        DateTime.now().isBefore(expiresAt)) {
      return current;
    }

    final pending = _tokenRequest;
    if (!refresh && pending != null) return pending;

    final request = _requestToken();
    _tokenRequest = request;
    try {
      return await request;
    } finally {
      if (identical(_tokenRequest, request)) _tokenRequest = null;
    }
  }

  static Future<String?> _requestToken() async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/token'),
        headers: const {
          'x-app-key': _appKey,
          'User-Agent': _userAgent,
        },
      ).timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final decoded = jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true));
      if (decoded is! Map) return null;
      final token = '${decoded['token'] ?? ''}'.trim();
      final expiresIn = int.tryParse('${decoded['expiresIn'] ?? ''}') ?? 0;
      if (token.isEmpty || expiresIn <= 0) return null;
      _token = token;
      final safeLifetime = expiresIn > 90 ? expiresIn - 60 : expiresIn;
      _tokenExpiresAt = DateTime.now().add(Duration(seconds: safeLifetime));
      return token;
    } catch (_) {
      return null;
    }
  }
}
