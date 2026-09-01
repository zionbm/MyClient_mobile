import '../utils/json_read.dart';

enum V2PaymentStatus {
  unpaid,
  partiallyPaid,
  paid;

  static V2PaymentStatus fromApi(Object? value) => switch (value) {
    'PAID' => paid,
    'PARTIALLY_PAID' => partiallyPaid,
    _ => unpaid,
  };
}

class V2Amount {
  const V2Amount({
    required this.id,
    required this.totalAmount,
    required this.paidAmount,
    required this.status,
    required this.version,
  });

  final String id;
  final double totalAmount;
  final double paidAmount;
  final V2PaymentStatus status;
  final int version;
  double get balance => totalAmount - paidAmount;

  factory V2Amount.fromJson(Map<String, Object?> json) => V2Amount(
    id: stringValue(json['id']),
    totalAmount: _number(json['totalAmount']),
    paidAmount: _number(json['paidAmount']),
    status: V2PaymentStatus.fromApi(json['paymentStatus']),
    version: (json['version'] as num?)?.toInt() ?? 1,
  );

  static double _number(Object? value) => switch (value) {
    num number => number.toDouble(),
    String text => double.tryParse(text) ?? 0,
    _ => 0,
  };
}
