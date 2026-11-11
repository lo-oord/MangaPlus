import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_js/flutter_js.dart';

/// A failure to parse or verify the Mangatek reader bundle.
class MangatekBundleSeedsException implements Exception {
  const MangatekBundleSeedsException(this.message);
  final String message;

  @override
  String toString() => 'MangatekBundleSeedsException: $message';
}

class MangatekBundleSeeds {
  const MangatekBundleSeeds(
      {required this.proofSalt, required this.readerSeed});

  final String proofSalt;
  final String readerSeed;
}

/// Extracts the two rotating reader seeds from the official obfuscated bundle.
/// No heuristic or unverified fallback is used: every required invariant must hold.
Future<MangatekBundleSeeds> extractMangatekBundleSeeds(String source) async {
  final bundle = _Bundle(source, _wasmSha256);
  return bundle.extract();
}

@visibleForTesting
Future<MangatekBundleSeeds> extractMangatekBundleSeedsWithExpectedWasmHash(
  String source, {
  required String expectedWasmSha256,
  required Future<String> Function(String script) evaluator,
}) =>
    _Bundle(source, expectedWasmSha256, evaluator: evaluator).extract();

class _Wrapper {
  const _Wrapper(this.position, this.scope, this.target, this.args);
  final int position;
  final _Range scope;
  final String target;
  final List<(int, int)> args;
}

class _Site {
  const _Site(this.position, this.expression);
  final int position;
  final String expression;
}

class _Range {
  const _Range(this.first, this.last);
  final int first;
  final int last;
  bool contains(int value) => value >= first && value <= last;
  int get length => last - first;
}

class _Bundle {
  _Bundle(this.js, this.expectedWasmSha256, {this.evaluator})
      : blocks = _scanBlocks(js) {
    for (final block in blocks) {
      closeOf[block.first] = block.last;
      openOf[block.last] = block.first;
    }
    final regex = RegExp(
        r'function ([\w$]+)\(([\w$]+),([\w$]+)\)\{return ([\w$]+)\(([^()]*)\)\}');
    for (final match in regex.allMatches(js)) {
      final name = match.group(1)!;
      final first = match.group(2)!;
      final second = match.group(3)!;
      final args = <(int, int)>[];
      var valid = true;
      for (final arg in match.group(5)!.split(',')) {
        final part =
            RegExp(r'([\w$]+)(?:\s*([+-])\s*(-?\d+))?').firstMatch(arg.trim());
        if (part == null || part.group(0) != arg.trim()) {
          valid = false;
          break;
        }
        final index = part.group(1) == first
            ? 0
            : part.group(1) == second
                ? 1
                : -1;
        if (index < 0) {
          valid = false;
          break;
        }
        final amount = int.tryParse(part.group(3) ?? '0');
        if (amount == null) {
          valid = false;
          break;
        }
        args.add((index, (part.group(2) == '-' ? -1 : 1) * amount));
      }
      if (valid) {
        (wrappers[name] ??= []).add(
            _Wrapper(match.start, _scope(match.start), match.group(4)!, args));
      }
    }
  }

  final String js;
  final String expectedWasmSha256;
  final Future<String> Function(String script)? evaluator;
  final List<_Range> blocks;
  final Map<int, int> closeOf = {};
  final Map<int, int> openOf = {};
  final Map<String, List<_Wrapper>> wrappers = {};
  late final String decoderName;
  late final String prelude;

  Future<MangatekBundleSeeds> extract() async {
    _buildPrelude();
    final sites = _concatSites();
    if (sites.isEmpty) {
      throw const MangatekBundleSeedsException(
          'No concatenated string lookup sites found');
    }
    final script =
        '$prelude JSON.stringify([${sites.map((s) => '(() => { try { return String(${s.expression}) } catch (e) { return null } })()').join(',')}])';
    try {
      final resultJson = evaluator == null
          ? await _evaluateWithQuickJs(script)
          : await evaluator!(script);
      final decoded = jsonDecode(resultJson);
      if (decoded is! List) {
        throw const MangatekBundleSeedsException(
            'Reader bundle evaluation did not return a list');
      }
      final values = <(int, String)>[];
      for (var i = 0; i < decoded.length && i < sites.length; i++) {
        final value = decoded[i];
        if (value is String) values.add((sites[i].position, value));
      }
      final wasm = _firstOrNull(
          values.map((e) => e.$2).where((s) => s.startsWith('AGFzbQ')));
      if (wasm == null) {
        throw const MangatekBundleSeedsException(
            'No decoded WASM module found');
      }
      Uint8List wasmBytes;
      try {
        wasmBytes = base64.decode(wasm);
      } on FormatException {
        throw const MangatekBundleSeedsException(
            'WASM module is not valid base64');
      }
      if (sha256.convert(wasmBytes).toString() != expectedWasmSha256) {
        throw const MangatekBundleSeedsException(
            'Reader bundle WASM hash did not match');
      }
      final seeds = values
          .where((e) => RegExp(r'^[0-9a-f]{48}$').hasMatch(e.$2))
          .toList();
      final top = seeds.where((e) => _depth(e.$1) == 0).toList();
      final nested = seeds.where((e) => _depth(e.$1) != 0).toList();
      if (top.length != 1) {
        throw MangatekBundleSeedsException(
            'Expected one top-level readerSeed, found ${top.length}');
      }
      if (nested.length != 1) {
        throw MangatekBundleSeedsException(
            'Expected one nested proofSalt, found ${nested.length}');
      }
      return MangatekBundleSeeds(
          proofSalt: nested.single.$2, readerSeed: top.single.$2);
    } on MangatekBundleSeedsException {
      rethrow;
    } catch (error) {
      throw MangatekBundleSeedsException(
          'Unable to extract verified reader seeds: $error');
    }
  }

