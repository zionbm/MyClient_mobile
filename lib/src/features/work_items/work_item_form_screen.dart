import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../models/customer.dart';
import '../../models/work_item.dart';
import '../../utils/date_formatting.dart';
import '../auth/session_controller.dart';
import '../customers/customer_form_screen.dart';

enum WorkItemKind { callback, homeVisit, quote }

class WorkItemFormScreen extends StatefulWidget {
  const WorkItemFormScreen({
    super.key,
    required this.controller,
    required this.kind,
    this.initialCustomer,
    this.existingItem,
  });

  final SessionController controller;
  final WorkItemKind kind;
  final Customer? initialCustomer;
  final WorkItem? existingItem;

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
  List<Customer> _customers = const [];
  bool _loadingCustomers = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingItem;
    _selectedCustomer = widget.initialCustomer ?? existing?.customer;
    if (existing != null) {
      _titleController.text = existing.title;
      _descriptionController.text = widget.kind == WorkItemKind.homeVisit
          ? existing.notes ?? existing.description ?? ''
          : existing.description ?? '';
      _locationController.text = existing.location ?? '';
      _priority = existing.priority ?? 'NORMAL';
      _status = _normalizeStatus(existing.status);
      if (existing.dueAt != null) {
        final dueAt = existing.dueAt!.toLocal();
        _date = DateTime(dueAt.year, dueAt.month, dueAt.day);
        _time = TimeOfDay(hour: dueAt.hour, minute: dueAt.minute);
      }
    }
    _loadCustomers();
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
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(labelText: _titleField),
                textInputAction: TextInputAction.next,
                validator: _required,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _selectedCustomer?.id,
                decoration: const InputDecoration(labelText: 'לקוח משויך'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('ללא לקוח'),
                  ),
                  const DropdownMenuItem<String?>(
                    value: '__new_customer__',
                    child: Text('הוסף לקוח חדש'),
                  ),
                  ..._customers.map(
                    (customer) => DropdownMenuItem<String?>(
                      value: customer.id,
                      child: Text(customer.name),
                    ),
                  ),
                ],
                onChanged: widget.initialCustomer == null && !_loadingCustomers
                    ? (value) async {
                        if (value == '__new_customer__') {
                          await _createCustomer();
                          return;
                        }
                        setState(() {
                          _selectedCustomer = value == null
                              ? null
                              : _customers.firstWhere(
                                  (customer) => customer.id == value,
                                );
                        });
                      }
                    : null,
              ),
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
              if (widget.kind == WorkItemKind.callback) ...[
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
              if (widget.kind == WorkItemKind.homeVisit) ...[
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
                  decoration: const InputDecoration(labelText: 'כתובת / מיקום'),
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
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_saveLabel),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _saving
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: const Text('ביטול'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _title {
    final prefix = widget.existingItem == null ? '' : 'עריכת ';
    return switch (widget.kind) {
      WorkItemKind.callback => '$prefixתזכורת / חזרה ללקוח',
      WorkItemKind.homeVisit => '$prefixביקור בית',
      WorkItemKind.quote => '$prefixהצעת מחיר',
    };
  }

  String get _titleField {
    return switch (widget.kind) {
      WorkItemKind.callback => 'מה צריך לעשות?',
      WorkItemKind.homeVisit => 'כותרת ביקור',
      WorkItemKind.quote => 'נושא ההצעה',
    };
  }

  String get _descriptionField {
    return switch (widget.kind) {
      WorkItemKind.callback => 'הערות',
      WorkItemKind.homeVisit => 'הערות לביקור',
      WorkItemKind.quote => 'תיאור העבודה',
    };
  }

  String get _saveLabel {
    if (widget.existingItem != null) return 'שמור שינויים';
    return switch (widget.kind) {
      WorkItemKind.callback => 'צור תזכורת',
      WorkItemKind.homeVisit => 'צור ביקור',
      WorkItemKind.quote => 'צור הצעה',
    };
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'שדה חובה' : null;
  }

  Future<void> _loadCustomers() async {
    final session = widget.controller.session!;
    try {
      final json = await widget.controller.apiClient.listCustomers(
        businessId: session.businessId!,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
      );
      final customers =
          (json['customers'] as List?)
              ?.whereType<Map<String, Object?>>()
              .map(Customer.fromJson)
              .toList() ??
          const <Customer>[];
      if (!mounted) return;
      setState(() {
        _customers = customers;
        _loadingCustomers = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingCustomers = false);
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
    setState(() {
      _customers = [
        customer,
        ..._customers.where((existing) => existing.id != customer.id),
      ];
      _selectedCustomer = customer;
    });
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
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final session = widget.controller.session!;
    final dueAt = combineDateAndTime(_date, _time.hour, _time.minute);
    final dueAtIso = dueAt.toUtc().toIso8601String();
    final customerId = _selectedCustomer?.id;

    try {
      switch (widget.kind) {
        case WorkItemKind.callback:
          final body = {
            'title': _titleController.text.trim(),
            'dueAt': dueAtIso,
            'priority': _priority,
            'customerId': customerId,
            'description': _nullableText(_descriptionController),
            'status': _status,
          };
          if (widget.existingItem == null) {
            await widget.controller.apiClient.createCallback(
              businessId: session.businessId!,
              firebaseUid: session.firebaseUid,
              mockPhoneNumber: session.mockPhoneNumber,
              body: _withoutNulls(body),
            );
          } else {
            await widget.controller.apiClient.updateCallback(
              businessId: session.businessId!,
              callbackId: widget.existingItem!.id,
              firebaseUid: session.firebaseUid,
              mockPhoneNumber: session.mockPhoneNumber,
              body: body,
            );
          }
        case WorkItemKind.homeVisit:
          final body = {
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
          };
          if (widget.existingItem == null) {
            await widget.controller.apiClient.createHomeVisit(
              businessId: session.businessId!,
              firebaseUid: session.firebaseUid,
              mockPhoneNumber: session.mockPhoneNumber,
              body: _withoutNulls(body),
            );
          } else {
            await widget.controller.apiClient.updateHomeVisit(
              businessId: session.businessId!,
              homeVisitId: widget.existingItem!.id,
              firebaseUid: session.firebaseUid,
              mockPhoneNumber: session.mockPhoneNumber,
              body: body,
            );
          }
        case WorkItemKind.quote:
          final body = {
            'title': _titleController.text.trim(),
            'dueAt': dueAtIso,
            'customerId': customerId,
            'description': _nullableText(_descriptionController),
            'estimatedAmount': _nullableText(_amountController),
            'status': _status,
          };
          if (widget.existingItem == null) {
            await widget.controller.apiClient.createQuote(
              businessId: session.businessId!,
              firebaseUid: session.firebaseUid,
              mockPhoneNumber: session.mockPhoneNumber,
              body: _withoutNulls(body),
            );
          } else {
            await widget.controller.apiClient.updateQuote(
              businessId: session.businessId!,
              quoteId: widget.existingItem!.id,
              firebaseUid: session.firebaseUid,
              mockPhoneNumber: session.mockPhoneNumber,
              body: body,
            );
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

  String? _nullableText(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  Map<String, Object?> _withoutNulls(Map<String, Object?> body) {
    return Map.fromEntries(body.entries.where((entry) => entry.value != null));
  }

  List<_StatusOption> get _statusOptions {
    return switch (widget.kind) {
      WorkItemKind.callback => const [
        _StatusOption('OPEN', 'פתוח'),
        _StatusOption('DONE', 'בוצע'),
      ],
      WorkItemKind.homeVisit => const [
        _StatusOption('OPEN', 'פתוח'),
        _StatusOption('DONE', 'בוצע'),
      ],
      WorkItemKind.quote => const [
        _StatusOption('OPEN', 'פתוחה'),
        _StatusOption('PAID', 'שולמה'),
      ],
    };
  }

  String _normalizeStatus(String? status) {
    final normalized = status?.toUpperCase();
    if (widget.kind == WorkItemKind.quote && normalized == 'PAID') {
      return 'PAID';
    }
    if (widget.kind != WorkItemKind.quote &&
        (normalized == 'DONE' || normalized == 'COMPLETED')) {
      return 'DONE';
    }
    return 'OPEN';
  }
}

class _StatusOption {
  const _StatusOption(this.value, this.label);

  final String value;
  final String label;
}
