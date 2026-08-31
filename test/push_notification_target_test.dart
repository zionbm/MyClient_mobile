import 'package:flutter_test/flutter_test.dart';
import 'package:dev_mobile/src/services/push_notification_target.dart';

void main() {
  test('reads the direct FCM work item target', () {
    final target = PushNotificationTarget.fromData(const {
      'notificationId': 'notification-1',
      'businessId': 'business-1',
      'itemType': 'appointment',
      'itemId': 'appointment-1',
    });

    expect(target?.type, 'appointment');
    expect(target?.id, 'appointment-1');
    expect(target?.businessId, 'business-1');
    expect(target?.notificationId, 'notification-1');
  });

  test('keeps opening legacy reminder payloads', () {
    final target = PushNotificationTarget.fromData(const {
      'notificationId': 'notification-2',
      'payload': '{"source":"reminder_reminder","reminderId":"reminder-1"}',
    });

    expect(target?.type, 'reminder');
    expect(target?.id, 'reminder-1');
    expect(target?.notificationId, 'notification-2');
  });

  test('does not mistake a notification id for a work item id', () {
    final target = PushNotificationTarget.fromData(const {
      'notificationId': 'notification-only',
    });

    expect(target, isNull);
  });
}
