part of 'home_screen.dart';

class _CreateActions extends StatelessWidget {
  const _CreateActions({
    required this.onReminder,
    required this.onHomeVisit,
    required this.onAppointment,
    required this.onQuote,
  });

  final VoidCallback onReminder;
  final VoidCallback onHomeVisit;
  final VoidCallback onAppointment;
  final VoidCallback onQuote;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed: onReminder,
          icon: const Icon(Icons.alarm_add_outlined),
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
        OutlinedButton.icon(
          onPressed: onQuote,
          icon: const Icon(Icons.request_quote_outlined),
          label: const Text('הצעה'),
        ),
      ],
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
    final dates = List.generate(7, (index) {
      final offset = index - 2;
      return DateTime(
        today.year,
        today.month,
        today.day,
      ).add(Duration(days: offset));
    });

    return SizedBox(
      height: 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: dates.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final date = dates[index];
          final selected = _sameDay(date, selectedDate);
          return ChoiceChip(
            selected: selected,
            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
            label: SizedBox(
              width: 52,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_weekday(date)),
                  const SizedBox(height: 1),
                  Text(
                    '${date.day}.${date.month}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            onSelected: (_) => onChanged(date),
          );
        },
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
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

class _WorkItemSection extends StatelessWidget {
  const _WorkItemSection({
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

class _PendingActionsBanner extends StatelessWidget {
  const _PendingActionsBanner({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: ListTile(
        leading: Icon(
          Icons.auto_awesome,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
        title: Text('$count פעולות AI ממתינות לאישור'),
        subtitle: const Text('בדוק, ערוך או אשר לפני ביצוע'),
        trailing: const Icon(Icons.chevron_left),
        onTap: onTap,
      ),
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
                  _iconForType(item.type),
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
              subtitle: _WorkItemSubtitle(
                typeLabel: _labelForType(item.type),
                customerName: item.customer?.name,
                onOpenCustomer: onOpenCustomer,
                dueAt: item.dueAt,
                isFinished: item.isFinished,
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

class _WorkItemSubtitle extends StatelessWidget {
  const _WorkItemSubtitle({
    required this.typeLabel,
    required this.customerName,
    required this.onOpenCustomer,
    required this.dueAt,
    required this.isFinished,
    required this.description,
  });

  final String typeLabel;
  final String? customerName;
  final VoidCallback? onOpenCustomer;
  final DateTime? dueAt;
  final bool isFinished;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    final mutedStyle = style?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    final linkStyle = style?.copyWith(
      color: Theme.of(context).colorScheme.primary,
      decoration: TextDecoration.underline,
      decorationColor: Theme.of(context).colorScheme.primary,
    );
    final overdueText = _overdueText(dueAt, isFinished);

    return Wrap(
      spacing: 4,
      runSpacing: 1,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(typeLabel, style: mutedStyle),
        if (customerName != null) ...[
          Text('·', style: mutedStyle),
          InkWell(
            onTap: onOpenCustomer,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                customerName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: linkStyle,
              ),
            ),
          ),
        ],
        if (dueAt != null) ...[
          Text('·', style: mutedStyle),
          Text(formatDateTime(dueAt), style: mutedStyle),
        ],
        if (overdueText != null) ...[
          Text('·', style: mutedStyle),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              overdueText,
              style: style?.copyWith(
                color: Theme.of(context).colorScheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        if (description != null) ...[
          Text('·', style: mutedStyle),
          Text(
            description!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: mutedStyle,
          ),
        ],
      ],
    );
  }

  String? _overdueText(DateTime? dueAt, bool isFinished) {
    if (dueAt == null || isFinished) return null;
    final localDueAt = dueAt.toLocal();
    final dueDate = DateTime(localDueAt.year, localDueAt.month, localDueAt.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = today.difference(dueDate).inDays;
    if (days <= 0) return null;
    if (days == 1) return 'באיחור יום';
    return 'באיחור $days ימים';
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
