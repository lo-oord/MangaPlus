import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/data/models/comic.dart';
import 'package:mangaplus/app/data/services/comic_service.dart';

class SearchController extends GetxController {
  final ComicService _comicService = ComicService();
  final TextEditingController textController = TextEditingController();
  final RxList<ComicsList> comicsList = <ComicsList>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool hasError = false.obs;
  final RxString query = ''.obs;
  Timer? _debounce;

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
    _debounce = Timer(const Duration(milliseconds: 280), () async {
      try {
        final data = await _comicService.searchComics(normalized);
        if (query.value == normalized) comicsList.assignAll(data.comicsList);
      } catch (error) {
        debugPrint('Team X search failed: $error');
        if (query.value == normalized) {
          hasError.value = true;
          comicsList.clear();
        }
      } finally {
        if (query.value == normalized) isLoading.value = false;
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
