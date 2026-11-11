import 'package:flutter_test/flutter_test.dart';
import 'package:mangaplus/app/core/reader/reader_offline_library.dart';

Map<String, dynamic> record({
  required String id,
  required String title,
  bool novel = false,
  String content = '',
  List<String> pages = const [],
  bool complete = true,
  int? pageCount,
  List<List<int>> sizes = const [],
  int totalBytes = 0,
}) =>
    {
      'comicId': 'comic-1',
      'comicTitle': 'عمل',
      'chapterId': id,
      'chapterTitle': title,
      'localImagePaths': pages,
      'content': content,
      'isNovel': novel,
      'complete': complete,
      'pageCount': pageCount ?? pages.length,
      'imageSizes': sizes,
      'totalBytes': totalBytes,
      'downloadedAt': '2026-01-01T00:00:00.000Z',
    };

ReaderOfflineResolution resolve(
  List<dynamic> records,
  String chapterId, {
  bool novel = false,
}) =>
    ReaderOfflineLibrary.resolve(
      records: records,
      chapterId: chapterId,
      comicId: 'comic-1',
      isNovel: novel,
      fileExists: (path) => path.startsWith('/ok/'),
      fileSize: (path) => path.startsWith('/ok/') ? 120 : 0,
    );

void main() {
  test('accepts a fully downloaded manga chapter and orders pages naturally',
      () {
    final result = resolve([
      record(
        id: 'c-2',
        title: 'الفصل 2',
        pages: const ['/ok/page_10.jpg', '/ok/page_2.jpg'],
        sizes: const [
          [100, 200],
          [100, 200]
        ],
        totalBytes: 240,
      ),
    ], 'c-2');

    expect(result.isReady, isTrue);
    expect(result.imagePaths, ['/ok/page_2.jpg', '/ok/page_10.jpg']);
    expect(result.chapter!.pageCount, 2);
    expect(result.imageSizes['/ok/page_2.jpg']!.height, 200);
  });

  test('rejects a chapter with a missing or empty page file', () {
    final result = resolve([
      record(
        id: 'c-1',
        title: 'الفصل 1',
        pages: const ['/ok/page_1.jpg', '/missing/page_2.jpg'],
      ),
    ], 'c-1');
    expect(result.isReady, isFalse);
    expect(result.issue, ReaderOfflineIssue.missingFiles);
    expect(result.issueMessage, isNotEmpty);
  });

  test('rejects a record that is not marked complete', () {
    final result = resolve([
      record(
        id: 'c-1',
        title: 'الفصل 1',
        pages: const ['/ok/page_1.jpg'],
        complete: false,
      ),
    ], 'c-1');
    expect(result.issue, ReaderOfflineIssue.incomplete);
  });

  test('rejects a page count that does not match the files', () {
    final result = resolve([
      record(
        id: 'c-1',
        title: 'الفصل 1',
        pages: const ['/ok/page_1.jpg'],
        pageCount: 3,
      ),
    ], 'c-1');
    expect(result.issue, ReaderOfflineIssue.incomplete);
  });

  test('validates offline novels by content and type', () {
    final novel = resolve([
      record(id: 'n-1', title: 'الفصل 1', novel: true, content: 'نص'),
    ], 'n-1', novel: true);
    expect(novel.isReady, isTrue);
    expect(novel.toChapterData(fallbackTitle: '')!.chapter.content, 'نص');

    final empty = resolve([
      record(id: 'n-2', title: 'الفصل 2', novel: true, content: '   '),
    ], 'n-2', novel: true);
    expect(empty.issue, ReaderOfflineIssue.emptyContent);

    final wrongType = resolve([
      record(id: 'n-3', title: 'الفصل 3', novel: true, content: 'نص'),
    ], 'n-3');
    expect(wrongType.issue, ReaderOfflineIssue.wrongType);
  });

  test('builds previous and next chapter links from the local library', () {
    final result = resolve([
      record(id: 'c-1', title: 'الفصل 1', pages: const ['/ok/page_1.jpg']),
      record(id: 'c-2', title: 'الفصل 2', pages: const ['/ok/page_1.jpg']),
      record(id: 'c-3', title: 'الفصل 3', pages: const ['/ok/page_1.jpg']),
    ], 'c-2');
    expect(result.nextChapterId, 'c-3');
    expect(result.previousChapterId, 'c-1');
    expect(
        result.navigation.map((item) => item.chapterId), ['c-3', 'c-2', 'c-1']);
  });

  test('counts only verified byte sizes for storage usage', () {
    final bytes = ReaderOfflineLibrary.usedBytes([
      record(
        id: 'c-1',
        title: 'الفصل 1',
        pages: const ['/ok/page_1.jpg', '/ok/page_2.jpg'],
        totalBytes: 500,
      ),
      record(
        id: 'c-2',
        title: 'الفصل 2',
        pages: const ['/ok/page_3.jpg'],
      ),
    ], fileSize: (path) => path.startsWith('/ok/') ? 120 : 0);
    expect(bytes, 620);
  });

  test('ignores records belonging to another comic', () {
    final foreign = record(
      id: 'x-1',
      title: 'الفصل 1',
      pages: const ['/ok/page_1.jpg'],
    )..['comicId'] = 'comic-2';
    final result = resolve([foreign], 'x-1');
    expect(result.issue, ReaderOfflineIssue.notFound);
  });
}
