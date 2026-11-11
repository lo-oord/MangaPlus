import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mangaplus/app/core/reader/reader_chapter_cache.dart';
import 'package:mangaplus/app/data/models/chapter.dart';

ReaderChapterSnapshot snapshot(String id, {int pages = 2}) =>
    ReaderChapterSnapshot(
      chapterId: id,
      data: ChapterData(
        chapter: DataChapter(
          chapterId: id,
          title: id,
          images: [
            for (var index = 0; index < pages; index++) '$id/page$index'
          ],
          previousChapter: '',
          chapters: const [],
        ),
        source: 'test',
      ),
      status: ReaderChapterStatus.ready,
    );

void main() {
  test('an in-flight prefetch is reused by navigation, never returned as null',
      () async {
    var calls = 0;
    final completer = Completer<ReaderChapterSnapshot>();
    final cache = ReaderChapterCache(
      loader: (id) {
        calls++;
        return completer.future;
      },
    );

    final prefetch = cache.prefetch('chapter-2');
    final navigation = cache.load('chapter-2');
    expect(identical(prefetch, navigation), isTrue);
    expect(cache.isInFlight('chapter-2'), isTrue);

    completer.complete(snapshot('chapter-2'));
    final result = await navigation;
    expect(result.chapterId, 'chapter-2');
    expect(result.data.chapter.images, hasLength(2));
    expect(calls, 1);
  });

  test('returns cached chapters without another request', () async {
    var calls = 0;
    final cache = ReaderChapterCache(
      loader: (id) async {
        calls++;
        return snapshot(id);
      },
    );
    await cache.load('a');
    final cached = await cache.load('a');
    expect(calls, 1);
    expect(cached.status, ReaderChapterStatus.ready);
    expect(cache.isCached('a'), isTrue);
  });

  test('keeps a bounded LRU and evicts the oldest chapter', () async {
    final cache = ReaderChapterCache(
      capacity: 2,
      loader: (id) async => snapshot(id),
    );
    await cache.load('a');
    await cache.load('b');
    await cache.load('a');
    await cache.load('c');
    expect(cache.isCached('a'), isTrue);
    expect(cache.isCached('b'), isFalse);
    expect(cache.isCached('c'), isTrue);
    expect(cache.length, 2);
  });

  test('does not cache failures and allows a retry', () async {
    var calls = 0;
    final cache = ReaderChapterCache(
      loader: (id) async {
        calls++;
        if (calls == 1) throw StateError('offline');
        return snapshot(id);
      },
    );
    await expectLater(cache.load('a'), throwsStateError);
    expect(cache.isCached('a'), isFalse);
    expect(cache.isInFlight('a'), isFalse);
    final recovered = await cache.load('a');
    expect(recovered.chapterId, 'a');
    expect(calls, 2);
  });

  test('does not cache an unavailable empty chapter', () async {
    final cache = ReaderChapterCache(
      loader: (id) async => ReaderChapterSnapshot(
        chapterId: id,
        data: ChapterData(
          chapter: DataChapter(
            chapterId: id,
            images: const [],
            previousChapter: '',
            chapters: const [],
          ),
          source: 'test',
        ),
        status: ReaderChapterStatus.unavailable,
      ),
    );
    final result = await cache.load('empty');
    expect(result.isUsable, isFalse);
    expect(cache.isCached('empty'), isFalse);
  });
}
