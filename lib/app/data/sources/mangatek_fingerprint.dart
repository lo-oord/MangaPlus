import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

/// Builds the signals, request headers, and unlock payload expected by the
/// official MangaTek reader. Device-specific values come from Android rather
/// than being guessed in Dart.
class MangaTekFingerprint {
  MangaTekFingerprint._({required this.headers, required this.fpc});

  static const _channel =
      MethodChannel('com.mangaplus.app/mangatek_fingerprint');
  static const userAgent =
      'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/131.0.0.0 Mobile Safari/537.36';

  final Map<String, String> headers;
  final Map<String, dynamic> fpc;

  static Future<MangaTekFingerprint?> create() async {
    if (!Platform.isAndroid) return null;
    final profile = await _channel.invokeMapMethod<String, dynamic>('profile');
    if (profile == null) return null;

    final locale = Platform.localeName.replaceAll('_', '-');
    final language = locale.split('-').first;
    final lang = locale.contains('-') ? '$locale,$language' : language;
    final cores = profile['cores'] as int;
    final mem = profile['mem'] as int;
    final tz = profile['tz'] as String;
    final tzOffset = profile['tzOffset'] as int;
    final screen = profile['screen'] as String;
    final dpr = (profile['dpr'] as num).toDouble();
    final canvas = profile['canvas'] as String;

    final signals = <String, dynamic>{
      'ua': userAgent,
      'lang': lang,
      'platform': 'Linux armv8l',
      'cores': cores,
      'mem': mem,
      'touch': 5,
      'tz': tz,
      'tzOffset': tzOffset,
      'screen': '${screen}x24',
      'avail': screen,
      'dpr': dpr,
      'canvas': canvas,
      'webgl': '',
    };

    final device = <String>[
      'Linux armv8l',
      '${screen}x24',
      tz,
      'cores:$cores',
      'mem:$mem',
      'touch:5',
      'dpr:${_shortDouble(dpr)}',
    ].join(' | ').replaceAll(RegExp(r'[^\x20-\x7E]'), '');

    final app = <String, dynamic>{
      'webdriver': false,
      'vendor': 'Google Inc.',
      'plugins': 0,
      'pdfViewer': false,
      'chromeObj': 'object',
      'androidBridge': false,
      'flutter': false,
      'reactNative': false,
      'webkitHandlers': false,
      'standalone': false,
    };

    return MangaTekFingerprint._(
      headers: {
        'x-fp': sha256.convert(utf8.encode(jsonEncode(signals))).toString(),
        'x-device': device.length > 256 ? device.substring(0, 256) : device,
      },
      fpc: {
        'v': 1,
        'ua': userAgent.length > 300 ? userAgent.substring(0, 300) : userAgent,
        'lang': lang.length > 60 ? lang.substring(0, 60) : lang,
        'platform': 'Linux armv8l',
        'cores': cores,
        'mem': mem,
        'touch': 5,
        'tz': tz,
        'tzOffset': tzOffset,
        'screen': '${screen}x24',
        'avail': screen,
        'dpr': dpr,
        'canvas':
            sha256.convert(utf8.encode(canvas)).toString().substring(0, 16),
        'webgl': '',
        'app': app,
      },
    );
  }

  static String _shortDouble(double value) =>
      value.toString().replaceFirst(RegExp(r'\.0$'), '');
}
