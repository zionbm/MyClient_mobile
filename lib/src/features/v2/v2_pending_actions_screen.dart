import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../core/network/idempotency_key.dart';
import '../../core/state/data_invalidator.dart';
import '../../utils/json_read.dart';
import '../auth/session_controller.dart';

class V2PendingActionsScreen extends StatefulWidget {
  const V2PendingActionsScreen({super.key, required this.controller});
  final SessionController controller;

  @override
  State<V2PendingActionsScreen> createState() => _V2PendingActionsScreenState();
}

class _V2PendingActionsScreenState extends State<V2PendingActionsScreen> {
  Future<Map<String, Object?>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('פעולות שמחכות להשלמה')),
    body: FutureBuilder<Map<String, Object?>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('לא הצלחנו לטעון את הפעולות'));
        }
        final actions = mapListValue(snapshot.data?['actions']);
        if (actions.isEmpty) {
          return const Center(child: Text('אין פעולות שמחכות להשלמה'));
        }
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: actions.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, index) => _PendingCard(
              action: actions[index],
              onResolve: (selectedId, payload, confirmed) =>
                  _resolve(actions[index], selectedId, payload, confirmed),
              onReject: () => _reject(actions[index]),
            ),
          ),
        );
      },
    ),
  );

  Future<void> _load() async {
    final session = widget.controller.session!;
    setState(() {
      _future = widget.controller.apiClient.v2Assistant.listPending(
        businessId: session.businessId!,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
      );
    });
    await _future;
  }

  Future<void> _resolve(
    Map<String, Object?> action,
    String? selectedId,
    Map<String, Object?> payload,
    bool confirmed,
  ) async {
    final session = widget.controller.session!;
    try {
      if (confirmed) {
        final accepted = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('אישור הפעולה'),
            content: Text(
              stringValue(
                action['question'],
                fallback: 'הפעולה דורשת אישור מפורש. להמשיך?',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('חזרה'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('אישור וביצוע'),
              ),
            ],
          ),
        );
        if (accepted != true) return;
      }
      await widget.controller.apiClient.v2Assistant.resolvePending(
        businessId: session.businessId!,
        pendingActionId: stringValue(action['id']),
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        selectedEntityId: selectedId,
        payload: payload,
        confirmed: confirmed,
        idempotencyKey: IdempotencyKey.create('pending_resolve'),
      );
      widget.controller.markDataChanged({DataScope.crm, DataScope.ai});
      await _load();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _reject(Map<String, Object?> action) async {
    final session = widget.controller.session!;
    await widget.controller.apiClient.v2Assistant.rejectPending(
      businessId: session.businessId!,
      pendingActionId: stringValue(action['id']),
      firebaseUid: session.firebaseUid,
      mockPhoneNumber: session.mockPhoneNumber,
      idempotencyKey: IdempotencyKey.create('pending_reject'),
    );
    widget.controller.markDataChanged({DataScope.ai});
    await _load();
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({
    required this.action,
    required this.onResolve,
    required this.onReject,
  });
  final Map<String, Object?> action;
  final void Function(
    String? selectedId,
    Map<String, Object?> payload,
    bool confirmed,
  )
  onResolve;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final candidates = mapListValue(action['candidateEntities']);
    final missingFields = (action['missingFields'] as List? ?? const [])
        .whereType<String>()
        .toList(growable: false);
    final confirmation = action['requiresExplicitConfirmation'] == true;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              stringValue(action['question'], fallback: 'נדרש מידע נוסף'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            if (candidates.isNotEmpty)
              ...candidates.map(
                (candidate) => ListTile(
                  title: Text(
                    stringValue(
                      candidate['name'],
                      fallback: stringValue(
                        candidate['title'],
                        fallback: 'אפשרות',
                      ),
                    ),
                  ),
                  trailing: confirmation
                      ? const Icon(Icons.verified_user_outlined)
                      : null,
                  onTap: () {
                    final payload = mapValue(candidate['payload']);
                    final selectedId = payload.isEmpty
                        ? stringValue(candidate['id'])
                        : null;
                    if (missingFields.isEmpty) {
                      onResolve(selectedId, payload, confirmation);
                    } else {
                      _editPayload(
                        context,
                        selectedId: selectedId,
                        initialPayload: payload,
                        missingFields: missingFields,
                        confirmation: confirmation,
                      );
                    }
                  },
                ),
              )
            else
              FilledButton(
                onPressed: () => missingFields.isEmpty && confirmation
                    ? onResolve(null, const {}, true)
                    : _editPayload(
                        context,
                        missingFields: missingFields,
                        confirmation: confirmation,
                      ),
                child: Text(
                  missingFields.isEmpty && confirmation
                      ? 'אישור וביצוע'
                      : 'השלמת פרטים',
                ),
              ),
            TextButton(onPressed: onReject, child: const Text('דחיית הפעולה')),
          ],
        ),
      ),
    );
  }

  Future<void> _editPayload(
    BuildContext context, {
    String? selectedId,
    Map<String, Object?> initialPayload = const {},
    required List<String> missingFields,
    required bool confirmation,
  }) async {
    final payload = await showModalBottomSheet<Map<String, Object?>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PendingPayloadForm(
        missingFields: missingFields,
        initialPayload: initialPayload,
      ),
    );
    if (payload != null) onResolve(selectedId, payload, confirmation);
  }
}

