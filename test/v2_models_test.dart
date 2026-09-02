import 'package:dev_mobile/src/core/network/idempotency_key.dart';
import 'package:dev_mobile/src/models/v2_customer.dart';
import 'package:dev_mobile/src/models/v2_task.dart';
import 'package:dev_mobile/src/models/v2_activity.dart';
import 'package:dev_mobile/src/models/v2_amount.dart';
import 'package:dev_mobile/src/features/voice/voice_command_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('V2 customer parses contact details, tasks and notes', () {
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
        {'id': 'address-1', 'addressText': 'הרצל 10, תל אביב', 'label': 'בית'},
      ],
      'tasks': [
        {'id': 'task-1', 'title': 'לחזור לדני', 'status': 'OPEN', 'version': 1},
      ],
      'notes': [
        {'id': 'note-1', 'text': 'מעדיף שיחה בערב', 'status': 'DONE'},
      ],
    });

    expect(customer.primaryPhone?.normalizedPhone, '+972501234567');
    expect(customer.addresses.single.label, 'בית');
    expect(customer.tasks.single.status, V2TaskStatus.open);
    expect(customer.notes.single.status, V2NoteStatus.done);
    expect(customer.version, 3);
  });

  test('idempotency keys are scoped and unique', () {
    final first = IdempotencyKey.create('customer_create');
    final second = IdempotencyKey.create('customer_create');

    expect(first, startsWith('customer_create_'));
    expect(second, isNot(first));
  });

  test('V2 activities apply the product default display durations', () {
    final startsAt = DateTime.parse('2026-09-06T10:00:00+03:00');
    final base = <String, Object?>{
      'id': 'activity-1',
      'customerId': 'customer-1',
      'title': 'התקנה',
      'status': 'OPEN',
      'startsAt': startsAt.toIso8601String(),
      'version': 1,
    };
    final job = V2Activity.fromJson(base, V2ActivityKind.job);
    final visit = V2Activity.fromJson(base, V2ActivityKind.visit);
    expect(job.effectiveEndsAt, startsAt.add(const Duration(hours: 2)));
    expect(visit.effectiveEndsAt, startsAt.add(const Duration(hours: 1)));
  });

  test('voice receipts expose the stored activity window', () {
    final result = VoiceCommandResult.fromJson({
      'state': 'done',
      'title': 'בוצע',
      'summary': 'הביקור נשמר',
      'items': [
        {
          'id': 'visit-1',
          'actionType': 'CREATE_VISIT',
          'status': 'created',
          'payload': {
            'title': 'תיקון נזילה',
            'startsAt': '2026-09-06T07:00:00.000Z',
            'endsAt': '2026-09-06T08:00:00.000Z',
          },
          'fields': <Object?>[],
          'missingFields': <Object?>[],
        },
      ],
      'secondaryActions': <Object?>[],
    });

    expect(
      result.items.single.fields.map((field) => field.label),
      containsAll(<String>['התחלה', 'סיום']),
    );
  });

  test('voice result distinguishes answers from action cards', () {
    final answer = VoiceCommandResultItem.fromJson(const {
      'id': 'today-overview',
      'actionType': 'GET_TODAY_OVERVIEW',
      'status': 'created',
      'payload': <String, Object?>{},
    });
    final action = VoiceCommandResultItem.fromJson(const {
      'id': 'job-1',
      'actionType': 'CREATE_JOB',
      'status': 'created',
      'payload': <String, Object?>{'title': 'עבודה'},
    });

    expect(answer.isReadOnly, isTrue);
    expect(action.isReadOnly, isFalse);
  });

  test('phone receipt shows both the customer and the added number', () {
    final item = VoiceCommandResultItem.fromJson(const {
      'id': 'phone-1',
      'actionType': 'ADD_CUSTOMER_PHONE',
      'kind': 'action',
      'status': 'created',
      'title': 'טלפון נוסף: דנה לוי',
      'payload': {'customerName': 'דנה לוי', 'phone': '0501234567'},
      'fields': <Object?>[],
    });

    expect(item.fields.map((field) => field.label), ['לקוח', 'טלפון']);
    expect(item.fields.map((field) => field.value), ['דנה לוי', '0501234567']);
  });

  test('activity receipt promotes the subject and shows the customer', () {
    final item = VoiceCommandResultItem.fromJson(const {
      'id': 'job-1',
      'actionType': 'CREATE_JOB',
      'kind': 'action',
      'status': 'created',
      'title': 'עבודה חדשה: תיקון מזגן',
      'payload': {
        'title': 'תיקון מזגן',
        'customerName': 'ג׳ק',
        'description': 'בדיקת מדחס',
      },
      'fields': <Object?>[],
    });

    expect(item.title, 'תיקון מזגן');
    expect(item.kind, 'job');
    expect(item.fields.map((field) => field.label), ['לקוח', 'תיאור']);
    expect(item.fields.first.value, 'ג׳ק');
  });

  test('note receipt is a tappable note work item', () {
    final item = VoiceCommandResultItem.fromJson(const {
      'id': 'note-1',
      'actionType': 'CREATE_NOTE',
      'status': 'created',
      'payload': {
        'customerId': 'customer-1',
        'customerName': 'ג׳ק',
        'text': 'הכלב בחצר',
      },
    });

    expect(item.title, 'הערה ללקוח');
    expect(item.kind, 'note');
    expect(item.fields.map((field) => field.label), ['לקוח', 'הערה']);
  });

  test('V2 amount parses decimal strings and calculates the balance', () {
    final amount = V2Amount.fromJson(const {
      'id': 'amount-1',
      'totalAmount': '1500.00',
      'paidAmount': '500.00',
      'paymentStatus': 'PARTIALLY_PAID',
      'version': 2,
    });
    expect(amount.balance, 1000);
    expect(amount.status, V2PaymentStatus.partiallyPaid);
  });
}
