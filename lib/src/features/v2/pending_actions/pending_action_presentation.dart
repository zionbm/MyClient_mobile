import 'package:flutter/material.dart';

import '../../../utils/json_read.dart';

const pendingDateFields = {'startsAt', 'endsAt', 'dueAt'};
const pendingCustomerEntityFields = {
  'customerId',
  'sourceCustomerId',
  'targetCustomerId',
};
const pendingEntityFields = {
  ...pendingCustomerEntityFields,
  'taskId',
  'entityId',
};

class PendingEntityChoice {
  const PendingEntityChoice(this.id, this.label);
  final String id;
  final String label;
}

class PendingPresentation {
  const PendingPresentation({
    required this.title,
    required this.question,
    required this.icon,
    this.workItemSummary,
    this.createCustomerName,
  });

  final String title;
  final String question;
  final IconData icon;
  final String? workItemSummary;
  final String? createCustomerName;

  factory PendingPresentation.fromAction(Map<String, Object?> action) {
    final actionType = stringValue(action['actionType']);
    final payload = mapValue(action['payload']);
    final suggestion = mapValue(payload['createCustomerSuggestion']);
    final continuationSteps = mapListValue(payload['continuationSteps']);
    final continuation = continuationSteps.isEmpty
        ? const <String, Object?>{}
        : continuationSteps.first;
    final continuationType = stringValue(continuation['tool']);
    final input = continuation.isEmpty
        ? mapValue(payload['input'])
        : mapValue(continuation['input']);
    final subject = stringValue(input['title']);
    final workType = pendingActionLabel(
      continuationType.isEmpty ? actionType : continuationType,
    );
    return PendingPresentation(
      title: actionType == 'FIND_CUSTOMERS' && suggestion.isNotEmpty
          ? 'לקוח לא נמצא'
          : pendingActionTitle(
              continuationType.isEmpty ? actionType : continuationType,
            ),
      question: stringValue(
        action['question'],
        fallback: 'צריך להשלים פרט לפני שאפשר לבצע את הפעולה.',
      ),
      icon: pendingActionIcon(
        continuationType.isEmpty ? actionType : continuationType,
      ),
      workItemSummary: subject.isEmpty ? null : '$workType: $subject',
      createCustomerName: nullableString(suggestion['name']),
    );
  }
}

String pendingActionLabel(String actionType) => switch (actionType) {
  'CREATE_TASK' ||
  'UPDATE_TASK' ||
  'COMPLETE_TASK' ||
  'CANCEL_TASK' ||
  'DELETE_TASK' => 'משימה',
  'CREATE_JOB' || 'UPDATE_JOB' || 'CANCEL_JOB' || 'DELETE_JOB' => 'עבודה',
  'CREATE_VISIT' ||
  'UPDATE_VISIT' ||
  'CANCEL_VISIT' ||
  'DELETE_VISIT' => 'ביקור',
  'CREATE_CUSTOMER' || 'UPDATE_CUSTOMER' || 'FIND_CUSTOMERS' => 'לקוח',
  'ADD_CUSTOMER_PHONE' || 'DELETE_CUSTOMER_PHONE' => 'טלפון',
  'ADD_SERVICE_ADDRESS' || 'DELETE_SERVICE_ADDRESS' => 'כתובת שירות',
  'CREATE_NOTE' || 'UPDATE_NOTE' => 'הערה',
  'SET_ACTIVITY_AMOUNT' => 'סכום',
  'ADD_PAYMENT' || 'SET_PAID_TOTAL' || 'SETTLE_BALANCE' => 'תשלום',
  'MERGE_CUSTOMERS' => 'מיזוג לקוחות',
  'UNDO_ACTION_BATCH' => 'ביטול פעולה אחרונה',
  _ => 'פעולה',
};

String pendingActionTitle(String actionType) => switch (actionType) {
  'CANCEL_TASK' => 'אישור ביטול משימה',
  'CANCEL_JOB' => 'אישור ביטול עבודה',
  'CANCEL_VISIT' => 'אישור ביטול ביקור',
  'DELETE_TASK' => 'אישור מחיקת משימה',
  'DELETE_JOB' => 'אישור מחיקת עבודה',
  'DELETE_VISIT' => 'אישור מחיקת ביקור',
  'DELETE_CUSTOMER_PHONE' => 'אישור מחיקת טלפון',
  'DELETE_SERVICE_ADDRESS' => 'אישור מחיקת כתובת שירות',
  'SET_ACTIVITY_AMOUNT' => 'אישור סכום',
  'ADD_PAYMENT' || 'SET_PAID_TOTAL' || 'SETTLE_BALANCE' => 'אישור תשלום',
  'MERGE_CUSTOMERS' => 'אישור מיזוג לקוחות',
  'UNDO_ACTION_BATCH' => 'אישור ביטול פעולה אחרונה',
  _ => 'השלמת ${pendingActionLabel(actionType)}',
};

