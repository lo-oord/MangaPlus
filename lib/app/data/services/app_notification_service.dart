import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';

import 'package:mangaplus/app/data/models/app_notification.dart';

class AppNotificationService {
  AppNotificationService({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  static const String topic = 'app_announcements';
  static const String _localKey = 'app_notifications';
  static const String _readKey = 'app_notifications_read';

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;
  final GetStorage _storage = GetStorage();

  Future<void> initialize() async {
    if (kIsWeb) return;
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    await _messaging.subscribeToTopic(topic);
    final token = await _messaging.getToken();
    if (token != null) await _saveToken(token);
    _messaging.onTokenRefresh.listen(_saveToken);
  }

  Future<void> _saveToken(String token) async {
    // App-wide announcements use the FCM topic; no user token is stored in
    // Firestore from the client.
  }

  Future<List<AppNotification>> loadNotifications() async {
    final readIds = _readIds();
    final byId = <String, AppNotification>{};
    final local = _storage.read<List<dynamic>>(_localKey) ?? const [];
    for (final raw in local.whereType<Map>()) {
      final item = AppNotification.fromLocal(
        Map<String, dynamic>.from(raw),
        readIds: readIds,
      );
      if (item.id.isNotEmpty) byId[item.id] = item;
    }
    try {
      final snapshot = await _firestore
          .collection('appNotifications')
          .orderBy('publishedAt', descending: true)
          .limit(50)
          .get();
      for (final document in snapshot.docs) {
        final item = AppNotification.fromFirestore(document, readIds: readIds);
        if (item.title.isNotEmpty || item.body.isNotEmpty) byId[item.id] = item;
      }
    } catch (_) {
      // Locally received FCM notifications remain available offline.
    }
    final result = byId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  Future<void> recordRemoteMessage(RemoteMessage message) async {
    await GetStorage.init();
    final notification = message.notification;
    final data = Map<String, dynamic>.from(message.data);
    final title = '${notification?.title ?? data['title'] ?? ''}'.trim();
    final body = '${notification?.body ?? data['body'] ?? data['message'] ?? ''}'.trim();
    if (title.isEmpty && body.isEmpty) return;
    final item = AppNotification(
      id: '${data['notificationId'] ?? message.messageId ?? '${DateTime.now().microsecondsSinceEpoch}'}',
      title: title,
      body: body,
      createdAt: DateTime.now(),
      imageUrl: '${data['imageUrl'] ?? ''}',
      route: '${data['route'] ?? ''}',
      data: data,
    );
    final current = _storage.read<List<dynamic>>(_localKey) ?? const [];
    final entries = current.whereType<Map>().map((raw) => Map<String, dynamic>.from(raw)).toList();
    entries.removeWhere((raw) => '${raw['id'] ?? ''}' == item.id);
    entries.insert(0, item.toLocal());
    await _storage.write(_localKey, entries.take(100).toList());
  }

  Future<void> recordLocalNotification({
    required String id,
    required String title,
    required String body,
    Map<String, dynamic> data = const {},
  }) async {
    await GetStorage.init();
    final item = AppNotification(
      id: id,
      title: title,
      body: body,
      createdAt: DateTime.now(),
      data: data,
    );
    final current = _storage.read<List<dynamic>>(_localKey) ?? const [];
    final entries = current.whereType<Map>().map((raw) => Map<String, dynamic>.from(raw)).toList();
    entries.removeWhere((raw) => '${raw['id'] ?? ''}' == id);
    entries.insert(0, item.toLocal());
    await _storage.write(_localKey, entries.take(100).toList());
  }

  Future<void> markRead(String id) async {
    final readIds = _readIds()..add(id);
    await _storage.write(_readKey, readIds.toList());
  }

  Set<String> _readIds() {
    final raw = _storage.read<List<dynamic>>(_readKey) ?? const [];
    return raw.map((value) => '$value').toSet();
  }
}
