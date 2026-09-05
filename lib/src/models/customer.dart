import '../utils/json_read.dart';
import 'task.dart';

class CustomerPhone {
  const CustomerPhone({
    required this.id,
    required this.rawPhone,
    required this.normalizedPhone,
    required this.isPrimary,
    this.label,
  });

  final String id;
  final String rawPhone;
  final String normalizedPhone;
  final String? label;
  final bool isPrimary;

  factory CustomerPhone.fromJson(Map<String, Object?> json) => CustomerPhone(
    id: stringValue(json['id']),
    rawPhone: stringValue(json['rawPhone']),
    normalizedPhone: stringValue(json['normalizedPhone']),
    label: nullableString(json['label']),
    isPrimary: json['isPrimary'] == true,
  );
}

class ServiceAddress {
  const ServiceAddress({
    required this.id,
    required this.addressText,
    this.label,
  });

  final String id;
  final String addressText;
  final String? label;

  factory ServiceAddress.fromJson(Map<String, Object?> json) => ServiceAddress(
    id: stringValue(json['id']),
    addressText: stringValue(json['addressText']),
    label: nullableString(json['label']),
  );
}

enum NoteStatus {
  open('OPEN', 'פתוחה'),
  done('DONE', 'הושלמה'),
  cancelled('CANCELLED', 'בוטלה');

  const NoteStatus(this.apiValue, this.hebrewLabel);
  final String apiValue;
  final String hebrewLabel;

  static NoteStatus fromApi(Object? value) => switch (value) {
    'DONE' => done,
    'CANCELLED' => cancelled,
    _ => open,
  };
}

class Note {
  const Note({
    required this.id,
    required this.text,
    required this.status,
    this.createdAt,
  });

  final String id;
  final String text;
  final NoteStatus status;
  final DateTime? createdAt;

  factory Note.fromJson(Map<String, Object?> json) => Note(
    id: stringValue(json['id']),
    text: stringValue(json['text']),
    status: NoteStatus.fromApi(json['status']),
    createdAt: DateTime.tryParse(nullableString(json['createdAt']) ?? ''),
  );
}

class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.version,
    this.email,
    this.generalNotes,
    this.phones = const [],
    this.addresses = const [],
    this.tasks = const [],
    this.notes = const [],
  });

  final String id;
  final String name;
  final String? email;
  final String? generalNotes;
  final int version;
  final List<CustomerPhone> phones;
  final List<ServiceAddress> addresses;
  final List<Task> tasks;
  final List<Note> notes;

  CustomerPhone? get primaryPhone {
    for (final phone in phones) {
      if (phone.isPrimary) return phone;
    }
    return phones.isEmpty ? null : phones.first;
  }

  factory Customer.fromJson(Map<String, Object?> json) => Customer(
    id: stringValue(json['id']),
    name: stringValue(json['name']),
    email: nullableString(json['email']),
    generalNotes: nullableString(json['generalNotes']),
    version: (json['version'] as num?)?.toInt() ?? 1,
    phones: mapListValue(
      json['customerPhones'],
    ).map(CustomerPhone.fromJson).toList(growable: false),
    addresses: mapListValue(
      json['serviceAddresses'],
    ).map(ServiceAddress.fromJson).toList(growable: false),
    tasks: mapListValue(
      json['tasks'],
    ).map(Task.fromJson).toList(growable: false),
    notes: mapListValue(
      json['notes'],
    ).map(Note.fromJson).toList(growable: false),
  );
}
