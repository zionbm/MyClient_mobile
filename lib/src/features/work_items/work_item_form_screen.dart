import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../data/repositories/work_item_repository.dart';
import '../../models/customer.dart';
import '../../models/work_item.dart';
import '../../utils/date_formatting.dart';
import '../../utils/json_read.dart';
import '../auth/session_controller.dart';
import '../customers/customer_form_screen.dart';
import '../customers/customer_picker_screen.dart';

part 'work_item_form_widgets.dart';

enum WorkItemKind { reminder, homeVisit, appointment, quote, note }

class WorkItemFormScreen extends StatefulWidget {
  const WorkItemFormScreen({
    super.key,
    required this.controller,
    required this.kind,
    this.initialCustomer,
    this.existingItem,
    this.initialPayload,
    this.aiPendingActionId,
  });

  final SessionController controller;
  final WorkItemKind kind;
  final Customer? initialCustomer;
  final WorkItem? existingItem;
  final Map<String, Object?>? initialPayload;
  final String? aiPendingActionId;

  @override
  State<WorkItemFormScreen> createState() => _WorkItemFormScreenState();
}

class _WorkItemFormScreenState extends State<WorkItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _amountController = TextEditingController();

  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  int _durationMinutes = 30;
  String _priority = 'NORMAL';
  String _status = 'OPEN';
  Customer? _selectedCustomer;
  String? _initialCustomerId;
  String? _initialCustomerName;
  bool _resolvingCustomer = false;
  bool _saving = false;
  String? _error;
  String? _initialSnapshot;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingItem;
    _selectedCustomer = widget.initialCustomer ?? existing?.customer;
    _hydrateFromPayload(widget.initialPayload);
    if (existing != null) {
      _titleController.text = existing.title;
      _descriptionController.text = switch (widget.kind) {
        WorkItemKind.homeVisit || WorkItemKind.appointment =>
          existing.notes ?? existing.description ?? '',
        _ => existing.description ?? '',
      };
      _locationController.text = existing.location ?? '';
      _priority = existing.priority?.apiValue ?? 'NORMAL';
      _status = _normalizeStatus(existing.status?.apiValue);
      if (existing.dueAt != null) {
        final dueAt = existing.dueAt!.toLocal();
        _date = DateTime(dueAt.year, dueAt.month, dueAt.day);
        _time = TimeOfDay(hour: dueAt.hour, minute: dueAt.minute);
      }
    }
    _initialSnapshot = _formSnapshot();
    _resolveInitialCustomer();
  }

  void _hydrateFromPayload(Map<String, Object?>? payload) {
    if (payload == null || payload.isEmpty) return;
    _titleController.text = stringValue(
      payload['title'] ?? payload['text'],
      fallback: _titleController.text,
    );
    _descriptionController.text = stringValue(switch (widget.kind) {
      WorkItemKind.homeVisit ||
      WorkItemKind.appointment => payload['notes'] ?? payload['description'],
      WorkItemKind.note => payload['text'],
      _ => payload['description'] ?? payload['notes'],
    }, fallback: _descriptionController.text);
    _locationController.text = stringValue(
      payload['location'] ?? payload['address'],
      fallback: _locationController.text,
    );
    _amountController.text = stringValue(
      payload['estimatedAmount'],
      fallback: _amountController.text,
    );
    final priority = stringValue(payload['priority']).toUpperCase();
    if (priority == 'URGENT' || priority == 'NORMAL') {
      _priority = priority;
    }
    final status = stringValue(payload['status']).toUpperCase();
    if (status.isNotEmpty) _status = _normalizeStatus(status);
    _initialCustomerId = nullableString(payload['customerId']);
    _initialCustomerName = nullableString(
      payload['customerName'] ?? payload['name'],
    );
    final rawDate = stringValue(payload['startsAt'] ?? payload['dueAt']);
    final parsedDate = DateTime.tryParse(rawDate);
    if (parsedDate != null) {
      final local = parsedDate.toLocal();
      _date = DateTime(local.year, local.month, local.day);
      _time = TimeOfDay(hour: local.hour, minute: local.minute);
    }
    final startsAt = DateTime.tryParse(stringValue(payload['startsAt']));
    final endsAt = DateTime.tryParse(stringValue(payload['endsAt']));
    if (startsAt != null && endsAt != null && endsAt.isAfter(startsAt)) {
      final minutes = endsAt.difference(startsAt).inMinutes;
      if (minutes > 0) _durationMinutes = minutes;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leadingWidth: 150,
          leading: _TopFormActions(
            saving: _saving,
            onSave: _save,
            onCancel: _cancel,
          ),
          title: Text(_title),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (widget.kind != WorkItemKind.note) ...[
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(labelText: _titleField),
                    textInputAction: TextInputAction.next,
                    validator: _required,
                  ),
                  const SizedBox(height: 12),
                ],
                InputDecorator(
                  decoration: const InputDecoration(labelText: 'לקוח משויך'),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: _resolvingCustomer
                        ? const SizedBox.square(
                            dimension: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.person_outline),
                    title: Text(_selectedCustomer?.name ?? 'ללא לקוח'),
                    subtitle: _selectedCustomer?.phone == null
                        ? null
                        : Text(_selectedCustomer!.phone!),
                    trailing: widget.initialCustomer == null
                        ? const Icon(Icons.chevron_left)
                        : null,
                    onTap: widget.initialCustomer == null && !_resolvingCustomer
                        ? _showCustomerActions
                        : null,
                  ),
                ),
                if (widget.kind != WorkItemKind.note) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.calendar_today_outlined),
                          label: Text(formatShortDate(_date)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickTime,
                          icon: const Icon(Icons.schedule),
                          label: Text(_time.format(context)),
                        ),
                      ),
                    ],
                  ),
                ],
                if (widget.kind == WorkItemKind.reminder) ...[
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'NORMAL', label: Text('רגיל')),
                      ButtonSegment(value: 'URGENT', label: Text('דחוף')),
                    ],
                    selected: {_priority},
                    onSelectionChanged: (value) =>
                        setState(() => _priority = value.first),
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'סטטוס'),
                  items: _statusOptions
                      .map(
                        (option) => DropdownMenuItem<String>(
                          value: option.value,
                          child: Text(option.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _status = value);
                  },
                ),
                if (widget.kind == WorkItemKind.homeVisit ||
                    widget.kind == WorkItemKind.appointment) ...[
                  const SizedBox(height: 12),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 30, label: Text('30 דק׳')),
                      ButtonSegment(value: 60, label: Text('שעה')),
                      ButtonSegment(value: 90, label: Text('שעה וחצי')),
                    ],
                    selected: {_durationMinutes},
                    onSelectionChanged: (value) =>
                        setState(() => _durationMinutes = value.first),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _locationController,
                    decoration: const InputDecoration(
                      labelText: 'כתובת / מיקום',
                    ),
                  ),
                ],
                if (widget.kind == WorkItemKind.quote) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _amountController,
                    decoration: const InputDecoration(labelText: 'סכום משוער'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(labelText: _descriptionField),
                  minLines: 2,
                  maxLines: 5,
                  validator: widget.kind == WorkItemKind.note
                      ? _required
                      : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _title {
    final prefix = widget.existingItem == null ? '' : 'עריכת ';
    return switch (widget.kind) {
      WorkItemKind.reminder => '$prefixתזכורת',
      WorkItemKind.homeVisit => '$prefixביקור בית',
      WorkItemKind.appointment => '$prefixפגישה',
      WorkItemKind.quote => '$prefixהצעת מחיר',
      WorkItemKind.note => '$prefixהערה',
    };
  }

  String get _titleField {
    return switch (widget.kind) {
      WorkItemKind.reminder => 'מה צריך לעשות?',
      WorkItemKind.homeVisit => 'כותרת ביקור',
      WorkItemKind.appointment => 'נושא הפגישה',
      WorkItemKind.quote => 'נושא ההצעה',
      WorkItemKind.note => '',
    };
  }

  String get _descriptionField {
    return switch (widget.kind) {
      WorkItemKind.reminder => 'הערות',
      WorkItemKind.homeVisit => 'הערות לביקור',
      WorkItemKind.appointment => 'הערות לפגישה',
      WorkItemKind.quote => 'תיאור העבודה',
      WorkItemKind.note => 'תוכן ההערה',
    };
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'שדה חובה' : null;
  }

  Future<void> _resolveInitialCustomer() async {
    if (_selectedCustomer != null) return;
    final customerId = _initialCustomerId;
    final customerName = _initialCustomerName?.trim();
    if ((customerId == null || customerId.isEmpty) &&
        (customerName == null || customerName.isEmpty)) {
      return;
    }
    final session = widget.controller.session!;
    setState(() => _resolvingCustomer = true);
    try {
      final Customer? selectedCustomer;
      if (customerId != null && customerId.isNotEmpty) {
        selectedCustomer = await widget.controller.apiClient.customers.get(
          businessId: session.businessId!,
          customerId: customerId,
          firebaseUid: session.firebaseUid,
          mockPhoneNumber: session.mockPhoneNumber,
        );
      } else {
        final page = await widget.controller.apiClient.customers.search(
          businessId: session.businessId!,
          firebaseUid: session.firebaseUid,
          mockPhoneNumber: session.mockPhoneNumber,
          query: customerName!,
          limit: 20,
        );
        final exactMatches = page.items
            .where((customer) => customer.name.trim() == customerName)
            .toList();
        selectedCustomer = exactMatches.length == 1 ? exactMatches.first : null;
      }
      if (!mounted) return;
      setState(() {
        _selectedCustomer = selectedCustomer;
        _resolvingCustomer = false;
      });
    } catch (_) {
      if (mounted) setState(() => _resolvingCustomer = false);
    }
  }

  Future<void> _showCustomerActions() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.person_search_outlined),
              title: const Text('בחר לקוח קיים'),
              onTap: () => Navigator.of(context).pop('pick'),
            ),
            ListTile(
              leading: const Icon(Icons.person_add_outlined),
              title: const Text('הוסף לקוח חדש'),
              onTap: () => Navigator.of(context).pop('create'),
            ),
            if (_selectedCustomer != null)
              ListTile(
                leading: const Icon(Icons.link_off),
                title: const Text('הסר שיוך ללקוח'),
                onTap: () => Navigator.of(context).pop('clear'),
              ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'create') {
      await _createCustomer();
    } else if (action == 'pick') {
      final customer = await Navigator.of(context).push<Customer>(
        MaterialPageRoute(
          builder: (_) => CustomerPickerScreen(controller: widget.controller),
        ),
      );
      if (customer != null && mounted) {
        setState(() => _selectedCustomer = customer);
      }
    } else if (action == 'clear') {
      setState(() => _selectedCustomer = null);
    }
  }

  Future<void> _createCustomer() async {
    final customer = await Navigator.of(context).push<Object?>(
      MaterialPageRoute(
        builder: (_) => CustomerFormScreen(
          controller: widget.controller,
          returnCreatedCustomer: true,
        ),
      ),
    );
    if (customer is! Customer) return;
    setState(() => _selectedCustomer = customer);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    if (!_hasUnsavedChanges && widget.aiPendingActionId == null) {
      Navigator.of(context).pop(false);
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (widget.kind == WorkItemKind.note && _selectedCustomer == null) {
      setState(() => _error = 'יש לבחור לקוח עבור ההערה.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    final session = widget.controller.session!;
    final body = _workItemPayload();

    try {
      if (widget.aiPendingActionId != null) {
        await widget.controller.apiClient.aiActions.approve(
          businessId: session.businessId!,
          aiPendingActionId: widget.aiPendingActionId!,
          firebaseUid: session.firebaseUid,
          mockPhoneNumber: session.mockPhoneNumber,
          payload: _withoutNulls(body),
        );
      } else {
        final type = _crmTypeFor(widget.kind);
        if (type != null) {
          if (widget.existingItem == null) {
            await widget.controller.apiClient.workItems.create(
              type: type,
              businessId: session.businessId!,
              firebaseUid: session.firebaseUid,
              mockPhoneNumber: session.mockPhoneNumber,
              body: _withoutNulls(body),
            );
          } else {
            await widget.controller.apiClient.workItems.update(
              type: type,
              businessId: session.businessId!,
              itemId: widget.existingItem!.id,
              firebaseUid: session.firebaseUid,
              mockPhoneNumber: session.mockPhoneNumber,
              body: body,
            );
          }
        } else {
          final customerId = _selectedCustomer!.id;
          if (widget.existingItem == null) {
            await widget.controller.apiClient.notes.create(
              businessId: session.businessId!,
              customerId: customerId,
              firebaseUid: session.firebaseUid,
              mockPhoneNumber: session.mockPhoneNumber,
              text: _descriptionController.text,
            );
          } else {
            await widget.controller.apiClient.notes.update(
              businessId: session.businessId!,
              customerId: customerId,
              noteId: widget.existingItem!.id,
              firebaseUid: session.firebaseUid,
              mockPhoneNumber: session.mockPhoneNumber,
              body: _withoutNulls(body),
            );
          }
        }
      }
      widget.controller.markDataChanged();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  CrmWorkItemType? _crmTypeFor(WorkItemKind kind) => switch (kind) {
    WorkItemKind.reminder => CrmWorkItemType.reminder,
    WorkItemKind.homeVisit => CrmWorkItemType.homeVisit,
    WorkItemKind.appointment => CrmWorkItemType.appointment,
    WorkItemKind.quote => CrmWorkItemType.quote,
    WorkItemKind.note => null,
  };

  Future<void> _cancel() async {
    if (_saving) return;
    if (!_hasUnsavedChanges) {
      Navigator.of(context).pop(false);
      return;
    }

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('לשמור את השינויים?'),
        content: const Text('יש שינויים שלא נשמרו במסמך הזה.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('לא'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('כן'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (shouldSave == true) {
      await _save();
    } else if (shouldSave == false) {
      Navigator.of(context).pop(false);
    }
  }

  String? _nullableText(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  Map<String, Object?> _workItemPayload() {
    final dueAt = combineDateAndTime(_date, _time.hour, _time.minute);
    final dueAtIso = dueAt.toUtc().toIso8601String();
    final customerId = _selectedCustomer?.id;
    return switch (widget.kind) {
      WorkItemKind.reminder => {
        'title': _titleController.text.trim(),
        'dueAt': dueAtIso,
        'priority': _priority,
        'customerId': customerId,
        'description': _nullableText(_descriptionController),
        'status': _status,
      },
      WorkItemKind.homeVisit => {
        'title': _titleController.text.trim(),
        'startsAt': dueAtIso,
        'endsAt': dueAt
            .add(Duration(minutes: _durationMinutes))
            .toUtc()
            .toIso8601String(),
        'customerId': customerId,
        'location': _nullableText(_locationController),
        'notes': _nullableText(_descriptionController),
        'status': _status,
      },
      WorkItemKind.appointment => {
        'title': _titleController.text.trim(),
        'startsAt': dueAtIso,
        'endsAt': dueAt
            .add(Duration(minutes: _durationMinutes))
            .toUtc()
            .toIso8601String(),
        'customerId': customerId,
        'location': _nullableText(_locationController),
        'notes': _nullableText(_descriptionController),
        'status': _status,
      },
      WorkItemKind.quote => {
        'title': _titleController.text.trim(),
        'dueAt': dueAtIso,
        'customerId': customerId,
        'description': _nullableText(_descriptionController),
        'estimatedAmount': _nullableText(_amountController),
        'status': _status,
      },
      WorkItemKind.note => {
        'text': _descriptionController.text.trim(),
        'status': _status,
      },
    };
  }

  Map<String, Object?> _withoutNulls(Map<String, Object?> body) {
    return Map.fromEntries(body.entries.where((entry) => entry.value != null));
  }

  bool get _hasUnsavedChanges => _formSnapshot() != _initialSnapshot;

  String _formSnapshot() {
    final payload = _withoutNulls(_workItemPayload());
    final entries =
        payload.entries.map((entry) => '${entry.key}:${entry.value}').toList()
          ..sort();
    return entries.join('|');
  }

  List<_StatusOption> get _statusOptions {
    return switch (widget.kind) {
      WorkItemKind.reminder => const [
        _StatusOption('OPEN', 'פתוח'),
        _StatusOption('DONE', 'בוצע'),
        _StatusOption('CANCELLED', 'בוטלה'),
      ],
      WorkItemKind.homeVisit => const [
        _StatusOption('OPEN', 'פתוח'),
        _StatusOption('DONE', 'בוצע'),
        _StatusOption('CANCELLED', 'בוטל'),
      ],
      WorkItemKind.appointment => const [
        _StatusOption('OPEN', 'פתוח'),
        _StatusOption('DONE', 'בוצע'),
        _StatusOption('CANCELLED', 'בוטל'),
      ],
      WorkItemKind.quote => const [
        _StatusOption('OPEN', 'פתוחה'),
        _StatusOption('PAID', 'שולמה'),
        _StatusOption('CANCELLED', 'בוטלה'),
      ],
      WorkItemKind.note => const [
        _StatusOption('OPEN', 'פתוחה'),
        _StatusOption('DONE', 'בוצעה'),
        _StatusOption('CANCELLED', 'בוטלה'),
      ],
    };
  }

  String _normalizeStatus(String? status) {
    final normalized = status?.toUpperCase();
    if (normalized == 'CANCELLED') return 'CANCELLED';
    if (widget.kind == WorkItemKind.quote && normalized == 'PAID') {
      return 'PAID';
    }
    if (widget.kind != WorkItemKind.quote && normalized == 'DONE') {
      return 'DONE';
    }
    return 'OPEN';
  }
}
