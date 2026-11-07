import 'package:flutter_test/flutter_test.dart';
import 'package:mangaplus/app/data/sources/manga_source_registry.dart';

/// Live verification for every content source.
///
/// These tests talk to the real source endpoints, so they are intentionally
/// kept outside `test/` (the default `flutter test` run stays hermetic).
///
/// Run all sources:
///   flutter test test_live/source_live_probe_test.dart
/// Run one source at a time (used by CI/manual audits):
///   flutter test test_live/source_live_probe_test.dart --dart-define=SOURCE_ID=team_x_manga
void main() {
  const onlySource = String.fromEnvironment('SOURCE_ID');
  final sources = MangaSourceRegistry.searchableSources
      .where((source) => onlySource.isEmpty || source.id == onlySource)
      .toList(growable: false);

  test('source registry contains unique ids', () {
    final ids = MangaSourceRegistry.searchableSources.map((s) => s.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  for (final source in sources) {
    group('${source.id} (${source.name})', () {
      late Map<String, dynamic> work;
      late List<dynamic> chapters;

      test('latest feed', () async {
        final latest =
            await source.latest().timeout(const Duration(seconds: 45));
        expect(latest, isNotEmpty, reason: '${source.id}: empty latest feed');
        final titled = latest.where((item) => '${item['title']}'.trim().isNotEmpty);
        expect(titled, isNotEmpty, reason: '${source.id}: items without titles');
        expect(
          titled.where((item) => '${item['url']}'.trim().isNotEmpty),
          isNotEmpty,
          reason: '${source.id}: items without work URLs',
        );
        expect(
          titled.where((item) => '${item['image_url'] ?? ''}'.trim().isNotEmpty),
          isNotEmpty,
          reason: '${source.id}: latest items without covers',
        );
        work = titled.first;
      });

      test('search', () async {
        final title = '${work['title']}'.trim();
        final words = title.split(RegExp(r'\s+')).where((w) => w.length >= 2);
        final query = words.isEmpty ? title : words.first;
        final results =
            await source.search(query).timeout(const Duration(seconds: 60));
        expect(results, isA<List<Map<String, dynamic>>>());
        for (final item in results) {
          expect('${item['title']}'.trim(), isNotEmpty,
              reason: '${source.id}: search item without title');
          expect('${item['source_id']}'.trim(), isNotEmpty,
              reason: '${source.id}: search item without source_id');
        }
      });

      test('details and chapter list', () async {
        final detail = await source
            .details('${work['url']}')
            .timeout(const Duration(seconds: 60));
        expect('${detail['title']}'.trim(), isNotEmpty,
            reason: '${source.id}: details without title');
        expect(detail['chapters'], isA<List>(),
            reason: '${source.id}: details without chapters list');
        chapters = detail['chapters'] as List;
        expect(chapters, isNotEmpty,
            reason: '${source.id}: no chapters resolved');
        final firstChapter = chapters.first as Map;
        final reference = '${firstChapter['url'] ?? firstChapter['chapter_url'] ?? ''}';
        expect(reference.trim(), isNotEmpty,
            reason: '${source.id}: chapter without a reference');
      });

      // MKNOV chapter bodies are decoded through an Android-only WOFF2 method
      // channel, which the Dart VM cannot provide (no TestWidgetsFlutterBinding
      // here because it also mocks HttpClient and blocks real source traffic).
      test('reader content', () async {
        expect(chapters, isNotEmpty);
        // A source may leave its newest chapter temporarily empty or removed;
        // that must not make the whole source unreadable, so try a few.
        Object? lastError;
        for (final entry in chapters.take(3)) {
          final chapter = entry as Map;
          final reference =
              '${chapter['url'] ?? chapter['chapter_url'] ?? ''}';
          try {
            final content = await source
                .chapterContent(reference)
                .timeout(const Duration(seconds: 60));
            if (content != null) {
              expect('${content['content'] ?? ''}'.trim(), isNotEmpty,
                  reason: '${source.id}: empty novel chapter body');
              return;
            }
            final images = await source
                .chapterImages(reference)
                .timeout(const Duration(seconds: 60));
            expect(images, isNotNull, reason: '${source.id}: no reader payload');
            final pages = images!['pages'];
            expect(pages, isA<List>(), reason: '${source.id}: no pages list');
            expect(pages as List, isNotEmpty,
                reason: '${source.id}: no pages');
            for (final page in pages) {
              expect('$page'.trim(), isNotEmpty);
            }
            return;
          } catch (error) {
            lastError = error;
          }
        }
        fail('${source.id}: no readable chapter among the first 3 ($lastError)');
      }, skip: source.id == 'mknov'
          ? 'Needs the Android WOFF2 decoder channel; verified on device only.'
          : null);

      test('registry resolves source by URL', () {
        final resolved = MangaSourceRegistry.forUrl('${work['url']}');
        expect(resolved, isNotNull,
            reason: '${source.id}: registry cannot resolve its own work URL');
        expect(resolved!.id, source.id);
        expect(MangaSourceRegistry.byId(source.id), isNotNull);
      });
    });
  }
}
