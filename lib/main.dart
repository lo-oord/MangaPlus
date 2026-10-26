import 'dart:async';
import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mangaplus/app/core/theme/theme.dart';
import 'package:mangaplus/app/core/theme/theme_mode_preference.dart';
import 'package:mangaplus/app/data/services/notification_presentation.dart';
import 'package:mangaplus/app/data/services/app_notification_service.dart';
import 'package:mangaplus/app/data/services/chapter_update_service.dart';
import 'package:mangaplus/app/data/services/download_manager_service.dart';
import 'package:mangaplus/app/core/translations/app_translations.dart';

import 'package:mangaplus/firebase_options.dart';

import 'app/routes/app_pages.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AppNotificationService().recordRemoteMessage(message);
  showFlutterNotification(message);
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  debugPrint('Handling a background message ${message.messageId}');
}

/// Create a [AndroidNotificationChannel] for heads up notifications
late AndroidNotificationChannel channel;

bool isFlutterLocalNotificationsInitialized = false;
final List<RemoteMessage> _pendingForegroundNotifications = [];

void _handleForegroundMessage(RemoteMessage message) {
  if (Get.isRegistered<AppNotificationService>()) {
    unawaited(Get.find<AppNotificationService>().recordRemoteMessage(message));
  }
  if (kIsWeb) return;
  if (!isFlutterLocalNotificationsInitialized) {
    if (_pendingForegroundNotifications.length < 10) {
      _pendingForegroundNotifications.add(message);
    }
    return;
  }
  showFlutterNotification(message);
}

void _handleLocalNotificationResponse(NotificationResponse response) {
  final comicId = response.payload?.trim() ?? '';
  if (comicId == 'reading_stats_weekly') {
    Get.toNamed(Routes.PROFILE);
    return;
  }
  if (comicId.isNotEmpty) {
    Get.toNamed(Routes.COMIC_DETAIL, arguments: comicId);
  } else {
    Get.toNamed(Routes.NOTIFICATIONS);
  }
}

Future<void> setupFlutterNotifications({required String languageCode}) async {
  if (isFlutterLocalNotificationsInitialized) {
    return;
  }
  channel = NotificationPresentation.channelFor(languageCode);

  flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_mangaplus'),
    ),
    onDidReceiveNotificationResponse: _handleLocalNotificationResponse,
  );

  /// Create an Android Notification Channel.
  ///
  /// We use this channel in the `AndroidManifest.xml` file to override the
  /// default FCM channel to enable heads up notifications.
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();

  isFlutterLocalNotificationsInitialized = true;
}

void showFlutterNotification(RemoteMessage message) {
  RemoteNotification? notification = message.notification;
  AndroidNotification? android = message.notification?.android;
  if (notification != null && android != null && !kIsWeb) {
    debugPrint("NOTIF RECEIVED:");
    debugPrint("Title: ${notification.title}");
    debugPrint("Body: ${notification.body}");

    flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          icon: 'ic_stat_mangaplus',
          color: const Color(0xff5b9bd5),
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}

/// Initialize the [FlutterLocalNotificationsPlugin] package.
late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    final licenseText = await rootBundle.loadString('assets/licenses/GPL-3.0.txt');
    yield LicenseEntryWithLineBreaks(
      ['MangaPlus', 'Team X adapter adapted from IWatch-main'],
      licenseText,
    );
  });

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  try {
    // Wait until Firebase restores any persisted user before controllers read currentUser.
    await FirebaseAuth.instance.authStateChanges().first;
  } catch (error) {
    debugPrint('Unable to restore Firebase auth session: $error');
  }

  FlutterError.onError = (errorDetails) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  };
  // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  await GetStorage.init();
  await Get.putAsync<DownloadManagerService>(
    () async => DownloadManagerService().init(),
    permanent: true,
  );
  final storage = GetStorage();
  final savedLanguage = storage.read('language') as String? ?? 'ar_SA';
  final savedTheme = storage.read<String>('themeMode');
  final initialLocale = savedLanguage == 'en_US'
      ? const Locale('en', 'US')
      : const Locale('ar', 'SA');

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  if (!kIsWeb) {
    await Workmanager().initialize(
      chapterUpdateCallbackDispatcher,
      isInDebugMode: false,
    );
  }
  if (!kIsWeb) FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
  final notificationService = Get.put(AppNotificationService(), permanent: true);
  final chapterUpdateService = Get.put(
    ChapterUpdateService(appNotificationService: notificationService),
    permanent: true,
  );
  if (!kIsWeb) {
    unawaited(notificationService.initialize().catchError((_) {}));
  }
  if (!kIsWeb) {
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      unawaited(notificationService.recordRemoteMessage(message));
      Get.toNamed(Routes.NOTIFICATIONS);
    });
  }
  final initialNotification = !kIsWeb
      ? await FirebaseMessaging.instance.getInitialMessage()
      : null;
  runApp(
    GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: "MangaPlus",
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        physics: const ClampingScrollPhysics(),
        overscroll: false,
      ),
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeModePreference.fromStorage(savedTheme),
      defaultTransition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 260),
      translations: AppTranslations(),
      locale: initialLocale,
      fallbackLocale: const Locale('ar', 'SA'),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('ar', 'SA'), Locale('en', 'US')],
      builder: (context, child) => Directionality(
        textDirection: TextDirection.ltr,
        child: child ?? const SizedBox.shrink(),
      ),
      initialRoute: Routes.SPLASH,
      getPages: AppPages.routes,
    ),
  );
  if (!kIsWeb) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setupFlutterNotifications(languageCode: savedLanguage).then((_) async {
        chapterUpdateService.attachNotificationPlugin(
          flutterLocalNotificationsPlugin,
          languageCode: savedLanguage,
        );
        unawaited(chapterUpdateService.initializeBackground());
        unawaited(chapterUpdateService.checkOnAppOpen());
        for (final message in _pendingForegroundNotifications) {
          showFlutterNotification(message);
        }
        _pendingForegroundNotifications.clear();
        final launchDetails = await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
        if (launchDetails?.didNotificationLaunchApp == true && launchDetails?.notificationResponse != null) {
          _handleLocalNotificationResponse(launchDetails!.notificationResponse!);
        }
      }).catchError((Object error) {
        debugPrint('Unable to initialize local notifications: $error');
      });
      if (initialNotification != null) {
        Get.toNamed(Routes.NOTIFICATIONS);
      }
    });
  }
}
