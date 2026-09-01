import '../utils/json_read.dart';
import 'v2_task.dart';

class V2CustomerPhone {
  const V2CustomerPhone({
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

  factory V2CustomerPhone.fromJson(Map<String, Object?> json) =>
      V2CustomerPhone(
        id: stringValue(json['id']),
        rawPhone: stringValue(json['rawPhone']),
        normalizedPhone: stringValue(json['normalizedPhone']),
        label: nullableString(json['label']),
        isPrimary: json['isPrimary'] == true,
      );
}

class V2ServiceAddress {
  const V2ServiceAddress({
    required this.id,
    required this.addressText,
    this.label,
  });

  final String id;
  final String addressText;
  final String? label;

  factory V2ServiceAddress.fromJson(Map<String, Object?> json) =>
      V2ServiceAddress(
        id: stringValue(json['id']),
        addressText: stringValue(json['addressText']),
        label: nullableString(json['label']),
      );
}

class V2Customer {
  const V2Customer({
    required this.id,
    required this.name,
    required this.version,
    this.email,
    this.generalNotes,
    this.phones = const [],
    this.addresses = const [],
    this.tasks = const [],
  });

  final String id;
  final String name;
  final String? email;
  final String? generalNotes;
  final int version;
  final List<V2CustomerPhone> phones;
  final List<V2ServiceAddress> addresses;
  final List<V2Task> tasks;

  V2CustomerPhone? get primaryPhone {
    for (final phone in phones) {
      if (phone.isPrimary) return phone;
    }
    return phones.isEmpty ? null : phones.first;
  }

  factory V2Customer.fromJson(Map<String, Object?> json) => V2Customer(
    id: stringValue(json['id']),
    name: stringValue(json['name']),
    email: nullableString(json['email']),
    generalNotes: nullableString(json['generalNotes']),
    version: (json['version'] as num?)?.toInt() ?? 1,
    phones: mapListValue(
      json['customerPhones'],
    ).map(V2CustomerPhone.fromJson).toList(growable: false),
    addresses: mapListValue(
      json['serviceAddresses'],
    ).map(V2ServiceAddress.fromJson).toList(growable: false),
    tasks: mapListValue(
      json['tasks'],
    ).map(V2Task.fromJson).toList(growable: false),
  );
}
