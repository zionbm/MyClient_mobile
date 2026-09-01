import '../utils/json_read.dart';

enum V2TaskStatus {
  open('OPEN'),
  done('DONE'),
  cancelled('CANCELLED');

  const V2TaskStatus(this.apiValue);
  final String apiValue;

  static V2TaskStatus fromApi(Object? value) => switch (value) {
    'DONE' => done,
    'CANCELLED' => cancelled,
    _ => open,
  };
}

class V2Task {
  const V2Task({
    required this.id,
    required this.title,
    required this.status,
    required this.version,
    this.customerId,
    this.description,
    this.dueAt,
  });

  final String id;
  final String? customerId;
  final String title;
  final String? description;
  final V2TaskStatus status;
  final DateTime? dueAt;
  final int version;

  factory V2Task.fromJson(Map<String, Object?> json) => V2Task(
    id: stringValue(json['id']),
    customerId: nullableString(json['customerId']),
    title: stringValue(json['title']),
    description: nullableString(json['description']),
    status: V2TaskStatus.fromApi(json['status']),
    dueAt: DateTime.tryParse(nullableString(json['dueAt']) ?? ''),
    version: (json['version'] as num?)?.toInt() ?? 1,
  );
}
