import 'package:get/get.dart';
import 'package:mangaplus/app/data/models/comic.dart';
import 'package:mangaplus/app/data/services/genre_service.dart';
import 'package:mangaplus/app/widgets/app_feedback.dart';

class GenreDetailController extends GetxController {
  final GenreService _genreService = GenreService();

  final comicsList = RxList<ComicsList>([]);
  final isLoading = true.obs;
  final isLoadingMore = false.obs;
  final hasError = false.obs;
  final currentPage = 1.obs;
  final hasMoreData = true.obs;
  final genreFilter = ''.obs;
  final genreTitle = ''.obs;

  Future<void> fetchGenreDetail(String genre, {int page = 1}) async {
    try {
      hasError(false);
      if (page == 1) {
        isLoading(true);
      } else {
        isLoadingMore(true);
      }
      final data = await _genreService.fetchGenreDetail(genre, page: page);
      if (page == 1) {
        comicsList.assignAll(data.comicsList);
      } else {
        comicsList.addAll(data.comicsList);
      }
      currentPage.value = data.page ?? page;
      hasMoreData.value = data.pagination?.nextPage != null;
    } catch (error) {
      debugPrint('Team X genre request failed: $error');
      hasError(true);
      AppFeedback.show(
        title: 'خطأ'.tr,
        message: 'تعذر تحميل قصص هذا التصنيف. تحقق من اتصال الإنترنت وحاول مجددًا.'.tr,
        type: AppNoticeType.error,
      );
    } finally {
      if (page == 1) {
        isLoading(false);
      } else {
        isLoadingMore(false);
      }
    }
  }

  void fetchNextPage(String genre) {
    if (hasMoreData.value && !isLoadingMore.value) {
      fetchGenreDetail(genre, page: currentPage.value + 1);
    }
  }

  void retry() => fetchGenreDetail(genreFilter.value);

  @override
  void onInit() {
    final arguments = Get.arguments;
    if (arguments is Map) {
      genreFilter.value = '${arguments['value'] ?? ''}';
      genreTitle.value = '${arguments['name'] ?? genreFilter.value}';
    } else {
      genreFilter.value = arguments?.toString() ?? '';
      genreTitle.value = genreFilter.value;
    }
    fetchGenreDetail(genreFilter.value);
    super.onInit();
  }
}
