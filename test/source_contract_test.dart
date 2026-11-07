import 'package:flutter_test/flutter_test.dart';
import 'package:mangaplus/app/data/sources/manga_source_registry.dart';

/// Hermetic contract checks for every content source.
///
/// Live endpoint behaviour is verified separately by
/// `test_live/source_live_probe_test.dart`; this test only guarantees the
/// registry/identity invariants the rest of the app relies on, so a single
/// broken source can never break the others.
void main() {
  final sources = MangaSourceRegistry.searchableSources;

  test('registry exposes every source exactly once', () {
    expect(sources, isNotEmpty);
    final ids = sources.map((source) => source.id).toList();
    expect(ids.toSet().length, ids.length, reason: 'duplicate source ids');
    final names = sources.map((source) => source.name).toList();
    for (final source in sources) {
      expect(source.id.trim(), isNotEmpty);
      expect(source.name.trim(), isNotEmpty);
      expect(source.kind, anyOf('manga', 'novel'),
          reason: '${source.id}: unknown kind ${source.kind}');
      expect(source.hosts, isNotEmpty,
          reason: '${source.id}: no hosts to resolve links');
      expect(names.where((name) => name == source.name).length, 1,
          reason: '${source.id}: duplicate display name');
    }
  });

  for (final source in sources) {
    test('${source.id} resolves its own links', () {
      expect(MangaSourceRegistry.byId(source.id), same(source));
      expect(source.handles(''), isFalse);
      expect(source.handles('https://unrelated.invalid/work'), isFalse);
      for (final host in source.hosts) {
        // Some sources (Kawaii) intentionally route by URL path instead of
        // accepting every URL on their host, so only assert the invariants
        // that their own resolver claims to support.
        final probe = 'https://$host/example/work';
        if (!source.handles(probe)) continue;
        expect(MangaSourceRegistry.forUrl(probe)?.id, source.id,
            reason: '${source.id}: registry resolves $host to another source');
      }
    });
  }

  test('shared Kawaii host routes manga and novels by path', () {
    const novelUrl = 'https://kawaiimanga.org/novel/some-novel/chapter-1';
    const mangaUrl = 'https://kawaiimanga.org/manga/some-manga/chapter-1';
    expect(MangaSourceRegistry.kawaiiNovels.handles(novelUrl), isTrue);
    expect(MangaSourceRegistry.kawaiiManga.handles(novelUrl), isFalse);
    expect(MangaSourceRegistry.forUrl(novelUrl)?.id, 'kawaii_novels');
    expect(MangaSourceRegistry.kawaiiManga.handles(mangaUrl), isTrue);
    expect(MangaSourceRegistry.kawaiiNovels.handles(mangaUrl), isFalse);
    expect(MangaSourceRegistry.forUrl(mangaUrl)?.id, 'kawaii_manga');
  });

  test('Azora resolves both its app scheme and its public hosts', () {
    expect(MangaSourceRegistry.azora.handles('azora://series/123'), isTrue);
    expect(
      MangaSourceRegistry.azora.handles('https://azorafly.com/series/123'),
      isTrue,
    );
    expect(
      MangaSourceRegistry.forUrl('https://azorafly.com/series/123')?.id,
      'azora',
    );
  });

  test('source kinds cover manga and novels', () {
    expect(sources.where((source) => source.kind == 'manga'), isNotEmpty);
    expect(sources.where((source) => source.kind == 'novel'), isNotEmpty);
  });
}