class _PendingPayloadForm extends StatefulWidget {
  const _PendingPayloadForm({
    required this.missingFields,
    required this.initialPayload,
  });

  final List<String> missingFields;
  final Map<String, Object?> initialPayload;

  @override
  State<_PendingPayloadForm> createState() => _PendingPayloadFormState();
}

class _PendingPayloadFormState extends State<_PendingPayloadForm> {
  late final Map<String, TextEditingController> _controllers;
  String? _error;

  @override
  void initState() {
    super.initState();
    final fields = _expandedFields(widget.missingFields);
    _controllers = {
      for (final field in fields)
        field: TextEditingController(
          text: widget.initialPayload[field]?.toString() ?? '',
        ),
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
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('השלמת פרטים', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text('אפשר להשלים או לתקן את הנתונים לפני ביצוע הפעולה.'),
          const SizedBox(height: 16),
          ..._controllers.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: entry.value,
                keyboardType: _numericFields.contains(entry.key)
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : TextInputType.text,
                decoration: InputDecoration(
                  labelText: _fieldLabel(entry.key),
                  helperText: _fieldHint(entry.key),
                ),
              ),
            ),
          ),
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
          ],
          FilledButton(onPressed: _submit, child: const Text('שמירה והמשך')),
        ],
      ),
    ),
  );

  void _submit() {
    final payload = <String, Object?>{...widget.initialPayload};
    for (final entry in _controllers.entries) {
      final value = entry.value.text.trim();
      if (value.isEmpty) continue;
      if (_numericFields.contains(entry.key)) {
        final number = double.tryParse(value);
        if (number == null || number < 0) {
          setState(
            () => _error = 'יש להזין מספר תקין בשדה ${_fieldLabel(entry.key)}',
          );
          return;
        }
        payload[entry.key] = number;
      } else if (entry.key == 'noCharge') {
        payload[entry.key] = ['כן', 'true', '1'].contains(value.toLowerCase());
      } else if (_dateFields.contains(entry.key)) {
        final date = DateTime.tryParse(value);
        if (date == null) {
          setState(() => _error = 'יש להזין תאריך ושעה תקינים');
          return;
        }
        payload[entry.key] = date.toUtc().toIso8601String();
      } else {
        payload[entry.key] = value;
      }
    }
    if (payload.isEmpty) {
      setState(() => _error = 'צריך להשלים לפחות שדה אחד');
      return;
    }
    Navigator.pop(context, payload);
  }
}

const _numericFields = {'amount', 'totalAmount', 'paidAmount'};
const _dateFields = {'startsAt', 'endsAt', 'dueAt'};

List<String> _expandedFields(List<String> fields) {
  if (fields.isEmpty) return const ['answer'];
  final result = <String>[];
  for (final field in fields) {
    if (field == 'schedule') {
      result.addAll(const ['startsAt', 'endsAt']);
    } else if (field == 'totalAmountOrPaidAmount') {
      result.addAll(const ['totalAmount', 'paidAmount']);
    } else if (field == 'noChargeOrAmount') {
      result.addAll(const ['noCharge', 'totalAmount']);
    } else {
      result.add(field);
    }
  }
  return result.toSet().toList(growable: false);
}

String _fieldLabel(String field) => switch (field) {
  'answer' => 'תשובה',
  'customerId' => 'מזהה לקוח',
  'taskId' => 'מזהה משימה',
  'entityId' => 'מזהה עבודה או ביקור',
  'phone' => 'מספר טלפון',
  'addressText' => 'כתובת שירות',
  'title' => 'כותרת',
  'description' => 'תיאור',
  'startsAt' => 'התחלה',
  'endsAt' => 'סיום',
  'dueAt' => 'מועד תזכורת',
  'amount' => 'סכום',
  'totalAmount' => 'סכום כולל',
  'paidAmount' => 'סכום ששולם',
  'noCharge' => 'ללא חיוב? כן / לא',
  _ => field,
};

String? _fieldHint(String field) => switch (field) {
  'startsAt' || 'endsAt' || 'dueAt' => 'לדוגמה: 2026-09-01 10:00',
  'noCharge' => 'יש לכתוב כן אם לא היה חיוב',
  _ => null,
};
