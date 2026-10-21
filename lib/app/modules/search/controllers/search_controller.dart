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
  final RxBool isLoading = false.obs;
  final RxBool isLoadingSuggestions = false.obs;
  final RxBool hasError = false.obs;
  final RxString query = ''.obs;
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

  void searchComics(String searchQuery) {
    final normalized = searchQuery.trim();
    query.value = normalized;
    _debounce?.cancel();
    if (normalized.isEmpty) {
      comicsList.clear();
      isLoading.value = false;
      hasError.value = false;
      return;
    }

    isLoading.value = true;
    hasError.value = false;
    comicsList.clear();
    final requestId = ++_requestId;
    _debounce = Timer(const Duration(milliseconds: 220), () async {
      try {
        await _comicService.searchComics(
          normalized,
          onBatch: (batch) {
            if (query.value != normalized || requestId != _requestId) return;
            final existing = comicsList.map((item) => item.comicId).toSet();
            comicsList.addAll(batch.where((item) => existing.add(item.comicId)));
          },
        );
      } catch (error) {
        debugPrint('Manga source search failed: $error');
        if (query.value == normalized && requestId == _requestId && comicsList.isEmpty) {
          hasError.value = true;
        }
      } finally {
        if (query.value == normalized && requestId == _requestId) {
          isLoading.value = false;
          if (comicsList.isEmpty) hasError.value = true;
        }
      }
    });
  }

  void clearSearch() {
    _debounce?.cancel();
    query.value = '';
    textController.clear();
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
