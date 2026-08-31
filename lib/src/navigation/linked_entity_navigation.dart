import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../data/repositories/work_item_repository.dart';
import '../features/auth/session_controller.dart';
import '../features/customers/customer_detail_screen.dart';
import '../features/work_items/work_item_form_screen.dart';
import '../models/customer.dart';
import '../models/work_item.dart';

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
