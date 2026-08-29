import 'customer.dart';

class WorkItem {
  const WorkItem({
    required this.id,
    required this.type,
    required this.title,
    this.description,
    this.location,
    this.notes,
    this.customer,
    this.dueAt,
    this.startsAt,
    this.endsAt,
    this.priority,
    this.status,
    this.estimatedAmount,
    this.linkedEntityType,
    this.linkedEntityId,
    this.actions = const [],
  });

  final String id;
  final String type;
  final String title;
  final String? description;
  final String? location;
  final String? notes;
  final Customer? customer;
  final DateTime? dueAt;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? priority;
  final String? status;
  final String? estimatedAmount;
  final String? linkedEntityType;
  final String? linkedEntityId;
  final List<String> actions;

  bool get isUrgent => priority == 'URGENT';
  bool get canComplete => actions.contains('complete');
  bool get canMarkPaid => actions.contains('mark_paid');
  bool get isFinished {
    final normalizedStatus = status?.toUpperCase();
    return normalizedStatus == 'DONE' ||
        normalizedStatus == 'PAID' ||
        normalizedStatus == 'CANCELLED';
  }

  factory WorkItem.fromJson(Map<String, Object?> json) {
    final customerJson = json['customer'];
    final linkedEntityJson = json['linkedEntity'];
    return WorkItem(
      id: _string(json['id']) ?? '',
      type: _string(json['type']) ?? 'work_item',
      title: _string(json['title']) ?? 'פריט לטיפול',
      description: _string(json['description']),
      location: _string(json['location']),
      notes: _string(json['notes']),
      customer: customerJson is Map<String, Object?>
          ? Customer.fromJson(customerJson)
          : null,
      dueAt: _date(json['dueAt'] ?? json['startsAt']),
      startsAt: _date(json['startsAt']),
      endsAt: _date(json['endsAt']),
      priority: _string(json['priority']),
      status: _string(json['status']),
      estimatedAmount: _string(json['estimatedAmount']),
      linkedEntityType: linkedEntityJson is Map<String, Object?>
          ? _string(linkedEntityJson['type'])
          : _string(json['linkedEntityType']),
      linkedEntityId: linkedEntityJson is Map<String, Object?>
          ? _string(linkedEntityJson['id'])
          : _string(json['linkedEntityId']),
      actions:
          (json['actions'] as List?)?.whereType<String>().toList() ?? const [],
    );
  }

  static String? _string(Object? value) {
    return value is String && value.isNotEmpty ? value : null;
  }

  static DateTime? _date(Object? value) {
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
