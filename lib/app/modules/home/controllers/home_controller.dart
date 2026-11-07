import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mangaplus/app/data/models/comic.dart';
import 'package:mangaplus/app/data/sources/manga_source_registry.dart';
import 'package:mangaplus/app/data/sources/source_base.dart';
import 'package:mangaplus/app/data/services/comic_service.dart';
import 'package:mangaplus/app/data/services/genre_service.dart';
import 'package:mangaplus/app/modules/genre/controllers/genre_controller.dart';
import 'package:mangaplus/app/widgets/app_feedback.dart';

class HomeController extends GetxController {
  HomeController();

  final ComicService _comicService = ComicService();
  final GenreService _genreService = GenreService();
  final GenreController genreController = Get.find();
  final RxString selectedSourceId =
      (GetStorage().read<String>('home_source_id') ?? 'all').obs;
  final PageController pageController = PageController(initialPage: 0);
  final ScrollController scrollController = ScrollController();
  final currentPage = 0.obs;
  final sourcePickerVisible = true.obs;
  final canLoadMore = true.obs;
  final isLoadingMore = false.obs;
  final loadMoreError = false.obs;
  final homeLoadFailed = false.obs;
  final showGenrePage = false.obs;
  final selectedGenreName = ''.obs;
  final selectedGenreFilter = ''.obs;
  final genreComics = <ComicsList>[].obs;
  final isGenreLoading = false.obs;
  final isGenreLoadingMore = false.obs;
  final genreHasError = false.obs;
  final genreLoadMoreError = false.obs;
  final genreHasMore = true.obs;
  int _genrePage = 1;
  int _genreRequestId = 0;
  int _loadedPage = 0;
  int _homeRequestId = 0;
  Timer? _sourcePickerIdleTimer;
  final List<Map<String, String>> heroComics = <Map<String, String>>[];

  List<ContentSource> get availableSources =>
      MangaSourceRegistry.searchableSources;

  String get selectedSourceName {
    if (selectedSourceId.value == 'all') return 'كل المصادر';
    return MangaSourceRegistry.byId(selectedSourceId.value)?.name ?? 'كل المصادر';
  }

