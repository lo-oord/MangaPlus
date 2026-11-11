import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangaplus/app/data/sources/mangatek_overlay.dart';

void main() {
  testWidgets('renders bubble text and its configured stroke', (tester) async {
    const url = 'https://api.mangatek.com/page.webp#'
        '[{"text":"نص تجريبي","x":10,"y":12,"w":140,"h":70,'
        '"font_size_px":20,"line_height":1.2,"color":"#000000",'
        '"stroke_color":"#ffffff","stroke_width_px":2}]';

    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 240,
          height: 320,
          child: MangaTekOverlay(
            imageUrl: url,
            child: ColoredBox(color: Colors.grey),
          ),
        ),
      ),
    );

    expect(find.text('نص تجريبي'), findsNWidgets(2));
    final textWidgets =
        tester.widgetList<Text>(find.text('نص تجريبي')).toList();
    expect(textWidgets.any((text) => text.style?.foreground != null), isTrue);
    expect(textWidgets.any((text) => text.style?.color != null), isTrue);
  });
}
