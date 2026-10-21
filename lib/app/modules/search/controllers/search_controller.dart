import 'package:get/get.dart';
import 'package:mangaplus/app/data/models/comic.dart';
import 'package:mangaplus/app/data/services/comic_service.dart';

class SearchController extends GetxController {
  final ComicService _comicService = ComicService();

  var comicsList = RxList<ComicsList>([]);
  var isLoading = false.obs;
  var query = ''.obs;

  Future<void> searchComics(String searchQuery) async {
    if (searchQuery.isEmpty) {
      comicsList.clear();
      return;
    }
    try {
      isLoading(true);
      query.value = searchQuery;
      final data = await _comicService.searchComics(searchQuery);
      comicsList.assignAll(data.comicsList);
    } catch (e) {
      Get.snackbar('خطأ', 'تعذر تحميل نتائج البحث. حاول مجددًا.');
    } finally {
      isLoading(false);
    }
  }

  void clearSearch() {
    query.value = '';
    comicsList.clear();
  }
}
