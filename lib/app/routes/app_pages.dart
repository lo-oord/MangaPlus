import 'package:get/get.dart';

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
import '../modules/profile/views/profile_view.dart';
import '../modules/profile/views/profile_details_view.dart';
import '../modules/search/bindings/search_binding.dart';
import '../modules/search/views/search_view.dart';
import '../modules/settings/bindings/settings_binding.dart';
import '../modules/settings/views/settings_view.dart';
import '../modules/settings/views/appearance_settings_view.dart';
import '../modules/settings/views/reader_settings_view.dart';
import '../modules/settings/views/language_region_view.dart';
import '../modules/settings/views/storage_data_view.dart';
import '../modules/settings/views/privacy_security_view.dart';
import '../modules/settings/views/sync_connection_view.dart';
import '../modules/settings/views/help_view.dart';
import '../modules/settings/views/feedback_view.dart';
import '../modules/settings/views/about_view.dart';
import '../modules/splash/views/splash_view.dart';

part 'app_routes.dart';

class AppPages {
  AppPages._();

  static const initial = Routes.SPLASH;

  static final routes = [
    GetPage(
      name: _Paths.AUTH,
      page: () => const AuthView(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: _Paths.SPLASH,
      page: () => const SplashView(),
    ),
    GetPage(
      name: _Paths.HOME,
      page: () => const HomeView(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: _Paths.GENRE,
      page: () => const GenreView(),
      binding: GenreBinding(),
    ),
    GetPage(
      name: _Paths.COMIC_DETAIL,
      page: () => const ComicDetailView(),
      binding: ComicDetailBinding(),
      transition: Transition.rightToLeftWithFade,
      transitionDuration: const Duration(milliseconds: 280),
    ),
    GetPage(
      name: _Paths.CHAPTER,
      page: () => const ChapterView(),
      binding: ChapterBinding(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 180),
    ),
    GetPage(
      name: _Paths.GENRE_DETAIL,
      page: () => const GenreDetailView(),
      binding: GenreDetailBinding(),
      transition: Transition.rightToLeftWithFade,
      transitionDuration: const Duration(milliseconds: 240),
    ),
    GetPage(
      name: _Paths.MAIN,
      page: () => const MainView(),
      binding: MainBinding(),
    ),
    GetPage(
      name: _Paths.DOWNLOAD,
      page: () => const DownloadView(),
      binding: DownloadBinding(),
    ),
    GetPage(
      name: _Paths.LOCAL_LIBRARY,
      page: () => const LocalLibraryView(),
      binding: LocalLibraryBinding(),
      transition: Transition.rightToLeftWithFade,
    ),
    GetPage(
      name: _Paths.SEARCH,
      page: () => const SearchView(),
      binding: SearchBinding(),
    ),
    GetPage(
      name: _Paths.PROFILE,
      page: () => const ProfileView(),
      binding: ProfileBinding(),
    ),
    GetPage(
      name: _Paths.PROFILE_DETAILS,
      page: () => const ProfileDetailsView(),
      binding: ProfileBinding(),
      transition: Transition.rightToLeftWithFade,
    ),
    GetPage(
      name: _Paths.SETTINGS,
      page: () => const SettingsView(),
      binding: SettingsBinding(),
    ),
    GetPage(
      name: _Paths.APPEARANCE,
      page: () => const AppearanceSettingsView(),
      binding: SettingsBinding(),
      transition: Transition.rightToLeftWithFade,
    ),
    GetPage(
      name: _Paths.READER,
      page: () => const ReaderSettingsView(),
      binding: SettingsBinding(),
      transition: Transition.rightToLeftWithFade,
    ),
    GetPage(
      name: _Paths.LANGUAGE_REGION,
      page: () => const LanguageRegionView(),
      binding: SettingsBinding(),
      transition: Transition.rightToLeftWithFade,
    ),
    GetPage(
      name: _Paths.STORAGE,
      page: () => const StorageDataView(),
      binding: SettingsBinding(),
      transition: Transition.rightToLeftWithFade,
    ),
    GetPage(
      name: _Paths.PRIVACY_SECURITY,
      page: () => const PrivacySecurityView(),
      binding: SettingsBinding(),
      transition: Transition.rightToLeftWithFade,
    ),
    GetPage(
      name: _Paths.SYNC_CONNECTION,
      page: () => const SyncConnectionView(),
      binding: SettingsBinding(),
      transition: Transition.rightToLeftWithFade,
    ),
    GetPage(
      name: _Paths.HELP,
      page: () => const HelpView(),
      binding: SettingsBinding(),
      transition: Transition.rightToLeftWithFade,
    ),
    GetPage(
      name: _Paths.FEEDBACK,
      page: () => const FeedbackView(),
      binding: SettingsBinding(),
      transition: Transition.rightToLeftWithFade,
    ),
    GetPage(
      name: _Paths.ABOUT,
      page: () => const AboutView(),
      binding: SettingsBinding(),
      transition: Transition.rightToLeftWithFade,
    ),
    GetPage(
      name: _Paths.HISTORY,
      page: () => const HistoryView(),
      binding: HistoryBinding(),
    ),
    GetPage(
      name: _Paths.BOOKMARK,
      page: () => const BookmarkView(),
      binding: BookmarkBinding(),
    ),
    GetPage(
      name: _Paths.NOTIFICATIONS,
      page: () => const NotificationsView(),
      binding: NotificationsBinding(),
    ),
  ];
}
