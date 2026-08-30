import 'customer.dart';

enum WorkItemType { reminder, homeVisit, appointment, quote, note, unknown }

extension WorkItemTypeApi on WorkItemType {
  String get apiValue => switch (this) {
    WorkItemType.reminder => 'reminder',
    WorkItemType.homeVisit => 'home_visit',
    WorkItemType.appointment => 'appointment',
    WorkItemType.quote => 'quote',
    WorkItemType.note => 'note',
    WorkItemType.unknown => 'unknown',
  };

  static WorkItemType parse(Object? value) => switch (value) {
    'reminder' => WorkItemType.reminder,
    'home_visit' => WorkItemType.homeVisit,
    'appointment' => WorkItemType.appointment,
    'quote' => WorkItemType.quote,
    'note' => WorkItemType.note,
    _ => WorkItemType.unknown,
  };
}

enum WorkItemStatus { open, done, cancelled, paid, unknown }

extension WorkItemStatusApi on WorkItemStatus {
  String get apiValue => switch (this) {
    WorkItemStatus.open => 'OPEN',
    WorkItemStatus.done => 'DONE',
    WorkItemStatus.cancelled => 'CANCELLED',
    WorkItemStatus.paid => 'PAID',
    WorkItemStatus.unknown => 'UNKNOWN',
  };

  static WorkItemStatus? parse(Object? value) => switch (value) {
    'OPEN' => WorkItemStatus.open,
    'DONE' => WorkItemStatus.done,
    'CANCELLED' => WorkItemStatus.cancelled,
    'PAID' => WorkItemStatus.paid,
    null => null,
    _ => WorkItemStatus.unknown,
  };
}

enum WorkItemPriority { normal, urgent, unknown }

extension WorkItemPriorityApi on WorkItemPriority {
  String get apiValue => switch (this) {
    WorkItemPriority.normal => 'NORMAL',
    WorkItemPriority.urgent => 'URGENT',
    WorkItemPriority.unknown => 'UNKNOWN',
  };

  static WorkItemPriority? parse(Object? value) => switch (value) {
    'NORMAL' => WorkItemPriority.normal,
    'URGENT' => WorkItemPriority.urgent,
    null => null,
    _ => WorkItemPriority.unknown,
  };
}

enum WorkItemAction { complete, markPaid, open, reopen, edit, call, navigate }

extension WorkItemActionApi on WorkItemAction {
  static WorkItemAction? parse(String value) => switch (value) {
    'complete' => WorkItemAction.complete,
    'mark_paid' => WorkItemAction.markPaid,
    'open' => WorkItemAction.open,
    'reopen' => WorkItemAction.reopen,
    'edit' => WorkItemAction.edit,
    'call' => WorkItemAction.call,
    'navigate' => WorkItemAction.navigate,
    _ => null,
  };
}

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
  final WorkItemType type;
  final String title;
  final String? description;
  final String? location;
  final String? notes;
  final Customer? customer;
  final DateTime? dueAt;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final WorkItemPriority? priority;
  final WorkItemStatus? status;
  final String? estimatedAmount;
  final String? linkedEntityType;
  final String? linkedEntityId;
  final List<WorkItemAction> actions;

  bool get isUrgent => priority == WorkItemPriority.urgent;
  bool get canComplete => actions.contains(WorkItemAction.complete);
  bool get canMarkPaid => actions.contains(WorkItemAction.markPaid);
  bool get isFinished =>
      status == WorkItemStatus.done ||
      status == WorkItemStatus.paid ||
      status == WorkItemStatus.cancelled;

  factory WorkItem.fromJson(Map<String, Object?> json) {
    final customerJson = json['customer'];
    final linkedEntityJson = json['linkedEntity'];
    return WorkItem(
      id: _requiredString(json, 'id'),
      type: WorkItemTypeApi.parse(json['type']),
      title: _requiredString(json, 'title'),
      description: _string(json['description']),
      location: _string(json['location']),
      notes: _string(json['notes']),
      customer: customerJson is Map<String, Object?>
          ? Customer.fromJson(customerJson)
          : null,
      dueAt: _date(json['dueAt'] ?? json['startsAt']),
      startsAt: _date(json['startsAt']),
      endsAt: _date(json['endsAt']),
      priority: WorkItemPriorityApi.parse(json['priority']),
      status: WorkItemStatusApi.parse(json['status']),
      estimatedAmount: _string(json['estimatedAmount']),
      linkedEntityType: linkedEntityJson is Map<String, Object?>
          ? _string(linkedEntityJson['type'])
          : _string(json['linkedEntityType']),
      linkedEntityId: linkedEntityJson is Map<String, Object?>
          ? _string(linkedEntityJson['id'])
          : _string(json['linkedEntityId']),
      actions:
          (json['actions'] as List?)
              ?.whereType<String>()
              .map(WorkItemActionApi.parse)
              .whereType<WorkItemAction>()
              .toList(growable: false) ??
          const [],
    );
  }

  static String _requiredString(Map<String, Object?> json, String key) {
    final value = _string(json[key]);
    if (value == null) throw FormatException('WorkItem.$key is required');
    return value;
  }

  static String? _string(Object? value) {
    return value is String && value.isNotEmpty ? value : null;
  }

  static DateTime? _date(Object? value) {
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
