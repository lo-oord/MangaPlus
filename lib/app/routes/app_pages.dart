import 'package:get/get.dart';
import 'package:mangaplus/app/core/theme/app_motion.dart';

import '../modules/auth/bindings/auth_binding.dart';
import '../modules/auth/views/auth_view.dart';
import '../modules/bookmark/bindings/bookmark_binding.dart';
import '../modules/bookmark/views/bookmark_view.dart';
import '../modules/chapter/bindings/chapter_binding.dart';
import '../modules/chapter/views/chapter_view.dart';
import '../modules/comic_detail/bindings/comic_detail_binding.dart';
import '../modules/comic_detail/views/comic_detail_view.dart';
import '../modules/download/bindings/download_binding.dart';
import '../modules/download/views/download_view.dart';
import '../modules/genre/bindings/genre_binding.dart';
import '../modules/genre/views/genre_view.dart';
import '../modules/genre_detail/bindings/genre_detail_binding.dart';
import '../modules/genre_detail/views/genre_detail_view.dart';
import '../modules/history/bindings/history_binding.dart';
import '../modules/history/views/history_view.dart';
import '../modules/home/bindings/home_binding.dart';
import '../modules/home/views/home_view.dart';
import '../modules/local_library/bindings/local_library_binding.dart';
import '../modules/local_library/views/local_library_view.dart';
import '../modules/main/bindings/main_binding.dart';
import '../modules/main/views/main_view.dart';
import '../modules/notifications/bindings/notifications_binding.dart';
import '../modules/notifications/views/notifications_view.dart';
import '../modules/profile/bindings/profile_binding.dart';
import '../modules/profile/views/account_settings_view.dart';
import '../modules/profile/views/change_password_view.dart';
import '../modules/profile/views/delete_account_view.dart';
import '../modules/profile/views/profile_edit_view.dart';
import '../modules/profile/views/profile_view.dart';
import '../modules/profile/views/reading_stats_view.dart';
import '../modules/search/bindings/search_binding.dart';
import '../modules/search/views/search_view.dart';
import '../modules/splash/views/splash_view.dart';

part 'app_routes.dart';

class AppPages {
  AppPages._();

  static const initial = Routes.SPLASH;

  static final routes = [
    // Motion is chosen by relationship: a screen pushed on top of another
    // slides in from the reading edge, a destination that replaces the shell
    // fades, and the reader opens with its shortest transition so page images
    // are never withheld for an effect.
    GetPage(
      name: _Paths.AUTH,
      page: () => const AuthView(),
      binding: AuthBinding(),
      transition: Transition.rightToLeftWithFade,
      transitionDuration: AppMotion.page,
      curve: AppMotion.emphasized,
    ),
    GetPage(
      name: _Paths.SPLASH,
      page: () => const SplashView(),
      transition: Transition.fadeIn,
      transitionDuration: AppMotion.slow,
    ),
    GetPage(
      name: _Paths.HOME,
      page: () => const HomeView(),
      binding: HomeBinding(),
      transition: Transition.rightToLeftWithFade,
      transitionDuration: AppMotion.page,
      curve: AppMotion.emphasized,
    ),
    GetPage(
      name: _Paths.GENRE,
      page: () => const GenreView(),
      binding: GenreBinding(),
      transition: Transition.rightToLeftWithFade,
      transitionDuration: AppMotion.page,
      curve: AppMotion.emphasized,
    ),
    GetPage(
      name: _Paths.COMIC_DETAIL,
      page: () => const ComicDetailView(),
      binding: ComicDetailBinding(),
      transition: Transition.rightToLeftWithFade,
      transitionDuration: AppMotion.page,
      curve: AppMotion.emphasized,
    ),
    GetPage(
      name: _Paths.CHAPTER,
      page: () => const ChapterView(),
      binding: ChapterBinding(),
      transition: Transition.fadeIn,
      transitionDuration: AppMotion.fast,
    ),
    GetPage(
      name: _Paths.GENRE_DETAIL,
      page: () => const GenreDetailView(),
      binding: GenreDetailBinding(),
      transition: Transition.rightToLeftWithFade,
      transitionDuration: AppMotion.page,
      curve: AppMotion.emphasized,
    ),
    GetPage(
      name: _Paths.MAIN,
      page: () => const MainView(),
      binding: MainBinding(),
      transition: Transition.fadeIn,
      transitionDuration: AppMotion.page,
    ),
    GetPage(
      name: _Paths.DOWNLOAD,
      page: () => const DownloadView(),
      binding: DownloadBinding(),
      transition: Transition.rightToLeftWithFade,
      transitionDuration: AppMotion.page,
      curve: AppMotion.emphasized,
    ),
    GetPage(
      name: _Paths.LOCAL_LIBRARY,
      page: () => const LocalLibraryView(),
      binding: LocalLibraryBinding(),
      transition: Transition.rightToLeftWithFade,
      transitionDuration: AppMotion.page,
      curve: AppMotion.emphasized,
    ),
    GetPage(
      name: _Paths.SEARCH,
      page: () => const SearchView(),
      binding: SearchBinding(),
      transition: Transition.fadeIn,
      transitionDuration: AppMotion.page,
    ),
    GetPage(
      name: _Paths.PROFILE,
      page: () => const ProfileView(),
      binding: ProfileBinding(),
      transition: Transition.fadeIn,
      transitionDuration: AppMotion.page,
    ),
    GetPage(
      name: _Paths.READING_STATS,
      page: () => const ReadingStatsView(),
      binding: ReadingStatsBinding(),
      transition: Transition.rightToLeftWithFade,
      transitionDuration: AppMotion.page,
      curve: AppMotion.emphasized,
    ),
    GetPage(
      name: _Paths.PROFILE_EDIT,
      page: () => const ProfileEditView(),
      binding: ProfileBinding(),
      transition: Transition.rightToLeftWithFade,
      transitionDuration: AppMotion.page,
      curve: AppMotion.emphasized,
    ),
    GetPage(
      name: _Paths.ACCOUNT_SETTINGS,
      page: () => const AccountSettingsView(),
      binding: AccountSettingsBinding(),
      transition: Transition.rightToLeftWithFade,
      transitionDuration: AppMotion.page,
      curve: AppMotion.emphasized,
    ),
    GetPage(
      name: _Paths.CHANGE_PASSWORD,
      page: () => const ChangePasswordView(),
      binding: AccountSecurityBinding(),
      transition: Transition.rightToLeftWithFade,
      transitionDuration: AppMotion.page,
      curve: AppMotion.emphasized,
    ),
    GetPage(
      name: _Paths.DELETE_ACCOUNT,
      page: () => const DeleteAccountView(),
      binding: AccountSecurityBinding(),
      transition: Transition.rightToLeftWithFade,
      transitionDuration: AppMotion.page,
      curve: AppMotion.emphasized,
    ),
    GetPage(
      name: _Paths.HISTORY,
      page: () => const HistoryView(),
      binding: HistoryBinding(),
      transition: Transition.rightToLeftWithFade,
      transitionDuration: AppMotion.page,
      curve: AppMotion.emphasized,
    ),
    GetPage(
      name: _Paths.BOOKMARK,
      page: () => const BookmarkView(),
      binding: BookmarkBinding(),
      transition: Transition.fadeIn,
      transitionDuration: AppMotion.page,
    ),
    GetPage(
      name: _Paths.NOTIFICATIONS,
      page: () => const NotificationsView(),
      binding: NotificationsBinding(),
      transition: Transition.rightToLeftWithFade,
      transitionDuration: AppMotion.page,
      curve: AppMotion.emphasized,
    ),
  ];
}
