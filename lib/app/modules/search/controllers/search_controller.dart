import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/data/models/comic.dart';
import 'package:mangaplus/app/data/services/bookmark_state_service.dart';
import 'package:mangaplus/app/data/services/comic_service.dart';
import 'package:mangaplus/app/data/sources/search_relevance.dart';

class SearchController extends GetxController {
  final ComicService _comicService = ComicService();
  final TextEditingController textController = TextEditingController();
  final RxList<ComicsList> comicsList = <ComicsList>[].obs;
  final RxList<ComicsList> suggestions = <ComicsList>[].obs;
  final RxString contentFilter = 'all'.obs;
  final RxBool isLoading = false.obs;
  final RxBool isLoadingSuggestions = false.obs;
  final RxBool hasError = false.obs;
  final RxString query = ''.obs;
  final List<ComicsList> _allSearchResults = [];
  Timer? _debounce;
  int _requestId = 0;

  @override
  void onInit() {
    super.onInit();
  }

  Future<void> loadSuggestions() async {
    if (isLoadingSuggestions.value || suggestions.isNotEmpty) return;
    isLoadingSuggestions.value = true;
    try {
      final data = await _comicService.fetchSearchSuggestions(limit: 6);
      suggestions.assignAll(data.comicsList);
    } catch (error) {
      debugPrint('Search suggestions unavailable: $error');
    } finally {
      isLoadingSuggestions.value = false;
    }
  }

  List<ComicsList> get visibleSuggestions =>
      suggestions.where(_matchesContentFilter).toList(growable: false);

  void setContentFilter(String value) {
    if (!const {'all', 'manga', 'novel'}.contains(value)) return;
    contentFilter.value = value;
    _applyContentFilter();
  }

  bool _matchesContentFilter(ComicsList comic) {
    final isNovel = const {'novel', 'light novel', 'رواية'}
        .contains(comic.type.trim().toLowerCase());
    switch (contentFilter.value) {
      case 'novel':
        return isNovel;
      case 'manga':
        return !isNovel;
      default:
        return true;
    }
  }

  void _applyContentFilter() {
    final originalOrder = <String, int>{};
    for (var index = 0; index < _allSearchResults.length; index++) {
      originalOrder[_allSearchResults[index].comicId] = index;
    }
    final filtered = _allSearchResults.where(_matchesContentFilter).toList();
    final favoriteById = <String, bool>{};
    final scoreById = <String, int>{};
    final workKeyById = <String, String>{};
    final chaptersById = <String, int>{};
    for (final comic in filtered) {
      favoriteById[comic.comicId] =
          BookmarkStateService.instance.contains(comic.comicId);
      scoreById[comic.comicId] = SearchRelevance.comicScore(query.value, comic);
      workKeyById[comic.comicId] = SearchRelevance.workKey(comic);
      chaptersById[comic.comicId] = _chapterCount(comic);
    }
    filtered.sort((left, right) {
      final leftFavorite = favoriteById[left.comicId] ?? false;
      final rightFavorite = favoriteById[right.comicId] ?? false;
      if (leftFavorite != rightFavorite) return leftFavorite ? -1 : 1;

      // When the same work is available from multiple sources, prefer the
      // source with the larger chapter catalog without disturbing unrelated
      // results.
      if (workKeyById[left.comicId] == workKeyById[right.comicId]) {
        final chapters = (chaptersById[right.comicId] ?? 0)
            .compareTo(chaptersById[left.comicId] ?? 0);
        if (chapters != 0) return chapters;
      }
      final relevance = (scoreById[left.comicId] ?? 0)
          .compareTo(scoreById[right.comicId] ?? 0);
      if (relevance != 0) return -relevance;
      return (originalOrder[left.comicId] ?? 0).compareTo(
        originalOrder[right.comicId] ?? 0,
      );
    });
    comicsList.assignAll(filtered);
  }

  int _chapterCount(ComicsList comic) {
    final value = comic.totalChapters
        .replaceAll('٠', '0')
        .replaceAll('١', '1')
        .replaceAll('٢', '2')
        .replaceAll('٣', '3')
        .replaceAll('٤', '4')
        .replaceAll('٥', '5')
        .replaceAll('٦', '6')
        .replaceAll('٧', '7')
        .replaceAll('٨', '8')
        .replaceAll('٩', '9');
    return int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }

  void searchComics(String searchQuery) {
    final normalized = searchQuery.trim();
    query.value = normalized;
    _debounce?.cancel();
    if (normalized.isEmpty) {
      _allSearchResults.clear();
      comicsList.clear();
      isLoading.value = false;
      hasError.value = false;
      return;
    }

    isLoading.value = true;
    hasError.value = false;
    _allSearchResults.clear();
    comicsList.clear();
    final requestId = ++_requestId;
    _debounce = Timer(const Duration(milliseconds: 220), () async {
      try {
        await _comicService.searchComics(
          normalized,
          onBatch: (batch) {
            if (query.value != normalized || requestId != _requestId) return;
            final existing =
                _allSearchResults.map((item) => item.comicId).toSet();
            _allSearchResults
                .addAll(batch.where((item) => existing.add(item.comicId)));
            _applyContentFilter();
          },
        );
      } catch (error) {
        debugPrint('Manga source search failed: $error');
        if (query.value == normalized &&
            requestId == _requestId &&
            _allSearchResults.isEmpty) {
          hasError.value = true;
        }
      } finally {
        if (query.value == normalized && requestId == _requestId) {
          isLoading.value = false;
          if (_allSearchResults.isEmpty) hasError.value = true;
        }
      }
    });
  }

  void clearSearch() {
    _debounce?.cancel();
    query.value = '';
    textController.clear();
    _allSearchResults.clear();
    comicsList.clear();
    isLoading.value = false;
    hasError.value = false;
  }

  @override
  void onClose() {
    _debounce?.cancel();
    textController.dispose();
    super.onClose();
  }
}
