import 'package:flutter/material.dart';

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

  final kind = switch (normalizedType) {
    'reminder' => WorkItemKind.reminder,
    'home_visit' => WorkItemKind.homeVisit,
    'appointment' => WorkItemKind.appointment,
    'quote' => WorkItemKind.quote,
    'note' => WorkItemKind.note,
    _ => null,
  };
  if (kind == null) return false;

  await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => WorkItemFormScreen(
        controller: controller,
        kind: kind,
        initialCustomer: customer,
        existingItem: WorkItem(
          id: id,
          type: WorkItemTypeApi.parse(normalizedType),
          title: title ?? 'פריט לטיפול',
          customer: customer,
        ),
      ),
    ),
  );
  return true;
}
