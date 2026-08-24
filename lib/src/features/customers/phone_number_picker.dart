import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import '../../api/api_client.dart';
import '../../models/session.dart';
import '../../utils/date_formatting.dart';
import '../../utils/json_read.dart';
import '../auth/session_controller.dart';

Future<String?> pickPhoneFromBusinessCalls({
  required BuildContext context,
  required SessionController controller,
}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => _BusinessCallsPhoneSheet(controller: controller),
  );
}

Future<String?> pickPhoneFromDeviceContacts(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final status = await FlutterContacts.permissions.request(PermissionType.read);
  if (status != PermissionStatus.granted &&
      status != PermissionStatus.limited) {
    if (context.mounted) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('צריך לאשר גישה לאנשי קשר כדי לבחור מספר'),
        ),
      );
    }
    return null;
  }

  final contact = await FlutterContacts.native.showPicker(
    properties: {ContactProperty.phone},
  );
  if (contact == null || contact.phones.isEmpty) return null;
  if (contact.phones.length == 1) return contact.phones.first.number;
  if (!context.mounted) return null;

  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              contact.displayName ?? 'איש קשר',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ...contact.phones.map(
            (phone) => ListTile(
              leading: const Icon(Icons.phone_outlined),
              title: Text(phone.number),
              onTap: () => Navigator.of(context).pop(phone.number),
            ),
          ),
        ],
      ),
    ),
  );
}

class PhoneSourceButtons extends StatelessWidget {
  const PhoneSourceButtons({
    super.key,
    required this.onBusinessCalls,
    required this.onContacts,
  });

  final VoidCallback onBusinessCalls;
  final VoidCallback onContacts;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: onBusinessCalls,
          icon: const Icon(Icons.history),
          label: const Text('משיחות'),
        ),
        OutlinedButton.icon(
          onPressed: onContacts,
          icon: const Icon(Icons.contacts_outlined),
          label: const Text('מאנשי קשר'),
        ),
      ],
    );
  }
}

class PhoneSourceIconButtons extends StatelessWidget {
  const PhoneSourceIconButtons({
    super.key,
    required this.onBusinessCalls,
    required this.onContacts,
  });

  final VoidCallback onBusinessCalls;
  final VoidCallback onContacts;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'בחר משיחות',
          onPressed: onBusinessCalls,
          icon: const Icon(Icons.history),
        ),
        IconButton(
          tooltip: 'בחר מאנשי קשר',
          onPressed: onContacts,
          icon: const Icon(Icons.contacts_outlined),
        ),
      ],
    );
  }
}

class _BusinessCallsPhoneSheet extends StatelessWidget {
  const _BusinessCallsPhoneSheet({required this.controller});

  final SessionController controller;

  @override
  Widget build(BuildContext context) {
    final session = controller.session!;
    return SafeArea(
      child: FutureBuilder<List<_CallPhoneOption>>(
        future: _loadCallPhones(session),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 180,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            final message = snapshot.error is ApiException
                ? (snapshot.error as ApiException).message
                : 'לא הצלחנו לטעון שיחות';
            return _SheetMessage(icon: Icons.cloud_off_outlined, text: message);
          }

          final calls = snapshot.data ?? const [];
          if (calls.isEmpty) {
            return const _SheetMessage(
              icon: Icons.call_outlined,
              text: 'אין שיחות עם מספרים לבחירה',
            );
          }

          return ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  'בחירה משיחות אחרונות במערכת',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ...calls.map(
                (call) => ListTile(
                  leading: const Icon(Icons.phone_callback_outlined),
                  title: Text(call.phone),
                  subtitle: Text(
                    [
                      if (call.customerName != null) call.customerName!,
                      if (call.calledAt != null) formatDateTime(call.calledAt),
                    ].join(' · '),
                  ),
                  onTap: () => Navigator.of(context).pop(call.phone),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<List<_CallPhoneOption>> _loadCallPhones(AppSession session) async {
    final json = await controller.apiClient.listCalls(
      businessId: session.businessId!,
      firebaseUid: session.firebaseUid,
      mockPhoneNumber: session.mockPhoneNumber,
    );
    final seen = <String>{};
    final options = <_CallPhoneOption>[];
    for (final call in mapListValue(json['calls'])) {
      final phone = nullableString(call['fromNumber']);
      if (phone == null || !seen.add(phone)) continue;
      options.add(
        _CallPhoneOption(
          phone: phone,
          customerName: nullableString(mapValue(call['customer'])['name']),
          calledAt: dateValue(call['calledAt'] ?? call['createdAt']),
        ),
      );
    }
    return options;
  }
}

class _CallPhoneOption {
  const _CallPhoneOption({
    required this.phone,
    this.customerName,
    this.calledAt,
  });

  final String phone;
  final String? customerName;
  final DateTime? calledAt;
}

class _SheetMessage extends StatelessWidget {
  const _SheetMessage({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32),
            const SizedBox(height: 8),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
