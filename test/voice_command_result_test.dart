import 'package:dev_mobile/src/features/voice/voice_command_result.dart';
import 'package:dev_mobile/src/features/work_items/work_item_form_screen.dart';
import 'package:dev_mobile/src/navigation/linked_entity_navigation.dart';
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
    expect(item.fields.first.label, 'סטטוס');
    expect(item.fields.first.value, 'תבוטל לאחר אישור');

    final target = voiceWorkItemTarget(item);
    expect(target?.kind, WorkItemKind.quote);
    expect(target?.id, 'quote-1');
    expect(target?.proposedStatus, 'CANCELLED');
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
    expect(voiceApprovalLabel(item.actionType), 'אשר מחיקה');
    expect(voiceWorkItemTarget(item)?.id, 'quote-1');
  });

  test('maps every lifecycle action to its existing work item and status', () {
    const cases = <(String, Map<String, Object?>, WorkItemKind, String?)>[
      (
        'COMPLETE_REMINDER',
        {'reminderId': 'r-1'},
        WorkItemKind.reminder,
        'DONE',
      ),
      (
        'COMPLETE_HOME_VISIT',
        {'homeVisitId': 'h-1'},
        WorkItemKind.homeVisit,
        'DONE',
      ),
      (
        'COMPLETE_APPOINTMENT',
        {'appointmentId': 'a-1'},
        WorkItemKind.appointment,
        'DONE',
      ),
      ('MARK_QUOTE_PAID', {'quoteId': 'q-1'}, WorkItemKind.quote, 'PAID'),
      ('UPDATE_NOTE', {'noteId': 'n-1'}, WorkItemKind.note, null),
    ];

    for (final entry in cases) {
      final item = VoiceCommandResultItem.fromPendingActionJson({
        'id': entry.$1,
        'actionType': entry.$1,
        'status': 'PENDING',
        'payload': entry.$2,
        'missingFields': <String>[],
      });
      final target = voiceWorkItemTarget(item);
      expect(target?.kind, entry.$3, reason: entry.$1);
      expect(target?.proposedStatus, entry.$4, reason: entry.$1);
    }
  });

  test('technical payload fields stay internal', () {
    expect(isVoiceTechnicalField('itemId'), isTrue);
    expect(isVoiceTechnicalField('customerId'), isTrue);
    expect(isVoiceTechnicalField('itemType'), isTrue);
    expect(isVoiceTechnicalField('title'), isFalse);
  });

  test('completed lifecycle action uses a business-facing result', () {
    final item = VoiceCommandResultItem.fromPendingActionJson(const {
      'id': 'complete-reminder',
      'actionType': 'COMPLETE_REMINDER',
      'status': 'PENDING',
      'payload': {'reminderId': 'reminder-1'},
      'missingFields': <String>[],
    }).markCompleted();

    expect(item.subtitle, 'התזכורת נסגרה כבוצעה');
  });
}
