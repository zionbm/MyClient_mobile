import '../../utils/json_read.dart';
import '../../utils/date_formatting.dart';

enum VoiceCommandResultState {
  done,
  needsReview,
  needsInput,
  failed,
  unsupported,
}

class VoiceCommandResult {
  const VoiceCommandResult({
    required this.state,
    required this.title,
    required this.summary,
    required this.items,
    required this.secondaryActions,
    this.transcript,
    this.primaryAction,
  });

  final VoiceCommandResultState state;
  final String title;
  final String summary;
  final String? transcript;
  final List<VoiceCommandResultItem> items;
  final String? primaryAction;
  final List<String> secondaryActions;

  factory VoiceCommandResult.fromJson(Map<String, Object?> json) {
    return VoiceCommandResult(
      state: _stateFromJson(stringValue(json['state'], fallback: 'done')),
      title: stringValue(json['title'], fallback: 'בוצע'),
      summary: stringValue(json['summary']),
      transcript: nullableString(json['transcript']),
      items: mapListValue(
        json['items'],
      ).map(VoiceCommandResultItem.fromJson).toList(),
      primaryAction: nullableString(json['primaryAction']),
      secondaryActions:
          (json['secondaryActions'] as List?)
              ?.map((value) => stringValue(value))
              .where((value) => value.isNotEmpty)
              .toList() ??
          const <String>[],
    );
  }

  VoiceCommandResult markItemCompleted(String itemId) {
    final updatedItems = items
        .map((item) => item.id == itemId ? item.markCompleted() : item)
        .toList();
    final hasPending = updatedItems.any((item) => item.status == 'pending');
    return VoiceCommandResult(
      state: hasPending ? state : VoiceCommandResultState.done,
      title: hasPending ? title : 'בוצע',
      summary: hasPending ? summary : 'הפעולה הושלמה ונשמרה במערכת.',
      transcript: transcript,
      items: updatedItems,
      primaryAction: hasPending ? primaryAction : 'סגור',
      secondaryActions: hasPending
          ? secondaryActions
          : const <String>['הקלט שוב'],
    );
  }

  VoiceCommandResult removeItem(String itemId) {
    final updatedItems = items.where((item) => item.id != itemId).toList();
    final hasMissing = updatedItems.any(
      (item) => item.status == 'pending' && item.missingFields.isNotEmpty,
    );
    final hasPending = updatedItems.any((item) => item.status == 'pending');
    return VoiceCommandResult(
      state: hasMissing
          ? VoiceCommandResultState.needsInput
          : hasPending
          ? VoiceCommandResultState.needsReview
          : VoiceCommandResultState.done,
      title: hasMissing
          ? 'צריך עוד פרט'
          : hasPending
          ? 'לאישור'
          : 'בוצע',
      summary: updatedItems.isEmpty ? 'לא נשארו פעולות לאישור.' : summary,
      transcript: transcript,
      items: updatedItems,
      primaryAction: updatedItems.isEmpty ? 'סגור' : primaryAction,
      secondaryActions: updatedItems.isEmpty
          ? const <String>['הקלט שוב']
          : secondaryActions,
    );
  }

  VoiceCommandResult addCompletedManualItem(VoiceCommandResultItem item) {
    return VoiceCommandResult(
      state: VoiceCommandResultState.done,
      title: 'בוצע',
      summary: 'הפעולה נוצרה ונשמרה במערכת.',
      transcript: transcript,
      items: [item.markCompleted(), ...items],
      primaryAction: 'סגור',
      secondaryActions: const <String>['הקלט שוב'],
    );
  }

  VoiceCommandResult updateItemPayload(
    String itemId,
    Map<String, Object?> payload,
  ) {
    final updatedItems = items
        .map((item) => item.id == itemId ? item.updatePayload(payload) : item)
        .toList();
    final hasMissing = updatedItems.any(
      (item) => item.status == 'pending' && item.missingFields.isNotEmpty,
    );
    final hasPending = updatedItems.any((item) => item.status == 'pending');
    return VoiceCommandResult(
      state: hasMissing
          ? VoiceCommandResultState.needsInput
          : hasPending
          ? VoiceCommandResultState.needsReview
          : VoiceCommandResultState.done,
      title: hasMissing
          ? 'צריך עוד פרט'
          : hasPending
          ? 'לאישור'
          : 'בוצע',
      summary: summary,
      transcript: transcript,
      items: updatedItems,
      primaryAction: primaryAction,
      secondaryActions: secondaryActions,
    );
  }

  static VoiceCommandResult fallback({String? message}) {
    return VoiceCommandResult(
      state: VoiceCommandResultState.failed,
      title: 'לא הצלחתי לבצע את הפקודה',
      summary: message ?? 'אפשר להקליט שוב או ליצור את הפעולה ידנית.',
      transcript: null,
      items: const <VoiceCommandResultItem>[],
      primaryAction: 'הקלט שוב',
      secondaryActions: const <String>['סגור'],
    );
  }
}

