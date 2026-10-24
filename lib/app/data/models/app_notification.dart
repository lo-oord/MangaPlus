import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.imageUrl = '',
    this.route = '',
    this.data = const {},
    this.isRead = false,
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final String imageUrl;
  final String route;
  final Map<String, dynamic> data;
  final bool isRead;

  factory AppNotification.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document, {
    Set<String> readIds = const {},
  }) {
    final raw = document.data() ?? const <String, dynamic>{};
    return AppNotification(
      id: document.id,
      title: '${raw['title'] ?? ''}'.trim(),
      body: '${raw['body'] ?? raw['message'] ?? ''}'.trim(),
      createdAt: _date(raw['publishedAt'] ?? raw['createdAt']) ?? DateTime.now(),
      imageUrl: '${raw['imageUrl'] ?? ''}'.trim(),
      route: '${raw['route'] ?? ''}'.trim(),
      data: raw['data'] is Map
          ? Map<String, dynamic>.from(raw['data'] as Map)
          : const {},
      isRead: readIds.contains(document.id),
    );
  }

  factory AppNotification.fromLocal(Map<String, dynamic> raw, {Set<String> readIds = const {}}) {
    final id = '${raw['id'] ?? ''}'.trim();
    return AppNotification(
      id: id,
      title: '${raw['title'] ?? ''}'.trim(),
      body: '${raw['body'] ?? ''}'.trim(),
      createdAt: _date(raw['createdAt']) ?? DateTime.now(),
      imageUrl: '${raw['imageUrl'] ?? ''}'.trim(),
      route: '${raw['route'] ?? ''}'.trim(),
      data: raw['data'] is Map
          ? Map<String, dynamic>.from(raw['data'] as Map)
          : const {},
      isRead: readIds.contains(id),
    );
  }

  Map<String, dynamic> toLocal() => {
        'id': id,
        'title': title,
        'body': body,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'imageUrl': imageUrl,
        'route': route,
        'data': data,
      };

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        title: title,
        body: body,
        createdAt: createdAt,
        imageUrl: imageUrl,
        route: route,
        data: data,
        isRead: isRead ?? this.isRead,
      );

  static DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse('$value');
  }
}
