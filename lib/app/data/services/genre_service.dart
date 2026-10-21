import 'package:get/get.dart';
import 'package:mangaplus/app/data/models/comic.dart';
import 'package:mangaplus/app/data/models/genre.dart';

/// Content-source placeholder. No genre API is called until a provider is added.
class GenreService extends GetxService {
  Future<GenreData> fetchGenres() async => GenreData(
        genres: const [],
        source: '',
      );

  Future<ComicData> fetchGenreDetail(String genre, {int page = 1}) async =>
      ComicData(
        comicsList: const [],
        source: '',
        page: page,
        genres: const [],
        status: '',
        type: '',
        orderby: '',
      );
}
