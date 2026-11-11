import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mangaplus/app/core/reader/reader_image_pipeline.dart';

void main() {
  test('never runs more than maxConcurrent loads and deduplicates URLs',
      () async {
    final started = <String>[];
    final completers = <String, Completer<void>>{};
    final pipeline = ReaderImagePipeline(
      maxConcurrent: 2,
      loader: (url) {
        started.add(url);
        return (completers[url] = Completer<void>()).future;
      },
    );

    for (final url in const ['a', 'b', 'c', 'd']) {
      pipeline.request(url);
    }
    await Future<void>.delayed(Duration.zero);
    expect(started, ['a', 'b']);
    expect(pipeline.pendingCount, 2);

    pipeline.request('a');
    pipeline.request('b');
    await Future<void>.delayed(Duration.zero);
    expect(started, ['a', 'b']);

    completers['a']!.complete();
    await Future<void>.delayed(Duration.zero);
    expect(started, ['a', 'b', 'c']);

    completers['b']!.complete();
    completers['c']!.complete();
    await Future<void>.delayed(Duration.zero);
    completers['d']!.complete();
    await pipeline.whenIdle;
    expect(started, ['a', 'b', 'c', 'd']);
    expect(pipeline.isCompleted('d'), isTrue);
  });

  test('serves a visible page before queued background prefetches', () async {
    final started = <String>[];
    final blocker = Completer<void>();
    final pipeline = ReaderImagePipeline(
      maxConcurrent: 1,
      loader: (url) {
        started.add(url);
        return blocker.future;
      },
    );
    pipeline.request('running');
    await Future<void>.delayed(Duration.zero);
    pipeline.request('background', priority: ReaderImagePriority.background);
    pipeline.request('visible', priority: ReaderImagePriority.visible);
    blocker.complete();
    await pipeline.whenIdle;
    expect(started, ['running', 'visible', 'background']);
  });

  test('retries a bounded number of times and then reports failure', () async {
    var attempts = 0;
    Object? reported;
    final pipeline = ReaderImagePipeline(
      maxConcurrent: 1,
      maxAttempts: 3,
      retryDelay: Duration.zero,
      loader: (url) async {
        attempts++;
        throw StateError('network');
      },
      onError: (url, error) => reported = error,
    );
    pipeline.request('page');
    await pipeline.whenIdle;
    expect(attempts, 3);
    expect(pipeline.isFailed('page'), isTrue);
    expect(reported, isNotNull);
  });

  test('can retry a successful URL after it is forgotten', () async {
    var attempts = 0;
    final pipeline = ReaderImagePipeline(
      loader: (url) async => attempts++,
    );
    pipeline.request('page');
    await pipeline.whenIdle;
    pipeline.request('page');
    await pipeline.whenIdle;
    expect(attempts, 1);
    pipeline.forget('page');
    pipeline.request('page');
    await pipeline.whenIdle;
    expect(attempts, 2);
  });

  test('cancels only pending work and leaves running work alone', () async {
    final started = <String>[];
    final completers = <String, Completer<void>>{};
    final pipeline = ReaderImagePipeline(
      maxConcurrent: 1,
      loader: (url) {
        started.add(url);
        return (completers[url] = Completer<void>()).future;
      },
    );
    pipeline.request('a');
    pipeline.request('b');
    pipeline.request('c');
    await Future<void>.delayed(Duration.zero);
    pipeline.cancel('c');
    completers['a']!.complete();
    await Future<void>.delayed(Duration.zero);
    completers['b']!.complete();
    await pipeline.whenIdle;
    expect(started, ['a', 'b']);
    expect(pipeline.isQueued('c'), isFalse);
  });
}