class VoiceCommandResultItem {
  const VoiceCommandResultItem({
    required this.id,
    required this.actionType,
    required this.kind,
    required this.status,
    required this.title,
    required this.payload,
    required this.fields,
    required this.missingFields,
    this.subtitle,
    this.entityId,
    this.aiPendingActionId,
  });

  final String id;
  final String actionType;
  final String kind;
  final String status;
  final String title;
  final String? subtitle;
  final Map<String, Object?> payload;
  final List<VoiceCommandResultField> fields;
  final String? entityId;
  final String? aiPendingActionId;
  final List<String> missingFields;

  bool get isReadOnly =>
      actionType.startsWith('GET_') ||
      actionType.startsWith('FIND_') ||
      actionType == 'RESPOND';

  factory VoiceCommandResultItem.fromJson(Map<String, Object?> json) {
    final actionType = stringValue(json['actionType'], fallback: 'ACTION');
    final payload = mapValue(json['payload']);
    final receivedKind = stringValue(json['kind'], fallback: 'action');
    final receivedTitle = stringValue(json['title'], fallback: 'פעולה');
    final missingFields =
        (json['missingFields'] as List?)
            ?.map((value) => stringValue(value))
            .where((value) => value.isNotEmpty)
            .toList() ??
        const <String>[];
    final providedFields = mapListValue(
      json['fields'],
    ).map(VoiceCommandResultField.fromJson).toList();
    return VoiceCommandResultItem(
      id: stringValue(json['id'], fallback: 'voice-result-item'),
      actionType: actionType,
      kind: receivedKind == 'action'
          ? _kindForActionType(actionType, payload)
          : receivedKind,
      status: stringValue(json['status'], fallback: 'created'),
      title: _completedItemTitle(actionType, payload, receivedTitle),
      subtitle: nullableString(json['subtitle']),
      payload: payload,
      fields: providedFields.isEmpty
          ? _fieldsFromPayload(actionType, payload, missingFields)
          : providedFields,
      entityId: nullableString(json['entityId']),
      aiPendingActionId: nullableString(json['aiPendingActionId']),
      missingFields: missingFields,
    );
  }

  factory VoiceCommandResultItem.manual({
    required String actionType,
    required String? transcript,
  }) {
    final isCustomer = actionType == 'CREATE_CUSTOMER';
    final payload = <String, Object?>{
      if (!isCustomer && transcript != null && transcript.trim().isNotEmpty)
        'title': transcript.trim(),
    };
    return VoiceCommandResultItem(
      id: 'manual_${DateTime.now().microsecondsSinceEpoch}',
      actionType: actionType,
      kind: isCustomer ? 'customer' : 'reminder',
      status: 'pending',
      title: isCustomer ? 'לקוח חדש' : 'תזכורת חדשה',
      subtitle: 'יצירה ידנית מההקלטה',
      payload: payload,
      fields: _fieldsFromPayload(actionType, payload, const <String>[]),
      missingFields: isCustomer ? const <String>['name'] : const <String>[],
    );
  }

  factory VoiceCommandResultItem.fromPendingActionJson(
    Map<String, Object?> json,
  ) {
    final actionType = stringValue(json['actionType'], fallback: 'ACTION');
    final payload = mapValue(json['payload']);
    final missingFields =
        (json['missingFields'] as List?)
            ?.map((value) => stringValue(value))
            .where((value) => value.isNotEmpty)
            .toList() ??
        const <String>[];
    return VoiceCommandResultItem(
      id: stringValue(json['id'], fallback: 'pending-action'),
      actionType: actionType,
      kind: _kindForActionType(actionType, payload),
      status: _statusFromPendingAction(stringValue(json['status'])),
      title: _titleForActionType(actionType, payload),
      subtitle: nullableString(json['reviewReason']),
      payload: payload,
      fields: _fieldsFromPayload(actionType, payload, missingFields),
      aiPendingActionId: nullableString(json['id']),
      missingFields: missingFields,
    );
  }

  VoiceCommandResultItem markCompleted() {
    return VoiceCommandResultItem(
      id: id,
      actionType: actionType,
      kind: kind,
      status: 'completed',
      title: title,
      subtitle: _completedSubtitle(actionType),
      payload: payload,
      fields: fields
          .map(
            (field) => field.missing
                ? VoiceCommandResultField(
                    label: field.label,
                    value: 'הושלם',
                    missing: false,
                  )
                : field,
          )
          .toList(),
      entityId: entityId,
      aiPendingActionId: aiPendingActionId,
      missingFields: const <String>[],
    );
  }