  Future<String> _evaluateWithQuickJs(String script) async {
    final runtime = getJavascriptRuntime();
    try {
      final result = runtime.evaluate(script);
      if (result.isError) {
        throw const MangatekBundleSeedsException(
          'Reader bundle JavaScript evaluation failed',
        );
      }
      return result.stringResult;
    } finally {
      runtime.dispose();
    }
  }

  void _buildPrelude() {
    final array =
        RegExp(r'function ([\w$]+)\(\)\{const [\w$]+=\[').firstMatch(js);
    if (array == null) {
      throw const MangatekBundleSeedsException(
          'No string array in reader bundle');
    }
    final arrayName = array.group(1)!;
    final decoder = _firstOrNull(RegExp(
            r'function ([\w$]+)\(([\w$]+),[\w$]+\)\{\2=\2-[^;]+;const [\w$]+=([\w$]+)\(\)')
        .allMatches(js)
        .where((m) => m.group(3) == arrayName));
    if (decoder == null) {
      throw const MangatekBundleSeedsException(
          'No string decoder in reader bundle');
    }
    decoderName = decoder.group(1)!;
    final rotation = _firstOrNull(RegExp(r'\}\)\(([\w$]+),')
        .allMatches(js)
        .where((m) => m.group(1) == arrayName));
    if (rotation == null) {
      throw const MangatekBundleSeedsException(
          'No string array rotation in reader bundle');
    }
    prelude =
        '${_functionAt(array.start)};\n${_functionAt(decoder.start)};\n${_rotationAt(rotation.start)};\n';
  }

  String _functionAt(int start) {
    final open = js.indexOf('{', start);
    final close = closeOf[open];
    if (close == null) {
      throw const MangatekBundleSeedsException('Unbalanced helper function');
    }
    return js.substring(start, close + 1);
  }

  String _rotationAt(int matchStart) {
    final close = js.lastIndexOf('}', matchStart);
    final open = openOf[close];
    if (open == null) {
      throw const MangatekBundleSeedsException('Unbalanced rotation helper');
    }
    final start = js.lastIndexOf('(function', open);
    if (start < 0) {
      throw const MangatekBundleSeedsException('Unexpected rotation helper');
    }
    var i = close + 2, depth = 0;
    do {
      if (i >= js.length) {
        throw const MangatekBundleSeedsException(
            'Unterminated rotation helper');
      }
      if (js[i] == '(') depth++;
      if (js[i] == ')') depth--;
      i++;
    } while (depth > 0);
    var source = js.substring(start, i);
    if (!source.contains('for(;;)')) {
      throw const MangatekBundleSeedsException('Unexpected rotation loop');
    }
    source = source.replaceFirst('for(;;)',
        'for(let rotationGuard=0;rotationGuard<10000;rotationGuard++)');
    return source;
  }

  List<_Site> _concatSites() {
    final sites = <_Site>[];
    final calls = RegExp(
        r'''([\w$]+)\((-?\d+(?:e\d+)?|"[^"\\]*"|'[^'\\]*'),(-?\d+(?:e\d+)?|"[^"\\]*"|'[^'\\]*')\)''');
    var from = 0;
    while (true) {
      final start =
          calls.matchAsPrefix(js, from) ?? calls.firstMatch(js.substring(from));
      if (start == null) break;
      final absolute =
          start.start + (calls.matchAsPrefix(js, from) == null ? from : 0);
      final endCall =
          start.end + (calls.matchAsPrefix(js, from) == null ? from : 0);
      if (absolute > 0 && RegExp(r'[\w$.]').hasMatch(js[absolute - 1])) {
        from = endCall;
        continue;
      }
      final first = calls.matchAsPrefix(js, absolute)!;
      final pieces = <(int, int, String, String, String)>[
        (absolute, first.end, first.group(1)!, first.group(2)!, first.group(3)!)
      ];
      var end = first.end;
      while (true) {
        var j = end;
        while (j < js.length && js[j] == ')') {
          j++;
        }
        if (j >= js.length || js[j] != '+') break;
        j++;
        while (j < js.length && js[j] == '(') {
          j++;
        }
        final p = calls.matchAsPrefix(js, j);
        if (p != null) {
          pieces.add((j, p.end, p.group(1)!, p.group(2)!, p.group(3)!));
          end = p.end;
          continue;
        }
        final literal =
            RegExp(r'''("[^"\\]*"|'[^'\\]*')''').matchAsPrefix(js, j);
        if (literal != null) {
          pieces.add((j, literal.end, '', literal.group(0)!, ''));
          end = literal.end;
          continue;
        }
        break;
      }
      if (pieces.length > 1) {
        final expressions = <String?>[];
        for (final p in pieces) {
          expressions
              .add(p.$3.isEmpty ? p.$4 : _resolve(p.$3, [p.$4, p.$5], p.$1));
        }
        if (expressions.every((e) => e != null)) {
          sites.add(_Site(absolute, expressions.join('+')));
        }
      }
      from = end > absolute ? end : absolute + 1;
    }
    return sites;
  }

