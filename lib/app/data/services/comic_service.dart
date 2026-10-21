import 'package:mangaplus/app/data/models/chapter.dart';
import 'package:mangaplus/app/data/models/comic.dart';
import 'package:mangaplus/app/data/models/comic_detail.dart';
import 'package:mangaplus/app/data/models/popular_comic.dart';

/// Content-source placeholder. A manga provider will be added in a later phase.
/// This service intentionally performs no network requests.
class ComicService {
  ComicData _emptyComicData({int page = 1}) => ComicData(
        comicsList: const [],
        source: '',
        page: page,
        genres: const [],
        status: '',
        type: '',
        orderby: '',
      );

  Future<ComicData> fetchComics() async => _emptyComicData();

  Future<ComicDetailData> fetchComicDetail(String comicId) async =>
      ComicDetailData.fromJson(const {});

  Future<ChapterData> fetchChapter(String chapterId) async =>
      ChapterData.fromJson(const {});

  Future<PopularKomikData> fetchPopularComics() async =>
      PopularKomikData(popularManga: const [], source: '');

  Future<ComicData> searchComics(String query) async => _emptyComicData();
}
