import 'dart:convert';

import '../utils/json_read.dart';

class PushNotificationTarget {
  const PushNotificationTarget({
    required this.type,
    required this.id,
    this.title,
    this.businessId,
    this.notificationId,
  });

  final String type;
  final String id;
  final String? title;
  final String? businessId;
  final String? notificationId;

  static PushNotificationTarget? fromData(Map<String, Object?> data) {
    final nested = _payloadMap(data['payload']);
    final type =
        nullableString(data['itemType']) ??
        nullableString(data['type']) ??
        nullableString(nested['itemType']) ??
        nullableString(nested['type']) ??
        ((nullableString(data['reminderId']) ??
                    nullableString(nested['reminderId'])) ==
                null
            ? null
            : 'reminder');
    final id =
        nullableString(data['itemId']) ??
        nullableString(data['reminderId']) ??
        nullableString(nested['itemId']) ??
        nullableString(nested['reminderId']);
    if (type == null || id == null || id.isEmpty) return null;
    return PushNotificationTarget(
      type: type,
      id: id,
      title: nullableString(data['title']) ?? nullableString(nested['title']),
      businessId:
          nullableString(data['businessId']) ??
          nullableString(nested['businessId']),
      notificationId: nullableString(data['notificationId']),
    );
  }

  static Map<String, Object?> _payloadMap(Object? value) {
    if (value is Map<String, Object?>) return value;
    if (value is! String || value.isEmpty) return const {};
    try {
      final decoded = jsonDecode(value);
      return decoded is Map<String, Object?> ? decoded : const {};
    } catch (_) {
      return const {};
    }
  }
}
