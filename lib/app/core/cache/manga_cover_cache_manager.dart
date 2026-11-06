import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Keeps manga covers in a dedicated disk cache so chapter-page traffic cannot
/// evict them during ordinary navigation or short background pauses.
class MangaCoverCacheManager {
  MangaCoverCacheManager._();

  static Map<String, String> requestHeadersForWorkUrl(String workUrl) {
    var uri = Uri.tryParse(workUrl);
    if (uri?.scheme == 'teamx') {
      uri = Uri.tryParse(uri!.queryParameters['url'] ?? '');
    }
    final headers = <String, String>{
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/131 Mobile Safari/537.36',
    };
    if (uri != null && uri.host.isNotEmpty) {
      final scheme = uri.scheme == 'http' ? 'http' : 'https';
      headers['Referer'] = '$scheme://${uri.host}/';
    }
    return headers;
  }

  /// Covers are effectively immutable, so keep them for a year and allow a
  /// generous entry count: the catalogue is long and evicting a cover forces a
  /// fresh network download the next time it is shown.
  static final CacheManager instance = CacheManager(
    Config(
      'mangaplusCoverCache',
      stalePeriod: const Duration(days: 365),
      maxNrOfCacheObjects: 1500,
    ),
  );
}
