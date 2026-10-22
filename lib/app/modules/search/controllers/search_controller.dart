import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/data/models/comic.dart';
import 'package:mangaplus/app/data/services/comic_service.dart';

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
    loadSuggestions();
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
    comicsList.assignAll(_allSearchResults.where(_matchesContentFilter));
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
