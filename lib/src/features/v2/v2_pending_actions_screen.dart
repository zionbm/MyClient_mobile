import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../core/network/idempotency_key.dart';
import '../../core/state/data_invalidator.dart';
import '../../utils/json_read.dart';
import '../../models/v2_activity.dart';
import '../../theme/app_theme.dart';
import '../auth/session_controller.dart';

class V2PendingActionsScreen extends StatelessWidget {
  const V2PendingActionsScreen({super.key, required this.controller});
  final SessionController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('מחכה להשלמה')),
    body: V2PendingActionsPanel(controller: controller),
  );
}

class V2PendingActionsPanel extends StatefulWidget {
  const V2PendingActionsPanel({
    super.key,
    required this.controller,
    this.compact = false,
    this.onChanged,
    this.onOpenAll,
    this.showHeader = true,
    this.status = 'PENDING',
    this.actionBatchId,
  });

  final SessionController controller;
  final bool compact;
  final VoidCallback? onChanged;
  final VoidCallback? onOpenAll;
  final bool showHeader;
  final String status;
  final String? actionBatchId;

  @override
  State<V2PendingActionsPanel> createState() => _V2PendingActionsPanelState();
}

class _V2PendingActionsPanelState extends State<V2PendingActionsPanel> {
  Future<Map<String, Object?>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, Object?>>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return widget.compact
            ? const LinearProgressIndicator()
            : const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: TextButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('לא הצלחנו לטעון. נסה שוב'),
          ),
        );
      }
      final actions = mapListValue(snapshot.data?['actions']);
      if (actions.isEmpty) {
        return widget.compact
            ? const SizedBox.shrink()
            : const Center(child: Text('אין פעולות שמחכות להשלמה'));
      }
      final visible = actions;
      final list = ListView.separated(
        shrinkWrap: widget.compact,
        physics: widget.compact
            ? const NeverScrollableScrollPhysics()
            : const AlwaysScrollableScrollPhysics(),
        padding: widget.compact ? EdgeInsets.zero : const EdgeInsets.all(16),
        itemCount: visible.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, index) => _PendingCard(
          controller: widget.controller,
          action: visible[index],
          onResolve: (selectedId, payload, confirmed) =>
              _resolve(visible[index], selectedId, payload, confirmed),
          onReject: () => _reject(visible[index]),
        ),
      );
      if (widget.compact) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.showHeader) ...[
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'מחכה לתשובה שלך',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (widget.onOpenAll != null)
                    TextButton(
                      onPressed: widget.onOpenAll,
                      child: const Text('כל הפעולות'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            list,
          ],
        );
      }
      return RefreshIndicator(onRefresh: _load, child: list);
    },
  );

  Future<void> _load() async {
    final session = widget.controller.session!;
    setState(() {
      _future = widget.controller.apiClient.v2Assistant.listPending(
        businessId: session.businessId!,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        status: widget.status,
        actionBatchId: widget.actionBatchId,
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
      widget.onChanged?.call();
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
    widget.onChanged?.call();
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({
    required this.controller,
    required this.action,
    required this.onResolve,
    required this.onReject,
  });
  final SessionController controller;
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
    final status = stringValue(action['status'], fallback: 'PENDING');
    final resolved = status != 'PENDING';
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
            if (resolved) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    status == 'COMPLETED'
                        ? Icons.check_circle_outline
                        : Icons.cancel_outlined,
                    size: 20,
                    color: status == 'COMPLETED'
                        ? AppColors.success
                        : AppColors.muted,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    status == 'COMPLETED' ? 'הפעולה הושלמה' : 'הפעולה נדחתה',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ] else ...[
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
              TextButton(
                onPressed: onReject,
                child: const Text('דחיית הפעולה'),
              ),
            ],
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
        controller: controller,
        missingFields: missingFields,
        initialPayload: initialPayload,
      ),
    );
    if (payload != null) onResolve(selectedId, payload, confirmation);
  }
}

class _PendingPayloadForm extends StatefulWidget {
  const _PendingPayloadForm({
    required this.controller,
    required this.missingFields,
    required this.initialPayload,
  });

  final SessionController controller;
  final List<String> missingFields;
  final Map<String, Object?> initialPayload;

  @override
  State<_PendingPayloadForm> createState() => _PendingPayloadFormState();
}

