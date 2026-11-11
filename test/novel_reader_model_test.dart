import 'package:flutter_test/flutter_test.dart';
import 'package:mangaplus/app/core/reader/novel_reader_model.dart';

void main() {
  test('splits text into trimmed paragraphs and preserves divider markers', () {
    final marker = novelChapterDividerMarker('الفصل 2');
    final paragraphs = splitNovelParagraphs(
      '  الفقرة الأولى  \n\n\n$marker\nالفقرة الثانية\n',
    );
    expect(paragraphs, ['الفقرة الأولى', marker, 'الفقرة الثانية']);
    expect(isNovelChapterDivider(paragraphs[1]), isTrue);
    expect(titleFromNovelChapterDivider(paragraphs[1]), 'الفصل 2');
  });

  test('searches case-insensitively and skips chapter dividers', () {
    final paragraphs = [
      'بداية Chapter One',
      novelChapterDividerMarker('Chapter Two'),
      'chapter one مرة أخرى',
    ];
    final hits = searchNovelParagraphs(paragraphs, 'CHAPTER');
    expect(hits, hasLength(2));
    expect(hits.map((hit) => hit.paragraphIndex), [0, 2]);
    expect(hits.first.matchedText.toLowerCase(), 'chapter');
    expect(searchNovelParagraphs(paragraphs, '   '), isEmpty);
    expect(
        searchNovelParagraphs(paragraphs, 'chapter', limit: 1), hasLength(1));
  });

  test('note highlight resolves its quote, including after text drift', () {
    final note = NovelNote(
      id: '1',
      chapterId: 'c',
      paragraphIndex: 0,
      note: 'ملاحظة',
      quote: 'مهم',
      color: '#ffd54f',
      createdAt: DateTime(2026),
      start: 2,
      end: 5,
    );
    expect(note.resolveRange('نص مهم هنا'), (start: 3, end: 6));
    expect(note.isHighlightOnly, isFalse);

    final json = NovelNote.fromJson(note.toJson());
    expect(json.quote, 'مهم');
    expect(json.paragraphIndex, 0);
    expect(json.resolveRange('مهم جدا').start, 0);
    expect(novelNoteColorValue('#ffd54f'), 0xffffd54f);
    expect(novelNoteColorValue('bad'), 0xffffd54f);
  });

  test('a note without a quote highlights the whole paragraph', () {
    final note = NovelNote(
      id: '2',
      chapterId: 'c',
      paragraphIndex: 3,
      note: '',
      quote: '',
      color: '#81c784',
      createdAt: DateTime(2026),
    );
    expect(note.isHighlightOnly, isTrue);
    expect(note.hasRange, isFalse);
    expect(note.resolveRange('أي نص').end, 0);
  });
}
