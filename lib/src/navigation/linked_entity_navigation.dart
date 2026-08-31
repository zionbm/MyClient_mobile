import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../data/repositories/work_item_repository.dart';
import '../features/auth/session_controller.dart';
import '../features/customers/customer_detail_screen.dart';
import '../features/voice/voice_command_result.dart';
import '../features/work_items/work_item_form_screen.dart';
import '../models/customer.dart';
import '../models/work_item.dart';

class VoiceWorkItemTarget {
  const VoiceWorkItemTarget({
    required this.kind,
    required this.type,
    required this.id,
    this.proposedStatus,
  });

  final WorkItemKind kind;
  final CrmWorkItemType type;
  final String id;
  final String? proposedStatus;
}

VoiceWorkItemTarget? voiceWorkItemTarget(VoiceCommandResultItem item) {
  final payload = item.payload;
  final actionType = item.actionType;
  final targetType = actionType == 'DELETE_WORK_ITEM'
      ? payload['itemType']?.toString()
      : switch (actionType) {
          'UPDATE_REMINDER' || 'COMPLETE_REMINDER' => 'reminder',
          'UPDATE_HOME_VISIT' || 'COMPLETE_HOME_VISIT' => 'home_visit',
          'UPDATE_APPOINTMENT' ||
          'COMPLETE_APPOINTMENT' ||
          'CANCEL_APPOINTMENT' => 'appointment',
          'UPDATE_QUOTE' || 'MARK_QUOTE_PAID' || 'CANCEL_QUOTE' => 'quote',
          'UPDATE_NOTE' => 'note',
          _ => null,
        };
  final idKey = actionType == 'DELETE_WORK_ITEM'
      ? 'itemId'
      : switch (targetType) {
          'reminder' => 'reminderId',
          'home_visit' => 'homeVisitId',
          'appointment' => 'appointmentId',
          'quote' => 'quoteId',
          'note' => 'noteId',
          _ => null,
        };
  final id = idKey == null ? null : payload[idKey]?.toString();
  if (targetType == null || id == null || id.isEmpty) return null;

  final mappedType = switch (targetType) {
    'reminder' => (WorkItemKind.reminder, CrmWorkItemType.reminder),
    'home_visit' => (WorkItemKind.homeVisit, CrmWorkItemType.homeVisit),
    'appointment' => (WorkItemKind.appointment, CrmWorkItemType.appointment),
    'quote' => (WorkItemKind.quote, CrmWorkItemType.quote),
    'note' => (WorkItemKind.note, CrmWorkItemType.note),
    _ => null,
  };
  if (mappedType == null) return null;
  final proposedStatus = switch (actionType) {
    'COMPLETE_REMINDER' ||
    'COMPLETE_HOME_VISIT' ||
    'COMPLETE_APPOINTMENT' => 'DONE',
    'CANCEL_APPOINTMENT' || 'CANCEL_QUOTE' => 'CANCELLED',
    'MARK_QUOTE_PAID' => 'PAID',
    _ => null,
  };
  return VoiceWorkItemTarget(
    kind: mappedType.$1,
    type: mappedType.$2,
    id: id,
    proposedStatus: proposedStatus,
  );
}

Future<bool?> openVoiceWorkItemAction({
  required BuildContext context,
  required SessionController controller,
  required VoiceCommandResultItem action,
  required VoiceWorkItemTarget target,
}) async {
  final session = controller.session;
  if (session == null || !session.hasBusiness) return false;
  WorkItem item;
  try {
    item = await controller.apiClient.workItems.get(
      type: target.type,
      businessId: session.businessId!,
      itemId: target.id,
      firebaseUid: session.firebaseUid,
      mockPhoneNumber: session.mockPhoneNumber,
    );
  } catch (error) {
    if (context.mounted) {
      final message = error is ApiException && error.statusCode == 404
          ? 'הפריט כבר לא זמין או נמחק.'
          : 'לא הצלחנו לפתוח את הפריט. נסה שוב בעוד רגע.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
    return false;
  }
  if (!context.mounted) return false;
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => WorkItemFormScreen(
        controller: controller,
        kind: target.kind,
        existingItem: item,
        initialPayload: {
          ...action.payload,
          if (target.proposedStatus != null) 'status': target.proposedStatus,
        },
        aiPendingActionId: action.aiPendingActionId,
        pendingActionType: action.actionType,
      ),
    ),
  );
}

Future<bool> openLinkedEntity({
  required BuildContext context,
  required SessionController controller,
  required String? type,
  required String? id,
  Customer? customer,
  String? title,
}) async {
  if (type == null || id == null || id.isEmpty) return false;

  final normalizedType = type.toLowerCase();
  if (normalizedType == 'customer') {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            CustomerDetailScreen(controller: controller, customerId: id),
      ),
    );
    return true;
  }

  final target = switch (normalizedType) {
    'reminder' => (WorkItemKind.reminder, CrmWorkItemType.reminder),
    'home_visit' => (WorkItemKind.homeVisit, CrmWorkItemType.homeVisit),
    'appointment' => (WorkItemKind.appointment, CrmWorkItemType.appointment),
    'quote' => (WorkItemKind.quote, CrmWorkItemType.quote),
    'note' => (WorkItemKind.note, CrmWorkItemType.note),
    _ => null,
  };
  if (target == null) return false;

  final session = controller.session;
  if (session == null || !session.hasBusiness) return false;

  WorkItem item;
  try {
    item = await controller.apiClient.workItems.get(
      type: target.$2,
      businessId: session.businessId!,
      itemId: id,
      firebaseUid: session.firebaseUid,
      mockPhoneNumber: session.mockPhoneNumber,
    );
  } catch (error) {
    if (context.mounted) {
      final message = error is ApiException && error.statusCode == 404
          ? 'הפריט כבר לא זמין או נמחק.'
          : 'לא הצלחנו לפתוח את הפריט. נסה שוב בעוד רגע.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
    return false;
  }
  if (!context.mounted) return false;

  await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => WorkItemFormScreen(
        controller: controller,
        kind: target.$1,
        initialCustomer: item.customer ?? customer,
        existingItem: item,
      ),
    ),
  );
  return true;
}
