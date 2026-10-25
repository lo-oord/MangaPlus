import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangaplus/app/data/services/notification_presentation.dart';

void main() {
  test('Arabic notification channel uses the expected high-priority settings', () {
    final channel = NotificationPresentation.channelFor('ar_SA');
    expect(channel.id, NotificationPresentation.channelId);
    expect(channel.name, 'الإشعارات المهمة');
    expect(channel.importance, Importance.high);
  });

  test('English notification channel uses the expected high-priority settings', () {
    final channel = NotificationPresentation.channelFor('en_US');
    expect(channel.id, NotificationPresentation.channelId);
    expect(channel.name, 'Important notifications');
    expect(channel.importance, Importance.high);
  });
}
