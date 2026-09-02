import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../features/auth/session_controller.dart';
import '../features/v2/v2_customers_screen.dart';
import '../features/v2/v2_activity_detail_screen.dart';
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

  if (normalizedType == 'job' || normalizedType == 'visit') {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => V2ActivityDetailScreen(
          controller: controller,
          kind: normalizedType == 'visit'
              ? V2ActivityKind.visit
              : V2ActivityKind.job,
          activityId: id,
        ),
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
      _ => null,
    };
    if (details == null || !context.mounted) return false;
    if (details is V2Task) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => V2TaskForm(controller: controller, task: details),
      );
      return true;
    }
    final (entityTitle, description, date) = switch (details) {
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
