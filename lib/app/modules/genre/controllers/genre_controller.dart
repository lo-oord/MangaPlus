import 'package:get/get.dart';
import 'package:mangaplus/app/widgets/app_feedback.dart';
import 'package:mangaplus/app/data/models/genre.dart';
import 'package:mangaplus/app/data/services/genre_service.dart';

class GenreController extends GetxController {
  final _genreService = Get.put<GenreService>(GenreService());

  Rx<GenreData> genreData = GenreData(
    genres: [],
    source: '',
  ).obs;
  RxBool isLoading = false.obs;
  int _requestId = 0;

  Future<void> fetchGenres({String? sourceId}) async {
    final requestId = ++_requestId;
    try {
      isLoading(true);
      final loaded = await _genreService.fetchGenres(sourceId: sourceId);
      if (isClosed || requestId != _requestId) return;
      genreData.value = loaded;
    } catch (e) {
      if (isClosed || requestId != _requestId) return;
      AppFeedback.show(title: 'خطأ'.tr, message: 'تعذر تحميل التصنيفات. تحقق من اتصال الإنترنت وحاول مجددًا.'.tr, type: AppNoticeType.error);
    } finally {
      if (!isClosed && requestId == _requestId) isLoading(false);
    }
  }

  @override
  void onInit() {
    fetchGenres();
    super.onInit();
  }
}
