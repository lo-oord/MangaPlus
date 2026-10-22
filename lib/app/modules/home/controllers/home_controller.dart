import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/data/models/comic.dart';
import 'package:mangaplus/app/data/services/comic_service.dart';
import 'package:mangaplus/app/data/services/genre_service.dart';
import 'package:mangaplus/app/modules/genre/controllers/genre_controller.dart';
import 'package:mangaplus/app/widgets/app_feedback.dart';

class HomeController extends GetxController {
  HomeController();

  final ComicService _comicService = ComicService();
  final GenreService _genreService = GenreService();
  final GenreController genreController = Get.find();
  final PageController pageController = PageController(initialPage: 0);
  final ScrollController scrollController = ScrollController();
  final currentPage = 0.obs;
  final canLoadMore = true.obs;
  final isLoadingMore = false.obs;
  final showGenrePage = false.obs;
  final selectedGenreName = ''.obs;
  final selectedGenreFilter = ''.obs;
  final genreComics = <ComicsList>[].obs;
  final isGenreLoading = false.obs;
  final isGenreLoadingMore = false.obs;
  final genreHasError = false.obs;
  final genreHasMore = true.obs;
  int _genrePage = 1;

  int _loadedPage = 0;
  final List<Map<String, String>> heroComics = <Map<String, String>>[];

  final comicData = ComicData(
    comicsList: [],
    page: 1,
    genres: [],
    status: '',
    type: '',
    orderby: '',
    source: '',
  ).obs;

  final isLoading = true.obs;

  Future<void> _loadHomeData() async {
    isLoading(true);
    canLoadMore(true);
    isLoadingMore(false);
    _loadedPage = 0;
    heroComics.clear();
    comicData.value = ComicData(
      comicsList: const [],
      page: 1,
      genres: const [],
      status: '',
      type: 'manga',
      orderby: '',
      source: '',
    );
    await fetchComics(page: 1);
    isLoading(false);
  }

  Future<void> reload() => _loadHomeData();

  Future<void> fetchComics({int page = 1}) async {
    try {
      final loaded = await _comicService.fetchComics(page: page);
      final incoming = loaded.comicsList;
      if (page == 1) {
        comicData.value = loaded;
        _loadedPage = 1;
        heroComics
          ..clear()
          ..addAll(incoming
              .where((comic) => comic.image.isNotEmpty)
              .take(4)
              .map((comic) => {
                    'comicId': comic.comicId,
                    'title': comic.title,
                    'subtitle': comic.chapter,
                    'image': comic.image,
                    'rating': comic.rating,
                    'status': comic.status ?? '',
                    'releaseDate': comic.latestChapterDate,
                  }));
      } else {
        final existing = comicData.value.comicsList
            .map((comic) => comic.comicId)
            .toSet();
        final combined = [
          ...comicData.value.comicsList,
          ...incoming.where((comic) => existing.add(comic.comicId)),
        ];
        combined.sort((left, right) {
          final leftDate = DateTime.tryParse(left.latestChapterDate.trim());
          final rightDate = DateTime.tryParse(right.latestChapterDate.trim());
          if (leftDate == null) return rightDate == null ? 0 : 1;
          if (rightDate == null) return -1;
          return rightDate.compareTo(leftDate);
        });
        comicData.value = ComicData(
          comicsList: combined,
          pagination: loaded.pagination,
          source: loaded.source,
          page: page,
          genres: loaded.genres,
          status: loaded.status,
          type: loaded.type,
          orderby: loaded.orderby,
        );
        _loadedPage = page;
      }
      canLoadMore(incoming.isNotEmpty);
    } catch (error) {
      debugPrint('Team X latest feed failed (page $page): $error');
      if (page == 1) {
        AppFeedback.show(
          title: 'خطأ'.tr,
          message: 'تعذر تحميل المحتوى'.tr,
          type: AppNoticeType.error,
        );
      }
      canLoadMore(false);
    }
  }

  Future<void> loadNextPage() async {
    if (isLoading.value || isLoadingMore.value || !canLoadMore.value) return;
    isLoadingMore(true);
    await fetchComics(page: _loadedPage + 1);
    isLoadingMore(false);
  }

  Future<void> openGenre(String filter, String name) async {
    if (filter.trim().isEmpty) return;
    selectedGenreFilter.value = filter;
    selectedGenreName.value = name;
    showGenrePage(true);
    _genrePage = 1;
    genreComics.clear();
    genreHasMore(true);
    await _loadGenrePage(1);
  }

  void closeGenre() => showGenrePage(false);

  Future<void> loadMoreGenre() async {
    if (!genreHasMore.value || isGenreLoadingMore.value || isGenreLoading.value) {
      return;
    }
    await _loadGenrePage(_genrePage + 1);
  }

  Future<void> _loadGenrePage(int page) async {
    if (page == 1) {
      isGenreLoading(true);
      genreHasError(false);
    } else {
      isGenreLoadingMore(true);
    }
    try {
      final data = await _genreService.fetchGenreDetail(
        selectedGenreFilter.value,
        page: page,
        genreName: selectedGenreName.value,
      );
      if (page == 1) {
        genreComics.assignAll(data.comicsList);
      } else {
        final ids = genreComics.map((comic) => comic.comicId).toSet();
        genreComics.addAll(
          data.comicsList.where((comic) => ids.add(comic.comicId)),
        );
      }
      _genrePage = data.page ?? page;
      genreHasMore(data.pagination?.nextPage != null);
    } catch (error) {
      debugPrint('Team X inline genre request failed: $error');
      if (page == 1) genreHasError(true);
    } finally {
      if (page == 1) {
        isGenreLoading(false);
      } else {
        isGenreLoadingMore(false);
      }
    }
  }

  void _checkScrollPosition() {
    if (!scrollController.hasClients ||
        isLoading.value ||
        isLoadingMore.value ||
        !canLoadMore.value) {
      return;
    }
    if (scrollController.position.extentAfter < 700) loadNextPage();
  }

  @override
  void onInit() {
    super.onInit();
    scrollController.addListener(_checkScrollPosition);
    _loadHomeData();
  }

  @override
  void onClose() {
    scrollController.removeListener(_checkScrollPosition);
    scrollController.dispose();
    pageController.dispose();
    super.onClose();
  }
}
