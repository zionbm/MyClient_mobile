import 'package:dev_mobile/src/core/network/idempotency_key.dart';
import 'package:dev_mobile/src/models/v2_customer.dart';
import 'package:dev_mobile/src/models/v2_task.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('V2 customer parses multiple phones, addresses and tasks', () {
    final customer = V2Customer.fromJson({
      'id': 'customer-1',
      'name': 'דני',
      'version': 3,
      'customerPhones': [
        {
          'id': 'phone-1',
          'rawPhone': '050-123-4567',
          'normalizedPhone': '+972501234567',
          'isPrimary': true,
        },
      ],
      'serviceAddresses': [
        {
          'id': 'address-1',
          'addressText': 'הרצל 10, תל אביב',
          'label': 'בית',
        },
      ],
      'tasks': [
        {
          'id': 'task-1',
          'title': 'לחזור לדני',
          'status': 'OPEN',
          'version': 1,
        },
      ],
    });

    expect(customer.primaryPhone?.normalizedPhone, '+972501234567');
    expect(customer.addresses.single.label, 'בית');
    expect(customer.tasks.single.status, V2TaskStatus.open);
    expect(customer.version, 3);
  });

  test('idempotency keys are scoped and unique', () {
    final first = IdempotencyKey.create('customer_create');
    final second = IdempotencyKey.create('customer_create');

    expect(first, startsWith('customer_create_'));
    expect(second, isNot(first));
  });
}
