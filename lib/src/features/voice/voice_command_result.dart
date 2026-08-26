import '../../utils/json_read.dart';

enum VoiceCommandResultState { done, needsInput, failed, unsupported }

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
      state: hasPending
          ? VoiceCommandResultState.needsInput
          : VoiceCommandResultState.done,
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
    required this.kind,
    required this.status,
    required this.title,
    required this.fields,
    required this.missingFields,
    this.subtitle,
    this.entityId,
    this.pendingActionId,
  });

  final String id;
  final String kind;
  final String status;
  final String title;
  final String? subtitle;
  final List<VoiceCommandResultField> fields;
  final String? entityId;
  final String? pendingActionId;
  final List<String> missingFields;

  factory VoiceCommandResultItem.fromJson(Map<String, Object?> json) {
    return VoiceCommandResultItem(
      id: stringValue(json['id'], fallback: 'voice-result-item'),
      kind: stringValue(json['kind'], fallback: 'action'),
      status: stringValue(json['status'], fallback: 'created'),
      title: stringValue(json['title'], fallback: 'פעולה'),
      subtitle: nullableString(json['subtitle']),
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

  VoiceCommandResultItem markCompleted() {
    return VoiceCommandResultItem(
      id: id,
      kind: kind,
      status: 'completed',
      title: title,
      subtitle: 'הושלם עכשיו',
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
    'needs_input' => VoiceCommandResultState.needsInput,
    'failed' => VoiceCommandResultState.failed,
    'unsupported' => VoiceCommandResultState.unsupported,
    _ => VoiceCommandResultState.done,
  };
}
