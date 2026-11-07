import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangaplus/app/core/utils/chapter_selection.dart';

const _base = 'https://site.test/manga/work';
List<String> _chapterIds(int count) =>
    List.generate(count, (index) => '$_base/chapter/${index + 1}');

void main() {
  group('ChapterSelection', () {
    test('selecting one chapter updates the counter to 1', () {
      final selection = ChapterSelection();
      expect(selection.count, 0);
      expect(selection.toggle(_chapterIds(5)[0]), isTrue);
      expect(selection.count, 1);
      expect(selection.contains(_chapterIds(5)[0]), isTrue);
    });

    test('selecting three distinct chapters counts three', () {
      final ids = _chapterIds(5);
      final selection = ChapterSelection();
      for (final id in ids.take(3)) {
        selection.toggle(id);
      }
      expect(selection.count, 3);
      expect(selection.coversAll(ids.take(3)), isTrue);
      expect(selection.coversAll(ids), isFalse);
    });

    test('select all and deselect all cover exactly the visible range', () {
      final ids = _chapterIds(12);
      final selection = ChapterSelection();
      selection.selectAll(ids);
      expect(selection.count, ids.length);
      expect(selection.coversAll(ids), isTrue);
      selection.deselectAll(ids);
      expect(selection.isEmpty, isTrue);
      expect(selection.count, 0);
    });

    test('deselecting one chapter decrements the counter', () {
      final ids = _chapterIds(3);
      final selection = ChapterSelection()..selectAll(ids);
      selection.toggle(ids[1]);
      expect(selection.count, 2);
      expect(selection.contains(ids[1]), isFalse);
      expect(selection.contains(ids[0]), isTrue);
    });

    test('duplicate identifiers collapse into a single selection', () {
      final selection = ChapterSelection();
      final id = _chapterIds(1).single;
      selection
        ..toggle(id)
        ..toggle(id)
        ..toggle(id);
      expect(selection.count, 1);
      expect(ChapterSelection().add(id), isTrue);
    });

    test('empty and placeholder identifiers are ignored', () {
      final selection = ChapterSelection();
      expect(selection.toggle(''), isFalse);
      expect(selection.toggle('null'), isFalse);
      expect(selection.count, 0);
    });

    test('same chapter id from different works or sources stays separate', () {
      const sharedId = 'https://site.test/chapter/1';
      final first = ChapterSelection(scope: 'https://a.test/manga/x');
      final second = ChapterSelection(scope: 'https://b.test/manga/x');
      first.add(sharedId);
      expect(first.contains(sharedId), isTrue);
      expect(second.contains(sharedId), isFalse);
      expect(second.count, 0);
    });

    test('selection is independent from list order', () {
      final ids = _chapterIds(6);
      final selection = ChapterSelection()..selectAll([ids[0], ids[3], ids[5]]);
      final reordered = [...ids.reversed];
      expect(selection.selectedCountOf(reordered), 3);
      expect(selection.ids.toSet(), {ids[0], ids[3], ids[5]});
    });

    test('the queue receives exactly the selected unique ids', () {
      final ids = _chapterIds(5);
      final selection = ChapterSelection()
        ..toggle(ids[0])
        ..toggle(ids[2])
        ..toggle(ids[4]);
      final queued = ids.where(selection.contains).toList(growable: false);
      expect(queued, [ids[0], ids[2], ids[4]]);
      expect(queued.length, selection.count);
    });
  });

  group('selection in a rebuilding list', () {
    testWidgets('each selected row renders its own checkmark and counter',
        (tester) async {
      final ids = _chapterIds(3);
      await tester.pumpWidget(_SelectionHarness(ids: ids));

      for (var index = 0; index < ids.length; index++) {
        await tester.tap(find.byKey(ValueKey(ids[index])));
        await tester.pumpAndSettle();
      }

      expect(find.text('3'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNWidgets(3));
      expect(find.byIcon(Icons.circle_outlined), findsNothing);
    });

    testWidgets('selection survives scrolling and a reordered rebuild',
        (tester) async {
      final ids = _chapterIds(40);
      await tester.pumpWidget(_SelectionHarness(ids: ids));

      Future<void> tapRow(int index) async {
        await tester.tap(find.byKey(ValueKey(ids[index])));
        await tester.pumpAndSettle();
      }

      await tapRow(0);
      await tapRow(1);
      await tapRow(2);
      expect(find.text('3'), findsOneWidget);

      // Scroll away and back: selection survives because it is keyed by id.
      await tester.drag(find.byType(Scrollable), const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(Scrollable), const Offset(0, 500));
      await tester.pumpAndSettle();
      expect(find.text('3'), findsOneWidget);

      // Reverse the list order and rebuild: the same chapters stay selected.
      await tester.tap(find.byKey(const ValueKey('reverse')));
      await tester.pumpAndSettle();
      expect(find.text('3'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('clear')));
      await tester.pumpAndSettle();
      expect(find.text('0'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNothing);
    });
  });
}

class _SelectionHarness extends StatefulWidget {
  const _SelectionHarness({required this.ids});
  final List<String> ids;

  @override
  State<_SelectionHarness> createState() => _SelectionHarnessState();
}

class _SelectionHarnessState extends State<_SelectionHarness> {
  final ChapterSelection _selection = ChapterSelection();
  bool _reversed = false;

  @override
  Widget build(BuildContext context) {
    final ids = _reversed
        ? widget.ids.reversed.toList(growable: false)
        : widget.ids;
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          actions: [
            Text('${_selection.count}', key: const ValueKey('count')),
            IconButton(
              key: const ValueKey('reverse'),
              icon: const Icon(Icons.swap_vert),
              onPressed: () => setState(() => _reversed = !_reversed),
            ),
            IconButton(
              key: const ValueKey('clear'),
              icon: const Icon(Icons.clear),
              onPressed: () => setState(_selection.clear),
            ),
          ],
        ),
        body: ListView.builder(
          itemCount: ids.length,
          itemBuilder: (context, index) {
            final id = ids[index];
            final selected = _selection.contains(id);
            return ListTile(
              key: ValueKey(id),
              onTap: () => setState(() => _selection.toggle(id)),
              leading: Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
              ),
              title: Text('Chapter ${index + 1}'),
            );
          },
        ),
      ),
    );
  }
}
