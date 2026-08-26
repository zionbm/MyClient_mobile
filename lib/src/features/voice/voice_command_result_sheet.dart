import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../models/customer.dart';
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
  Future<List<Customer>>? _customersFuture;
  final Map<String, Customer> _selectedCustomers = {};
  final Map<String, DateTime> _selectedTimes = {};
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
                _EmptyResultCard(state: _result.state)
              else
                ..._result.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ResultItemCard(
                      item: item,
                      selectedCustomer: _selectedCustomers[item.id],
                      selectedTime: _selectedTimes[item.id],
                      submitting: _submittingItems.contains(item.id),
                      onPickCustomer: _canPickCustomer(item)
                          ? () => _pickCustomer(item)
                          : null,
                      onPickTime: _canPickTime(item)
                          ? () => _pickTime(item)
                          : null,
                      onApprove: _canApprove(item)
                          ? () => _approvePendingItem(item)
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

  bool _canPickCustomer(VoiceCommandResultItem item) {
    return item.status == 'pending' &&
        item.pendingActionId != null &&
        _missing(item, 'customerId', 'customerName');
  }

  bool _canPickTime(VoiceCommandResultItem item) {
    return item.status == 'pending' &&
        item.pendingActionId != null &&
        _missing(item, 'dueAt', 'startsAt');
  }

  bool _canApprove(VoiceCommandResultItem item) {
    if (item.status != 'pending' || item.pendingActionId == null) return false;
    if (_canPickCustomer(item) && _selectedCustomers[item.id] == null) {
      return false;
    }
    if (_canPickTime(item) && _selectedTimes[item.id] == null) return false;
    return true;
  }

  bool _missing(VoiceCommandResultItem item, String first, [String? second]) {
    return item.missingFields.contains(first) ||
        (second != null && item.missingFields.contains(second));
  }

  Future<void> _pickCustomer(VoiceCommandResultItem item) async {
    late final List<Customer> customers;
    try {
      customers = await _customers();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _inlineError = error.message);
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() => _inlineError = 'לא הצלחנו לטעון לקוחות');
      return;
    }
    if (!mounted) return;
    final selected = await showModalBottomSheet<Customer>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: _CustomerPicker(customers: customers),
      ),
    );
    if (selected == null) return;
    setState(() {
      _inlineError = null;
      _selectedCustomers[item.id] = selected;
    });
  }

  Future<List<Customer>> _customers() {
    final existing = _customersFuture;
    if (existing != null) return existing;
    final session = widget.controller.session!;
    final future = widget.controller.apiClient
        .listCustomers(
          businessId: session.businessId!,
          firebaseUid: session.firebaseUid,
          mockPhoneNumber: session.mockPhoneNumber,
        )
        .then(
          (json) =>
              mapListValue(json['customers']).map(Customer.fromJson).toList(),
        );
    _customersFuture = future;
    return future;
  }

  Future<void> _pickTime(VoiceCommandResultItem item) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedTimes[item.id] ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      helpText: 'בחר תאריך',
      cancelText: 'ביטול',
      confirmText: 'המשך',
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedTimes[item.id] ?? now),
      helpText: 'בחר שעה',
      cancelText: 'ביטול',
      confirmText: 'אישור',
    );
    if (time == null) return;
    setState(() {
      _inlineError = null;
      _selectedTimes[item.id] = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _approvePendingItem(VoiceCommandResultItem item) async {
    final pendingActionId = item.pendingActionId;
    if (pendingActionId == null) return;
    setState(() {
      _inlineError = null;
      _submittingItems.add(item.id);
    });
    try {
      final session = widget.controller.session!;
      final payload = <String, Object?>{};
      final customer = _selectedCustomers[item.id];
      if (customer != null) payload['customerId'] = customer.id;
      final time = _selectedTimes[item.id];
      if (time != null) {
        payload[item.kind == 'home_visit' ? 'startsAt' : 'dueAt'] = time
            .toIso8601String();
      }
      await widget.controller.apiClient.approveAiPendingAction(
        businessId: session.businessId!,
        pendingActionId: pendingActionId,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        payload: payload,
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

  IconData _statusIcon() {
    return switch (_result.state) {
      VoiceCommandResultState.done => Icons.check_circle_outline,
      VoiceCommandResultState.needsInput => Icons.error_outline,
      VoiceCommandResultState.failed => Icons.mic_off_outlined,
      VoiceCommandResultState.unsupported => Icons.help_outline,
    };
  }

  Color _statusColor(ColorScheme colorScheme) {
    return switch (_result.state) {
      VoiceCommandResultState.done => colorScheme.primary,
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
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
      collapsedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      leading: const Icon(Icons.mic_none_outlined),
      title: const Text('מה שמעתי', textAlign: TextAlign.end),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(transcript, textAlign: TextAlign.end),
          ),
        ),
      ],
    );
  }
}

class _ResultItemCard extends StatelessWidget {
  const _ResultItemCard({
    required this.item,
    this.selectedCustomer,
    this.selectedTime,
    this.submitting = false,
    this.onPickCustomer,
    this.onPickTime,
    this.onApprove,
  });

  final VoiceCommandResultItem item;
  final Customer? selectedCustomer;
  final DateTime? selectedTime;
  final bool submitting;
  final VoidCallback? onPickCustomer;
  final VoidCallback? onPickTime;
  final VoidCallback? onApprove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final pending = item.status == 'pending';
    return DecoratedBox(
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
              if (onPickCustomer != null)
                _InlineChoiceButton(
                  icon: Icons.person_search_outlined,
                  label: selectedCustomer?.name ?? 'בחר לקוח',
                  onPressed: submitting ? null : onPickCustomer,
                ),
              if (onPickTime != null) ...[
                if (onPickCustomer != null) const SizedBox(height: 8),
                _InlineChoiceButton(
                  icon: Icons.schedule_outlined,
                  label: selectedTime == null
                      ? 'בחר שעה'
                      : _formatLocalDateTime(context, selectedTime!),
                  onPressed: submitting ? null : onPickTime,
                ),
              ],
              if (onApprove != null) ...[
                const SizedBox(height: 12),
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
            ],
          ],
        ),
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

class _InlineChoiceButton extends StatelessWidget {
  const _InlineChoiceButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Align(
        alignment: Alignment.centerRight,
        child: Text(label, overflow: TextOverflow.ellipsis),
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(46),
        alignment: Alignment.centerRight,
      ),
    );
  }
}

