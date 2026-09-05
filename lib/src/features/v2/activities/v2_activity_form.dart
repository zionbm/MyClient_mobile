import 'package:flutter/material.dart';

import '../../../api/api_client.dart';
import '../../../core/network/idempotency_key.dart';
import '../../../models/v2_activity.dart';
import '../../../models/v2_customer.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/json_read.dart';
import '../../auth/session_controller.dart';
import '../widgets/v2_form_sheet.dart';

class V2ActivityForm extends StatefulWidget {
  const V2ActivityForm({
    super.key,
    required this.controller,
    required this.kind,
    required this.initialDate,
    this.activity,
  });
  final SessionController controller;
  final V2ActivityKind kind;
  final DateTime initialDate;
  final V2Activity? activity;

  @override
  State<V2ActivityForm> createState() => _V2ActivityFormState();
}

class _V2ActivityFormState extends State<V2ActivityForm> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  Future<List<V2Customer>>? _customers;
  String? _customerId;
  String? _serviceAddressId;
  DateTime? _startsAt;
  DateTime? _endsAt;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final session = widget.controller.session!;
    final activity = widget.activity;
    if (activity != null) {
      _customerId = activity.customerId;
      _serviceAddressId = activity.serviceAddressId;
      _title.text = activity.title;
      _description.text = activity.description ?? '';
      _startsAt = activity.startsAt?.toLocal();
      _endsAt = activity.endsAt?.toLocal();
    }
    _customers = widget.controller.apiClient.v2Customers
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
  Widget build(BuildContext context) => V2FormSheet(
    title: widget.activity == null
        ? widget.kind == V2ActivityKind.job
              ? 'עבודה חדשה'
              : 'ביקור חדש'
        : 'עריכת ${widget.kind.hebrewLabel}',
    saving: _saving,
    error: _error,
    onSave: _save,
    child: Column(
      children: [
        FutureBuilder<List<V2Customer>>(
          future: _customers,
          builder: (context, snapshot) => DropdownButtonFormField<String>(
            key: ValueKey(
              'activity-customer-${snapshot.connectionState}-$_customerId',
            ),
            initialValue: _customerId,
            decoration: const InputDecoration(
              labelText: 'לקוח *',
              prefixIcon: Icon(Icons.person_outline),
            ),
            items: (snapshot.data ?? const <V2Customer>[])
                .map(
                  (customer) => DropdownMenuItem(
                    value: customer.id,
                    child: Text(customer.name),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() {
              _customerId = value;
              _serviceAddressId = null;
            }),
          ),
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<V2Customer>>(
          future: _customers,
          builder: (context, snapshot) {
            final customers = snapshot.data ?? const <V2Customer>[];
            final selected = customers
                .where((customer) => customer.id == _customerId)
                .firstOrNull;
            final addresses = selected?.addresses ?? const <V2ServiceAddress>[];
            return DropdownButtonFormField<String?>(
              key: ValueKey('activity-address-$_customerId-$_serviceAddressId'),
              initialValue:
                  addresses.any((address) => address.id == _serviceAddressId)
                  ? _serviceAddressId
                  : null,
              decoration: const InputDecoration(
                labelText: 'כתובת שירות (אופציונלי)',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('ללא כתובת'),
                ),
                ...addresses.map(
                  (address) => DropdownMenuItem<String?>(
                    value: address.id,
                    child: Text(address.addressText),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _serviceAddressId = value),
            );
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _title,
          decoration: const InputDecoration(labelText: 'כותרת *'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _description,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(labelText: 'תיאור (אופציונלי)'),
        ),
        const SizedBox(height: 12),
        _ActivityScheduleEditor(
          startsAt: _startsAt,
          endsAt: _endsAt,
          onPickStart: _pickDateTime,
          onPickEnd: _pickEndTime,
          onClear: _startsAt == null
              ? null
              : () => setState(() {
                  _startsAt = null;
                  _endsAt = null;
                }),
        ),
      ],
    ),
  );

  Future<void> _pickDateTime() async {
    final previousDuration = _startsAt != null && _endsAt != null
        ? _endsAt!.difference(_startsAt!)
        : Duration(minutes: widget.kind == V2ActivityKind.job ? 120 : 60);
    final date = await showDatePicker(
      context: context,
      initialDate: widget.initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (time == null) return;
    setState(() {
      _startsAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      _endsAt = _startsAt!.add(previousDuration);
    });
  }

  Future<void> _pickEndTime() async {
    final startsAt = _startsAt;
    if (startsAt == null) return;
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _endsAt ?? startsAt.add(const Duration(hours: 1)),
      ),
    );
    if (selected == null) return;
    var value = DateTime(
      startsAt.year,
      startsAt.month,
      startsAt.day,
      selected.hour,
      selected.minute,
    );
    if (!value.isAfter(startsAt)) value = value.add(const Duration(days: 1));
    setState(() => _endsAt = value);
  }

  Future<void> _save({String? scheduleConflictToken}) async {
    if (_customerId == null || _title.text.trim().isEmpty) {
      setState(() => _error = 'צריך לבחור לקוח ולהוסיף כותרת');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final session = widget.controller.session!;
    try {
      final body = <String, Object?>{
        'customerId': _customerId,
        'title': _title.text.trim(),
        if (widget.activity != null || _description.text.trim().isNotEmpty)
          'description': _description.text.trim().isEmpty
              ? null
              : _description.text.trim(),
        if (widget.activity != null || _startsAt != null)
          'startsAt': _startsAt?.toUtc().toIso8601String(),
        if (widget.activity != null || _endsAt != null)
          'endsAt': _endsAt?.toUtc().toIso8601String(),
        if (widget.activity != null || _serviceAddressId != null)
          'serviceAddressId': _serviceAddressId,
        if (widget.activity != null) 'version': widget.activity!.version,
        'scheduleConflictToken': ?scheduleConflictToken,
      };
      final activity = widget.activity == null
          ? await widget.controller.apiClient.v2Activities.create(
              kind: widget.kind,
              businessId: session.businessId!,
              firebaseUid: session.firebaseUid,
              mockPhoneNumber: session.mockPhoneNumber,
              idempotencyKey: IdempotencyKey.create(
                '${widget.kind.apiPath}_create',
              ),
              body: body,
            )
          : await widget.controller.apiClient.v2Activities.update(
              kind: widget.kind,
              businessId: session.businessId!,
              entityId: widget.activity!.id,
              firebaseUid: session.firebaseUid,
              mockPhoneNumber: session.mockPhoneNumber,
              idempotencyKey: IdempotencyKey.create(
                '${widget.kind.apiPath}_update',
              ),
              body: body,
            );
      if (mounted) Navigator.pop(context, activity);
    } on ApiException catch (error) {
      final envelope = mapValue(error.details);
      final apiError = mapValue(envelope['error']);
      final conflict = mapValue(apiError['details']);
      final token = stringValue(conflict['scheduleConflictToken']);
      if (error.statusCode == 409 &&
          conflict['code'] == 'SCHEDULE_CONFLICT' &&
          token.isNotEmpty &&
          mounted) {
        final conflictCount = (conflict['conflicts'] as List?)?.length ?? 0;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('יש התנגשות בלוח'),
            content: Text(
              conflictCount == 1
                  ? 'כבר קיימת פעילות בזמן הזה. ליצור בכל זאת? האישור תקף לחמש דקות ורק להתנגשות שהוצגה.'
                  : 'קיימות $conflictCount פעילויות בזמן הזה. ליצור בכל זאת? האישור תקף לחמש דקות ורק להתנגשויות שהוצגו.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('חזרה'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('יצירה בכל זאת'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await _save(scheduleConflictToken: token);
        }
      } else if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _ActivityScheduleEditor extends StatelessWidget {
  const _ActivityScheduleEditor({
    required this.startsAt,
    required this.endsAt,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onClear,
  });

  final DateTime? startsAt;
  final DateTime? endsAt;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final start = startsAt;
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'מועד (אופציונלי)',
        prefixIcon: Icon(Icons.schedule_outlined),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: _SchedulePart(
              label: 'תאריך',
              value: start == null ? 'לא נקבע' : _displayDate(start),
              onTap: onPickStart,
            ),
          ),
          Expanded(
            flex: 2,
            child: _SchedulePart(
              label: 'התחלה',
              value: start == null
                  ? '—'
                  : TimeOfDay.fromDateTime(start).format(context),
              onTap: onPickStart,
            ),
          ),
          Expanded(
            flex: 2,
            child: _SchedulePart(
              label: 'סיום',
              value: endsAt == null
                  ? '—'
                  : TimeOfDay.fromDateTime(endsAt!).format(context),
              onTap: start == null ? onPickStart : onPickEnd,
            ),
          ),
          if (onClear != null)
            IconButton(
              tooltip: 'הסרת המועד',
              visualDensity: VisualDensity.compact,
              onPressed: onClear,
              icon: const Icon(Icons.close, size: 20),
            ),
        ],
      ),
    );
  }
}

class _SchedulePart extends StatelessWidget {
  const _SchedulePart({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(8),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    ),
  );
}

String _displayDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