  Future<void> selectSource(String sourceId) async {
    if (sourceId == selectedSourceId.value) return;
    _genreRequestId++;
    selectedSourceId.value = sourceId;
    showGenrePage(false);
    genreComics.clear();
    isGenreLoading(false);
    isGenreLoadingMore(false);
    genreHasError(false);
    genreLoadMoreError(false);
    genreHasMore(true);
    final reload = _loadHomeData();
    await GetStorage().write('home_source_id', sourceId);
    unawaited(genreController.fetchGenres(
      sourceId: sourceId == 'all' ? null : sourceId,
    ));
    await reload;
  }

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
    final requestId = ++_homeRequestId;
    if (pageController.hasClients) pageController.jumpToPage(0);
    currentPage(0);
    isLoading(true);
    canLoadMore(true);
    isLoadingMore(false);
    loadMoreError(false);
    homeLoadFailed(false);
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
    if (isClosed || requestId != _homeRequestId) return;
    isLoading(false);
  }

  Future<void> reload() => _loadHomeData();

  Future<void> fetchComics({int page = 1}) async {
    final requestId = _homeRequestId;
    try {
      final loaded = await _comicService.fetchComics(
        page: page,
        sourceId: selectedSourceId.value == 'all' ? null : selectedSourceId.value,
      );
      if (isClosed || requestId != _homeRequestId) return;
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
        homeLoadFailed(false);
        unawaited(_enrichHomeDates(requestId, startIndex: 0, updateHero: true));
        canLoadMore(incoming.isNotEmpty);
      } else {
        final existing = comicData.value.comicsList
            .map((comic) => comic.comicId)
            .toSet();
        final previousLength = comicData.value.comicsList.length;
        final combined = [
          ...comicData.value.comicsList,
          ...incoming.where((comic) => existing.add(comic.comicId)),
        ];
        // Page 1 is already ordered by the feed service. Once the user has
        // started scrolling, never reorder the existing prefix: doing so
        // moves visible cards when page 2+ arrives and breaks scroll position.
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
        canLoadMore(combined.length > previousLength);
        loadMoreError(false);
        if (combined.length > previousLength) {
          unawaited(_enrichHomeDates(requestId, startIndex: previousLength));
        }
      }
    } catch (error) {
      if (isClosed || requestId != _homeRequestId) return;
      debugPrint('Team X latest feed failed (page $page): $error');
      if (page == 1) {
        homeLoadFailed(true);
        AppFeedback.show(
          title: 'خطأ'.tr,
          message: 'تعذر تحميل المحتوى'.tr,
          type: AppNoticeType.error,
        );
        canLoadMore(false);
      } else {
        // Keep the same page retryable, without triggering automatic retries on scroll.
        loadMoreError(true);
        canLoadMore(true);
      }
    }
  }

  Future<void> _enrichHomeDates(
    int requestId, {
    required int startIndex,
    bool updateHero = false,
  }) async {
    try {
      final snapshot = comicData.value.comicsList;
      if (startIndex >= snapshot.length) return;
      final enriched = await _comicService.enrichLatestChapterDates(
        snapshot.skip(startIndex).take(12).toList(growable: false),
      );
      if (isClosed || requestId != _homeRequestId || enriched.isEmpty) return;
      final replacements = {for (final item in enriched) item.comicId: item};
      final updated = comicData.value.comicsList
          .map((item) => replacements[item.comicId] ?? item)
          .toList(growable: false);
      // Date enrichment updates metadata only. Keep the original order so a
      // background response cannot move cards while the user is scrolling.
      final current = comicData.value;
      comicData.value = ComicData(
        comicsList: updated,
        pagination: current.pagination,
        source: current.source,
        page: current.page,
        genres: current.genres,
        status: current.status,
        type: current.type,
        orderby: current.orderby,
      );
      if (updateHero) {
        heroComics
          ..clear()
          ..addAll(updated
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
      }
    } catch (error) {
      debugPrint('Background Team X date enrichment failed: $error');
    }
  }

  Future<void> loadNextPage() async {
    if (isLoading.value || isLoadingMore.value || !canLoadMore.value) return;
    loadMoreError(false);
    isLoadingMore(true);
    await fetchComics(page: _loadedPage + 1);
    isLoadingMore(false);
  }

  Future<void> retryNextPage() async {
    if (!loadMoreError.value) return;
    await loadNextPage();
  }

  Future<void> openGenre(String filter, String name) async {
    if (filter.trim().isEmpty) return;
    _genreRequestId++;
    selectedGenreFilter.value = filter;
    selectedGenreName.value = name;
    showGenrePage(true);
    _genrePage = 1;
    genreComics.clear();
    genreHasMore(true);
    genreLoadMoreError(false);
    await _loadGenrePage(1);
  }

  void closeGenre() {
    _genreRequestId++;
    showGenrePage(false);
  }

  Future<void> loadMoreGenre() async {
    if (!genreHasMore.value || isGenreLoadingMore.value || isGenreLoading.value) {
      return;
    }
    await _loadGenrePage(_genrePage + 1);
  }

  Future<void> retryMoreGenre() async {
    if (!genreLoadMoreError.value) return;
    await _loadGenrePage(_genrePage + 1);
  }

  Future<void> _loadGenrePage(int page) async {
    final requestId = _genreRequestId;
    if (page == 1) {
      isGenreLoading(true);
      genreHasError(false);
    } else {
      genreLoadMoreError(false);
      isGenreLoadingMore(true);
    }
    try {
      final data = await _genreService.fetchGenreDetail(
        selectedGenreFilter.value,
        page: page,
        genreName: selectedGenreName.value,
        sourceId: selectedSourceId.value == 'all' ? null : selectedSourceId.value,
      );
      if (isClosed || requestId != _genreRequestId) return;
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
      genreLoadMoreError(false);
    } catch (error) {
      if (isClosed || requestId != _genreRequestId) return;
      debugPrint('Team X inline genre request failed: $error');
      if (page == 1) {
        genreHasError(true);
      } else {
        genreLoadMoreError(true);
      }
    } finally {
      if (!isClosed && requestId == _genreRequestId) {
        if (page == 1) {
          isGenreLoading(false);
        } else {
          isGenreLoadingMore(false);
        }
      }
    }
  }

  void _checkScrollPosition() {
    if (!scrollController.hasClients ||
        isLoading.value ||
        isLoadingMore.value ||
        !canLoadMore.value ||
        loadMoreError.value) {
      return;
    }
    if (scrollController.position.extentAfter < 700) loadNextPage();
  }

  bool handleHomeScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    if (notification is ScrollStartNotification ||
        notification is ScrollUpdateNotification ||
        notification is OverscrollNotification) {
      _sourcePickerIdleTimer?.cancel();
      if (sourcePickerVisible.value) sourcePickerVisible(false);
    } else if (notification is ScrollEndNotification) {
      _sourcePickerIdleTimer?.cancel();
      _sourcePickerIdleTimer = Timer(const Duration(milliseconds: 620), () {
        if (!isClosed) sourcePickerVisible(true);
      });
    }
    return false;
  }

  @override
  void onInit() {
    super.onInit();
    if (selectedSourceId.value != 'all' &&
        !availableSources.any((source) => source.id == selectedSourceId.value)) {
      selectedSourceId.value = 'all';
      GetStorage().write('home_source_id', 'all');
    }
    scrollController.addListener(_checkScrollPosition);
    _loadHomeData();
  }

  @override
  void onClose() {
    _homeRequestId++;
    _sourcePickerIdleTimer?.cancel();
    scrollController.removeListener(_checkScrollPosition);
    scrollController.dispose();
    pageController.dispose();
    super.onClose();
  }
}
