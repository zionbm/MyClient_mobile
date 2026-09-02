import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../utils/json_read.dart';
import 'voice_command_result.dart';

class VoicePayloadEditorSheet extends StatefulWidget {
  const VoicePayloadEditorSheet({super.key, required this.item});

  final VoiceCommandResultItem item;

  @override
  State<VoicePayloadEditorSheet> createState() =>
      _VoicePayloadEditorSheetState();
}

class _VoicePayloadEditorSheetState extends State<VoicePayloadEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    final keys = <String>{
      ..._defaultFieldsFor(widget.item.actionType),
      ...widget.item.payload.keys,
      ...widget.item.missingFields,
    }..removeWhere(isVoiceTechnicalField);
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
      child: ColoredBox(
        color: AppColors.background,
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 10,
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 720),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.edit_note_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.item.title,
                              style: const TextStyle(
                                color: AppColors.ink,
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'אפשר לשנות את הפרטים לפני האישור',
                              style: TextStyle(color: AppColors.muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.check),
                  label: const Text(
                    'בצע פעולה',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('ביטול'),
                  ),
                ),
              ],
            ),
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
        'CREATE_TASK' || 'UPDATE_TASK' => const ['title'],
        'CREATE_JOB' ||
        'UPDATE_JOB' ||
        'CREATE_VISIT' ||
        'UPDATE_VISIT' => const ['title', 'customerId'],
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
      'CREATE_TASK' ||
      'UPDATE_TASK' => ['title', 'name', 'customerId', 'dueAt', 'description'],
      'CREATE_JOB' || 'UPDATE_JOB' || 'CREATE_VISIT' || 'UPDATE_VISIT' => [
        'title',
        'name',
        'customerId',
        'startsAt',
        'endsAt',
        'locationSnapshot',
        'description',
      ],
      'CREATE_NOTE' || 'UPDATE_NOTE' => ['customerId', 'name', 'text'],
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
      'customerName' => 'שם לקוח',
      'appointmentId' => 'פגישה',
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

class VoiceResultItemCard extends StatelessWidget {
  const VoiceResultItemCard({
    super.key,
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
    final pending = item.status == 'pending';
    final accent = _accentForKind(item.kind);
    final card = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: pending
              ? AppColors.accent.withValues(alpha: 0.55)
              : AppColors.border,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.13),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_iconForKind(item.kind), color: accent),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (item.subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          item.subtitle!,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _VoiceStatusBadge(
                  status: item.status,
                  missingFields: item.missingFields,
                ),
              ],
            ),
            if (item.fields.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 6),
              ...item.fields.map(
                (field) => Padding(
                  padding: const EdgeInsets.only(top: 9),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 88,
                        child: Text(
                          field.label,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          field.value,
                          style: TextStyle(
                            color: field.missing
                                ? Theme.of(context).colorScheme.error
                                : AppColors.ink,
                            fontWeight: field.missing
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (item.status == 'pending') ...[
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.start,
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (onTap != null)
                    OutlinedButton.icon(
                      onPressed: submitting ? null : onTap,
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(
                        isExistingVoiceWorkItemAction(item.actionType)
                            ? 'פתח וערוך'
                            : 'עריכה',
                      ),
                    ),
                  if (onReject != null)
                    TextButton.icon(
                      onPressed: submitting ? null : onReject,
                      icon: const Icon(Icons.delete_outline),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.accent,
                      ),
                      label: const Text('דחייה'),
                    ),
                  if (onApprove != null)
                    FilledButton.icon(
                      onPressed: submitting ? null : onApprove,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      icon: submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: Text(
                        submitting
                            ? 'שומר...'
                            : voiceApprovalLabel(item.actionType),
                      ),
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
        borderRadius: BorderRadius.circular(20),
        onTap: submitting ? null : onTap,
        child: card,
      ),
    );
  }

  IconData _iconForKind(String kind) {
    return switch (kind) {
      'customer' => Icons.person_outline,
      'home_visit' => Icons.event_available_outlined,
      'appointment' => Icons.event_outlined,
      'quote' => Icons.request_quote_outlined,
      'note' => Icons.sticky_note_2_outlined,
      'reminder' => Icons.alarm_outlined,
      _ => Icons.auto_awesome_outlined,
    };
  }

  Color _accentForKind(String kind) {
    return switch (kind) {
      'home_visit' || 'appointment' => AppColors.visit,
      'quote' => AppColors.quote,
      'customer' => AppColors.primary,
      _ => AppColors.accent,
    };
  }
}

class _VoiceStatusBadge extends StatelessWidget {
  const _VoiceStatusBadge({required this.status, required this.missingFields});

  final String status;
  final List<String> missingFields;

  @override
  Widget build(BuildContext context) {
    final pending = status == 'pending';
    final failed = status == 'failed';
    final label = pending
        ? missingFields.isEmpty
              ? 'לאישור'
              : 'צריך השלמה'
        : failed
        ? 'לא בוצע'
        : 'בוצע';
    final color = failed
        ? Theme.of(context).colorScheme.error
        : pending
        ? AppColors.accent
        : AppColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: color.withValues(alpha: 0.12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
