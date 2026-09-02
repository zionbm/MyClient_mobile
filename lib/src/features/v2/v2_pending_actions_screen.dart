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
  final Set<String> _submittingActionIds = {};
  final Map<String, String> _requestIdempotencyKeys = {};

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
          submitting: _submittingActionIds.contains(
            stringValue(visible[index]['id']),
          ),
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
    final actionId = stringValue(action['id']);
    if (actionId.isEmpty || _submittingActionIds.contains(actionId)) return;
    setState(() => _submittingActionIds.add(actionId));
    final requestKey = _requestIdempotencyKeys.putIfAbsent(
      'resolve:$actionId',
      () => IdempotencyKey.create('pending_resolve'),
    );
    try {
      final result = await widget.controller.apiClient.v2Assistant
          .resolvePending(
            businessId: session.businessId!,
            pendingActionId: actionId,
            firebaseUid: session.firebaseUid,
            mockPhoneNumber: session.mockPhoneNumber,
            selectedEntityId: selectedId,
            payload: payload,
            confirmed: confirmed,
            idempotencyKey: requestKey,
          );
      _requestIdempotencyKeys.remove('resolve:$actionId');
      widget.controller.markDataChanged({DataScope.crm, DataScope.ai});
      await _load();
      widget.onChanged?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              stringValue(result['summary'], fallback: 'הפעולה הושלמה'),
            ),
          ),
        );
      }
    } on ApiException catch (error) {
      _requestIdempotencyKeys.remove('resolve:$actionId');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _submittingActionIds.remove(actionId));
    }
  }

  Future<void> _reject(Map<String, Object?> action) async {
    final session = widget.controller.session!;
    final actionId = stringValue(action['id']);
    if (actionId.isEmpty || _submittingActionIds.contains(actionId)) return;
    setState(() => _submittingActionIds.add(actionId));
    final requestKey = _requestIdempotencyKeys.putIfAbsent(
      'reject:$actionId',
      () => IdempotencyKey.create('pending_reject'),
    );
    try {
      await widget.controller.apiClient.v2Assistant.rejectPending(
        businessId: session.businessId!,
        pendingActionId: actionId,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        idempotencyKey: requestKey,
      );
      _requestIdempotencyKeys.remove('reject:$actionId');
      widget.controller.markDataChanged({DataScope.ai});
      await _load();
      widget.onChanged?.call();
    } on ApiException catch (error) {
      _requestIdempotencyKeys.remove('reject:$actionId');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _submittingActionIds.remove(actionId));
    }
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({
    required this.controller,
    required this.action,
    required this.submitting,
    required this.onResolve,
    required this.onReject,
  });
  final SessionController controller;
  final Map<String, Object?> action;
  final bool submitting;
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
    final actionType = stringValue(action['actionType']);
    final status = stringValue(action['status'], fallback: 'PENDING');
    final resolved = status != 'PENDING';
    final presentation = _PendingPresentation.fromAction(action);
    final card = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(presentation.icon, color: AppColors.primary),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        presentation.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (presentation.workItemSummary != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          presentation.workItemSummary!,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ],
                  ),
                ),
                if (submitting)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (!resolved)
                  const Icon(Icons.chevron_left, color: AppColors.muted),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              presentation.question,
              style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4),
            ),
            if (missingFields.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: missingFields
                    .map(
                      (field) => Chip(
                        avatar: const Icon(Icons.error_outline, size: 16),
                        label: Text('חסר: ${_fieldLabel(field)}'),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(),
              ),
            ],
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
              const SizedBox(height: 14),
              if (presentation.createCustomerName != null)
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: submitting
                            ? null
                            : () => onResolve(null, {
                                'createCustomerName':
                                    presentation.createCustomerName!,
                              }, false),
                        child: const Text('כן, צור לקוח'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: submitting ? null : onReject,
                        child: const Text('לא, בטל'),
                      ),
                    ),
                  ],
                )
              else if (candidates.isNotEmpty)
                ...candidates.map(
                  (candidate) => Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.person_outline),
                      label: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          stringValue(
                            candidate['name'],
                            fallback: stringValue(
                              candidate['title'],
                              fallback: 'אפשרות',
                            ),
                          ),
                        ),
                      ),
                      onPressed: submitting
                          ? null
                          : () {
                              final payload = mapValue(candidate['payload']);
                              final selectedId = payload.isEmpty
                                  ? stringValue(candidate['id'])
                                  : null;
                              if (missingFields.isEmpty) {
                                onResolve(selectedId, payload, confirmation);
                              } else {
                                _editPayload(
                                  context,
                                  presentation: presentation,
                                  selectedId: selectedId,
                                  initialPayload: payload,
                                  missingFields: missingFields,
                                  confirmation: confirmation,
                                );
                              }
                            },
                    ),
                  ),
                )
              else
                FilledButton.icon(
                  onPressed: submitting
                      ? null
                      : () => missingFields.isEmpty && confirmation
                            ? onResolve(null, const {}, true)
                            : _editPayload(
                                context,
                                presentation: presentation,
                                missingFields: missingFields,
                                confirmation: confirmation,
                              ),
                  icon: submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          confirmation
                              ? Icons.verified_user_outlined
                              : Icons.edit,
                        ),
                  label: Text(
                    submitting
                        ? 'מבצע...'
                        : missingFields.isEmpty && confirmation
                        ? _confirmationButtonLabel(actionType)
                        : missingFields.isEmpty
                        ? 'כתיבת תשובה'
                        : 'פתח והשלם פרטים',
                  ),
                ),
              if (presentation.createCustomerName == null)
                TextButton(
                  onPressed: submitting ? null : onReject,
                  child: const Text('לא עכשיו / דחיית הפעולה'),
                ),
            ],
          ],
        ),
      ),
    );
    if (resolved) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: submitting
            ? null
            : () => _openPrimaryAction(
                context,
                presentation: presentation,
                candidates: candidates,
                missingFields: missingFields,
                confirmation: confirmation,
              ),
        child: card,
      ),
    );
  }

  void _openPrimaryAction(
    BuildContext context, {
    required _PendingPresentation presentation,
    required List<Map<String, Object?>> candidates,
    required List<String> missingFields,
    required bool confirmation,
  }) {
    if (presentation.createCustomerName != null) {
      showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        builder: (_) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                presentation.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(presentation.question),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  onResolve(null, {
                    'createCustomerName': presentation.createCustomerName!,
                  }, false);
                },
                child: const Text('כן, צור לקוח והמשך'),
              ),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                  onReject();
                },
                child: const Text('לא, בטל את הפעולה'),
              ),
            ],
          ),
        ),
      );
      return;
    }
    if (candidates.length == 1 && missingFields.isEmpty) {
      final candidate = candidates.single;
      final payload = mapValue(candidate['payload']);
      onResolve(
        payload.isEmpty ? stringValue(candidate['id']) : null,
        payload,
        confirmation,
      );
      return;
    }
    _editPayload(
      context,
      presentation: presentation,
      missingFields: missingFields,
      confirmation: confirmation,
    );
  }

  Future<void> _editPayload(
    BuildContext context, {
    required _PendingPresentation presentation,
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
        presentation: presentation,
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
    required this.presentation,
    required this.missingFields,
    required this.initialPayload,
  });

  final SessionController controller;
  final _PendingPresentation presentation;
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
    final fields = _expandedFields(
      widget.missingFields,
      needsFreeTextAnswer: widget.missingFields.isEmpty,
    );
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
          Row(
            children: [
              Icon(widget.presentation.icon, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.presentation.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(widget.presentation.question),
          if (widget.presentation.workItemSummary != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                widget.presentation.workItemSummary!,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
          if (widget.missingFields.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'צריך להשלים: ${widget.missingFields.map(_fieldLabel).join(', ')}',
              style: const TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
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
                        labelText: '${_fieldLabel(field)} — שדה חובה',
                        helperText: 'בחר מהרשימה כדי להמשיך',
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
                        labelText: widget.missingFields.contains(entry.key)
                            ? '${_fieldLabel(entry.key)} — שדה חובה'
                            : _fieldLabel(entry.key),
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
          FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.check),
            label: const Text('שמירה וביצוע הפעולה'),
          ),
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
    for (final field in widget.missingFields) {
      if (_entityFields.contains(field)) {
        if (_selectedEntities[field] == null) {
          setState(() => _error = 'צריך לבחור ${_fieldLabel(field)}');
          return;
        }
      } else if ((payload[field]?.toString().trim().isEmpty ?? true)) {
        setState(() => _error = 'צריך להשלים ${_fieldLabel(field)}');
        return;
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

class _PendingPresentation {
  const _PendingPresentation({
    required this.title,
    required this.question,
    required this.icon,
    this.workItemSummary,
    this.createCustomerName,
  });

  final String title;
  final String question;
  final IconData icon;
  final String? workItemSummary;
  final String? createCustomerName;

  factory _PendingPresentation.fromAction(Map<String, Object?> action) {
    final actionType = stringValue(action['actionType']);
    final payload = mapValue(action['payload']);
    final suggestion = mapValue(payload['createCustomerSuggestion']);
    final continuationSteps = mapListValue(payload['continuationSteps']);
    final continuation = continuationSteps.isEmpty
        ? const <String, Object?>{}
        : continuationSteps.first;
    final continuationType = stringValue(continuation['tool']);
    final input = continuation.isEmpty
        ? mapValue(payload['input'])
        : mapValue(continuation['input']);
    final subject = stringValue(input['title']);
    final workType = _actionLabel(
      continuationType.isEmpty ? actionType : continuationType,
    );
    return _PendingPresentation(
      title: actionType == 'FIND_CUSTOMERS' && suggestion.isNotEmpty
          ? 'לקוח לא נמצא'
          : _pendingActionTitle(
              continuationType.isEmpty ? actionType : continuationType,
            ),
      question: stringValue(
        action['question'],
        fallback: 'צריך להשלים פרט לפני שאפשר לבצע את הפעולה.',
      ),
      icon: _actionIcon(
        continuationType.isEmpty ? actionType : continuationType,
      ),
      workItemSummary: subject.isEmpty ? null : '$workType: $subject',
      createCustomerName: nullableString(suggestion['name']),
    );
  }
}

String _actionLabel(String actionType) => switch (actionType) {
  'CREATE_TASK' ||
  'UPDATE_TASK' ||
  'COMPLETE_TASK' ||
  'CANCEL_TASK' ||
  'DELETE_TASK' => 'משימה',
  'CREATE_JOB' || 'UPDATE_JOB' || 'CANCEL_JOB' || 'DELETE_JOB' => 'עבודה',
  'CREATE_VISIT' ||
  'UPDATE_VISIT' ||
  'CANCEL_VISIT' ||
  'DELETE_VISIT' => 'ביקור',
  'CREATE_CUSTOMER' || 'UPDATE_CUSTOMER' || 'FIND_CUSTOMERS' => 'לקוח',
  'ADD_CUSTOMER_PHONE' || 'DELETE_CUSTOMER_PHONE' => 'טלפון',
  'ADD_SERVICE_ADDRESS' || 'DELETE_SERVICE_ADDRESS' => 'כתובת שירות',
  'CREATE_NOTE' || 'UPDATE_NOTE' => 'הערה',
  'SET_ACTIVITY_AMOUNT' => 'סכום',
  'ADD_PAYMENT' || 'SET_PAID_TOTAL' || 'SETTLE_BALANCE' => 'תשלום',
  'MERGE_CUSTOMERS' => 'מיזוג לקוחות',
  'UNDO_ACTION_BATCH' => 'ביטול פעולה אחרונה',
  _ => 'פעולה',
};

String _pendingActionTitle(String actionType) => switch (actionType) {
  'CANCEL_TASK' => 'אישור ביטול משימה',
  'CANCEL_JOB' => 'אישור ביטול עבודה',
  'CANCEL_VISIT' => 'אישור ביטול ביקור',
  'DELETE_TASK' => 'אישור מחיקת משימה',
  'DELETE_JOB' => 'אישור מחיקת עבודה',
  'DELETE_VISIT' => 'אישור מחיקת ביקור',
  'DELETE_CUSTOMER_PHONE' => 'אישור מחיקת טלפון',
  'DELETE_SERVICE_ADDRESS' => 'אישור מחיקת כתובת שירות',
  'SET_ACTIVITY_AMOUNT' => 'אישור סכום',
  'ADD_PAYMENT' || 'SET_PAID_TOTAL' || 'SETTLE_BALANCE' => 'אישור תשלום',
  'MERGE_CUSTOMERS' => 'אישור מיזוג לקוחות',
  'UNDO_ACTION_BATCH' => 'אישור ביטול פעולה אחרונה',
  _ => 'השלמת ${_actionLabel(actionType)}',
};

String _confirmationButtonLabel(String actionType) => switch (actionType) {
  'CANCEL_TASK' || 'CANCEL_JOB' || 'CANCEL_VISIT' => 'אישור ביטול',
  'DELETE_TASK' ||
  'DELETE_JOB' ||
  'DELETE_VISIT' ||
  'DELETE_CUSTOMER_PHONE' ||
  'DELETE_SERVICE_ADDRESS' => 'אישור מחיקה',
  'SET_ACTIVITY_AMOUNT' => 'אישור סכום',
  'ADD_PAYMENT' || 'SET_PAID_TOTAL' || 'SETTLE_BALANCE' => 'אישור תשלום',
  'MERGE_CUSTOMERS' => 'אישור מיזוג',
  'UNDO_ACTION_BATCH' => 'אישור ביטול הפעולה',
  _ => 'אישור וביצוע',
};

IconData _actionIcon(String actionType) => switch (actionType) {
  'CREATE_TASK' || 'UPDATE_TASK' || 'COMPLETE_TASK' => Icons.task_alt,
  'CREATE_JOB' || 'UPDATE_JOB' => Icons.home_repair_service_outlined,
  'CREATE_VISIT' || 'UPDATE_VISIT' => Icons.event_outlined,
  'CREATE_CUSTOMER' ||
  'UPDATE_CUSTOMER' ||
  'FIND_CUSTOMERS' => Icons.person_outline,
  'ADD_CUSTOMER_PHONE' => Icons.phone_outlined,
  'DELETE_CUSTOMER_PHONE' => Icons.phone_disabled_outlined,
  'ADD_SERVICE_ADDRESS' => Icons.location_on_outlined,
  'DELETE_SERVICE_ADDRESS' => Icons.wrong_location_outlined,
  'SET_ACTIVITY_AMOUNT' => Icons.payments_outlined,
  'ADD_PAYMENT' ||
  'SET_PAID_TOTAL' ||
  'SETTLE_BALANCE' => Icons.account_balance_wallet_outlined,
  'CANCEL_TASK' || 'CANCEL_JOB' || 'CANCEL_VISIT' => Icons.event_busy_outlined,
  'DELETE_TASK' || 'DELETE_JOB' || 'DELETE_VISIT' => Icons.delete_outline,
  'MERGE_CUSTOMERS' => Icons.merge_outlined,
  'UNDO_ACTION_BATCH' => Icons.undo,
  _ => Icons.auto_awesome_outlined,
};

List<String> _expandedFields(
  List<String> fields, {
  bool needsFreeTextAnswer = false,
}) {
  if (fields.isEmpty) return needsFreeTextAnswer ? const ['answer'] : const [];
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
