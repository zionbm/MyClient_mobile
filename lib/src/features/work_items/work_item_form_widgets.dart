part of 'work_item_form_screen.dart';

class _WorkItemFormHeader extends StatelessWidget {
  const _WorkItemFormHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(34)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          MediaQuery.paddingOf(context).top + 14,
          18,
          26,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              onPressed: onBack,
              color: Colors.white,
              icon: const Icon(Icons.arrow_forward),
              tooltip: 'חזרה',
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KindSelector extends StatelessWidget {
  const _KindSelector({
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final WorkItemKind selected;
  final bool enabled;
  final ValueChanged<WorkItemKind> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: WorkItemKind.values
            .map((kind) {
              final isSelected = kind == selected;
              return Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: ChoiceChip(
                  selected: isSelected,
                  onSelected: enabled ? (_) => onChanged(kind) : null,
                  showCheckmark: false,
                  avatar: Icon(
                    _kindIcon(kind),
                    size: 18,
                    color: isSelected ? Colors.white : AppColors.primary,
                  ),
                  label: Text(_kindLabel(kind)),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.ink,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  selectedColor: AppColors.accent,
                  backgroundColor: Colors.white,
                  disabledColor: isSelected ? AppColors.accent : Colors.white,
                  side: BorderSide(
                    color: isSelected ? AppColors.accent : AppColors.border,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }

  static String _kindLabel(WorkItemKind kind) => switch (kind) {
    WorkItemKind.reminder => 'תזכורת',
    WorkItemKind.appointment => 'פגישה',
    WorkItemKind.homeVisit => 'ביקור בית',
    WorkItemKind.quote => 'הצעת מחיר',
    WorkItemKind.note => 'הערה',
  };

  static IconData _kindIcon(WorkItemKind kind) => switch (kind) {
    WorkItemKind.reminder => Icons.notifications_none,
    WorkItemKind.appointment => Icons.event_outlined,
    WorkItemKind.homeVisit => Icons.home_outlined,
    WorkItemKind.quote => Icons.request_quote_outlined,
    WorkItemKind.note => Icons.notes_outlined,
  };
}

class _FormSectionTitle extends StatelessWidget {
  const _FormSectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        color: AppColors.ink,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _FormSectionCard extends StatelessWidget {
  const _FormSectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _FormFieldLabel extends StatelessWidget {
  const _FormFieldLabel({required this.label, this.required = false});

  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text.rich(
        TextSpan(
          text: label,
          children: required
              ? const [
                  TextSpan(
                    text: ' *',
                    style: TextStyle(color: AppColors.accent),
                  ),
                ]
              : const [],
        ),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.muted,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CustomerSelectionTile extends StatelessWidget {
  const _CustomerSelectionTile({
    required this.customer,
    required this.resolving,
    required this.enabled,
    required this.onTap,
  });

  final Customer? customer;
  final bool resolving;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = customer?.name ?? 'בחירת לקוח';
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFFD7EEEE),
              foregroundColor: AppColors.primary,
              child: resolving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      customer == null
                          ? '+'
                          : customer!.name.trim().characters.first,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (customer?.phone != null)
                    Text(
                      customer!.phone!,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                ],
              ),
            ),
            if (enabled)
              const Icon(Icons.chevron_left, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

class _FormDateTile extends StatelessWidget {
  const _FormDateTile({required this.date, required this.onTap});

  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _FormPickerTile(
      label: 'תאריך',
      value: formatShortDate(date),
      icon: Icons.calendar_month_outlined,
      onTap: onTap,
    );
  }
}

class _FormTimeTile extends StatelessWidget {
  const _FormTimeTile({
    required this.label,
    required this.time,
    required this.onTap,
  });

  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _FormPickerTile(
      label: label,
      value: time.format(context),
      icon: Icons.schedule,
      onTap: onTap,
    );
  }
}

class _FormPickerTile extends StatelessWidget {
  const _FormPickerTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.accent, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_left, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _PrioritySelector extends StatelessWidget {
  const _PrioritySelector({required this.priority, required this.onChanged});

  final String priority;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'NORMAL', label: Text('רגילה')),
        ButtonSegment(
          value: 'URGENT',
          icon: Icon(Icons.priority_high),
          label: Text('דחופה'),
        ),
      ],
      selected: {priority},
      onSelectionChanged: (value) => onChanged(value.first),
      style: ButtonStyle(
        visualDensity: VisualDensity.comfortable,
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

class _FormBottomActions extends StatelessWidget {
  const _FormBottomActions({
    required this.saving,
    required this.saveLabel,
    required this.onSave,
    required this.onCancel,
  });

  final bool saving;
  final String saveLabel;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 8,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 12, 16, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(
              onPressed: saving ? null : onSave,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: saving
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      saveLabel,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
            TextButton(
              onPressed: saving ? null : onCancel,
              child: const Text('ביטול'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusOption {
  const _StatusOption(this.value, this.label);

  final String value;
  final String label;
}
