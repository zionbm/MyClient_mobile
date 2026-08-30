part of 'customer_detail_screen.dart';

class _CustomerDetail {
  const _CustomerDetail({required this.customer, required this.activity});

  final Customer customer;
  final List<WorkItem> activity;

  List<WorkItem> get openActivity =>
      activity.where((item) => !item.isFinished).toList();

  List<WorkItem> get doneActivity =>
      activity.where((item) => item.isFinished).toList();
}

class _MergeFieldConflict {
  const _MergeFieldConflict({
    required this.field,
    required this.label,
    required this.sourceValue,
    required this.targetValue,
  });

  final String field;
  final String label;
  final String sourceValue;
  final String targetValue;

  static _MergeFieldConflict? fromValues({
    required String field,
    required String label,
    required String? sourceValue,
    required String? targetValue,
  }) {
    final source = sourceValue?.trim();
    final target = targetValue?.trim();
    if (source == null || source.isEmpty || target == null || target.isEmpty) {
      return null;
    }
    if (source == target) return null;
    return _MergeFieldConflict(
      field: field,
      label: label,
      sourceValue: source,
      targetValue: target,
    );
  }
}

class _CustomerHeader extends StatelessWidget {
  const _CustomerHeader({
    required this.customer,
    required this.controller,
    required this.onSaveField,
  });

  final Customer customer;
  final SessionController controller;
  final Future<bool> Function(String field, String value) onSaveField;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _EditableCustomerField(
              label: 'שם',
              value: customer.name,
              field: 'name',
              icon: Icons.person_outline,
              onSave: onSaveField,
            ),
            const SizedBox(height: 8),
            _EditableCustomerField(
              label: 'טלפון',
              value: customer.phone ?? '',
              field: 'phone',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              phonePickerController: controller,
              onSave: onSaveField,
            ),
            const SizedBox(height: 8),
            _EditableCustomerField(
              label: 'אימייל',
              value: customer.email ?? '',
              field: 'email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              onSave: onSaveField,
            ),
            const SizedBox(height: 8),
            _EditableCustomerField(
              label: 'כתובת',
              value: customer.address ?? '',
              field: 'address',
              icon: Icons.location_on_outlined,
              onSave: onSaveField,
            ),
          ],
        ),
      ),
    );
  }
}

class _EditableCustomerField extends StatefulWidget {
  const _EditableCustomerField({
    required this.label,
    required this.value,
    required this.field,
    required this.icon,
    required this.onSave,
    this.keyboardType,
    this.phonePickerController,
  });

  final String label;
  final String value;
  final String field;
  final IconData icon;
  final TextInputType? keyboardType;
  final SessionController? phonePickerController;
  final Future<bool> Function(String field, String value) onSave;

  @override
  State<_EditableCustomerField> createState() => _EditableCustomerFieldState();
}

class _EditableCustomerFieldState extends State<_EditableCustomerField> {
  late final TextEditingController _controller;
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _EditableCustomerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && oldWidget.value != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      readOnly: !_editing || _saving,
      keyboardType: widget.keyboardType,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        labelText: widget.label,
        prefixIcon: Icon(widget.icon),
        prefixIconConstraints: const BoxConstraints(minWidth: 40),
        suffixIcon: _buildSuffix(),
      ),
      onSubmitted: (_) {
        if (_editing && !_saving) _toggleOrSave();
      },
    );
  }

  Widget _buildSuffix() {
    final editButton = IconButton(
      tooltip: _editing ? 'שמור' : 'ערוך',
      onPressed: _saving ? null : _toggleOrSave,
      icon: _saving
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(_editing ? Icons.check : Icons.edit_outlined),
    );
    final pickerController = widget.phonePickerController;
    if (!_editing || widget.field != 'phone' || pickerController == null) {
      return editButton;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PhoneSourceIconButtons(
          onBusinessCalls: () => _pickPhoneFromCalls(pickerController),
          onContacts: _pickPhoneFromContacts,
        ),
        editButton,
      ],
    );
  }

  Future<void> _pickPhoneFromCalls(SessionController controller) async {
    final phone = await pickPhoneFromBusinessCalls(
      context: context,
      controller: controller,
    );
    if (phone == null || !mounted) return;
    setState(() => _controller.text = phone);
  }

  Future<void> _pickPhoneFromContacts() async {
    final phone = await pickPhoneFromDeviceContacts(context);
    if (phone == null || !mounted) return;
    setState(() => _controller.text = phone);
  }

  Future<void> _toggleOrSave() async {
    if (!_editing) {
      setState(() => _editing = true);
      return;
    }
    if (widget.field == 'name' && _controller.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('שם לקוח הוא שדה חובה')));
      return;
    }
    setState(() => _saving = true);
    final saved = await widget.onSave(widget.field, _controller.text);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (saved) _editing = false;
    });
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({
    required this.onReminder,
    required this.onHomeVisit,
    required this.onAppointment,
    required this.onQuote,
    required this.onNote,
  });

  final VoidCallback onReminder;
  final VoidCallback onHomeVisit;
  final VoidCallback onAppointment;
  final VoidCallback onQuote;
  final VoidCallback onNote;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed: onReminder,
          icon: const Icon(Icons.alarm),
          label: const Text('תזכורת'),
        ),
        FilledButton.icon(
          onPressed: onHomeVisit,
          icon: const Icon(Icons.home_repair_service_outlined),
          label: const Text('ביקור'),
        ),
        FilledButton.icon(
          onPressed: onAppointment,
          icon: const Icon(Icons.event_outlined),
          label: const Text('פגישה'),
        ),
        FilledButton.icon(
          onPressed: onQuote,
          icon: const Icon(Icons.request_quote_outlined),
          label: const Text('הצעה'),
        ),
        OutlinedButton.icon(
          onPressed: onNote,
          icon: const Icon(Icons.note_add_outlined),
          label: const Text('הערה'),
        ),
      ],
    );
  }
}

