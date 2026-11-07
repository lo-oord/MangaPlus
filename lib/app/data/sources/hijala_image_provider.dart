import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

/// Loads a `hijala-pair://` page and joins the two source images horizontally.
/// Hijala's official extension performs this operation in its HTTP interceptor.
class HijalaImageProvider extends ImageProvider<HijalaImageProvider> {
  const HijalaImageProvider(this.url);

  final String url;

  static bool handles(String value) => value.startsWith('hijala-pair://');

  @override
  Future<HijalaImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<HijalaImageProvider>(this);

  @override
  ImageStreamCompleter loadImage(
    HijalaImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _decode(decode),
      scale: 1,
      informationCollector: () sync* {
        yield DiagnosticsProperty<String>('Hijala page', key.url);
      },
    );
  }

  Future<ui.Codec> _decode(ImageDecoderCallback decode) async {
    final uri = Uri.parse(url);
    final leftUrl = uri.queryParameters['leftImage'];
    final rightUrl = uri.queryParameters['rightImage'];
    if (leftUrl == null || rightUrl == null) {
      throw const FormatException('Hijala pair is missing one of its images');
    }

    final headers = const {
      'Referer': 'https://hijala.com/',
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/131 Mobile Safari/537.36',
    };
    final responses = await Future.wait([
      http.get(Uri.parse(leftUrl), headers: headers),
      http.get(Uri.parse(rightUrl), headers: headers),
    ]);
    if (responses.any((response) => response.statusCode < 200 || response.statusCode >= 300)) {
      throw StateError('Hijala page image request failed');
    }

    final left = img.decodeImage(responses[0].bodyBytes);
    final right = img.decodeImage(responses[1].bodyBytes);
    if (left == null || right == null) throw StateError('Hijala image decode failed');

    final result = img.Image(
      width: left.width + right.width,
      height: left.height > right.height ? left.height : right.height,
    );
    img.compositeImage(result, left, dstX: 0, dstY: 0);
    img.compositeImage(result, right, dstX: left.width, dstY: 0);
    final bytes = Uint8List.fromList(img.encodeJpg(result, quality: 90));
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  bool operator ==(Object other) =>
      other is HijalaImageProvider && other.url == url;

  @override
  int get hashCode => url.hashCode;
}
