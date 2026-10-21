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

  Future<void> fetchGenres() async {
    try {
      isLoading(true);
      print('kaka${_genreService.fetchGenres()}');
      genreData.value = await _genreService.fetchGenres();
    } catch (e) {
      AppFeedback.show(title: 'خطأ'.tr, message: 'تعذر تحميل التصنيفات. تحقق من اتصال الإنترنت وحاول مجددًا.'.tr, type: AppNoticeType.error);
    } finally {
      isLoading(false);
    }
  }

  @override
  void onInit() {
    fetchGenres();
    super.onInit();
  }
}
