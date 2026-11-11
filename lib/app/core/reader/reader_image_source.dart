import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:mangaplus/app/core/reader/reader_page_geometry.dart';

/// Whether [reference] points at a file that is already on the device.
bool isLocalReaderImage(String reference) =>
    reference.startsWith('/') ||
    reference.startsWith('file://') ||
    reference.startsWith('content://');

String? localReaderImagePath(String reference) {
  if (reference.startsWith('/')) return reference;
  if (reference.startsWith('file://')) {
    try {
      return Uri.parse(reference).toFilePath();
    } catch (_) {
      return null;
    }
  }
  return null;
}

/// Request headers required by the sources that hot-link their images.
Map<String, String> readerImageHeaders(String imageUrl) {
  final uri = Uri.tryParse(imageUrl);
  final host = uri?.host.toLowerCase() ?? '';
  final isMangaDar = host == 'storage.mangadar.com' ||
      host.endsWith('.storage.mangadar.com') ||
      host == 'mangadar.com';
  final isProComic = host == 'procomic.pro' || host.endsWith('.procomic.pro');
  final referer = isProComic
      ? 'https://procomic.pro/'
      : isMangaDar
          ? 'https://mangadar.com/'
          : uri == null || host.isEmpty
              ? 'https://olympustaff.com/'
              : '${uri.scheme}://${uri.host}/';
  return <String, String>{
    'Referer': referer,
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/131 Mobile Safari/537.36',
  };
}

/// The one provider the reader uses for online and offline pages.
///
/// Using the provider directly (instead of the `CachedNetworkImage` widget)
/// lets Flutter's image cache deduplicate simultaneous requests for the same
/// page, keeps the decoded image out of widget state, and makes the offline
/// path identical to the online one instead of a separate, weaker code path.
ImageProvider<Object> readerImageProvider(
  String reference, {
  Map<String, String>? headers,
  int? maxWidth,
}) {
  final localPath = localReaderImagePath(reference);
  if (localPath != null) {
    final provider = FileImage(File(localPath));
    return maxWidth == null
        ? provider
        : ResizeImage.resizeIfNeeded(maxWidth, null, provider);
  }
  return CachedNetworkImageProvider(
    reference,
    headers: headers,
    maxWidth: maxWidth,
  );
}

/// Measures a page image without keeping its full decoded bitmap in memory.
///
/// A 96px-wide probe is enough to recover the exact aspect ratio, while the
/// original file still lands in the disk cache for the real page render. This
/// is what removes the "page grows when it finishes loading" jump.
Future<ReaderPageSize?> measureReaderImageSize(
  String reference, {
  Map<String, String>? headers,
  int probeWidth = 96,
  Duration timeout = const Duration(seconds: 20),
}) async {
  final trimmed = reference.trim();
  if (trimmed.isEmpty) return null;
  final provider = readerImageProvider(
    trimmed,
    headers: headers ?? readerImageHeaders(trimmed),
    maxWidth: probeWidth,
  );
  final completer = Completer<ReaderPageSize?>();
  late final ImageStreamListener listener;
  ImageStream? stream;
  void finish(ReaderPageSize? size) {
    if (completer.isCompleted) return;
    completer.complete(size);
    try {
      stream?.removeListener(listener);
    } catch (_) {}
  }

  listener = ImageStreamListener(
    (ImageInfo info, bool synchronousCall) {
      final width = info.image.width;
      final height = info.image.height;
      info.dispose();
      finish(width > 0 && height > 0
          ? ReaderPageSize(width: width, height: height)
          : null);
    },
    onError: (Object error, StackTrace? stackTrace) {
      debugPrint('Unable to measure reader page: $error');
      finish(null);
    },
  );
  try {
    final resolved = provider.resolve(ImageConfiguration.empty);
    stream = resolved;
    resolved.addListener(listener);
    return await completer.future.timeout(timeout, onTimeout: () {
      try {
        stream?.removeListener(listener);
      } catch (_) {}
      return null;
    });
  } catch (error) {
    debugPrint('Unable to resolve reader page: $error');
    return null;
  }
}

/// Reads the pixel dimensions of encoded bytes (used while downloading).
Future<ReaderPageSize?> measureEncodedImageBytes(
  Uint8List bytes, {
  int probeWidth = 96,
}) async {
  ui.Codec? codec;
  try {
    codec = await ui.instantiateImageCodec(bytes, targetWidth: probeWidth);
    final frame = await codec.getNextFrame();
    final width = frame.image.width;
    final height = frame.image.height;
    frame.image.dispose();
    if (width <= 0 || height <= 0) return null;
    return ReaderPageSize(width: width, height: height);
  } catch (error) {
    debugPrint('Unable to measure downloaded page: $error');
    return null;
  } finally {
    codec?.dispose();
  }
}
