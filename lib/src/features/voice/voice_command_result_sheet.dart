import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../utils/json_read.dart';
import '../auth/session_controller.dart';
import 'voice_command_result.dart';

class VoiceCommandResultSheet extends StatefulWidget {
  const VoiceCommandResultSheet({
    super.key,
    required this.result,
    required this.controller,
    this.onOpenPendingActions,
    this.onRecordAgain,
    this.onResolved,
  });

  final VoiceCommandResult result;
  final SessionController controller;
  final VoidCallback? onOpenPendingActions;
  final VoidCallback? onRecordAgain;
  final VoidCallback? onResolved;

  @override
  State<VoiceCommandResultSheet> createState() =>
      _VoiceCommandResultSheetState();
}

class _VoiceCommandResultSheetState extends State<VoiceCommandResultSheet> {
  late VoiceCommandResult _result;
  final Set<String> _submittingItems = {};
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    _result = widget.result;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = _statusColor(colorScheme);
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.78,
        minChildSize: 0.48,
        maxChildSize: 0.94,
        builder: (context, scrollController) {
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    tooltip: 'סגור',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Icon(_statusIcon(), color: statusColor, size: 30),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                _result.title,
                                textAlign: TextAlign.end,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _result.summary,
                          textAlign: TextAlign.end,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_result.transcript != null) ...[
                const SizedBox(height: 16),
                _TranscriptCard(transcript: _result.transcript!),
              ],
              const SizedBox(height: 16),
              if (_result.items.isEmpty)
                _EmptyResultCard(
                  state: _result.state,
                  onCreateCustomer: () =>
                      _createManualAction('CREATE_CUSTOMER'),
                  onCreateTask: () => _createManualAction('CREATE_TASK'),
                )
              else
                ..._result.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ResultItemCard(
                      item: item,
                      submitting: _submittingItems.contains(item.id),
                      onTap: item.status == 'pending'
                          ? () => _editPendingItem(item)
                          : null,
                      onApprove: _canApprove(item)
                          ? () => _approvePendingItem(item)
                          : null,
                      onReject: item.status == 'pending'
                          ? () => _rejectPendingItem(item)
                          : null,
                    ),
                  ),
                ),
              if (_inlineError != null) ...[
                const SizedBox(height: 4),
                Text(
                  _inlineError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.error),
                ),
              ],
              const SizedBox(height: 8),
              if (_result.primaryAction != null)
                FilledButton(
                  onPressed: () =>
                      _handleAction(context, _result.primaryAction!),
                  child: Text(_result.primaryAction!),
                ),
              if (_result.secondaryActions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: _result.secondaryActions
                      .map(
                        (action) => TextButton(
                          onPressed: () => _handleAction(context, action),
                          child: Text(action),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  void _handleAction(BuildContext context, String action) {
    Navigator.of(context).pop();
    if (action == 'פתח פעולות AI') {
      widget.onOpenPendingActions?.call();
      return;
    }
    if (action == 'הקלט שוב') {
      widget.onRecordAgain?.call();
    }
  }

  Future<void> _editPendingItem(VoiceCommandResultItem item) async {
    final edited = await showModalBottomSheet<Map<String, Object?>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: _PayloadEditorSheet(item: item),
      ),
    );
    if (edited == null) return;
    await _approvePendingItem(item, edited);
  }

  bool _canApprove(VoiceCommandResultItem item) =>
      item.status == 'pending' &&
      item.pendingActionId != null &&
      item.missingFields.isEmpty;

  Future<void> _approvePendingItem(
    VoiceCommandResultItem item, [
    Map<String, Object?>? editedPayload,
  ]) async {
    final pendingActionId = item.pendingActionId;
    if (pendingActionId == null) return;
    setState(() {
      _inlineError = null;
      _submittingItems.add(item.id);
    });
    try {
      final session = widget.controller.session!;
      await widget.controller.apiClient.approveAiPendingAction(
        businessId: session.businessId!,
        pendingActionId: pendingActionId,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        payload: editedPayload ?? item.payload,
      );
      widget.controller.markDataChanged();
      widget.onResolved?.call();
      if (!mounted) return;
      setState(() {
        _result = _result.markItemCompleted(item.id);
        _submittingItems.remove(item.id);
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _inlineError = error.message;
        _submittingItems.remove(item.id);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _inlineError = 'לא הצלחנו להשלים את הפעולה';
        _submittingItems.remove(item.id);
      });
    }
  }

  Future<void> _rejectPendingItem(VoiceCommandResultItem item) async {
    final pendingActionId = item.pendingActionId;
    if (pendingActionId == null) return;
    setState(() {
      _inlineError = null;
      _submittingItems.add(item.id);
    });
    try {
      final session = widget.controller.session!;
      await widget.controller.apiClient.rejectAiPendingAction(
        businessId: session.businessId!,
        pendingActionId: pendingActionId,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
      );
      widget.controller.markDataChanged();
      widget.onResolved?.call();
      if (!mounted) return;
      setState(() {
        _result = _result.removeItem(item.id);
        _submittingItems.remove(item.id);
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _inlineError = error.message;
        _submittingItems.remove(item.id);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _inlineError = 'לא הצלחנו למחוק את הפעולה';
        _submittingItems.remove(item.id);
      });
    }
  }

  Future<void> _createManualAction(String actionType) async {
    final item = VoiceCommandResultItem.manual(
      actionType: actionType,
      transcript: _result.transcript,
    );
    final payload = await showModalBottomSheet<Map<String, Object?>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: _PayloadEditorSheet(item: item),
      ),
    );
    if (payload == null) return;
    setState(() {
      _inlineError = null;
      _submittingItems.add(item.id);
    });
    try {
      final session = widget.controller.session!;
      if (actionType == 'CREATE_CUSTOMER') {
        await widget.controller.apiClient.createCustomer(
          businessId: session.businessId!,
          firebaseUid: session.firebaseUid,
          mockPhoneNumber: session.mockPhoneNumber,
          body: _withoutEmptyValues(payload),
        );
      } else {
        await widget.controller.apiClient.createCallback(
          businessId: session.businessId!,
          firebaseUid: session.firebaseUid,
          mockPhoneNumber: session.mockPhoneNumber,
          body: _withoutEmptyValues(payload),
        );
      }
      widget.controller.markDataChanged();
      widget.onResolved?.call();
      if (!mounted) return;
      setState(() {
        _result = _result.addCompletedManualItem(item.updatePayload(payload));
        _submittingItems.remove(item.id);
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _inlineError = error.message;
        _submittingItems.remove(item.id);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _inlineError = 'לא הצלחנו ליצור את הפעולה';
        _submittingItems.remove(item.id);
      });
    }
  }

  IconData _statusIcon() {
    return switch (_result.state) {
      VoiceCommandResultState.done => Icons.check_circle_outline,
      VoiceCommandResultState.needsReview => Icons.fact_check_outlined,
      VoiceCommandResultState.needsInput => Icons.error_outline,
      VoiceCommandResultState.failed => Icons.mic_off_outlined,
      VoiceCommandResultState.unsupported => Icons.help_outline,
    };
  }

  Color _statusColor(ColorScheme colorScheme) {
    return switch (_result.state) {
      VoiceCommandResultState.done => colorScheme.primary,
      VoiceCommandResultState.needsReview => colorScheme.primary,
      VoiceCommandResultState.needsInput => colorScheme.tertiary,
      VoiceCommandResultState.failed => colorScheme.error,
      VoiceCommandResultState.unsupported => colorScheme.secondary,
    };
  }
}