class _CustomerPicker extends StatefulWidget {
  const _CustomerPicker({required this.customers});

  final List<Customer> customers;

  @override
  State<_CustomerPicker> createState() => _CustomerPickerState();
}

class _CustomerPickerState extends State<_CustomerPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final customers = widget.customers.where((customer) {
      final query = _query.trim();
      if (query.isEmpty) return true;
      return customer.name.contains(query) ||
          (customer.phone?.contains(query) ?? false);
    }).toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 14,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'למי לחזור?',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            TextField(
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'חיפוש לקוח',
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: customers.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('לא נמצאו לקוחות')),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: customers.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final customer = customers[index];
                        return ListTile(
                          leading: const Icon(Icons.person_outline),
                          title: Text(
                            customer.name,
                            textAlign: TextAlign.right,
                          ),
                          subtitle: customer.phone == null
                              ? null
                              : Text(
                                  customer.phone!,
                                  textAlign: TextAlign.right,
                                ),
                          onTap: () => Navigator.of(context).pop(customer),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatLocalDateTime(BuildContext context, DateTime dateTime) {
  final localizations = MaterialLocalizations.of(context);
  final date = localizations.formatShortDate(dateTime);
  final time = localizations.formatTimeOfDay(TimeOfDay.fromDateTime(dateTime));
  return '$date, $time';
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
  const _EmptyResultCard({required this.state});

  final VoiceCommandResultState state;

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
          ],
        ),
      ),
    );
  }
}
