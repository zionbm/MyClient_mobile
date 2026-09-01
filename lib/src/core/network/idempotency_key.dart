import 'dart:math';

class IdempotencyKey {
  IdempotencyKey._();

  static final Random _random = Random.secure();

  static String create(String scope) {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final entropy = List.generate(
      4,
      (_) => _random.nextInt(0x100000000).toRadixString(16).padLeft(8, '0'),
    ).join();
    return '${scope}_${timestamp}_$entropy';
  }
}