class _ActivitySection extends StatelessWidget {
  const _ActivitySection({
    super.key,
    required this.title,
    required this.count,
    required this.expanded,
    required this.emptyText,
    required this.onToggle,
    required this.children,
  });

  final String title;
  final int count;
  final bool expanded;
  final String emptyText;
  final VoidCallback onToggle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(expanded ? Icons.expand_less : Icons.expand_more),
                const SizedBox(width: 4),
                Text(
                  '$title ($count)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          if (children.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(emptyText),
            )
          else
            ...children,
      ],
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.item,
    this.onOpen,
    this.onComplete,
    this.onMarkPaid,
    this.onReopen,
    this.onDelete,
  });

  final WorkItem item;
  final VoidCallback? onOpen;
  final VoidCallback? onComplete;
  final VoidCallback? onMarkPaid;
  final VoidCallback? onReopen;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(8, 2, 8, 6),
        child: Column(
          children: [
            ListTile(
              dense: true,
              visualDensity: const VisualDensity(vertical: -2),
              contentPadding: const EdgeInsetsDirectional.only(
                start: 4,
                end: 4,
              ),
              onTap: onOpen,
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: item.isUrgent
                    ? Theme.of(context).colorScheme.errorContainer
                    : Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  _icon,
                  color: item.isUrgent
                      ? Theme.of(context).colorScheme.onErrorContainer
                      : Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              title: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: _ActivitySubtitle(
                typeLabel: _label,
                dueAt: item.dueAt,
                description: item.description,
              ),
            ),
            if (onComplete != null ||
                onMarkPaid != null ||
                onReopen != null ||
                onDelete != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Wrap(
                  spacing: 4,
                  children: [
                    if (onComplete != null)
                      TextButton.icon(
                        onPressed: onComplete,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.check),
                        label: const Text('בוצע'),
                      ),
                    if (onMarkPaid != null)
                      TextButton.icon(
                        onPressed: onMarkPaid,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.payments_outlined),
                        label: const Text('שולם'),
                      ),
                    if (onReopen != null)
                      TextButton.icon(
                        onPressed: onReopen,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.refresh),
                        label: const Text('פתח מחדש'),
                      ),
                    if (onDelete != null)
                      TextButton.icon(
                        onPressed: onDelete,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('מחק'),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData get _icon {
    return switch (item.type) {
      WorkItemType.reminder => Icons.alarm,
      WorkItemType.homeVisit => Icons.home_repair_service_outlined,
      WorkItemType.appointment => Icons.event_outlined,
      WorkItemType.quote => Icons.request_quote_outlined,
      WorkItemType.note => Icons.note_outlined,
      _ => Icons.task_alt,
    };
  }

  String get _label {
    return switch (item.type) {
      WorkItemType.reminder => 'תזכורת',
      WorkItemType.homeVisit => 'ביקור בית',
      WorkItemType.appointment => 'פגישה',
      WorkItemType.quote => 'הצעת מחיר',
      WorkItemType.note => 'הערה',
      WorkItemType.unknown => 'פריט',
    };
  }
}

class _ActivitySubtitle extends StatelessWidget {
  const _ActivitySubtitle({
    required this.typeLabel,
    required this.dueAt,
    required this.description,
  });

  final String typeLabel;
  final DateTime? dueAt;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    return Wrap(
      spacing: 4,
      runSpacing: 1,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(typeLabel, style: style),
        if (dueAt != null) ...[
          Text('·', style: style),
          Text(formatDateTime(dueAt), style: style),
        ],
        if (description != null) ...[
          Text('·', style: style),
          Text(
            description!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ],
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
