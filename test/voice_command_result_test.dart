import 'package:dev_mobile/src/features/voice/voice_command_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('presents a cancelled quote as a quote action', () {
    final item = VoiceCommandResultItem.fromPendingActionJson(const {
      'id': 'cancel-quote',
      'actionType': 'CANCEL_QUOTE',
      'status': 'PENDING',
      'payload': {'quoteId': 'quote-1', 'customerName': 'יואב גת'},
      'missingFields': <String>[],
    });

    expect(item.kind, 'quote');
    expect(item.title, 'ביטול הצעת מחיר');
  });

  test('presents quote deletion using its payload item type', () {
    final item = VoiceCommandResultItem.fromPendingActionJson(const {
      'id': 'delete-quote',
      'actionType': 'DELETE_WORK_ITEM',
      'status': 'PENDING',
      'payload': {
        'itemType': 'quote',
        'itemId': 'quote-1',
        'customerName': 'יואב גת',
      },
      'missingFields': <String>[],
    });

    expect(item.kind, 'quote');
    expect(item.title, 'מחיקת הצעת מחיר');
  });
}
