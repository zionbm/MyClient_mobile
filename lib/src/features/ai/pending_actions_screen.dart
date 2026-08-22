import 'dart:convert';

import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../utils/date_formatting.dart';
import '../../utils/json_read.dart';
import '../auth/session_controller.dart';

class PendingActionsScreen extends StatefulWidget {
  const PendingActionsScreen({super.key, required this.controller});

  final SessionController controller;

  @override
  State<PendingActionsScreen> createState() => _PendingActionsScreenState();
}

class _PendingActionsScreenState extends State<PendingActionsScreen> {
  Future<List<_PendingAction>>? _future;
  String _status = 'PENDING';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('פעולות AI')),
      body: RefreshIndicator(
        onRefresh: () async => _load(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'PENDING', label: Text('ממתינות')),
                ButtonSegment(value: 'EXECUTED', label: Text('בוצעו')),
                ButtonSegment(value: 'REJECTED', label: Text('נדחו')),
              ],
              selected: {_status},
              onSelectionChanged: (value) {
                setState(() => _status = value.first);
                _load();
              },
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<_PendingAction>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return _InfoCard(
                    icon: Icons.cloud_off_outlined,
                    title: 'לא הצלחנו לטעון פעולות',
                    body: _messageFor(snapshot.error),
                  );
                }
                final items = snapshot.data ?? const <_PendingAction>[];
                if (items.isEmpty) {
                  return const _InfoCard(
                    icon: Icons.auto_awesome_outlined,
                    title: 'אין פעולות שממתינות לאישור',
                    body: 'כאשר פקודה קולית תדרוש אישור, היא תופיע כאן.',
                  );
                }
                return Column(
                  children: items
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _PendingActionCard(
                            item: item,
                            onEdit: item.status == 'PENDING'
                                ? () => _edit(item)
                                : null,
                            onApprove: item.status == 'PENDING'
                                ? () => _approve(item)
                                : null,
                            onReject: item.status == 'PENDING'
                                ? () => _reject(item)
                                : null,
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _load() {
    final session = widget.controller.session!;
    setState(() {
      _future = widget.controller.apiClient
          .listAiPendingActions(
            businessId: session.businessId!,
            firebaseUid: session.firebaseUid,
            mockPhoneNumber: session.mockPhoneNumber,
            status: _status,
          )
          .then(
            (json) => mapListValue(
              json['pendingActions'],
            ).map(_PendingAction.fromJson).toList(),
          );
    });
  }

  Future<void> _edit(_PendingAction item) async {
    final controller = TextEditingController(
      text: const JsonEncoder.withIndent('  ').convert(item.payload),
    );
    final edited = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('עריכת פעולה'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: controller,
            minLines: 8,
            maxLines: 16,
            decoration: const InputDecoration(labelText: 'Payload JSON'),
            textDirection: TextDirection.ltr,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ביטול'),
          ),
          FilledButton(
            onPressed: () {
              try {
                final decoded = jsonDecode(controller.text);
                if (decoded is Map<String, Object?>) {
                  Navigator.of(context).pop(decoded);
                }
              } catch (_) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('JSON לא תקין')));
              }
            },
            child: const Text('שמור'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (edited == null) return;

    final session = widget.controller.session!;
    try {
      await widget.controller.apiClient.updateAiPendingAction(
        businessId: session.businessId!,
        pendingActionId: item.id,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        body: {'payload': edited},
      );
      widget.controller.markDataChanged();
      _load();
    } on ApiException catch (error) {
      _showError(error.message);
    }
  }

  Future<void> _approve(_PendingAction item) async {
    final session = widget.controller.session!;
    try {
      await widget.controller.apiClient.approveAiPendingAction(
        businessId: session.businessId!,
        pendingActionId: item.id,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
      );
      widget.controller.markDataChanged();
      _load();
    } on ApiException catch (error) {
      _showError(error.message);
    }
  }

  Future<void> _reject(_PendingAction item) async {
    final session = widget.controller.session!;
    try {
      await widget.controller.apiClient.rejectAiPendingAction(
        businessId: session.businessId!,
        pendingActionId: item.id,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
      );
      widget.controller.markDataChanged();
      _load();
    } on ApiException catch (error) {
      _showError(error.message);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _messageFor(Object? error) {
    if (error is ApiException) return error.message;
    return 'בדוק שהשרת המקומי זמין.';
  }
}

class _PendingActionCard extends StatelessWidget {
  const _PendingActionCard({
    required this.item,
    required this.onEdit,
    required this.onApprove,
    required this.onReject,
  });

  final _PendingAction item;
  final VoidCallback? onEdit;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Icon(Icons.auto_awesome)),
              title: Text(item.actionType),
              subtitle: Text(
                [
                  item.status,
                  if (item.reviewReason != null) item.reviewReason!,
                  if (item.createdAt != null) formatDateTime(item.createdAt),
                ].join(' · '),
              ),
            ),
            if (item.missingFields.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('חסר: ${item.missingFields.join(', ')}'),
              ),
            Text(
              const JsonEncoder.withIndent('  ').convert(item.payload),
              textDirection: TextDirection.ltr,
              maxLines: 8,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (onEdit != null || onApprove != null || onReject != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 8,
                  children: [
                    if (onEdit != null)
                      TextButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('ערוך'),
                      ),
                    if (onApprove != null)
                      FilledButton.icon(
                        onPressed: onApprove,
                        icon: const Icon(Icons.check),
                        label: const Text('אשר'),
                      ),
                    if (onReject != null)
                      TextButton.icon(
                        onPressed: onReject,
                        icon: const Icon(Icons.close),
                        label: const Text('דחה'),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PendingAction {
  const _PendingAction({
    required this.id,
    required this.actionType,
    required this.status,
    required this.payload,
    required this.missingFields,
    this.reviewReason,
    this.createdAt,
  });

  final String id;
  final String actionType;
  final String status;
  final Map<String, Object?> payload;
  final List<String> missingFields;
  final String? reviewReason;
  final DateTime? createdAt;

  factory _PendingAction.fromJson(Map<String, Object?> json) {
    return _PendingAction(
      id: stringValue(json['id']),
      actionType: stringValue(json['actionType'], fallback: 'פעולה'),
      status: stringValue(json['status'], fallback: 'PENDING'),
      payload: mapValue(json['payload']),
      missingFields:
          (json['missingFields'] as List?)?.whereType<String>().toList() ??
          const <String>[],
      reviewReason: nullableString(json['reviewReason']),
      createdAt: dateValue(json['createdAt']),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
