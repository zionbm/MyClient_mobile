import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../models/customer.dart';
import '../../utils/date_formatting.dart';
import '../auth/session_controller.dart';

enum WorkItemKind { callback, homeVisit, quote }

class WorkItemFormScreen extends StatefulWidget {
  const WorkItemFormScreen({
    super.key,
    required this.controller,
    required this.kind,
    this.initialCustomer,
  });

  final SessionController controller;
  final WorkItemKind kind;
  final Customer? initialCustomer;

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
  String _priority = 'NORMAL';
  Customer? _selectedCustomer;
  List<Customer> _customers = const [];
  bool _loadingCustomers = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedCustomer = widget.initialCustomer;
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
                  ..._customers.map(
                    (customer) => DropdownMenuItem<String?>(
                      value: customer.id,
                      child: Text(customer.name),
                    ),
                  ),
                ],
                onChanged: widget.initialCustomer == null && !_loadingCustomers
                    ? (value) {
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
              if (widget.kind == WorkItemKind.homeVisit) ...[
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
    return switch (widget.kind) {
      WorkItemKind.callback => 'תזכורת / חזרה ללקוח',
      WorkItemKind.homeVisit => 'ביקור בית',
      WorkItemKind.quote => 'הצעת מחיר',
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
    final dueAt = combineDateAndTime(
      _date,
      _time.hour,
      _time.minute,
    ).toUtc().toIso8601String();
    final customerId = _selectedCustomer?.id;

    try {
      switch (widget.kind) {
        case WorkItemKind.callback:
          await widget.controller.apiClient.createCallback(
            businessId: session.businessId!,
            firebaseUid: session.firebaseUid,
            mockPhoneNumber: session.mockPhoneNumber,
            body: {
              'title': _titleController.text.trim(),
              'dueAt': dueAt,
              'priority': _priority,
              'customerId': ?customerId,
              if (_descriptionController.text.trim().isNotEmpty)
                'description': _descriptionController.text.trim(),
            },
          );
        case WorkItemKind.homeVisit:
          await widget.controller.apiClient.createHomeVisit(
            businessId: session.businessId!,
            firebaseUid: session.firebaseUid,
            mockPhoneNumber: session.mockPhoneNumber,
            body: {
              'title': _titleController.text.trim(),
              'startsAt': dueAt,
              'customerId': ?customerId,
              if (_locationController.text.trim().isNotEmpty)
                'location': _locationController.text.trim(),
              if (_descriptionController.text.trim().isNotEmpty)
                'notes': _descriptionController.text.trim(),
            },
          );
        case WorkItemKind.quote:
          await widget.controller.apiClient.createQuote(
            businessId: session.businessId!,
            firebaseUid: session.firebaseUid,
            mockPhoneNumber: session.mockPhoneNumber,
            body: {
              'title': _titleController.text.trim(),
              'dueAt': dueAt,
              'customerId': ?customerId,
              if (_descriptionController.text.trim().isNotEmpty)
                'description': _descriptionController.text.trim(),
              if (_amountController.text.trim().isNotEmpty)
                'estimatedAmount': _amountController.text.trim(),
            },
          );
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
}