  VoiceCommandResultItem updatePayload(Map<String, Object?> nextPayload) {
    return VoiceCommandResultItem(
      id: id,
      actionType: actionType,
      kind: kind,
      status: status,
      title: title,
      subtitle: subtitle,
      payload: nextPayload,
      fields: _fieldsFromPayload(actionType, nextPayload, missingFields),
      entityId: entityId,
      aiPendingActionId: aiPendingActionId,
      missingFields: missingFields
          .where((field) => !_payloadHasValue(nextPayload, field))
          .toList(),
    );
  }
}

bool isVoiceWorkItemAction(String actionType) =>
    voiceWorkItemKindName(actionType) != null;

String? voiceWorkItemKindName(String actionType) {
  return switch (actionType) {
    'CREATE_TASK' || 'UPDATE_TASK' => 'task',
    'CREATE_JOB' || 'UPDATE_JOB' => 'job',
    'CREATE_VISIT' || 'UPDATE_VISIT' => 'visit',
    'CREATE_NOTE' || 'UPDATE_NOTE' => 'note',
    _ => null,
  };
}

bool isVoiceTechnicalField(String field) {
  return field == 'itemType' || field == 'entityType' || field.endsWith('Id');
}

bool isExistingVoiceWorkItemAction(String actionType) => switch (actionType) {
  'UPDATE_TASK' ||
  'COMPLETE_TASK' ||
  'CANCEL_TASK' ||
  'REOPEN_TASK' ||
  'DELETE_TASK' ||
  'UPDATE_JOB' ||
  'REPORT_JOB_COMPLETED' ||
  'CANCEL_JOB' ||
  'REOPEN_JOB' ||
  'DELETE_JOB' ||
  'UPDATE_VISIT' ||
  'REPORT_VISIT_COMPLETED' ||
  'CANCEL_VISIT' ||
  'REOPEN_VISIT' ||
  'DELETE_VISIT' ||
  'UPDATE_NOTE' => true,
  _ => false,
};

String voiceApprovalLabel(String actionType) => switch (actionType) {
  'COMPLETE_TASK' ||
  'REPORT_JOB_COMPLETED' ||
  'REPORT_VISIT_COMPLETED' => 'סיום הפעולה',
  'CANCEL_TASK' || 'CANCEL_JOB' || 'CANCEL_VISIT' => 'אשר ביטול',
  'SET_ACTIVITY_AMOUNT' => 'אשר סכום',
  'ADD_PAYMENT' || 'SET_PAID_TOTAL' || 'SETTLE_BALANCE' => 'אשר תשלום',
  'DELETE_TASK' ||
  'DELETE_JOB' ||
  'DELETE_VISIT' ||
  'DELETE_CUSTOMER_PHONE' ||
  'DELETE_SERVICE_ADDRESS' => 'אשר מחיקה',
  'MERGE_CUSTOMERS' => 'אשר מיזוג',
  'UNDO_ACTION_BATCH' => 'אשר ביטול פעולה',
  _ => 'בצע פעולה',
};

class VoiceCommandResultField {
  const VoiceCommandResultField({
    required this.label,
    required this.value,
    required this.missing,
  });

  final String label;
  final String value;
  final bool missing;

  factory VoiceCommandResultField.fromJson(Map<String, Object?> json) {
    return VoiceCommandResultField(
      label: stringValue(json['label']),
      value: stringValue(json['value']),
      missing: stringValue(json['state']) == 'missing',
    );
  }
}

VoiceCommandResultState _stateFromJson(String value) {
  return switch (value) {
    'needs_review' => VoiceCommandResultState.needsReview,
    'needs_input' => VoiceCommandResultState.needsInput,
    'failed' => VoiceCommandResultState.failed,
    'unsupported' => VoiceCommandResultState.unsupported,
    _ => VoiceCommandResultState.done,
  };
}

List<VoiceCommandResultField> _fieldsFromPayload(
  String actionType,
  Map<String, Object?> payload,
  List<String> missingFields,
) {
  final fields = <VoiceCommandResultField>[];
  void add(String key, String label) {
    final value = _displayFieldValue(key, payload[key]);
    if (value.isEmpty && !missingFields.contains(key)) return;
    fields.add(
      VoiceCommandResultField(
        label: label,
        value: value.isEmpty ? 'חסר' : value,
        missing: value.isEmpty,
      ),
    );
  }

  final proposedStatus = _proposedStatusLabel(actionType);
  if (proposedStatus != null) {
    fields.add(
      VoiceCommandResultField(
        label: 'סטטוס',
        value: proposedStatus,
        missing: false,
      ),
    );
  }

  if (actionType == 'CREATE_CUSTOMER') {
    add('name', 'שם');
    add('phone', 'טלפון');
    add('email', 'אימייל');
    return fields;
  }
  if (actionType == 'ADD_CUSTOMER_PHONE') {
    add('customerName', 'לקוח');
    add('phone', 'טלפון');
    return fields;
  }
  if (missingFields.contains('title')) add('title', 'נושא');
  add('customerName', 'לקוח');
  if (!payload.containsKey('customerName')) {
    add('name', 'לקוח');
  }
  add('dueAt', 'מועד');
  add('startsAt', 'התחלה');
  add('endsAt', 'סיום');
  add('totalAmount', 'סכום');
  add('locationSnapshot', 'כתובת');
  add('description', 'תיאור');
  add('text', 'הערה');
  add('generalNotes', 'הערות');
  return fields;
}

