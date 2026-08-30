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

class _CustomerDetailHero extends StatelessWidget {
  const _CustomerDetailHero({
    required this.customer,
    required this.onBack,
    required this.onCall,
    required this.onWhatsApp,
    required this.onEdit,
    required this.onMerge,
    required this.onDelete,
  });

  final Customer customer;
  final VoidCallback onBack;
  final VoidCallback? onCall;
  final VoidCallback? onWhatsApp;
  final VoidCallback onEdit;
  final VoidCallback? onMerge;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(34)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'חזרה',
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const Text(
                    'פרטי לקוח',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    tooltip: 'פעולות נוספות',
                    iconColor: Colors.white,
                    onSelected: (value) {
                      if (value == 'merge') onMerge?.call();
                      if (value == 'delete') onDelete?.call();
                    },
                    itemBuilder: (context) => [
                      if (onMerge != null)
                        const PopupMenuItem(
                          value: 'merge',
                          child: ListTile(
                            leading: Icon(Icons.merge_type_outlined),
                            title: Text('מיזוג לקוח'),
                          ),
                        ),
                      if (onDelete != null)
                        const PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            leading: Icon(Icons.delete_outline),
                            title: Text('מחיקת לקוח'),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  CircleAvatar(
                    radius: 42,
                    backgroundColor: const Color(0xFFDDEFF5),
                    child: Text(
                      _initials(customer.name),
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (customer.phone != null)
                          Text(
                            customer.phone!,
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                          ),
                        if (customer.createdAt != null)
                          Text(
                            'לקוחה מאז ${_monthYear(customer.createdAt!)}',
                            style: const TextStyle(
                              color: Color(0xCCFFFFFF),
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _HeroAction(
                    icon: Icons.call_outlined,
                    label: 'שיחה',
                    onPressed: onCall,
                  ),
                  _HeroAction(
                    icon: Icons.chat_bubble_outline,
                    label: 'WhatsApp',
                    onPressed: onWhatsApp,
                  ),
                  _HeroAction(
                    icon: Icons.edit_outlined,
                    label: 'עריכה',
                    onPressed: onEdit,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1);
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}';
  }

  String _monthYear(DateTime value) {
    const months = [
      'ינואר',
      'פברואר',
      'מרץ',
      'אפריל',
      'מאי',
      'יוני',
      'יולי',
      'אוגוסט',
      'ספטמבר',
      'אוקטובר',
      'נובמבר',
      'דצמבר',
    ];
    final local = value.toLocal();
    return '${months[local.month - 1]} ${local.year}';
  }
}

class _HeroAction extends StatelessWidget {
  const _HeroAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: enabled ? Colors.white70 : Colors.white24,
                ),
              ),
              child: Icon(icon, color: enabled ? Colors.white : Colors.white38),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                color: enabled ? Colors.white : Colors.white38,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerHeader extends StatelessWidget {
  const _CustomerHeader({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'פרטי קשר',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            _ContactDetailRow(
              icon: Icons.phone_outlined,
              value: customer.phone,
              textDirection: TextDirection.ltr,
            ),
            const Divider(height: 1),
            _ContactDetailRow(
              icon: Icons.email_outlined,
              value: customer.email,
              textDirection: TextDirection.ltr,
            ),
            const Divider(height: 1),
            _ContactDetailRow(
              icon: Icons.location_on_outlined,
              value: customer.address,
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactDetailRow extends StatelessWidget {
  const _ContactDetailRow({
    required this.icon,
    required this.value,
    this.textDirection,
  });

  final IconData icon;
  final String? value;
  final TextDirection? textDirection;

  @override
  Widget build(BuildContext context) {
    final text = value?.trim();
    final hasValue = text != null && text.isNotEmpty;
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              hasValue ? text : 'לא הוגדר',
              textDirection: hasValue ? textDirection : TextDirection.rtl,
              textAlign: TextAlign.start,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: hasValue ? AppColors.ink : AppColors.muted,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
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
    return Row(
      children: [
        Expanded(
          child: _CreateActivityTile(
            onPressed: onReminder,
            icon: Icons.alarm_outlined,
            label: 'תזכורת',
            color: const Color(0xFFFFE7E2),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _CreateActivityTile(
            onPressed: onHomeVisit,
            icon: Icons.home_repair_service_outlined,
            label: 'ביקור',
            color: const Color(0xFFE4F2ED),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _CreateActivityTile(
            onPressed: onAppointment,
            icon: Icons.event_outlined,
            label: 'פגישה',
            color: const Color(0xFFE7F2F8),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _CreateActivityTile(
            onPressed: onQuote,
            icon: Icons.request_quote_outlined,
            label: 'הצעה',
            color: const Color(0xFFFFF0D5),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _CreateActivityTile(
            onPressed: onNote,
            icon: Icons.note_add_outlined,
            label: 'הערה',
            color: const Color(0xFFF1EAF4),
          ),
        ),
      ],
    );
  }
}

class _CreateActivityTile extends StatelessWidget {
  const _CreateActivityTile({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.color,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        constraints: const BoxConstraints(minHeight: 76),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.primary, size: 23),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
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
        Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: const Color(0xFFE8EFEE),
                    child: Text('$count'),
                  ),
                  const Spacer(),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
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
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 6, color: _accent),
            Expanded(
              child: InkWell(
                onTap: onOpen,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(_icon, size: 19, color: _accent),
                          const SizedBox(width: 6),
                          Text(
                            _label,
                            style: const TextStyle(color: AppColors.muted),
                          ),
                          if (item.dueAt != null) ...[
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                formatDateTime(item.dueAt!),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ] else
                            const Spacer(),
                          PopupMenuButton<String>(
                            tooltip: 'פעולות נוספות',
                            onSelected: (value) {
                              if (value == 'edit') onOpen?.call();
                              if (value == 'delete') onDelete?.call();
                            },
                            itemBuilder: (context) => [
                              if (onOpen != null)
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('עריכה'),
                                ),
                              if (onDelete != null)
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('מחיקה'),
                                ),
                            ],
                          ),
                        ],
                      ),
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (_detail != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _detail!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ],
                      if (onComplete != null ||
                          onMarkPaid != null ||
                          onReopen != null) ...[
                        const SizedBox(height: 9),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: OutlinedButton(
                            onPressed: onComplete ?? onMarkPaid ?? onReopen,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(92, 42),
                            ),
                            child: Text(
                              onComplete != null
                                  ? 'סיום'
                                  : onMarkPaid != null
                                  ? 'סמן כשולם'
                                  : 'פתח מחדש',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color get _accent {
    if (item.isUrgent) return AppColors.accent;
    return switch (item.type) {
      WorkItemType.homeVisit => AppColors.visit,
      WorkItemType.quote => AppColors.quote,
      WorkItemType.appointment => AppColors.primarySoft,
      _ => AppColors.primary,
    };
  }

  String? get _detail {
    final values = [
      item.location,
      item.estimatedAmount == null ? null : '₪${item.estimatedAmount}',
      item.description,
      item.notes,
    ].whereType<String>().where((value) => value.trim().isNotEmpty).toList();
    return values.isEmpty ? null : values.first;
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