class _PendingPayloadFormState extends State<_PendingPayloadForm> {
  late final Map<String, TextEditingController> _controllers;
  late final Future<Map<String, List<_EntityChoice>>> _choices;
  final Map<String, String?> _selectedEntities = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    final fields = _expandedFields(widget.missingFields);
    _controllers = {
      for (final field in fields.where(
        (field) => !_entityFields.contains(field),
      ))
        field: TextEditingController(
          text: widget.initialPayload[field]?.toString() ?? '',
        ),
    };
    for (final field in fields.where(_entityFields.contains)) {
      _selectedEntities[field] = widget.initialPayload[field] as String?;
    }
    _choices = _loadChoices(fields);
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
          FutureBuilder<Map<String, List<_EntityChoice>>>(
            future: _choices,
            builder: (context, snapshot) => Column(
              children: [
                ..._selectedEntities.keys.map((field) {
                  final choices = snapshot.data?[field] ?? const [];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DropdownButtonFormField<String>(
                      initialValue:
                          choices.any(
                            (choice) => choice.id == _selectedEntities[field],
                          )
                          ? _selectedEntities[field]
                          : null,
                      decoration: InputDecoration(
                        labelText: _fieldLabel(field),
                      ),
                      items: choices
                          .map(
                            (choice) => DropdownMenuItem(
                              value: choice.id,
                              child: Text(choice.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _selectedEntities[field] = value),
                    ),
                  );
                }),
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
              ],
            ),
          ),
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: 8),
          ],
          FilledButton(onPressed: _submit, child: const Text('שמירה והמשך')),
        ],
      ),
    ),
  );

  void _submit() {
    final payload = <String, Object?>{...widget.initialPayload};
    for (final entry in _selectedEntities.entries) {
      if (entry.value != null) payload[entry.key] = entry.value;
    }
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

  Future<Map<String, List<_EntityChoice>>> _loadChoices(
    List<String> fields,
  ) async {
    final result = <String, List<_EntityChoice>>{};
    final session = widget.controller.session!;
    final needsCustomers = fields.any(_customerEntityFields.contains);
    if (needsCustomers) {
      final page = await widget.controller.apiClient.v2Customers.list(
        businessId: session.businessId!,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
      );
      final choices = page.items
          .map((customer) => _EntityChoice(customer.id, customer.name))
          .toList(growable: false);
      for (final field in fields.where(_customerEntityFields.contains)) {
        result[field] = choices;
      }
    }
    if (fields.contains('taskId')) {
      final page = await widget.controller.apiClient.v2Tasks.list(
        businessId: session.businessId!,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
      );
      result['taskId'] = page.items
          .map((task) => _EntityChoice(task.id, task.title))
          .toList(growable: false);
    }
    if (fields.contains('entityId')) {
      final pages = await Future.wait([
        widget.controller.apiClient.v2Activities.list(
          kind: V2ActivityKind.job,
          businessId: session.businessId!,
          firebaseUid: session.firebaseUid,
          mockPhoneNumber: session.mockPhoneNumber,
        ),
        widget.controller.apiClient.v2Activities.list(
          kind: V2ActivityKind.visit,
          businessId: session.businessId!,
          firebaseUid: session.firebaseUid,
          mockPhoneNumber: session.mockPhoneNumber,
        ),
      ]);
      result['entityId'] = pages
          .expand((page) => page.items)
          .map(
            (activity) => _EntityChoice(
              activity.id,
              '${activity.kind.hebrewLabel}: ${activity.title}',
            ),
          )
          .toList(growable: false);
    }
    return result;
  }
}

const _numericFields = {'amount', 'totalAmount', 'paidAmount'};
const _dateFields = {'startsAt', 'endsAt', 'dueAt'};
const _customerEntityFields = {
  'customerId',
  'sourceCustomerId',
  'targetCustomerId',
};
const _entityFields = {..._customerEntityFields, 'taskId', 'entityId'};

class _EntityChoice {
  const _EntityChoice(this.id, this.label);
  final String id;
  final String label;
}

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
    } else if (field == 'customers') {
      result.addAll(const ['sourceCustomerId', 'targetCustomerId']);
    } else if (field == 'customerOrAddress') {
      result.addAll(const ['customerId', 'addressText']);
    } else {
      result.add(field);
    }
  }
  return result.toSet().toList(growable: false);
}

String _fieldLabel(String field) => switch (field) {
  'answer' => 'תשובה',
  'customerId' => 'לקוח',
  'sourceCustomerId' => 'לקוח מקור',
  'targetCustomerId' => 'לקוח יעד',
  'taskId' => 'משימה',
  'entityId' => 'עבודה או ביקור',
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
