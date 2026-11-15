import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mangaplus/app/core/cache/manga_cover_cache_manager.dart';
import 'package:mangaplus/app/data/models/downloaded_chapter.dart';
import 'package:path_provider/path_provider.dart';

/// Reports what actually occupies the device, and clears only the category the
/// user asked for.
///
/// Three categories are kept apart on purpose:
/// * downloaded chapters, read from the same records the local library uses;
/// * the image cache (covers) served by the app cache manager;
/// * temporary files left behind by interrupted downloads (`*.tmp` folders).
class StorageUsageController extends GetxController {
  final GetStorage _storage = GetStorage();

  final RxBool isLoading = true.obs;
  final RxBool clearing = false.obs;
  final RxInt downloadedCount = 0.obs;
  final RxInt downloadedBytes = 0.obs;
  final RxInt cacheBytes = 0.obs;
  final RxInt incompleteCount = 0.obs;
  final RxInt incompleteBytes = 0.obs;

  @override
  void onInit() {
    super.onInit();
    unawaited(refresh());
  }

  Future<void> refresh() async {
    isLoading.value = true;
    try {
      _readDownloads();
      if (kIsWeb) {
        cacheBytes.value = 0;
        incompleteCount.value = 0;
        incompleteBytes.value = 0;
      } else {
        await _measureFiles();
      }
    } catch (_) {
      // Sizes are informative; a failure must not break the screen.
    } finally {
      isLoading.value = false;
    }
  }

  void _readDownloads() {
    final raw = _storage.read<List<dynamic>>('downloadedChapters') ?? const [];
    var bytes = 0;
    for (final entry in raw.whereType<Map>()) {
      try {
        bytes += DownloadedChapter.fromJson(Map<String, dynamic>.from(entry)).totalBytes;
      } catch (_) {
        // Ignore a corrupt record rather than misreporting the total.
      }
    }
    downloadedCount.value = raw.length;
    downloadedBytes.value = bytes;
  }

  Future<void> _measureFiles() async {
    final base = await getApplicationDocumentsDirectory();
    final chapters = Directory('${base.path}/chapters');
    var incomplete = 0;
    var incompleteSize = 0;
    if (await chapters.exists()) {
      await for (final entity in chapters.list(followLinks: false)) {
        if (entity is Directory && entity.path.endsWith('.tmp')) {
          incomplete++;
          incompleteSize += await _directorySize(entity);
        }
      }
    }
    incompleteCount.value = incomplete;
    incompleteBytes.value = incompleteSize;

    try {
      final temp = await getTemporaryDirectory();
      cacheBytes.value = await _directorySize(temp);
    } catch (_) {
      cacheBytes.value = 0;
    }
  }

  Future<int> _directorySize(Directory directory) async {
    var total = 0;
    try {
      await for (final entity in directory.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          try {
            total += await entity.length();
          } catch (_) {
            // A file removed while walking is simply skipped.
          }
        }
      }
    } catch (_) {
      // Unreadable directories contribute nothing.
    }
    return total;
  }

  /// Empties the cover image cache only; downloaded chapters and reading
  /// progress are untouched.
  Future<void> clearImageCache() async {
    clearing.value = true;
    try {
      await MangaCoverCacheManager.instance.emptyCache();
    } finally {
      clearing.value = false;
    }
    await refresh();
  }

  /// Removes folders left behind by interrupted downloads.
  Future<void> clearTemporaryFiles() async {
    if (kIsWeb) return;
    clearing.value = true;
    try {
      final base = await getApplicationDocumentsDirectory();
      final chapters = Directory('${base.path}/chapters');
      if (await chapters.exists()) {
        await for (final entity in chapters.list(followLinks: false)) {
          if (entity is Directory && entity.path.endsWith('.tmp')) {
            try {
              await entity.delete(recursive: true);
            } catch (_) {
              // A locked file is retried on the next clear.
            }
          }
        }
      }
    } finally {
      clearing.value = false;
    }
    await refresh();
  }

  String get downloadedSizeLabel => _formatBytes(downloadedBytes.value);

  String get cacheSizeLabel => _formatBytes(cacheBytes.value);

  String get incompleteSizeLabel => _formatBytes(incompleteBytes.value);

  static String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 KB';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
