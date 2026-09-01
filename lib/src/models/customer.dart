class Customer {
  const Customer({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.createdAt,
  });

  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final DateTime? createdAt;

  factory Customer.fromJson(Map<String, Object?> json) {
    final phones = json['customerPhones'] is List
        ? (json['customerPhones'] as List).whereType<Map<String, Object?>>()
        : const Iterable<Map<String, Object?>>.empty();
    final addresses = json['serviceAddresses'] is List
        ? (json['serviceAddresses'] as List).whereType<Map<String, Object?>>()
        : const Iterable<Map<String, Object?>>.empty();
    return Customer(
      id: _requiredString(json, 'id'),
      name: _requiredString(json, 'name'),
      phone:
          _string(json['phone']) ??
          (phones.isEmpty ? null : _string(phones.first['rawPhone'])),
      email: _string(json['email']),
      address:
          _string(json['address']) ??
          (addresses.isEmpty ? null : _string(addresses.first['addressText'])),
      createdAt: _date(json['createdAt']),
    );
  }

  static String _requiredString(Map<String, Object?> json, String key) {
    final value = _string(json[key]);
    if (value == null) throw FormatException('Customer.$key is required');
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
