import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';

/// Cryptographic helpers shared by MangaTek's page and translated-text APIs.
/// The legacy key and v3 envelope format match Keiyoushi's MangaTek extension.
class MangaTekOverlayCrypto {
  MangaTekOverlayCrypto._();

  static const _legacyKeyHex =
      'ff453871399fe268588a0936b45376022d85ed0fd1292001d5102f6a30291dc1';
  static final _aesGcm = AesGcm.with256bits();

  static String proof(String proofSalt, String token, Object chapterId) =>
      _sha256Hex('$proofSalt|$token|$chapterId');

  static String esid(String readerSeed) =>
      _sha256Hex('esid|$readerSeed').substring(0, 8);

  static Future<String> decryptHexBlob(
    String blob, {
    String keyHex = _legacyKeyHex,
  }) async {
    final parts = blob.split(':');
    if (parts.length != 3) {
      throw const FormatException('Unexpected MangaTek overlay blob.');
    }
    final nonce = _decodeHex(parts[0]);
    final cipherText = _decodeHex(parts[1]);
    final tag = _decodeHex(parts[2]);
    if (nonce.isEmpty || tag.isEmpty || cipherText.isEmpty) {
      throw const FormatException('Incomplete MangaTek overlay blob.');
    }
    final clear = await _aesGcm.decrypt(
      SecretBox(cipherText, nonce: nonce, mac: Mac(tag)),
      secretKey: SecretKey(_decodeHex(keyHex)),
    );
    return utf8.decode(clear);
  }

  static Future<String> decryptEnvelope({
    required String readerSeed,
    required String overlay,
    required String keySeed,
    required String token,
    required Object chapterId,
  }) async {
    final bytes = _decodeBase64Url(overlay);
    if (bytes.length < 6 || bytes.first != 3) {
      throw const FormatException('Unsupported MangaTek overlay version.');
    }

    final data = bytes.sublist(1);
    for (var start = 0; start < data.length; start += 32) {
      final stream = _sha256Bytes('$readerSeed|v3|$keySeed|${start ~/ 32}');
      final end = start + 32 < data.length ? start + 32 : data.length;
      for (var index = start; index < end; index++) {
        data[index] ^= stream[index - start];
      }
    }

    final tagLength = _readU16(data, 0);
    final nonceLength = _readU16(data, 2);
    final cipherStart = 4 + tagLength;
    final cipherEnd = data.length - nonceLength;
    if (tagLength <= 0 ||
        nonceLength <= 0 ||
        cipherStart < 4 ||
        cipherEnd <= cipherStart ||
        cipherEnd + nonceLength != data.length) {
      throw const FormatException('Malformed MangaTek overlay envelope.');
    }

    final tag = data.sublist(4, cipherStart);
    final cipherText = data.sublist(cipherStart, cipherEnd);
    final nonce = data.sublist(cipherEnd);
    final key = _sha256Bytes(
      '$readerSeed|v3|$keySeed|$token|$chapterId',
    );
    final clear = await _aesGcm.decrypt(
      SecretBox(cipherText, nonce: nonce, mac: Mac(tag)),
      secretKey: SecretKey(key),
    );
    return utf8.decode(clear);
  }

  static String _sha256Hex(String value) =>
      sha256.convert(utf8.encode(value)).toString();

  static List<int> _sha256Bytes(String value) =>
      sha256.convert(utf8.encode(value)).bytes;

  static List<int> _decodeHex(String value) {
    final clean = value.trim();
    if (clean.isEmpty ||
        clean.length.isOdd ||
        !RegExp(r'^[0-9a-fA-F]+$').hasMatch(clean)) {
      throw const FormatException('Invalid MangaTek hexadecimal value.');
    }
    return [
      for (var index = 0; index < clean.length; index += 2)
        int.parse(clean.substring(index, index + 2), radix: 16),
    ];
  }

  static List<int> _decodeBase64Url(String value) {
    final clean = value.trim().replaceAll('-', '+').replaceAll('_', '/');
    return base64.decode(base64.normalize(clean));
  }

  static int _readU16(List<int> bytes, int offset) {
    if (offset < 0 || offset + 1 >= bytes.length) {
      throw const FormatException('Truncated MangaTek overlay header.');
    }
    return (bytes[offset] << 8) | bytes[offset + 1];
  }
}
