import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangaplus/app/data/sources/mangatek_overlay_crypto.dart';

void main() {
  test('proof matches the MangaTek reader formula', () {
    expect(
      MangaTekOverlayCrypto.proof('salt', 'token', 42),
      'b5f21cfeda2adfa566f7e68958717320cbff72321d305f59eff186df4ed48161',
    );
  });

  test('esid uses the first eight SHA-256 hex characters', () {
    expect(MangaTekOverlayCrypto.esid('reader-seed'), '8fb6da5d');
  });

  test('malformed legacy overlay payload is rejected', () async {
    await expectLater(
      MangaTekOverlayCrypto.decryptHexBlob('not-an-overlay'),
      throwsA(isA<FormatException>()),
    );
  });

  test('decrypts the official v3 XOR-wrapped AES-GCM envelope', () async {
    const readerSeed = '0123456789abcdef0123456789abcdef0123456789abcdef';
    const keySeed = 'fixture-key-seed';
    const token = 'fixture-token';
    const chapterId = 42;
    const clearText = '{"pages":[]}';
    final nonce = List<int>.generate(12, (index) => index + 1);
    final key = sha256
        .convert(utf8.encode('$readerSeed|v3|$keySeed|$token|$chapterId'))
        .bytes;
    final secretBox = await AesGcm.with256bits().encrypt(
      utf8.encode(clearText),
      secretKey: SecretKey(key),
      nonce: nonce,
    );
    final tag = secretBox.mac.bytes;
    final data = <int>[
      tag.length >> 8,
      tag.length & 0xff,
      nonce.length >> 8,
      nonce.length & 0xff,
      ...tag,
      ...secretBox.cipherText,
      ...nonce,
    ];
    for (var start = 0; start < data.length; start += 32) {
      final stream = sha256
          .convert(utf8.encode('$readerSeed|v3|$keySeed|${start ~/ 32}'))
          .bytes;
      final end = start + 32 < data.length ? start + 32 : data.length;
      for (var index = start; index < end; index++) {
        data[index] ^= stream[index - start];
      }
    }
    final overlay = base64Url.encode([3, ...data]);

    expect(
      await MangaTekOverlayCrypto.decryptEnvelope(
        readerSeed: readerSeed,
        overlay: overlay,
        keySeed: keySeed,
        token: token,
        chapterId: chapterId,
      ),
      clearText,
    );
  });
}
