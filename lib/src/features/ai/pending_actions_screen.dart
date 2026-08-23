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
    final edited = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (context) => _PayloadFieldEditorDialog(
        actionType: item.actionType,
        payload: item.payload,
        missingFields: item.missingFields,
      ),
    );
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

class _PayloadFieldEditorDialog extends StatefulWidget {
  const _PayloadFieldEditorDialog({
    required this.actionType,
    required this.payload,
    required this.missingFields,
  });

  final String actionType;
  final Map<String, Object?> payload;
  final List<String> missingFields;

  @override
  State<_PayloadFieldEditorDialog> createState() =>
      _PayloadFieldEditorDialogState();
}

class _PayloadFieldEditorDialogState extends State<_PayloadFieldEditorDialog> {
  late final Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    final keys = <String>{
      ..._defaultFieldsFor(widget.actionType),
      ...widget.payload.keys,
      ...widget.missingFields,
    }.toList();
    _controllers = {
      for (final key in keys)
        key: TextEditingController(text: _displayValue(widget.payload[key])),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('עריכת ${widget.actionType}'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _controllers.entries
                .map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      controller: entry.value,
                      minLines: _isLongField(entry.key) ? 2 : 1,
                      maxLines: _isLongField(entry.key) ? 5 : 1,
                      decoration: InputDecoration(
                        labelText: _labelForField(entry.key),
                        helperText: widget.missingFields.contains(entry.key)
                            ? 'שדה חסר'
                            : null,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ביטול'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_payload()),
          child: const Text('שמור'),
        ),
      ],
    );
  }

  Map<String, Object?> _payload() {
    final next = Map<String, Object?>.from(widget.payload);
    for (final entry in _controllers.entries) {
      final value = entry.value.text.trim();
      if (value.isEmpty) {
        next.remove(entry.key);
      } else {
        next[entry.key] = _parseValue(value);
      }
    }
    return next;
  }

  Object? _parseValue(String value) {
    if (value == 'true') return true;
    if (value == 'false') return false;
    return num.tryParse(value) ?? value;
  }

  String _displayValue(Object? value) {
    if (value == null) return '';
    if (value is String || value is num || value is bool) return '$value';
    return jsonEncode(value);
  }

  bool _isLongField(String key) {
    return key.toLowerCase().contains('description') ||
        key.toLowerCase().contains('notes') ||
        key.toLowerCase().contains('text');
  }

  List<String> _defaultFieldsFor(String actionType) {
    return switch (actionType) {
      'CREATE_CUSTOMER' => ['name', 'phone', 'address'],
      'CREATE_TASK' || 'CREATE_CALLBACK' => [
        'title',
        'name',
        'customerId',
        'dueAt',
        'priority',
        'description',
      ],
      'CREATE_APPOINTMENT' || 'CREATE_HOME_VISIT' => [
        'title',
        'name',
        'customerId',
        'startsAt',
        'endsAt',
        'location',
        'description',
      ],
      'CREATE_QUOTE' => [
        'title',
        'name',
        'customerId',
        'dueAt',
        'estimatedAmount',
        'description',
      ],
      'ADD_CUSTOMER_NOTE' => ['customerId', 'name', 'text'],
      _ => widget.payload.keys.toList(),
    };
  }

  String _labelForField(String key) {
    return switch (key) {
      'name' => 'שם',
      'phone' => 'טלפון',
      'address' => 'כתובת',
      'title' => 'כותרת',
      'customerId' => 'לקוח',
      'dueAt' => 'תאריך יעד',
      'startsAt' => 'התחלה',
      'endsAt' => 'סיום',
      'priority' => 'דחיפות',
      'description' => 'תיאור',
      'location' => 'מיקום',
      'estimatedAmount' => 'סכום משוער',
      'text' => 'טקסט',
      _ => key,
    };
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
              title: Text(_actionTitle(item.actionType)),
              subtitle: Text(
                [
                  _statusLabel(item.status),
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
            _PayloadSummary(item: item),
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

  String _actionTitle(String actionType) {
    return switch (actionType) {
      'CREATE_CUSTOMER' => 'יצירת לקוח',
      'CREATE_TASK' || 'CREATE_CALLBACK' => 'יצירת תזכורת',
      'CREATE_APPOINTMENT' || 'CREATE_HOME_VISIT' => 'יצירת ביקור',
      'CREATE_QUOTE' => 'יצירת הצעת מחיר',
      'ADD_CUSTOMER_NOTE' => 'הוספת הערת לקוח',
      _ => 'פעולת AI',
    };
  }

  String _statusLabel(String status) {
    return switch (status) {
      'PENDING' => 'ממתינה לאישור',
      'EXECUTED' => 'בוצעה',
      'REJECTED' => 'נדחתה',
      'FAILED' => 'נכשלה',
      _ => status,
    };
  }
}

class _PayloadSummary extends StatelessWidget {
  const _PayloadSummary({required this.item});

  final _PendingAction item;

  @override
  Widget build(BuildContext context) {
    final rows = _summaryRows();
    if (rows.isEmpty) {
      return const Text('אין פרטים נוספים להצגה.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows
          .map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(row),
            ),
          )
          .toList(),
    );
  }

  List<String> _summaryRows() {
    final payload = item.payload;
    final rows = <String>[];
    void add(String label, Object? value) {
      final text = _displayValue(value);
      if (text != null) rows.add('$label: $text');
    }

    switch (item.actionType) {
      case 'CREATE_CUSTOMER':
        add('שם', payload['name']);
        add('טלפון', payload['phone']);
        add('כתובת', payload['address']);
        break;
      case 'CREATE_TASK':
      case 'CREATE_CALLBACK':
        add('כותרת', payload['title']);
        add(
          'לקוח',
          payload['name'] ?? payload['customerName'] ?? payload['customerId'],
        );
        add('מועד', payload['dueAt']);
        add('דחיפות', payload['priority']);
        add('הערות', payload['description']);
        break;
      case 'CREATE_APPOINTMENT':
      case 'CREATE_HOME_VISIT':
        add('כותרת', payload['title']);
        add(
          'לקוח',
          payload['name'] ?? payload['customerName'] ?? payload['customerId'],
        );
        add('התחלה', payload['startsAt']);
        add('סיום', payload['endsAt']);
        add('מיקום', payload['location']);
        add('הערות', payload['description'] ?? payload['notes']);
        break;
      case 'CREATE_QUOTE':
        add('כותרת', payload['title']);
        add(
          'לקוח',
          payload['name'] ?? payload['customerName'] ?? payload['customerId'],
        );
        add('תאריך יעד', payload['dueAt']);
        add('סכום משוער', payload['estimatedAmount']);
        add('תיאור', payload['description']);
        break;
      case 'ADD_CUSTOMER_NOTE':
        add(
          'לקוח',
          payload['name'] ?? payload['customerName'] ?? payload['customerId'],
        );
        add('הערה', payload['text']);
        break;
      default:
        for (final entry in payload.entries.take(6)) {
          add(entry.key, entry.value);
        }
        break;
    }
    return rows;
  }

  String? _displayValue(Object? value) {
    if (value == null) return null;
    if (value is String) return value.trim().isEmpty ? null : value.trim();
    if (value is num || value is bool) return '$value';
    return null;
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
