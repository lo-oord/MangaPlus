import 'dart:async';
import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
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
import 'package:mangaplus/app/data/services/account_sync_service.dart';
import 'package:mangaplus/app/data/services/reading_stats_service.dart';
import 'package:mangaplus/app/core/translations/app_translations.dart';

import 'package:mangaplus/firebase_options.dart';

import 'app/routes/app_pages.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  DartPluginRegistrant.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AppNotificationService().recordRemoteMessage(message);
  // Android displays notification-payload messages itself while the app is
  // backgrounded. Only render data-only messages locally to avoid duplicates.
  if (message.notification == null) {
    await setupFlutterNotifications(languageCode: 'ar_SA');
    showFlutterNotification(message);
  }
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
  // Shared with the download manager so its actions and app navigation both
  // survive whichever plugin instance initialised last.
  unawaited(NotificationPresentation.handleResponse(response));
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
  final notification = message.notification;
  final title = '${notification?.title ?? message.data['title'] ?? message.data['notification_title'] ?? ''}'.trim();
  final body = '${notification?.body ?? message.data['body'] ?? message.data['notification_body'] ?? message.data['message'] ?? message.data['text'] ?? ''}'.trim();
  if ((title.isNotEmpty || body.isNotEmpty) && !kIsWeb) {
    debugPrint("NOTIF RECEIVED:");
    debugPrint("Title: $title");
    debugPrint("Body: $body");

    unawaited(flutterLocalNotificationsPlugin.show(
      (message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch).abs(),
      title.isEmpty ? 'MangaPlus' : title,
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
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    ).catchError((Object error) {
      debugPrint('Unable to show incoming push notification: $error');
    }));
  } else {
    debugPrint('Received a push message without a displayable title or body.');
  }
}

/// Initialize the [FlutterLocalNotificationsPlugin] package.
late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
StreamSubscription<User?>? _syncAuthSubscription;

void _syncPendingReadingData() {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null || user.isAnonymous) return;
  unawaited(AccountSyncService().syncLocalData());
  if (user.emailVerified && Get.isRegistered<ReadingStatsService>()) {
    unawaited(Get.find<ReadingStatsService>().syncOwner(user.uid).catchError(
      (Object error) => debugPrint('Unable to sync pending reading statistics: $error'),
    ));
  }
}

void _handleConnectivity(List<ConnectivityResult> results) {
  if (results.any((result) => result != ConnectivityResult.none)) {
    _syncPendingReadingData();
  }
}

void main() async {
  /// Best-effort restore of the account card using the local profile cache.
  /// Keeps the UI from clearing the name/photo when the device is offline at
  /// startup and Firebase Auth already has a persisted user.
  Future<void> _tryRestoreCachedAccountIfAny() async {
    try {
      final storage = GetStorage();
      final raw = storage.read('localAccount');
      if (raw == null) return;
      final map = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
      final uid = map['uid'];
      if (uid is! String || uid.isEmpty) return;
      final current = FirebaseAuth.instance.currentUser;
      if (current == null || current.uid != uid) return;
      if (current.isAnonymous) return;

      // Only surface the cached profile when we are likely offline right now,
      // so we do not show stale data after a real sign-out / session expiry.
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.any((result) => result != ConnectivityResult.none)) {
        return;
      }

      if (Get.isRegistered<AuthService>()) {
        final auth = Get.find<AuthService>();
        try {
          final profile = await auth.loadProfile(uid).timeout(const Duration(seconds: 8));
          if (profile != null &&
              auth.currentUser?.uid == uid &&
              !auth.currentUser!.isAnonymous) {
            return;
          }
        } catch (_) {
          // Fall back to the cached copy below.
        }
      }

      final cached = _decodeLocalAccount(map);
      if (cached != null) {
        final controller = Get.isRegistered<ProfileController>()
            ? Get.find<ProfileController>()
            : null;
        controller?.accountProfile.value = cached;
      }
    } catch (_) {
      // Startup should never depend on this cache.
    }
  }

  UserProfile? _decodeLocalAccount(Map<String, dynamic> map) {
    final uid = map['uid'];
    if (uid is! String || uid.isEmpty) return null;
    final createdAt = map['createdAt'];
    if (createdAt == null) return null;
    return UserProfile(
      uid: uid,
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      username: map['username'] as String? ?? '',
      countryCode: map['countryCode'] as String? ?? '',
      countryName: map['countryName'] as String? ?? '',
      createdAt: _parseLocalDate(createdAt),
      birthDate: map['birthDate'] as DateTime?,
      gender: map['gender'] as String? ?? '',
      bio: map['bio'] as String? ?? '',
      photoUrl: map['photoUrl'] as String? ?? '',
      photoData: map['photoData'] as String? ?? '',
      isGuest: map['isGuest'] == true,
      emailVerified: map['emailVerified'] == true,
      isVerified: map['isVerified'] == true,
      isOfficialDeveloper: map['isOfficialDeveloper'] == true,
      syncFavorites: map['syncFavorites'] != false,
      privacy: UserPrivacy.fromMap(map['privacy']),
    );
  }

  DateTime _parseLocalDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.tryParse('$value') ?? DateTime.now();
  }
}
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
  if (!kIsWeb) {
    if (!Get.isRegistered<ReadingStatsService>()) {
      Get.put<ReadingStatsService>(ReadingStatsService(), permanent: true);
    }
    _connectivitySubscription ??= Connectivity().onConnectivityChanged.listen(
      _handleConnectivity,
      onError: (Object error) => debugPrint('Connectivity monitor failed: $error'),
    );
    _syncAuthSubscription ??= FirebaseAuth.instance.userChanges().listen((user) {
      if (user != null && !user.isAnonymous) _syncPendingReadingData();
    });
    unawaited(Connectivity().checkConnectivity().then(_handleConnectivity).catchError(
      (Object error) => debugPrint('Unable to read connectivity state: $error'),
    ));
  }
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

  // Prefer the last known cached profile so the account row can render even
  // when the device is offline at startup. This cache is only a read fallback;
  // Firebase Auth / Firestore remain authoritative.
  unawaited(_tryRestoreCachedAccountIfAny());

  if (!kIsWeb) {
    await setupFlutterNotifications(languageCode: savedLanguage);
  }

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
      notificationService.initialize().then((_) async {
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
        debugPrint('Unable to initialize push notifications: $error');
      });
      if (initialNotification != null) {
        Get.toNamed(Routes.NOTIFICATIONS);
      }
    });
  }
}
