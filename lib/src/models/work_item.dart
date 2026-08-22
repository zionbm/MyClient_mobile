import 'customer.dart';

class WorkItem {
  const WorkItem({
    required this.id,
    required this.type,
    required this.title,
    this.description,
    this.customer,
    this.dueAt,
    this.priority,
    this.status,
    this.actions = const [],
  });

  final String id;
  final String type;
  final String title;
  final String? description;
  final Customer? customer;
  final DateTime? dueAt;
  final String? priority;
  final String? status;
  final List<String> actions;

  bool get isUrgent => priority == 'URGENT';
  bool get canComplete => actions.contains('complete');
  bool get canMarkPaid => actions.contains('mark_paid');

  factory WorkItem.fromJson(Map<String, Object?> json) {
    final customerJson = json['customer'];
    return WorkItem(
      id: _string(json['id']) ?? '',
      type: _string(json['type']) ?? 'work_item',
      title: _string(json['title']) ?? 'פריט לטיפול',
      description: _string(json['description']),
      customer: customerJson is Map<String, Object?>
          ? Customer.fromJson(customerJson)
          : null,
      dueAt: _date(json['dueAt']),
      priority: _string(json['priority']),
      status: _string(json['status']),
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
