part of 'home_screen.dart';

class _HomeHero extends StatelessWidget {
  const _HomeHero({
    required this.displayName,
    required this.businessName,
    required this.selectedDate,
    required this.openCount,
    required this.overdueCount,
    required this.doneCount,
    required this.pendingActionsCountFuture,
    required this.onSearch,
    required this.onNotifications,
    required this.onPendingActions,
  });

  final String? displayName;
  final String? businessName;
  final DateTime selectedDate;
  final int openCount;
  final int overdueCount;
  final int doneCount;
  final Future<int>? pendingActionsCountFuture;
  final VoidCallback onSearch;
  final VoidCallback onNotifications;
  final VoidCallback onPendingActions;

  @override
  Widget build(BuildContext context) {
    final name = displayName?.trim();
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(34)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 25,
                    backgroundColor: Color(0xFFE2F0F1),
                    child: Icon(Icons.person_outline, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name == null || name.isEmpty
                              ? 'בוקר טוב'
                              : 'בוקר טוב, $name',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          businessName ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xCCFFFFFF),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _HeroIconButton(
                    tooltip: 'חיפוש',
                    icon: Icons.search,
                    onPressed: onSearch,
                  ),
                  FutureBuilder<int>(
                    future: pendingActionsCountFuture,
                    builder: (context, snapshot) => _HeroIconButton(
                      tooltip: 'פעולות AI',
                      icon: Icons.auto_awesome_outlined,
                      badge: snapshot.data ?? 0,
                      onPressed: onPendingActions,
                    ),
                  ),
                  _HeroIconButton(
                    tooltip: 'התראות',
                    icon: Icons.notifications_none,
                    onPressed: onNotifications,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                _weekday(selectedDate),
                style: const TextStyle(color: Color(0xDDFFFFFF), fontSize: 19),
              ),
              Text(
                '${selectedDate.day} ${_month(selectedDate.month)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _SummaryTile(value: openCount, label: 'לביצוע'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryTile(
                      value: overdueCount,
                      label: 'באיחור',
                      accent: overdueCount > 0,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryTile(value: doneCount, label: 'הושלמו'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _weekday(DateTime date) => switch (date.weekday) {
    DateTime.sunday => 'יום ראשון',
    DateTime.monday => 'יום שני',
    DateTime.tuesday => 'יום שלישי',
    DateTime.wednesday => 'יום רביעי',
    DateTime.thursday => 'יום חמישי',
    DateTime.friday => 'יום שישי',
    _ => 'יום שבת',
  };

  String _month(int month) => const [
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
  ][month - 1];
}

class _HeroIconButton extends StatelessWidget {
  const _HeroIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.badge = 0,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, color: Colors.white),
          if (badge > 0)
            PositionedDirectional(
              top: -8,
              start: -9,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  badge > 9 ? '9+' : '$badge',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.value,
    required this.label,
    this.accent = false,
  });

  final int value;
  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              color: accent ? const Color(0xFFFFA08E) : Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Color(0xDDFFFFFF), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _HomeActionsRow extends StatelessWidget {
  const _HomeActionsRow({
    required this.count,
    required this.filterLabel,
    required this.onCreate,
    required this.onFilter,
  });

  final int count;
  final String filterLabel;
  final VoidCallback onCreate;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'לביצוע',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(width: 8),
        CircleAvatar(
          radius: 15,
          backgroundColor: AppColors.primary,
          child: Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: onFilter,
          icon: const Icon(Icons.filter_list, size: 20),
          label: Text(filterLabel == 'הכל' ? 'סינון' : filterLabel),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: onCreate,
          style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
          icon: const Icon(Icons.add),
          label: const Text('חדש'),
        ),
      ],
    );
  }
}

class _CreateActionSheet extends StatelessWidget {
  const _CreateActionSheet();

