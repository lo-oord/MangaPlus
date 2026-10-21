import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/widgets/app_feedback.dart';
import 'package:mangaplus/app/data/models/comic.dart';
import 'package:mangaplus/app/data/models/popular_comic.dart';
import 'package:mangaplus/app/data/services/comic_service.dart';
import 'package:mangaplus/app/modules/genre/controllers/genre_controller.dart';
import 'package:mangaplus/app/modules/history/controllers/history_controller.dart';

class HomeController extends GetxController {
  final ComicService _comicService = ComicService();
  final GenreController genreController = Get.find();
  final HistoryController historyController = Get.find();
  PageController pageController = PageController(initialPage: 0);
  final currentPage = 0.obs;

  final List<Map<String, String>> heroComics = <Map<String, String>>[];

  var comicData = ComicData(
    comicsList: [],
    page: 1,
    genres: [],
    status: "",
    type: "",
    orderby: "",
    source: "",
  ).obs;

  var isLoading = true.obs;
  var popularKomikData = PopularKomikData(popularManga: [], source: "").obs;

  Future<void> fetchComics() async {
    try {
      isLoading(true);
      comicData.value = await _comicService.fetchComics();
    } catch (e) {
      print('error cuy: $e');
      AppFeedback.show(title: 'خطأ'.tr, message: 'حدث خطأ غير متوقع. يرجى المحاولة مجددًا.'.tr, type: AppNoticeType.error);
    } finally {
      isLoading(false);
    }
  }

  Future<void> fetchPopularComics() async {
    try {
      isLoading(true);
      popularKomikData.value = await _comicService.fetchPopularComics();
    } catch (e) {
      AppFeedback.show(title: 'خطأ'.tr, message: 'تعذر تحميل القصص المصورة الشائعة. حاول مجددًا.'.tr, type: AppNoticeType.error);
    } finally {
      isLoading(false);
    }
  }

  @override
  void onInit() {
    fetchComics();
    fetchPopularComics();

    print('genre: ${genreController.genreData.value.genres}');
    super.onInit();
  }

  @override
  void onReady() {
    super.onReady();
  }

  @override
  void onClose() {
    pageController.dispose();
    super.onClose();
  }
}
