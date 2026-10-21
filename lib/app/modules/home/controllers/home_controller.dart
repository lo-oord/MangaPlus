import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/data/models/comic.dart';
import 'package:mangaplus/app/data/models/popular_comic.dart';
import 'package:mangaplus/app/data/services/comic_service.dart';
import 'package:mangaplus/app/modules/genre/controllers/genre_controller.dart';
import 'package:mangaplus/app/modules/history/controllers/history_controller.dart';
import 'package:mangaplus/app/widgets/app_feedback.dart';

class HomeController extends GetxController {
  final ComicService _comicService = ComicService();
  final GenreController genreController = Get.find();
  final HistoryController historyController = Get.find();
  final PageController pageController = PageController(initialPage: 0);
  final currentPage = 0.obs;

  final List<Map<String, String>> heroComics = <Map<String, String>>[];

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
  final popularKomikData =
      PopularKomikData(popularManga: [], source: '').obs;

  Future<void> _loadHomeData() async {
    isLoading(true);
    await Future.wait([fetchComics(), fetchPopularComics()]);
    isLoading(false);
  }

  Future<void> reload() => _loadHomeData();

  Future<void> fetchComics() async {
    try {
      comicData.value = await _comicService.fetchComics();
      heroComics
        ..clear()
        ..addAll(
          comicData.value.comicsList
              .where((comic) => comic.image.isNotEmpty)
              .take(4)
              .map((comic) => {
                    'comicId': comic.comicId,
                    'title': comic.title,
                    'subtitle': comic.chapter,
                    'image': comic.image,
                  }),
        );
    } catch (error) {
      debugPrint('Team X latest feed failed: $error');
      AppFeedback.show(
        title: 'خطأ'.tr,
        message: 'تعذر تحميل محتوى Team X. تحقق من اتصال الإنترنت وحاول مجددًا.'.tr,
        type: AppNoticeType.error,
      );
    }
  }

  Future<void> fetchPopularComics() async {
    try {
      popularKomikData.value = await _comicService.fetchPopularComics();
    } catch (error) {
      debugPrint('Team X catalog failed: $error');
      AppFeedback.show(
        title: 'خطأ'.tr,
        message: 'تعذر تحميل كتالوج Team X. تحقق من اتصال الإنترنت وحاول مجددًا.'.tr,
        type: AppNoticeType.error,
      );
    }
  }

  @override
  void onInit() {
    super.onInit();
    _loadHomeData();
  }

  @override
  void onClose() {
    pageController.dispose();
    super.onClose();
  }
}
