import '../../utils/json_read.dart';

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
    this.pendingActionId,
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
  final String? pendingActionId;
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
      pendingActionId: nullableString(json['pendingActionId']),
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
      kind: isCustomer ? 'customer' : 'callback',
      status: 'pending',
      title: isCustomer ? 'לקוח חדש' : 'תזכורת חדשה',
      subtitle: 'יצירה ידנית מההקלטה',
      payload: payload,
      fields: _fieldsFromPayload(actionType, payload, const <String>[]),
      missingFields: isCustomer ? const <String>['name'] : const <String>[],
    );
  }

  VoiceCommandResultItem markCompleted() {
    return VoiceCommandResultItem(
      id: id,
      actionType: actionType,
      kind: kind,
      status: 'completed',
      title: title,
      subtitle: 'הושלם עכשיו',
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
      pendingActionId: pendingActionId,
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
      pendingActionId: pendingActionId,
      missingFields: missingFields
          .where((field) => !_payloadHasValue(nextPayload, field))
          .toList(),
    );
  }
}

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
    final value = stringValue(payload[key]);
    if (value.isEmpty && !missingFields.contains(key)) return;
    fields.add(
      VoiceCommandResultField(
        label: label,
        value: value.isEmpty ? 'חסר' : value,
        missing: value.isEmpty,
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
  add('name', 'לקוח');
  add('customerId', 'לקוח');
  add('dueAt', 'מועד');
  add('startsAt', 'מועד');
  add('estimatedAmount', 'סכום');
  add('location', 'כתובת');
  add('description', 'תיאור');
  add('notes', 'הערות');
  add('text', 'תוכן');
  return fields;
}

bool _payloadHasValue(Map<String, Object?> payload, String field) {
  return stringValue(payload[field]).isNotEmpty;
}
