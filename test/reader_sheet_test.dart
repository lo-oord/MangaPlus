import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangaplus/app/core/theme/theme.dart';
import 'package:mangaplus/app/modules/chapter/widgets/reader_sheet.dart';

void main() {
  testWidgets(
      'reader sheet shows its header and content instead of a blank surface',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showReaderSheet<void>(
                  context,
                  child: const Column(
                    children: [
                      ReaderSheetHeader(title: 'قائمة الاختبار'),
                      Expanded(
                        child: Center(child: Text('محتوى ظاهر')),
                      ),
                    ],
                  ),
                ),
                child: const Text('فتح'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('فتح'));
    await tester.pumpAndSettle();

    expect(find.text('قائمة الاختبار'), findsOneWidget);
    expect(find.text('محتوى ظاهر'), findsOneWidget);
    expect(find.byTooltip('إغلاق'), findsOneWidget);
  });

  test('reader widgets never fall back to GetX overlay sheets', () {
    final offenders = <String>[];
    for (final entity in Directory('lib/app/modules/chapter/widgets')
        .listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      if (source.contains('Get.bottomSheet') || source.contains('Get.dialog')) {
        offenders.add(entity.path);
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Use showModalBottomSheet/showDialog so reader options cannot '
          'collapse into an empty grey barrier: $offenders',
    );
  });

  testWidgets('empty notice explains the state and offers retry',
      (tester) async {
    var retried = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: ReaderSheetNotice(
            icon: Icons.list_alt_rounded,
            title: 'لا توجد فصول',
            message: 'حاول التحديث.',
            actionLabel: 'تحديث',
            onAction: () => retried++,
          ),
        ),
      ),
    );

    expect(find.text('لا توجد فصول'), findsOneWidget);
    expect(find.text('حاول التحديث.'), findsOneWidget);
    await tester.tap(find.text('تحديث'));
    expect(retried, 1);
  });
}
