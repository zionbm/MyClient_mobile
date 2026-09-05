import '../utils/json_read.dart';

enum TaskStatus {
  open('OPEN'),
  done('DONE'),
  cancelled('CANCELLED');

  const TaskStatus(this.apiValue);
  final String apiValue;

  static TaskStatus fromApi(Object? value) => switch (value) {
    'DONE' => done,
    'CANCELLED' => cancelled,
    _ => open,
  };
}

enum TaskAction {
  complete('complete'),
  reopen('reopen'),
  cancel('cancel');

  const TaskAction(this.apiValue);
  final String apiValue;
}

class Task {
  const Task({
    required this.id,
    required this.title,
    required this.status,
    required this.version,
    this.customerId,
    this.customerName,
    this.description,
    this.dueAt,
    this.completedAt,
  });

  final String id;
  final String? customerId;
  final String? customerName;
  final String title;
  final String? description;
  final TaskStatus status;
  final DateTime? dueAt;
  final DateTime? completedAt;
  final int version;

  factory Task.fromJson(Map<String, Object?> json) => Task(
    id: stringValue(json['id']),
    customerId: nullableString(json['customerId']),
    customerName: nullableString(mapValue(json['customer'])['name']),
    title: stringValue(json['title']),
    description: nullableString(json['description']),
    status: TaskStatus.fromApi(json['status']),
    dueAt: DateTime.tryParse(nullableString(json['dueAt']) ?? ''),
    completedAt: DateTime.tryParse(nullableString(json['completedAt']) ?? ''),
    version: (json['version'] as num?)?.toInt() ?? 1,
  );
}
