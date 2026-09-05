import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../features/auth/session_controller.dart';
import '../features/crm/tasks/task_form.dart';
import '../features/crm/customers_screen.dart';
import '../features/crm/activity_detail_screen.dart';
import '../models/activity.dart';
import '../models/task.dart';
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
            CustomerDetailScreen(controller: controller, customerId: id),
      ),
    );
    return true;
  }

  if (normalizedType == 'job' || normalizedType == 'visit') {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActivityDetailScreen(
          controller: controller,
          kind: normalizedType == 'visit'
              ? ActivityKind.visit
              : ActivityKind.job,
          activityId: id,
        ),
      ),
    );
    return true;
  }

  try {
    final Object? details = switch (normalizedType) {
      'task' => await controller.apiClient.tasks.get(
        businessId: session.businessId!,
        taskId: id,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
      ),
      _ => null,
    };
    if (details == null || !context.mounted) return false;
    if (details is Task) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => TaskForm(controller: controller, task: details),
      );
      return true;
    }
    final (entityTitle, description, date) = switch (details) {
      Activity item => (item.title, item.description, item.startsAt),
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
