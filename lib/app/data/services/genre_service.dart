import 'package:get/get.dart';
import 'package:mangaplus/app/data/models/comic.dart';
import 'package:mangaplus/app/data/models/genre.dart';
import 'package:mangaplus/app/data/services/comic_service.dart';
import 'package:mangaplus/app/data/sources/team_x_source.dart';

class GenreService extends GetxService {
  GenreService({TeamXSource? source}) : _source = source ?? TeamXSource();

  final TeamXSource _source;

  Future<GenreData> fetchGenres() async {
    final entries = await _source.genres();
    return GenreData(
      genres: entries
          .map((entry) => Genre(
                name: '${entry['name'] ?? ''}',
                seriesCount: 0,
                link: '${entry['value'] ?? ''}',
              ))
          .toList(growable: false),
      source: ComicService.sourceName,
    );
  }

  Future<ComicData> fetchGenreDetail(String genre, {int page = 1}) async {
    final result = await _source.catalogPage(genre: genre, page: page);
    return ComicData(
      comicsList: result.items
          .map(ComicService.mapComicItem)
          .toList(growable: false),
      pagination: Pagination(
        currentPage: result.currentPage,
        prevPage: result.currentPage > 1 ? result.currentPage - 1 : null,
        nextPage: result.nextPage,
      ),
      source: ComicService.sourceName,
      page: result.currentPage,
      genres: [genre],
      status: '',
      type: 'manga',
      orderby: '',
    );
  }
}
