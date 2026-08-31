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

  factory VoiceCommandResultItem.fromJson(Map<String, Object?> json) {
    return VoiceCommandResultItem(
      id: stringValue(json['id'], fallback: 'voice-result-item'),
      actionType: stringValue(json['actionType'], fallback: 'ACTION'),
      kind: stringValue(json['kind'], fallback: 'action'),
      status: stringValue(json['status'], fallback: 'created'),
      title: stringValue(json['title'], fallback: 'פעולה'),
      subtitle: nullableString(json['subtitle']),
      payload: mapValue(json['payload']),
      fields: mapListValue(
        json['fields'],
      ).map(VoiceCommandResultField.fromJson).toList(),
      entityId: nullableString(json['entityId']),
      aiPendingActionId: nullableString(json['aiPendingActionId']),
      missingFields:
          (json['missingFields'] as List?)
              ?.map((value) => stringValue(value))
              .where((value) => value.isNotEmpty)
              .toList() ??
          const <String>[],
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
    'CREATE_REMINDER' || 'UPDATE_REMINDER' => 'reminder',
    'CREATE_HOME_VISIT' || 'UPDATE_HOME_VISIT' => 'homeVisit',
    'CREATE_APPOINTMENT' || 'UPDATE_APPOINTMENT' => 'appointment',
    'CREATE_QUOTE' || 'UPDATE_QUOTE' => 'quote',
    'CREATE_NOTE' || 'UPDATE_NOTE' => 'note',
    _ => null,
  };
}

bool isVoiceTechnicalField(String field) {
  return field == 'itemType' || field == 'entityType' || field.endsWith('Id');
}

bool isExistingVoiceWorkItemAction(String actionType) => switch (actionType) {
  'UPDATE_REMINDER' ||
  'COMPLETE_REMINDER' ||
  'UPDATE_HOME_VISIT' ||
  'COMPLETE_HOME_VISIT' ||
  'UPDATE_APPOINTMENT' ||
  'COMPLETE_APPOINTMENT' ||
  'CANCEL_APPOINTMENT' ||
  'UPDATE_QUOTE' ||
  'MARK_QUOTE_PAID' ||
  'CANCEL_QUOTE' ||
  'UPDATE_NOTE' ||
  'DELETE_WORK_ITEM' => true,
  _ => false,
};

String voiceApprovalLabel(String actionType) => switch (actionType) {
  'COMPLETE_REMINDER' ||
  'COMPLETE_HOME_VISIT' ||
  'COMPLETE_APPOINTMENT' => 'אשר סגירה',
  'CANCEL_APPOINTMENT' || 'CANCEL_QUOTE' => 'אשר ביטול',
  'MARK_QUOTE_PAID' => 'אשר תשלום',
  'DELETE_WORK_ITEM' => 'אשר מחיקה',
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
    add('address', 'כתובת');
    return fields;
  }
  add('title', 'נושא');
  add('customerName', 'לקוח');
  if (!payload.containsKey('customerName')) {
    add('name', 'לקוח');
  }
  add('dueAt', 'מועד');
  add('startsAt', 'מועד');
  add('estimatedAmount', 'סכום');
  add('location', 'כתובת');
  add('description', 'תיאור');
  add('notes', 'הערות');
  add('text', 'תוכן');
  return fields;
}

String? _proposedStatusLabel(String actionType) => switch (actionType) {
  'COMPLETE_REMINDER' => 'תיסגר כבוצעה לאחר אישור',
  'COMPLETE_HOME_VISIT' => 'ייסגר כבוצע לאחר אישור',
  'COMPLETE_APPOINTMENT' => 'תיסגר כבוצעה לאחר אישור',
  'CANCEL_APPOINTMENT' || 'CANCEL_QUOTE' => 'תבוטל לאחר אישור',
  'MARK_QUOTE_PAID' => 'תיסגר כשולמה לאחר אישור',
  'DELETE_WORK_ITEM' => 'יימחק לאחר אישור',
  _ => null,
};

