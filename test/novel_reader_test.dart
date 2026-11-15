import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangaplus/app/core/reader/novel_reader_model.dart';
import 'package:mangaplus/app/core/reader/novel_speech.dart';
import 'package:mangaplus/app/core/reader/novel_typography.dart';
import 'package:mangaplus/app/core/theme/theme.dart';
import 'package:mangaplus/app/modules/chapter/widgets/reader_novel_chrome.dart';

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(body: child),
    );

void main() {
  group('splitNovelSentences', () {
    test('splits Arabic sentences and keeps their punctuation', () {
      final sentences = splitNovelSentences(
        'وقف عند الباب. سأل: من هناك؟ ثم ابتسم!',
      );
      expect(sentences, [
        'وقف عند الباب.',
        'سأل: من هناك؟',
        'ثم ابتسم!',
      ]);
    });

    test('splits English and mixed text without losing words', () {
      final sentences = splitNovelSentences(
        'He opened the book. ثم قرأ الفصل الأول. It was long!',
      );
      expect(sentences.length, 3);
      expect(sentences.first, 'He opened the book.');
      expect(sentences[1], 'ثم قرأ الفصل الأول.');
      expect(sentences.last, 'It was long!');
    });

    test('keeps a paragraph without terminators as one sentence', () {
      expect(splitNovelSentences('نص بلا نقطة'), ['نص بلا نقطة']);
    });

    test('bounds very long sentences by words, never mid-word', () {
      final long = List.filled(120, 'كلمة').join(' ');
      final sentences = splitNovelSentences(long, maxChars: 60);
      expect(sentences.length, greaterThan(1));
      for (final sentence in sentences) {
        expect(sentence.length, lessThanOrEqualTo(60));
        expect(sentence.startsWith(' '), isFalse);
      }
    });

    test('empty input produces no sentences', () {
      expect(splitNovelSentences('   '), isEmpty);
    });
  });

  group('splitNovelSpeech', () {
    test('skips chapter dividers and keeps paragraph indexes', () {
      final content = [
        'الفقرة الأولى. جملة ثانية.',
        novelChapterDividerMarker('الفصل الثاني'),
        'فقرة الفصل الثاني.',
      ].join('\n\n');
      final chunks = splitNovelSpeech(content);

      expect(chunks.length, 3);
      expect(chunks.map((chunk) => chunk.paragraphIndex).toList(), [0, 0, 2]);
      expect(chunks.first.sentenceIndex, 0);
      expect(chunks[1].sentenceIndex, 1);
      expect(chunks.last.text, 'فقرة الفصل الثاني.');
    });

    test('returns an empty sequence for empty content', () {
      expect(splitNovelSpeech('  \n\n '), isEmpty);
    });
  });

  group('novelReadingPadding', () {
    test('uses the configured margins on a phone', () {
      expect(
        novelReadingPadding(viewportWidth: 400, margins: 24, maxWidth: 720),
        24,
      );
    });

    test('centres the text on a wide screen', () {
      final padding = novelReadingPadding(
        viewportWidth: 1200,
        margins: 24,
        maxWidth: 720,
      );
      expect(padding, 264);
    });

    test('never returns negative or unusable padding', () {
      expect(
        novelReadingPadding(viewportWidth: 20, margins: 60, maxWidth: 720),
        12,
      );
      expect(
        novelReadingPadding(viewportWidth: 0, margins: 24, maxWidth: 720),
        12,
      );
    });
  });

  group('NovelReaderTopBar', () {
    testWidgets('shows identity and progress', (tester) async {
      await tester.pumpWidget(
        _host(
          NovelReaderTopBar(
            comicTitle: 'رواية طويلة',
            chapterTitle: 'الفصل 3',
            pageLabel: '12%',
            progress: .04,
            onBack: () {},
            onBookmark: () {},
            onTools: () {},
          ),
        ),
      );

      expect(find.text('رواية طويلة'), findsOneWidget);
      expect(find.text('الفصل 3'), findsOneWidget);
      expect(find.text('12%'), findsOneWidget);
      expect(find.text('4%'), findsOneWidget);
      expect(find.byTooltip('أدوات الرواية'), findsOneWidget);
      expect(find.byTooltip('القراءة الصوتية'), findsNothing);
    });

    testWidgets('invokes back, bookmark and tools', (tester) async {
      var back = 0;
      var bookmark = 0;
      var tools = 0;
      await tester.pumpWidget(
        _host(
          NovelReaderTopBar(
            comicTitle: '',
            chapterTitle: 'الفصل',
            pageLabel: '0%',
            progress: 0,
            onBack: () => back++,
            onBookmark: () => bookmark++,
            onTools: () => tools++,
          ),
        ),
      );

      await tester.tap(find.byTooltip('رجوع'));
      await tester.tap(find.byTooltip('حفظ موضع القراءة'));
      await tester.tap(find.byTooltip('أدوات الرواية'));
      expect([back, bookmark, tools], [1, 1, 1]);
    });
  });

  group('NovelReaderBottomBar', () {
    testWidgets('exposes listen, settings and chapter actions',
        (tester) async {
      var listen = 0;
      var chapters = 0;
      var settings = 0;
      await tester.pumpWidget(
        _host(
          NovelReaderBottomBar(
            chapterTitle: 'الفصل 3',
            pageLabel: '40%',
            progress: .4,
            onListen: () => listen++,
            onSeek: (_) {},
            onSeekEnd: () {},
            onChapters: () => chapters++,
            onSettings: () => settings++,
          ),
        ),
      );

      expect(find.text('40% • 40%'), findsOneWidget);
      await tester.tap(find.byTooltip('الاستماع للفصل'));
      await tester.tap(find.byTooltip('قائمة الفصول'));
      await tester.tap(find.byTooltip('إعدادات القراءة'));
      expect([listen, chapters, settings], [1, 1, 1]);

      final previous = tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip('الفصل السابق'),
          matching: find.byType(IconButton),
        ),
      );
      expect(previous.onPressed, isNull);
    });

    testWidgets('reflects a running listening session', (tester) async {
      await tester.pumpWidget(
        _host(
          NovelReaderBottomBar(
            chapterTitle: 'الفصل',
            pageLabel: '1%',
            progress: .01,
            listening: true,
            onListen: () {},
            onSeek: (_) {},
            onSeekEnd: () {},
            onChapters: () {},
            onSettings: () {},
          ),
        ),
      );
      expect(find.byTooltip('الاستماع للفصل'), findsOneWidget);
    });
  });
}
