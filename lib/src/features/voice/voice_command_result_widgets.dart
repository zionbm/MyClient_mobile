import 'package:flutter/material.dart';

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
                label: const Text('בצע פעולה'),
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
                _VoiceStatusBadge(
                  status: item.status,
                  missingFields: item.missingFields,
                ),
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
                    textDirection: TextDirection.rtl,
                    children: [
                      Text(
                        '${field.label}:',
                        textAlign: TextAlign.end,
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            field.value,
                            textAlign: TextAlign.left,
                            style: TextStyle(
                              color: field.missing ? colorScheme.error : null,
                              fontWeight: field.missing
                                  ? FontWeight.w700
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (item.status == 'pending') ...[
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (onTap != null)
                    TextButton.icon(
                      onPressed: submitting ? null : onTap,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('פתח וערוך'),
                    ),
                  if (onReject != null)
                    TextButton.icon(
                      onPressed: submitting ? null : onReject,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('מחיקה'),
                    ),
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
                      label: Text(submitting ? 'שומר...' : 'בצע פעולה'),
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

class _VoiceStatusBadge extends StatelessWidget {
  const _VoiceStatusBadge({required this.status, required this.missingFields});

  final String status;
  final List<String> missingFields;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