  String? _resolve(String name, List<String> args, int position) {
    var target = name, current = args, from = position;
    for (var n = 0; n < 32; n++) {
      final candidates =
          wrappers[target]?.where((w) => w.scope.contains(from)).toList() ?? [];
      candidates.sort((a, b) => a.scope.length.compareTo(b.scope.length));
      if (candidates.isEmpty) {
        return target == decoderName
            ? '$decoderName(${current.join(',')})'
            : null;
      }
      final w = candidates.first;
      final mapped = <String>[];
      for (final arg in w.args) {
        final value = double.tryParse(current[arg.$1]);
        if (arg.$2 != 0 && value == null) return null;
        mapped.add(arg.$2 == 0
            ? current[arg.$1]
            : (value!.toInt() + arg.$2).toString());
      }
      target = w.target;
      current = mapped;
      from = w.position;
    }
    return null;
  }

  _Range _scope(int position) {
    final enclosing = blocks
        .where((b) => position > b.first && position < b.last)
        .toList()
      ..sort((a, b) => a.length.compareTo(b.length));
    return enclosing.isEmpty ? _Range(0, js.length - 1) : enclosing.first;
  }

  int _depth(int position) =>
      blocks.where((b) => position > b.first && position < b.last).length;
}

List<_Range> _scanBlocks(String js) {
  final result = <_Range>[];
  final stack = <int>[];
  var i = 0, previous = ';';
  void template() {
    while (i < js.length) {
      if (js[i] == r'\') {
        i += 2;
        continue;
      }
      if (js[i] == '`') {
        i++;
        return;
      }
      if (js[i] == r'$' && i + 1 < js.length && js[i + 1] == '{') {
        stack.add(-1);
        i += 2;
        return;
      }
      i++;
    }
  }

  while (i < js.length) {
    final c = js[i];
    if (c == '"' || c == "'") {
      i++;
      while (i < js.length && js[i] != c) {
        if (js[i] == r'\') i++;
        i++;
      }
      i++;
      previous = 'a';
      continue;
    }
    if (c == '`') {
      i++;
      template();
      previous = 'a';
      continue;
    }
    if (c == '/' && i + 1 < js.length && js[i + 1] == '/') {
      final n = js.indexOf('\n', i);
      i = n < 0 ? js.length : n;
      continue;
    }
    if (c == '/' && i + 1 < js.length && js[i + 1] == '*') {
      final n = js.indexOf('*/', i + 2);
      i = n < 0 ? js.length : n + 2;
      continue;
    }
    if (c == '/' && '(:,=:[!&|?{};+-*%<>~^'.contains(previous)) {
      i++;
      var inClass = false;
      while (i < js.length) {
        if (js[i] == r'\') {
          i += 2;
          continue;
        }
        if (js[i] == '[') inClass = true;
        if (js[i] == ']') inClass = false;
        if (js[i] == '/' && !inClass) break;
        i++;
      }
      i++;
      while (i < js.length && RegExp(r'[A-Za-z]').hasMatch(js[i])) {
        i++;
      }
      previous = 'a';
      continue;
    }
    if (c == '{') {
      stack.add(i);
      i++;
      previous = c;
      continue;
    }
    if (c == '}') {
      final open = stack.isEmpty ? null : stack.removeLast();
      i++;
      if (open == -1) {
        template();
      } else if (open != null) {
        result.add(_Range(open, i - 1));
      }
      previous = c;
      continue;
    }
    if (!RegExp(r'\s').hasMatch(c)) previous = c;
    i++;
  }
  return result;
}

const _wasmSha256 =
    '7ae024b07b1264939707262242c6810b570b0bc1051c01c35dcd864e9bdecd2e';

T? _firstOrNull<T>(Iterable<T> values) {
  for (final value in values) {
    return value;
  }
  return null;
}