  @override
  Widget build(BuildContext context) {
    const actions = [
      (WorkItemKind.reminder, Icons.alarm_add_outlined, 'תזכורת'),
      (WorkItemKind.homeVisit, Icons.home_repair_service_outlined, 'ביקור בית'),
      (WorkItemKind.appointment, Icons.event_outlined, 'פגישה'),
      (WorkItemKind.quote, Icons.request_quote_outlined, 'הצעת מחיר'),
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'מה תרצה ליצור?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            for (final action in actions)
              ListTile(
                leading: CircleAvatar(child: Icon(action.$2)),
                title: Text(action.$3),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => Navigator.of(context).pop(action.$1),
              ),
          ],
        ),
      ),
    );
  }
}

class _VoiceRecordingStatus extends StatelessWidget {
  const _VoiceRecordingStatus({required this.recorder, required this.onCancel});

  final VoiceCommandRecorder recorder;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final error = recorder.error;
    if (!recorder.recording &&
        !recorder.preparing &&
        !recorder.uploading &&
        error == null) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final message =
        error ??
        (recorder.uploading ? 'מסיים ומפענח...' : recorder.inputLevelMessage());
    final transcript = recorder.liveTranscript;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            color: colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        recorder.uploading
                            ? Icons.cloud_upload_outlined
                            : recorder.preparing
                            ? Icons.hourglass_top
                            : error == null
                            ? Icons.mic
                            : Icons.error_outline,
                        color: error == null
                            ? colorScheme.primary
                            : colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          message,
                          style: textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  if (recorder.recording) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: recorder.inputLevel,
                        minHeight: 6,
                      ),
                    ),
                    if (transcript.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          transcript,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: onCancel,
                      icon: const Icon(Icons.close),
                      label: const Text('ביטול הקלטה'),
                    ),
                  ] else if (recorder.preparing) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: onCancel,
                      icon: const Icon(Icons.close),
                      label: const Text('ביטול'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DateStrip extends StatelessWidget {
  const _DateStrip({required this.selectedDate, required this.onChanged});

  final DateTime selectedDate;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final dates = centeredHomeWeek(today);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        child: Row(
          children: [
            for (final date in dates)
              Expanded(
                child: _DateCell(
                  date: date,
                  selected: _sameDay(date, selectedDate),
                  isToday: _sameDay(date, today),
                  onTap: () => onChanged(date),
                  weekday: _weekday(date),
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) {
    return isSameCalendarDay(a, b);
  }

  String _weekday(DateTime date) {
    return switch (date.weekday) {
      DateTime.sunday => 'א׳',
      DateTime.monday => 'ב׳',
      DateTime.tuesday => 'ג׳',
      DateTime.wednesday => 'ד׳',
      DateTime.thursday => 'ה׳',
      DateTime.friday => 'ו׳',
      _ => 'ש׳',
    };
  }
}

class _DateCell extends StatelessWidget {
  const _DateCell({
    required this.date,
    required this.selected,
    required this.isToday,
    required this.onTap,
    required this.weekday,
  });

  final DateTime date;
  final bool selected;
  final bool isToday;
  final VoidCallback onTap;
  final String weekday;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 14,
              child: isToday
                  ? Text(
                      'היום',
                      style: TextStyle(
                        color: selected ? Colors.white : AppColors.accent,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 1),
            Text(
              weekday,
              style: TextStyle(
                color: selected ? Colors.white70 : AppColors.muted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${date.day}',
              style: TextStyle(
                color: selected ? Colors.white : AppColors.ink,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkItemSection extends StatelessWidget {
  const _WorkItemSection({
    super.key,
    required this.title,
    required this.count,
    required this.expanded,
    required this.emptyText,
    required this.onToggle,
    required this.children,
    this.showHeader = true,
  });

  final String title;
  final int count;
  final bool expanded;
  final String emptyText;
  final VoidCallback onToggle;
  final List<Widget> children;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showHeader)
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onToggle,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
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

class _WorkItemCard extends StatelessWidget {
  const _WorkItemCard({
    required this.item,
    this.onOpen,
    this.onOpenCustomer,
    this.onComplete,
    this.onMarkPaid,
    this.onReopen,
    this.onDelete,
  });

  final WorkItem item;
  final VoidCallback? onOpen;
  final VoidCallback? onOpenCustomer;
  final VoidCallback? onComplete;
  final VoidCallback? onMarkPaid;
  final VoidCallback? onReopen;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final detail = _detailText();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 6, color: _accentColor()),
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
                          Icon(
                            _iconForType(item.type),
                            size: 19,
                            color: _accentColor(),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _labelForType(item.type),
                            style: const TextStyle(color: AppColors.muted),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _timeText(),
                            style: const TextStyle(color: AppColors.muted),
                          ),
                          if (_isOverdue()) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFE6E1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'באיחור',
                                style: TextStyle(
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
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
                                  child: ListTile(
                                    leading: Icon(Icons.edit_outlined),
                                    title: Text('עריכה'),
                                  ),
                                ),
                              if (onDelete != null)
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: ListTile(
                                    leading: Icon(Icons.delete_outline),
                                    title: Text('מחיקה'),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      if (item.customer != null)
                        InkWell(
                          onTap: onOpenCustomer,
                          child: Text(
                            item.customer!.name,
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontSize: 18,
                              height: 1.2,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      const SizedBox(height: 3),
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: item.customer == null
                            ? const TextStyle(
                                fontSize: 18,
                                height: 1.2,
                                fontWeight: FontWeight.w800,
                              )
                            : const TextStyle(
                                color: AppColors.muted,
                                fontWeight: FontWeight.w600,
                              ),
                      ),
                      if (detail != null) ...[
                        const SizedBox(height: 5),
                        Text(
                          detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ],
                      if (onComplete != null ||
                          onMarkPaid != null ||
                          onReopen != null) ...[
                        const SizedBox(height: 10),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: OutlinedButton(
                            onPressed: onComplete ?? onMarkPaid ?? onReopen,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(92, 42),
                              visualDensity: VisualDensity.compact,
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

  Color _accentColor() {
    if (item.isUrgent || _isOverdue()) return AppColors.accent;
    return switch (item.type) {
      WorkItemType.homeVisit => AppColors.visit,
      WorkItemType.quote => AppColors.quote,
      WorkItemType.appointment => AppColors.primarySoft,
      _ => AppColors.primary,
    };
  }

  String _timeText() {
    final date = item.startsAt ?? item.dueAt;
    if (date == null) return '';
    final local = date.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  bool _isOverdue() {
    final date = item.dueAt;
    if (date == null || item.isFinished) return false;
    return date.toLocal().isBefore(DateTime.now());
  }

  String? _detailText() {
    final values = [
      item.location,
      item.estimatedAmount == null ? null : '₪${item.estimatedAmount}',
      item.description,
      item.notes,
    ].whereType<String>().where((value) => value.trim().isNotEmpty).toList();
    return values.isEmpty ? null : values.first;
  }

  IconData _iconForType(WorkItemType type) {
    return switch (type) {
      WorkItemType.reminder => Icons.alarm_outlined,
      WorkItemType.homeVisit => Icons.home_repair_service_outlined,
      WorkItemType.appointment => Icons.event_outlined,
      WorkItemType.quote => Icons.request_quote_outlined,
      _ => Icons.task_alt,
    };
  }

  String _labelForType(WorkItemType type) {
    return switch (type) {
      WorkItemType.reminder => 'תזכורת',
      WorkItemType.homeVisit => 'ביקור בית',
      WorkItemType.appointment => 'פגישה',
      WorkItemType.quote => 'הצעת מחיר',
      WorkItemType.note => 'הערה',
      WorkItemType.unknown => 'פריט',
    };
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (body != null) ...[
              const SizedBox(height: 8),
              Text(body!, textAlign: TextAlign.center),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
