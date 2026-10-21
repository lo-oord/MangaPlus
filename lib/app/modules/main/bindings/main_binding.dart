import 'package:get/get.dart';
import 'package:mangaplus/app/data/services/app_data_service.dart';
import 'package:mangaplus/app/data/services/auth_service.dart';
import 'package:mangaplus/app/modules/bookmark/controllers/bookmark_controller.dart';
import 'package:mangaplus/app/modules/download/controllers/download_controller.dart';
import 'package:mangaplus/app/modules/genre/controllers/genre_controller.dart';
import 'package:mangaplus/app/modules/history/controllers/history_controller.dart';
import 'package:mangaplus/app/modules/home/controllers/home_controller.dart';
import 'package:mangaplus/app/modules/profile/controllers/profile_controller.dart';
import 'package:mangaplus/app/modules/search/controllers/search_controller.dart';

import '../controllers/main_controller.dart';

class MainBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<AppDataService>(AppDataService(), permanent: true);
    if (!Get.isRegistered<AuthService>()) {
      Get.put<AuthService>(AuthService(), permanent: true);
    }
    Get.lazyPut<MainController>(() => MainController());
    Get.lazyPut<HomeController>(() => HomeController());
    Get.lazyPut<GenreController>(() => GenreController());
    Get.lazyPut<ProfileController>(() => ProfileController());
    Get.lazyPut<HistoryController>(() => HistoryController());
    Get.lazyPut<DownloadController>(() => DownloadController());
    Get.lazyPut<SearchController>(() => SearchController());
    Get.lazyPut<BookmarkController>(() => BookmarkController());
  }
}
