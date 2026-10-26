import 'package:flutter_test/flutter_test.dart';
import 'package:mangaplus/app/data/sources/manga_source_registry.dart';
import 'package:mangaplus/app/data/sources/source_base.dart';

void main() {
  test('search returns early batches and still forwards slow-source results', () async {
    final received = <Map<String, dynamic>>[];
    final sources = [
      _FakeSource(
        id: 'fast',
        delay: Duration.zero,
        item: {'title': 'Hero fast result', 'url': 'https://fast.test/manga/1'},
      ),
      _FakeSource(
        id: 'slow',
        delay: const Duration(milliseconds: 400),
        item: {'title': 'Hero slow result', 'url': 'https://slow.test/manga/2'},
      ),
    ];

    final result = await MangaSourceRegistry.search(
      'hero',
      sources: sources,
      progressiveDeadline: const Duration(milliseconds: 30),
      onBatch: received.addAll,
    );

    expect(result, hasLength(1));
    expect(result.single['source_id'], 'fast');
    expect(received, hasLength(1));
    await Future<void>.delayed(const Duration(milliseconds: 450));
    expect(received, hasLength(2));
    expect(received.last['source_id'], 'slow');
  });

  test('search without a batch callback preserves complete-result semantics', () async {
    final result = await MangaSourceRegistry.search(
      'hero',
      sources: [
        _FakeSource(
          id: 'slow',
          delay: const Duration(milliseconds: 20),
          item: {'title': 'Hero result', 'url': 'https://slow.test/manga/1'},
        ),
      ],
      progressiveDeadline: const Duration(milliseconds: 1),
    );

    expect(result, hasLength(1));
    expect(result.single['source_id'], 'slow');
  });
}

class _FakeSource extends ContentSource {
  _FakeSource({required this.id, required this.delay, required Map<String, dynamic> item})
      : resultItem = item;

  @override
  final String id;
  final Duration delay;
  final Map<String, dynamic> resultItem;

  @override
  String get name => id;
  @override
  String get kind => 'manga';
  @override
  List<String> get hosts => [ '$id.test' ];
  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    await Future<void>.delayed(delay);
    return [resultItem];
  }
  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) async => const [];
  @override
  Future<Map<String, dynamic>> details(String url) async => const {};
  @override
  Future<Map<String, dynamic>?> streams(String url) async => null;
}
