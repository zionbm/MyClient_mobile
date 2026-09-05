import '../utils/json_read.dart';

enum ActivityKind {
  job('job', 'עבודה'),
  visit('visit', 'ביקור');

  const ActivityKind(this.apiPath, this.hebrewLabel);
  final String apiPath;
  final String hebrewLabel;
}

enum ActivityStatus {
  open('OPEN'),
  closed('CLOSED'),
  cancelled('CANCELLED');

  const ActivityStatus(this.apiValue);
  final String apiValue;

  static ActivityStatus fromApi(Object? value) => switch (value) {
    'CLOSED' => closed,
    'CANCELLED' => cancelled,
    _ => open,
  };
}

enum ActivityAction {
  reportCompleted('report-completed'),
  reopen('reopen'),
  cancel('cancel');

  const ActivityAction(this.apiValue);
  final String apiValue;
}

class Activity {
  const Activity({
    required this.id,
    required this.kind,
    required this.customerId,
    required this.title,
    required this.status,
    required this.version,
    this.customerName,
    this.description,
    this.startsAt,
    this.endsAt,
    this.locationSnapshot,
    this.serviceAddressId,
    this.executionCompletedAt,
  });

  final String id;
  final ActivityKind kind;
  final String customerId;
  final String? customerName;
  final String title;
  final String? description;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? locationSnapshot;
  final String? serviceAddressId;
  final ActivityStatus status;
  final DateTime? executionCompletedAt;
  final int version;

  DateTime? get effectiveEndsAt =>
      endsAt ??
      startsAt?.add(Duration(minutes: kind == ActivityKind.job ? 120 : 60));

  factory Activity.fromJson(Map<String, Object?> json, ActivityKind kind) =>
      Activity(
        id: stringValue(json['id']),
        kind: kind,
        customerId: stringValue(json['customerId']),
        customerName: nullableString(mapValue(json['customer'])['name']),
        title: stringValue(json['title']),
        description: nullableString(json['description']),
        startsAt: DateTime.tryParse(nullableString(json['startsAt']) ?? ''),
        endsAt: DateTime.tryParse(nullableString(json['endsAt']) ?? ''),
        locationSnapshot: nullableString(json['locationSnapshot']),
        serviceAddressId: nullableString(json['serviceAddressId']),
        status: ActivityStatus.fromApi(json['status']),
        executionCompletedAt: DateTime.tryParse(
          nullableString(json['executionCompletedAt']) ?? '',
        ),
        version: (json['version'] as num?)?.toInt() ?? 1,
      );
}
