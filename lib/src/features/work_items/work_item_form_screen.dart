import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../data/repositories/work_item_repository.dart';
import '../../models/customer.dart';
import '../../models/work_item.dart';
import '../../utils/date_formatting.dart';
import '../../utils/json_read.dart';
import '../../utils/work_item_time_defaults.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_confirmation_dialog.dart';
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
    this.pendingActionType,
  });

  final SessionController controller;
  final WorkItemKind kind;
  final Customer? initialCustomer;
  final WorkItem? existingItem;
  final Map<String, Object?>? initialPayload;
  final String? aiPendingActionId;
  final String? pendingActionType;

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
  late WorkItemKind _kind;
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
    _kind = widget.kind;
    final existing = widget.existingItem;
    _selectedCustomer = widget.initialCustomer ?? existing?.customer;
    if (existing != null) {
      _titleController.text = existing.title;
      _descriptionController.text = switch (_kind) {
        WorkItemKind.homeVisit || WorkItemKind.appointment =>
          existing.notes ?? existing.description ?? '',
        _ => existing.description ?? '',
      };
      _locationController.text = existing.location ?? '';
      _priority = existing.priority?.apiValue ?? 'NORMAL';
      _status = _normalizeStatus(existing.status?.apiValue);
      final existingStart = existing.startsAt ?? existing.dueAt;
      if (existingStart != null) {
        final dueAt = existingStart.toLocal();
        _date = DateTime(dueAt.year, dueAt.month, dueAt.day);
        _time = TimeOfDay(hour: dueAt.hour, minute: dueAt.minute);
      }
      if (existing.startsAt != null &&
          existing.endsAt != null &&
          existing.endsAt!.isAfter(existing.startsAt!)) {
        _durationMinutes = existing.endsAt!
            .difference(existing.startsAt!)
            .inMinutes;
      }
    }
    _hydrateFromPayload(widget.initialPayload);
    if (_initialCustomerId != null &&
        _initialCustomerId != existing?.customer?.id) {
      _selectedCustomer = null;
    }
    if (existing == null && !_payloadContainsSchedule(widget.initialPayload)) {
      _setRecommendedStart(DateTime.now());
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
    _descriptionController.text = stringValue(switch (_kind) {
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
        bottomNavigationBar: _FormBottomActions(
          saving: _saving,
          saveLabel: _saveLabel,
          onSave: _save,
          onCancel: _cancel,
        ),
        body: SafeArea(
          top: false,
          child: Form(key: _formKey, child: _buildForm()),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _WorkItemFormHeader(
            title: widget.existingItem == null ? 'פריט חדש' : _title,
            subtitle: widget.pendingActionType == 'DELETE_WORK_ITEM'
                ? 'בדוק את הפרטים לפני אישור המחיקה'
                : widget.aiPendingActionId != null
                ? 'בדוק את הפרטים והסטטוס לפני האישור'
                : widget.existingItem == null
                ? 'מה תרצה להוסיף?'
                : 'כל הפרטים במקום אחד',
            onBack: _cancel,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          sliver: SliverList.list(
            children: [
              _KindSelector(
                selected: _kind,
                enabled: widget.existingItem == null && !_saving,
                onChanged: _changeKind,
              ),
              const SizedBox(height: 18),
              _FormSectionCard(
                children: [
                  _FormFieldLabel(
                    label: _kind == WorkItemKind.note ? 'לקוח *' : 'לקוח',
                  ),
                  _CustomerSelectionTile(
                    customer: _selectedCustomer,
                    resolving: _resolvingCustomer,
                    enabled:
                        widget.initialCustomer == null && !_resolvingCustomer,
                    onTap: _showCustomerActions,
                  ),
                  if (_kind != WorkItemKind.note) ...[
                    const SizedBox(height: 16),
                    _FormFieldLabel(label: _titleField, required: true),
                    TextFormField(
                      controller: _titleController,
                      textInputAction: TextInputAction.next,
                      validator: _required,
                      decoration: const InputDecoration(
                        hintText: 'הוספת כותרת קצרה וברורה',
                      ),
                    ),
                  ],
                ],
              ),
              if (_kind != WorkItemKind.note) ...[
                const SizedBox(height: 18),
                const _FormSectionTitle('מועד'),
                const SizedBox(height: 8),
                _FormSectionCard(
                  children: [
                    _FormDateTile(date: _date, onTap: _pickDate),
                    const SizedBox(height: 12),
                    if (_hasEndTime)
                      Row(
                        children: [
                          Expanded(
                            child: _FormTimeTile(
                              label: 'שעת התחלה',
                              time: _time,
                              onTap: _pickTime,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _FormTimeTile(
                              label: 'שעת סיום',
                              time: _endTime,
                              onTap: _pickEndTime,
                            ),
                          ),
                        ],
                      )
                    else
                      _FormTimeTile(
                        label: 'שעה',
                        time: _time,
                        onTap: _pickTime,
                      ),
                  ],
                ),
              ],
              if (_kind == WorkItemKind.reminder) ...[
                const SizedBox(height: 18),
                const _FormSectionTitle('עדיפות'),
                const SizedBox(height: 8),
                _PrioritySelector(
                  priority: _priority,
                  onChanged: (value) => setState(() => _priority = value),
                ),
              ],
              if (_kind == WorkItemKind.homeVisit ||
                  _kind == WorkItemKind.appointment) ...[
                const SizedBox(height: 18),
                const _FormSectionTitle('מיקום'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    hintText: 'כתובת או מקום (לא חובה)',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
              ],
              if (_kind == WorkItemKind.quote) ...[
                const SizedBox(height: 18),
                const _FormSectionTitle('סכום'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                    hintText: 'סכום משוער',
                    prefixIcon: Icon(Icons.payments_outlined),
                    suffixText: '₪',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              const _FormSectionTitle('פרטים נוספים'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  hintText: _descriptionField,
                  alignLabelWithHint: true,
                ),
                minLines: 3,
                maxLines: 6,
                validator: _kind == WorkItemKind.note ? _required : null,
              ),
              if (widget.existingItem != null) ...[
                const SizedBox(height: 18),
                const _FormSectionTitle('סטטוס'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(),
                  items: _statusOptions
                      .map(
                        (option) => DropdownMenuItem<String>(
                          value: option.value,
                          child: Text(option.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _status = value);
                  },
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String get _title {
    final prefix = widget.existingItem == null ? '' : 'עריכת ';
    return switch (_kind) {
      WorkItemKind.reminder => '$prefixתזכורת',
      WorkItemKind.homeVisit => '$prefixביקור בית',
      WorkItemKind.appointment => '$prefixפגישה',
      WorkItemKind.quote => '$prefixהצעת מחיר',
      WorkItemKind.note => '$prefixהערה',
    };
  }

  String get _titleField {
    return switch (_kind) {
      WorkItemKind.reminder => 'מה צריך לעשות?',
      WorkItemKind.homeVisit => 'כותרת ביקור',
      WorkItemKind.appointment => 'נושא הפגישה',
      WorkItemKind.quote => 'נושא ההצעה',
      WorkItemKind.note => '',
    };
  }

  String get _descriptionField {
    return switch (_kind) {
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

  bool _payloadContainsSchedule(Map<String, Object?>? payload) {
    if (payload == null) return false;
    return nullableString(payload['startsAt'] ?? payload['dueAt']) != null;
  }

  void _setRecommendedStart(DateTime selectedDate) {
    final recommended = recommendedWorkItemStart(
      selectedDate: selectedDate,
      now: DateTime.now(),
    );
    _date = DateTime(recommended.year, recommended.month, recommended.day);
    _time = TimeOfDay(hour: recommended.hour, minute: recommended.minute);
  }

  void _changeKind(WorkItemKind kind) {
    if (_kind == kind || widget.existingItem != null) return;
    setState(() {
      _kind = kind;
      _status = 'OPEN';
      _error = null;
      _durationMinutes = 30;
    });
  }

  bool get _hasEndTime =>
      _kind == WorkItemKind.appointment || _kind == WorkItemKind.homeVisit;

  TimeOfDay get _endTime {
    final start = combineDateAndTime(_date, _time.hour, _time.minute);
    return TimeOfDay.fromDateTime(
      start.add(Duration(minutes: _durationMinutes)),
    );
  }

  String get _saveLabel {
    if (widget.pendingActionType == 'DELETE_WORK_ITEM') return 'אישור ומחיקה';
    if (widget.aiPendingActionId != null) return 'אישור ושמירה';
    return switch (_kind) {
      WorkItemKind.reminder => 'שמירת התזכורת',
      WorkItemKind.homeVisit => 'שמירת הביקור',
      WorkItemKind.appointment => 'שמירת הפגישה',
      WorkItemKind.quote => 'שמירת ההצעה',
      WorkItemKind.note => 'שמירת ההערה',
    };
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
    if (picked == null) return;
    setState(() {
      if (widget.existingItem == null) {
        _setRecommendedStart(picked);
        _durationMinutes = 30;
      } else {
        _date = picked;
      }
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) {
      setState(() {
        _time = picked;
        if (_hasEndTime) _durationMinutes = 30;
      });
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked == null) return;
    final start = combineDateAndTime(_date, _time.hour, _time.minute);
    var end = combineDateAndTime(_date, picked.hour, picked.minute);
    if (!end.isAfter(start)) end = end.add(const Duration(days: 1));
    setState(() => _durationMinutes = end.difference(start).inMinutes);
  }

  Future<void> _save() async {
    if (!_hasUnsavedChanges && widget.aiPendingActionId == null) {
      Navigator.of(context).pop(false);
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_kind == WorkItemKind.note && _selectedCustomer == null) {
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
        final approvalPayload = <String, Object?>{
          ...?widget.initialPayload,
          ..._withoutNulls(body),
        };
        await widget.controller.apiClient.aiActions.approve(
          businessId: session.businessId!,
          aiPendingActionId: widget.aiPendingActionId!,
          firebaseUid: session.firebaseUid,
          mockPhoneNumber: session.mockPhoneNumber,
          payload: approvalPayload,
        );
      } else {
        final type = _crmTypeFor(_kind);
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
      if (widget.aiPendingActionId != null) {
        widget.controller.markAiActionResolved();
      } else {
        widget.controller.markDataChanged();
      }
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

    final shouldSave = await showAppConfirmationDialog(
      context: context,
      title: 'לשמור את השינויים?',
      body: 'יש שינויים שלא נשמרו במסמך הזה.',
      cancelLabel: 'יציאה ללא שמירה',
      confirmLabel: 'שמירה',
      icon: Icons.save_outlined,
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
    return switch (_kind) {
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
    return '${_kind.name}|${entries.join('|')}';
  }

  List<_StatusOption> get _statusOptions {
    return switch (_kind) {
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
    if (_kind == WorkItemKind.quote && normalized == 'PAID') {
      return 'PAID';
    }
    if (_kind != WorkItemKind.quote && normalized == 'DONE') {
      return 'DONE';
    }
    return 'OPEN';
  }
}