String? _proposedStatusLabel(String actionType) => switch (actionType) {
  'COMPLETE_TASK' ||
  'REPORT_JOB_COMPLETED' ||
  'REPORT_VISIT_COMPLETED' => 'ייסגר כבוצע',
  'CANCEL_TASK' || 'CANCEL_JOB' || 'CANCEL_VISIT' => 'יבוטל לאחר אישור',
  'DELETE_TASK' || 'DELETE_JOB' || 'DELETE_VISIT' => 'יימחק לאחר אישור',
  _ => null,
};

String _completedSubtitle(String actionType) => switch (actionType) {
  'COMPLETE_TASK' => 'המשימה הושלמה',
  'REPORT_JOB_COMPLETED' => 'העבודה דווחה כבוצעה',
  'REPORT_VISIT_COMPLETED' => 'הביקור דווח כבוצע',
  'CANCEL_TASK' || 'CANCEL_JOB' || 'CANCEL_VISIT' => 'הפריט בוטל',
  'DELETE_TASK' || 'DELETE_JOB' || 'DELETE_VISIT' => 'הפריט נמחק',
  _ => 'הושלם עכשיו',
};

String _displayFieldValue(String key, Object? rawValue) {
  final value = stringValue(rawValue);
  if ((key == 'dueAt' || key == 'startsAt' || key == 'endsAt') &&
      value.isNotEmpty) {
    final date = DateTime.tryParse(value);
    if (date != null) return formatDateTime(date);
  }
  return value;
}

bool _payloadHasValue(Map<String, Object?> payload, String field) {
  return stringValue(payload[field]).isNotEmpty;
}

String _kindForActionType(
  String actionType, [
  Map<String, Object?> payload = const {},
]) {
  return switch (actionType) {
    'CREATE_CUSTOMER' => 'customer',
    'CREATE_TASK' ||
    'UPDATE_TASK' ||
    'COMPLETE_TASK' ||
    'CANCEL_TASK' ||
    'REOPEN_TASK' ||
    'DELETE_TASK' => 'reminder',
    'CREATE_JOB' ||
    'UPDATE_JOB' ||
    'REPORT_JOB_COMPLETED' ||
    'CANCEL_JOB' ||
    'REOPEN_JOB' ||
    'DELETE_JOB' => 'job',
    'CREATE_VISIT' ||
    'UPDATE_VISIT' ||
    'REPORT_VISIT_COMPLETED' ||
    'CANCEL_VISIT' ||
    'REOPEN_VISIT' ||
    'DELETE_VISIT' => 'home_visit',
    'CREATE_NOTE' || 'UPDATE_NOTE' => 'note',
    _ => 'action',
  };
}

String _titleForActionType(
  String actionType, [
  Map<String, Object?> payload = const {},
]) {
  return switch (actionType) {
    'CREATE_CUSTOMER' => 'לקוח חדש',
    'ADD_CUSTOMER_PHONE' => 'הוספת טלפון ללקוח',
    'CREATE_TASK' => 'משימה חדשה',
    'UPDATE_TASK' => 'עדכון משימה',
    'COMPLETE_TASK' => 'השלמת משימה',
    'CANCEL_TASK' => 'ביטול משימה',
    'CREATE_JOB' => 'עבודה חדשה',
    'UPDATE_JOB' => 'עדכון עבודה',
    'CREATE_VISIT' => 'ביקור חדש',
    'UPDATE_VISIT' => 'עדכון ביקור',
    'CREATE_NOTE' => 'הערה חדשה',
    'UPDATE_NOTE' => 'עדכון הערה',
    _ => 'פעולת AI',
  };
}

String _completedItemTitle(
  String actionType,
  Map<String, Object?> payload,
  String fallback,
) {
  if (actionType == 'CREATE_NOTE' || actionType == 'UPDATE_NOTE') {
    return 'הערה ללקוח';
  }
  if (isVoiceWorkItemAction(actionType)) {
    final title = stringValue(payload['title']);
    if (title.isNotEmpty) return title;
  }
  return fallback;
}

String _statusFromPendingAction(String status) {
  return switch (status) {
    'PENDING' => 'pending',
    'FAILED' || 'REJECTED' => 'failed',
    _ => 'completed',
  };
}
