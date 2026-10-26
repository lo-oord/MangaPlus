import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mangaplus/app/data/services/comic_service.dart';
import 'package:mangaplus/app/data/sources/source_base.dart';

void main() {
  test('a timed-out detail request is removed so it can be retried', () async {
    final source = _HangingThenHealthySource();
    final service = ComicService(
      sourceResolver: (_) => source,
      detailRequestTimeout: const Duration(milliseconds: 30),
    );

    await expectLater(
      service.fetchComicDetail('https://example.test/comic/1'),
      throwsA(isA<TimeoutException>()),
    );

    final retry = await service.fetchComicDetail('https://example.test/comic/1');
    expect(retry.comicDetail.title, 'Recovered manga');
    final cached = await service.fetchComicDetail('https://example.test/comic/1');
    expect(cached.comicDetail.title, 'Recovered manga');
    expect(source.detailRequests, 2);
  });
}

class _HangingThenHealthySource extends ContentSource {
  int detailRequests = 0;

  @override
  String get id => 'test';

  @override
  String get name => 'Test source';

  @override
  String get kind => 'manga';

  @override
  List<String> get hosts => const ['example.test'];

  @override
  Future<List<Map<String, dynamic>>> search(String query) async => const [];

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) async => const [];

  @override
  Future<Map<String, dynamic>> details(String url) async {
    detailRequests++;
    if (detailRequests == 1) {
      await Completer<Map<String, dynamic>>().future;
    }
    return {'url': url, 'title': 'Recovered manga'};
  }

  @override
  Future<Map<String, dynamic>?> streams(String url) async => null;
}