String pendingConfirmationButtonLabel(String actionType) =>
    switch (actionType) {
      'CANCEL_TASK' || 'CANCEL_JOB' || 'CANCEL_VISIT' => 'אישור ביטול',
      'DELETE_TASK' ||
      'DELETE_JOB' ||
      'DELETE_VISIT' ||
      'DELETE_CUSTOMER_PHONE' ||
      'DELETE_SERVICE_ADDRESS' => 'אישור מחיקה',
      'SET_ACTIVITY_AMOUNT' => 'אישור סכום',
      'ADD_PAYMENT' || 'SET_PAID_TOTAL' || 'SETTLE_BALANCE' => 'אישור תשלום',
      'MERGE_CUSTOMERS' => 'אישור מיזוג',
      'UNDO_ACTION_BATCH' => 'אישור ביטול הפעולה',
      _ => 'אישור וביצוע',
    };

IconData pendingActionIcon(String actionType) => switch (actionType) {
  'CREATE_TASK' || 'UPDATE_TASK' || 'COMPLETE_TASK' => Icons.task_alt,
  'CREATE_JOB' || 'UPDATE_JOB' => Icons.home_repair_service_outlined,
  'CREATE_VISIT' || 'UPDATE_VISIT' => Icons.event_outlined,
  'CREATE_CUSTOMER' ||
  'UPDATE_CUSTOMER' ||
  'FIND_CUSTOMERS' => Icons.person_outline,
  'ADD_CUSTOMER_PHONE' => Icons.phone_outlined,
  'DELETE_CUSTOMER_PHONE' => Icons.phone_disabled_outlined,
  'ADD_SERVICE_ADDRESS' => Icons.location_on_outlined,
  'DELETE_SERVICE_ADDRESS' => Icons.wrong_location_outlined,
  'SET_ACTIVITY_AMOUNT' => Icons.payments_outlined,
  'ADD_PAYMENT' ||
  'SET_PAID_TOTAL' ||
  'SETTLE_BALANCE' => Icons.account_balance_wallet_outlined,
  'CANCEL_TASK' || 'CANCEL_JOB' || 'CANCEL_VISIT' => Icons.event_busy_outlined,
  'DELETE_TASK' || 'DELETE_JOB' || 'DELETE_VISIT' => Icons.delete_outline,
  'MERGE_CUSTOMERS' => Icons.merge_outlined,
  'UNDO_ACTION_BATCH' => Icons.undo,
  _ => Icons.auto_awesome_outlined,
};

List<String> expandedPendingFields(
  List<String> fields, {
  bool needsFreeTextAnswer = false,
}) {
  if (fields.isEmpty) return needsFreeTextAnswer ? const ['answer'] : const [];
  final result = <String>[];
  for (final field in fields) {
    if (field == 'schedule') {
      result.addAll(const ['startsAt', 'endsAt']);
    } else if (field == 'totalAmountOrPaidAmount') {
      result.addAll(const ['totalAmount', 'paidAmount']);
    } else if (field == 'noChargeOrAmount') {
      result.addAll(const ['noCharge', 'totalAmount']);
    } else if (field == 'customers') {
      result.addAll(const ['sourceCustomerId', 'targetCustomerId']);
    } else if (field == 'customerOrAddress') {
      result.addAll(const ['customerId', 'addressText']);
    } else {
      result.add(field);
    }
  }
  return result.toSet().toList(growable: false);
}

String pendingFieldLabel(String field) => switch (field) {
  'answer' => 'תשובה',
  'customerId' => 'לקוח',
  'sourceCustomerId' => 'לקוח מקור',
  'targetCustomerId' => 'לקוח יעד',
  'taskId' => 'משימה',
  'entityId' => 'עבודה או ביקור',
  'phone' => 'מספר טלפון',
  'addressText' => 'כתובת שירות',
  'title' => 'כותרת',
  'description' => 'תיאור',
  'startsAt' => 'התחלה',
  'endsAt' => 'סיום',
  'dueAt' => 'מועד תזכורת',
  'amount' => 'סכום',
  'totalAmount' => 'סכום כולל',
  'paidAmount' => 'סכום ששולם',
  'noCharge' => 'ללא חיוב? כן / לא',
  _ => field,
};

String? pendingFieldHint(String field) => switch (field) {
  'startsAt' || 'endsAt' || 'dueAt' => 'לדוגמה: 2026-09-01 10:00',
  'noCharge' => 'יש לכתוב כן אם לא היה חיוב',
  _ => null,
};
