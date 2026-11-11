import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mangaplus/app/data/sources/mangatek_bundle_seeds.dart';

void main() {
  test('rejects bundles without the official string-array structure', () async {
    await expectLater(
      extractMangatekBundleSeeds('function unrelated(){ return "fixture"; }'),
      throwsA(isA<MangatekBundleSeedsException>()),
    );
  });

  test(
      'resolves wrapped and scoped seed expressions and verifies the WASM hash',
      () async {
    const readerSeed = '0123456789abcdef0123456789abcdef0123456789abcdef';
    const proofSalt = 'abcdef0123456789abcdef0123456789abcdef0123456789';
    const fixture = r'''
function strings(){const a=["AGFz","bQ==","0123456789abcdef01234567","89abcdef0123456789abcdef","abcdef0123456789abcdef01","23456789abcdef0123456789"];return a;}
function decode(i,a){i=i-0;const b=strings();return b[i];}
(function(a,b){for(;;){return;}})(strings,0);
function wrap(x,y){return decode(x+0,y+0)}
decode(0,0)+decode(1,0);
wrap(2,0)+wrap(3,0);
function holder(){return wrap(4,0)+wrap(5,0)}
''';

    final seeds = await extractMangatekBundleSeedsWithExpectedWasmHash(
      fixture,
      expectedWasmSha256:
          'cd5d4935a48c0672cb06407bb443bc0087aff947c6b864bac886982c73b3027f',
      evaluator: (script) async {
        expect(script, contains('decode(0,0)+decode(1,0)'));
        expect(script, contains('decode(2,0)+decode(3,0)'));
        expect(script, contains('decode(4,0)+decode(5,0)'));
        return jsonEncode(['AGFzbQ==', readerSeed, proofSalt]);
      },
    );

    expect(seeds.readerSeed, readerSeed);
    expect(seeds.proofSalt, proofSalt);
  });
}
