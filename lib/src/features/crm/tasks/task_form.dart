import 'package:flutter/material.dart';

import '../../../core/network/idempotency_key.dart';
import '../../../core/presentation/user_error_message.dart';
import '../../../models/customer.dart';
import '../../../models/task.dart';
import '../../auth/session_controller.dart';
import '../widgets/form_sheet.dart';

class TaskForm extends StatefulWidget {
  const TaskForm({
    super.key,
    required this.controller,
    this.customerId,
    this.task,
  });
  final SessionController controller;
  final String? customerId;
  final Task? task;

  @override
  State<TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<TaskForm> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _key = IdempotencyKey.create('task_create');
  Future<List<Customer>>? _customers;
  String? _customerId;
  DateTime? _dueAt;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _customerId = task?.customerId ?? widget.customerId;
    if (task != null) {
      _title.text = task.title;
      _description.text = task.description ?? '';
      _dueAt = task.dueAt;
    }
    final session = widget.controller.session!;
    _customers = widget.controller.apiClient.customers
        .list(
          businessId: session.businessId!,
          firebaseUid: session.firebaseUid,
          mockPhoneNumber: session.mockPhoneNumber,
        )
        .then((page) => page.items);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FormSheet(
    title: widget.task != null
        ? 'עריכת משימה'
        : widget.customerId == null
        ? 'משימה כללית'
        : 'משימה ללקוח',
    saving: _saving,
    error: _error,
    onSave: _save,
    child: Column(
      children: [
        FutureBuilder<List<Customer>>(
          future: _customers,
          builder: (context, snapshot) {
            final customers = snapshot.data ?? const <Customer>[];
            return DropdownButtonFormField<String?>(
              key: ValueKey(
                'task-customer-${snapshot.connectionState}-$_customerId',
              ),
              initialValue:
                  customers.any((customer) => customer.id == _customerId)
                  ? _customerId
                  : null,
              decoration: const InputDecoration(
                labelText: 'לקוח (אופציונלי)',
                prefixIcon: Icon(Icons.person_outline),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('משימה כללית — ללא לקוח'),
                ),
                ...customers.map(
                  (customer) => DropdownMenuItem<String?>(
                    value: customer.id,
                    child: Text(customer.name),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _customerId = value),
            );
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _title,
          decoration: const InputDecoration(labelText: 'מה צריך לעשות? *'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _description,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'פרטים נוספים'),
        ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.notifications_active_outlined),
          title: Text(
            _dueAt == null
                ? 'ללא תזכורת'
                : MaterialLocalizations.of(
                    context,
                  ).formatFullDate(_dueAt!.toLocal()),
          ),
          subtitle: _dueAt == null
              ? const Text('אפשר להוסיף תזכורת גם בהמשך')
              : Text(
                  MaterialLocalizations.of(
                    context,
                  ).formatTimeOfDay(TimeOfDay.fromDateTime(_dueAt!.toLocal())),
                ),
          trailing: _dueAt == null
              ? const Icon(Icons.add)
              : IconButton(
                  onPressed: () => setState(() => _dueAt = null),
                  icon: const Icon(Icons.close),
                ),
          onTap: _pickDueAt,
        ),
      ],
    ),
  );

  Future<void> _pickDueAt() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 3),
      initialDate: _dueAt?.toLocal() ?? now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _dueAt == null
          ? const TimeOfDay(hour: 10, minute: 0)
          : TimeOfDay.fromDateTime(_dueAt!.toLocal()),
    );
    if (time == null) return;
    setState(() {
      _dueAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'צריך לכתוב את המשימה');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final session = widget.controller.session!;
    try {
      final body = <String, Object?>{
        if (widget.task != null || _customerId != null)
          'customerId': _customerId,
        'title': _title.text.trim(),
        if (widget.task != null || _description.text.trim().isNotEmpty)
          'description': _description.text.trim().isEmpty
              ? null
              : _description.text.trim(),
        if (widget.task != null || _dueAt != null)
          'dueAt': _dueAt?.toUtc().toIso8601String(),
        if (widget.task != null) 'version': widget.task!.version,
      };
      final task = widget.task == null
          ? await widget.controller.apiClient.tasks.create(
              businessId: session.businessId!,
              firebaseUid: session.firebaseUid,
              mockPhoneNumber: session.mockPhoneNumber,
              idempotencyKey: _key,
              body: body,
            )
          : await widget.controller.apiClient.tasks.update(
              businessId: session.businessId!,
              taskId: widget.task!.id,
              firebaseUid: session.firebaseUid,
              mockPhoneNumber: session.mockPhoneNumber,
              idempotencyKey: _key,
              body: body,
            );
      if (mounted) Navigator.of(context).pop(task);
    } catch (error) {
      if (mounted) setState(() => _error = userErrorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
