import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mangaplus/app/data/services/genre_service.dart';
import 'package:mangaplus/app/data/sources/source_base.dart';
import 'package:mangaplus/app/data/sources/team_x_source.dart';

void main() {
  test('collects categories and matching works from all sources when Team X is down', () async {
    final source = _CatalogSource(
      id: 'manga_online',
      works: [
        {
          'title': 'Work from another source',
          'url': 'https://manga.example/series/work',
          'image_url': '',
          'type': 'manga',
          'genres': ['فانتازيا'],
        },
      ],
    );
    final teamX = TeamXSource(
      client: MockClient((_) async => http.Response('unavailable', 503)),
    );
    final service = GenreService(source: teamX, sources: [teamX, source]);

    final genres = await service.fetchGenres();
    expect(genres.genres.map((genre) => genre.link), contains('فانتازيا'));

    final results = await service.fetchGenreDetail('فانتازيا');
    expect(results.comicsList.map((work) => work.title), contains('Work from another source'));
  });
}

class _CatalogSource extends ContentSource {
  _CatalogSource({required this.id, required this.works});

  @override
  final String id;
  final List<Map<String, dynamic>> works;

  @override
  String get name => 'Test catalog';
  @override
  String get kind => 'manga';
  @override
  List<String> get hosts => const ['manga.example'];
  @override
  Future<List<Map<String, dynamic>>> search(String query) async => works;
  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) async => works;
  @override
  Future<List<Map<String, dynamic>>> catalog({int page = 1}) async => works;
  @override
  Future<Map<String, dynamic>> details(String url) async =>
      works.firstWhere((work) => work['url'] == url);
  @override
  Future<Map<String, dynamic>?> streams(String url) async => null;
}
