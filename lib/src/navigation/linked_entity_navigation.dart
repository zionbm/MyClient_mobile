import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../features/auth/session_controller.dart';
import '../features/v2/v2_customers_screen.dart';
import '../models/v2_activity.dart';
import '../models/v2_task.dart';
import '../utils/date_formatting.dart';

Future<bool> openLinkedEntity({
  required BuildContext context,
  required SessionController controller,
  required String? type,
  required String? id,
  Object? customer,
  String? title,
}) async {
  final session = controller.session;
  if (session == null ||
      !session.hasBusiness ||
      type == null ||
      id == null ||
      id.isEmpty) {
    return false;
  }
  final normalizedType = type.toLowerCase();
  if (normalizedType == 'customer') {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            V2CustomerDetailScreen(controller: controller, customerId: id),
      ),
    );
    return true;
  }

  try {
    final Object? details = switch (normalizedType) {
      'task' => await controller.apiClient.v2Tasks.get(
        businessId: session.businessId!,
        taskId: id,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
      ),
      'job' => await controller.apiClient.v2Activities.get(
        kind: V2ActivityKind.job,
        businessId: session.businessId!,
        entityId: id,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
      ),
      'visit' => await controller.apiClient.v2Activities.get(
        kind: V2ActivityKind.visit,
        businessId: session.businessId!,
        entityId: id,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
      ),
      _ => null,
    };
    if (details == null || !context.mounted) return false;
    final (entityTitle, description, date) = switch (details) {
      V2Task item => (item.title, item.description, item.dueAt),
      V2Activity item => (item.title, item.description, item.startsAt),
      _ => ('פריט', null, null),
    };
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(entityTitle),
        content: Text(
          [?description, if (date != null) formatDateTime(date)].join('\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('סגור'),
          ),
        ],
      ),
    );
    return true;
  } on ApiException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
    return false;
  }
}
