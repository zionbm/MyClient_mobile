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
    return Customer(
      id: _string(json['id']) ?? '',
      name: _string(json['name']) ?? 'לקוח ללא שם',
      phone: _string(json['phone']),
      email: _string(json['email']),
      address: _string(json['address']),
      createdAt: _date(json['createdAt']),
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
