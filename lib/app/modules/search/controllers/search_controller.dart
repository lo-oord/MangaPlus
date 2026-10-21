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
  final RxString query = ''.obs;
  Timer? _debounce;

  void searchComics(String searchQuery) {
    final normalized = searchQuery.trim();
    query.value = normalized;
    _debounce?.cancel();
    if (normalized.isEmpty) {
      comicsList.clear();
      isLoading.value = false;
      return;
    }

    isLoading.value = true;
    _debounce = Timer(const Duration(milliseconds: 280), () async {
      try {
        final data = await _comicService.searchComics(normalized);
        if (query.value == normalized) comicsList.assignAll(data.comicsList);
      } catch (_) {
        comicsList.clear();
      } finally {
        if (query.value == normalized) isLoading.value = false;
      }
    });
  }

  void clearSearch() {
    _debounce?.cancel();
    textController.clear();
    query.value = '';
    comicsList.clear();
    isLoading.value = false;
  }

  @override
  void onClose() {
    _debounce?.cancel();
    textController.dispose();
    super.onClose();
  }
}
