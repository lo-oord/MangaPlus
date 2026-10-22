import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Keeps manga covers in a dedicated disk cache so chapter-page traffic cannot
/// evict them during ordinary navigation or short background pauses.
class MangaCoverCacheManager {
  MangaCoverCacheManager._();

  static final CacheManager instance = CacheManager(
    Config(
      'mangaplusCoverCache',
      stalePeriod: const Duration(days: 180),
      maxNrOfCacheObjects: 500,
    ),
  );
}