String _completedSubtitle(String actionType) => switch (actionType) {
  'COMPLETE_REMINDER' => 'התזכורת נסגרה כבוצעה',
  'COMPLETE_HOME_VISIT' => 'ביקור הבית נסגר כבוצע',
  'COMPLETE_APPOINTMENT' => 'הפגישה נסגרה כבוצעה',
  'CANCEL_APPOINTMENT' => 'הפגישה בוטלה',
  'MARK_QUOTE_PAID' => 'הצעת המחיר נסגרה כשולמה',
  'CANCEL_QUOTE' => 'הצעת המחיר בוטלה',
  'DELETE_WORK_ITEM' => 'הפריט נמחק',
  _ => 'הושלם עכשיו',
};

String _displayFieldValue(String key, Object? rawValue) {
  final value = stringValue(rawValue);
  if ((key == 'dueAt' || key == 'startsAt') && value.isNotEmpty) {
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
  if (actionType == 'DELETE_WORK_ITEM') {
    return switch (stringValue(payload['itemType'])) {
      'reminder' => 'reminder',
      'home_visit' => 'home_visit',
      'appointment' => 'appointment',
      'quote' => 'quote',
      'note' => 'note',
      _ => 'action',
    };
  }
  return switch (actionType) {
    'CREATE_CUSTOMER' => 'customer',
    'CREATE_REMINDER' || 'UPDATE_REMINDER' || 'COMPLETE_REMINDER' => 'reminder',
    'CREATE_HOME_VISIT' ||
    'UPDATE_HOME_VISIT' ||
    'COMPLETE_HOME_VISIT' => 'home_visit',
    'CREATE_APPOINTMENT' ||
    'UPDATE_APPOINTMENT' ||
    'COMPLETE_APPOINTMENT' ||
    'CANCEL_APPOINTMENT' => 'appointment',
    'CREATE_QUOTE' ||
    'UPDATE_QUOTE' ||
    'MARK_QUOTE_PAID' ||
    'CANCEL_QUOTE' => 'quote',
    'CREATE_NOTE' || 'UPDATE_NOTE' => 'note',
    _ => 'action',
  };
}

String _titleForActionType(
  String actionType, [
  Map<String, Object?> payload = const {},
]) {
  if (actionType == 'DELETE_WORK_ITEM') {
    return switch (stringValue(payload['itemType'])) {
      'quote' => 'מחיקת הצעת מחיר',
      'appointment' => 'מחיקת פגישה',
      'home_visit' => 'מחיקת ביקור בית',
      'reminder' => 'מחיקת תזכורת',
      'note' => 'מחיקת הערה',
      _ => 'מחיקת פריט עבודה',
    };
  }
  return switch (actionType) {
    'CREATE_CUSTOMER' => 'לקוח חדש',
    'CREATE_REMINDER' => 'תזכורת חדשה',
    'UPDATE_REMINDER' => 'עדכון תזכורת',
    'COMPLETE_REMINDER' => 'סגירת תזכורת',
    'CREATE_HOME_VISIT' => 'ביקור בית חדש',
    'UPDATE_HOME_VISIT' => 'עדכון ביקור בית',
    'COMPLETE_HOME_VISIT' => 'סגירת ביקור בית',
    'CREATE_APPOINTMENT' => 'פגישה חדשה',
    'UPDATE_APPOINTMENT' => 'עדכון פגישה',
    'COMPLETE_APPOINTMENT' => 'סיום פגישה',
    'CANCEL_APPOINTMENT' => 'ביטול פגישה',
    'CREATE_QUOTE' => 'הצעת מחיר חדשה',
    'UPDATE_QUOTE' => 'עדכון הצעת מחיר',
    'MARK_QUOTE_PAID' => 'סימון הצעה כשולמה',
    'CANCEL_QUOTE' => 'ביטול הצעת מחיר',
    'CREATE_NOTE' => 'הערת לקוח חדשה',
    'UPDATE_NOTE' => 'עדכון הערה',
    _ => 'פעולת AI',
  };
}

String _statusFromPendingAction(String status) {
  return switch (status) {
    'PENDING' => 'pending',
    'FAILED' || 'REJECTED' => 'failed',
    _ => 'completed',
  };
}
