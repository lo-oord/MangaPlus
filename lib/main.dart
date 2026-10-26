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
import 'package:mangaplus/app/data/services/notification_permission_prompt.dart';
import 'package:mangaplus/app/data/services/app_notification_service.dart';
import 'package:mangaplus/app/data/services/chapter_update_coordinator.dart';
import 'package:mangaplus/app/data/services/chapter_update_service.dart';
import 'package:mangaplus/app/data/services/download_manager_service.dart';
import 'package:mangaplus/app/core/translations/app_translations.dart';

import 'package:mangaplus/firebase_options.dart';

import 'app/routes/app_pages.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AppNotificationService().recordRemoteMessage(message);
  // FCM displays notification payloads itself in the background. Only show
  // data-only messages locally to avoid duplicate system notifications.
  if (message.notification == null) {
    await _showBackgroundDataNotification(message);
  }
  debugPrint('Handling a background message ${message.messageId}');
}

Future<void> _showBackgroundDataNotification(RemoteMessage message) async {
  final data = message.data;
  final title = '${data['title'] ?? ''}'.trim();
  final body = '${data['body'] ?? data['message'] ?? ''}'.trim();
  if (title.isEmpty && body.isEmpty) return;

  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_mangaplus'),
    ),
  );
  final backgroundChannel = NotificationPresentation.channelFor('ar_SA');
  await plugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(backgroundChannel);
  await plugin.show(
    message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        backgroundChannel.id,
        backgroundChannel.name,
        channelDescription: backgroundChannel.description,
        icon: 'ic_stat_mangaplus',
        color: const Color(0xff5b9bd5),
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
  );
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
  isFlutterLocalNotificationsInitialized = true;
}

void showFlutterNotification(RemoteMessage message) {
  if (kIsWeb) return;
  final notification = message.notification;
  final title = '${notification?.title ?? message.data['title'] ?? ''}'.trim();
  final body = '${notification?.body ?? message.data['body'] ?? message.data['message'] ?? ''}'.trim();
  if (title.isEmpty && body.isEmpty) return;

  unawaited(flutterLocalNotificationsPlugin.show(
    message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
    title,
    body,
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
  ));
}

/// Initialize the [FlutterLocalNotificationsPlugin] package.
late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

Future<void> _initializeRemoteMessaging(AppNotificationService notificationService) async {
  try {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      unawaited(() async {
        try {
          await notificationService.recordRemoteMessage(message);
        } catch (_) {
          // Opening the inbox should still work when local persistence fails.
        }
        if (Get.context != null) Get.toNamed(Routes.NOTIFICATIONS);
      }());
    });
    final initialNotification = await FirebaseMessaging.instance
        .getInitialMessage()
        .timeout(const Duration(seconds: 3));
    if (initialNotification != null) {
      try {
        await notificationService.recordRemoteMessage(initialNotification);
      } catch (error) {
        debugPrint('Unable to persist the initial Firebase message: $error');
      }
      if (Get.context != null) Get.toNamed(Routes.NOTIFICATIONS);
    }
  } catch (error) {
    debugPrint('Firebase messaging is unavailable after startup: $error');
  }
}

class _FirebaseStartupFailure extends StatelessWidget {
  const _FirebaseStartupFailure({required this.details});

  final String details;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'تعذر تشغيل خدمات الحساب',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'تحقق من اتصال الإنترنت ثم أعد فتح التطبيق.',
                    textAlign: TextAlign.center,
                  ),
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(details, textAlign: TextAlign.center),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    final licenseText = await rootBundle.loadString('assets/licenses/GPL-3.0.txt');
    yield LicenseEntryWithLineBreaks(
      ['MangaPlus', 'Team X adapter adapted from IWatch-main'],
      licenseText,
    );
  });

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (error) {
    debugPrint('Firebase initialization failed: $error');
    runApp(_FirebaseStartupFailure(details: '$error'));
    return;
  }
  try {
    // Let Firebase restore its persisted user before auth screens read currentUser.
    // A network/auth provider problem must never prevent the first frame.
    await FirebaseAuth.instance
        .authStateChanges()
        .first
        .timeout(const Duration(seconds: 3));
  } catch (error) {
    debugPrint('Unable to restore Firebase auth session before startup: $error');
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

  if (!kIsWeb) {
    await Workmanager().initialize(
      chapterUpdateCallbackDispatcher,
      isInDebugMode: false,
    );
  }
  final notificationService = Get.put(AppNotificationService(), permanent: true);
  final chapterUpdateService = Get.put(
    ChapterUpdateService(appNotificationService: notificationService),
    permanent: true,
  );
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
        ChapterUpdateCoordinator(chapterUpdateService).start();
        unawaited(Future<void>.delayed(const Duration(seconds: 1)).then((_) =>
            NotificationPermissionPrompt.showIfNeeded()).catchError((_) {}));
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
      unawaited(_initializeRemoteMessaging(notificationService));
    });
  }
}