class _TranscriptCard extends StatelessWidget {
  const _TranscriptCard({required this.transcript});

  final String transcript;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'מה שמעתי',
                  textAlign: TextAlign.end,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 8),
                Icon(Icons.mic_none_outlined, color: colorScheme.primary),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(transcript, textAlign: TextAlign.end),
            ),
          ],
        ),
      ),
    );
  }
}

class _PayloadEditorSheet extends StatefulWidget {
  const _PayloadEditorSheet({required this.item});

  final VoiceCommandResultItem item;

  @override
  State<_PayloadEditorSheet> createState() => _PayloadEditorSheetState();
}

class _PayloadEditorSheetState extends State<_PayloadEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    final keys = <String>{
      ..._defaultFieldsFor(widget.item.actionType),
      ...widget.item.payload.keys,
      ...widget.item.missingFields,
    };
    _controllers = {
      for (final key in keys)
        key: TextEditingController(text: stringValue(widget.item.payload[key])),
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
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 14,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 680),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                widget.item.title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'אפשר לשנות את הפרטים לפני אישור הפעולה.',
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              Flexible(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    shrinkWrap: true,
                    children: _controllers.entries
                        .map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: TextFormField(
                              controller: entry.value,
                              textAlign: TextAlign.right,
                              minLines: _isLongField(entry.key) ? 2 : 1,
                              maxLines: _isLongField(entry.key) ? 5 : 1,
                              decoration: InputDecoration(
                                labelText: _labelForField(entry.key),
                                helperText:
                                    widget.item.missingFields.contains(
                                      entry.key,
                                    )
                                    ? 'שדה חסר'
                                    : null,
                              ),
                              validator: (value) =>
                                  _validateField(entry.key, value),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () {
                  if (!_formKey.currentState!.validate()) return;
                  Navigator.of(context).pop(_payload());
                },
                icon: const Icon(Icons.check),
                label: const Text('אישור'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('ביטול'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, Object?> _payload() {
    final next = Map<String, Object?>.from(widget.item.payload);
    for (final entry in _controllers.entries) {
      final value = entry.value.text.trim();
      if (value.isEmpty) {
        next.remove(entry.key);
      } else {
        next[entry.key] = num.tryParse(value) ?? value;
      }
    }
    return next;
  }

  bool _isLongField(String key) {
    final lower = key.toLowerCase();
    return lower.contains('description') ||
        lower.contains('notes') ||
        lower.contains('text');
  }

  Set<String> _requiredFields() {
    return {
      ...widget.item.missingFields,
      ...switch (widget.item.actionType) {
        'CREATE_CUSTOMER' => const ['name'],
        'CREATE_TASK' || 'CREATE_CALLBACK' => const ['title'],
        'CREATE_APPOINTMENT' ||
        'CREATE_HOME_VISIT' => const ['title', 'startsAt'],
        'CREATE_QUOTE' => const ['title'],
        'ADD_CUSTOMER_NOTE' => const ['customerId', 'text'],
        _ => const <String>[],
      },
    };
  }

  String? _validateField(String key, String? value) {
    if (!_requiredFields().contains(key)) return null;
    if (key == 'customerId') {
      final customerId = _controllers['customerId']?.text.trim() ?? '';
      final name = _controllers['name']?.text.trim() ?? '';
      return customerId.isEmpty && name.isEmpty ? 'בחר או כתוב לקוח' : null;
    }
    return value == null || value.trim().isEmpty ? 'שדה חובה' : null;
  }

  List<String> _defaultFieldsFor(String actionType) {
    return switch (actionType) {
      'CREATE_CUSTOMER' => ['name', 'phone', 'email', 'address'],
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
        'notes',
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
      _ => widget.item.payload.keys.toList(),
    };
  }

  String _labelForField(String key) {
    return switch (key) {
      'name' => 'שם לקוח',
      'phone' => 'טלפון',
      'email' => 'אימייל',
      'address' => 'כתובת',
      'title' => 'נושא',
      'customerId' => 'לקוח',
      'dueAt' => 'מועד',
      'startsAt' => 'התחלה',
      'endsAt' => 'סיום',
      'priority' => 'דחיפות',
      'description' => 'תיאור',
      'notes' => 'הערות',
      'location' => 'כתובת / מיקום',
      'estimatedAmount' => 'סכום',
      'text' => 'תוכן',
      _ => key,
    };
  }
}

class _ResultItemCard extends StatelessWidget {
  const _ResultItemCard({
    required this.item,
    this.submitting = false,
    this.onTap,
    this.onApprove,
    this.onReject,
  });

  final VoiceCommandResultItem item;
  final bool submitting;
  final VoidCallback? onTap;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final pending = item.status == 'pending';
    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: pending ? colorScheme.tertiary : colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              children: [
                _StatusBadge(status: item.status),
                const Spacer(),
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        item.title,
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      if (item.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.subtitle!,
                          textAlign: TextAlign.end,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                CircleAvatar(
                  radius: 21,
                  backgroundColor: colorScheme.primaryContainer,
                  foregroundColor: colorScheme.onPrimaryContainer,
                  child: Icon(_iconForKind(item.kind)),
                ),
              ],
            ),
            if (item.fields.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...item.fields.map(
                (field) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          field.value,
                          textAlign: TextAlign.start,
                          style: TextStyle(
                            color: field.missing ? colorScheme.error : null,
                            fontWeight: field.missing ? FontWeight.w700 : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${field.label}:',
                        textAlign: TextAlign.end,
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (item.status == 'pending') ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  if (onReject != null)
                    TextButton.icon(
                      onPressed: submitting ? null : onReject,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('מחיקה'),
                    ),
                  const Spacer(),
                  if (onApprove != null)
                    FilledButton.icon(
                      onPressed: submitting ? null : onApprove,
                      icon: submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: Text(submitting ? 'שומר...' : 'השלים פעולה'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: submitting ? null : onTap,
        child: card,
      ),
    );
  }

  IconData _iconForKind(String kind) {
    return switch (kind) {
      'customer' => Icons.person_outline,
      'home_visit' => Icons.event_available_outlined,
      'quote' => Icons.request_quote_outlined,
      'note' => Icons.sticky_note_2_outlined,
      'callback' => Icons.phone_callback_outlined,
      _ => Icons.auto_awesome_outlined,
    };
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final pending = status == 'pending';
    final failed = status == 'failed';
    final label = pending
        ? 'צריך השלמה'
        : failed
        ? 'לא בוצע'
        : 'בוצע';
    final color = failed
        ? colorScheme.error
        : pending
        ? colorScheme.tertiary
        : colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color.withValues(alpha: 0.12),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _EmptyResultCard extends StatelessWidget {
  const _EmptyResultCard({
    required this.state,
    required this.onCreateCustomer,
    required this.onCreateTask,
  });

  final VoiceCommandResultState state;
  final VoidCallback onCreateCustomer;
  final VoidCallback onCreateTask;

  @override
  Widget build(BuildContext context) {
    final unsupported = state == VoiceCommandResultState.unsupported;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              unsupported ? Icons.rule_folder_outlined : Icons.mic_off_outlined,
              size: 36,
            ),
            const SizedBox(height: 10),
            Text(
              unsupported
                  ? 'אפשר ליצור לקוחות, תזכורות, ביקורי בית, הצעות מחיר והערות.'
                  : 'לא נוצרו שינויים במערכת.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onCreateTask,
                  icon: const Icon(Icons.add_task_outlined),
                  label: const Text('פתח משימה'),
                ),
                OutlinedButton.icon(
                  onPressed: onCreateCustomer,
                  icon: const Icon(Icons.person_add_alt_outlined),
                  label: const Text('פתח לקוח'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Map<String, Object?> _withoutEmptyValues(Map<String, Object?> payload) {
  final next = <String, Object?>{};
  for (final entry in payload.entries) {
    final value = entry.value;
    if (value == null) continue;
    if (value is String && value.trim().isEmpty) continue;
    next[entry.key] = value;
  }
  return next;
}
