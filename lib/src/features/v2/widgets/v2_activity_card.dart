import 'package:flutter/material.dart';

import '../../../models/v2_activity.dart';
import '../../../theme/app_theme.dart';

class V2ActivityCard extends StatelessWidget {
  const V2ActivityCard({
    super.key,
    required this.item,
    required this.onOpen,
    required this.onAction,
    required this.onAmount,
    required this.onEdit,
    required this.onDelete,
  });

  final V2Activity item;
  final VoidCallback onOpen;
  final ValueChanged<String> onAction;
  final VoidCallback onAmount;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isOpen = item.status == V2ActivityStatus.open;
    final executionCompleted = item.executionCompletedAt != null;
    final isUnscheduled =
        isOpen && !executionCompleted && item.startsAt == null;
    return Card(
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    item.kind == V2ActivityKind.job
                        ? Icons.work_outline
                        : Icons.home_work_outlined,
                    color: item.kind == V2ActivityKind.job
                        ? AppColors.primary
                        : AppColors.visit,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          [
                            item.kind.hebrewLabel,
                            item.customerName,
                          ].whereType<String>().join(' · '),
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'פעולות נוספות',
                    onSelected: (action) {
                      switch (action) {
                        case 'amount':
                          onAmount();
                        case 'edit':
                          onEdit();
                        case 'cancel':
                        case 'reopen':
                          onAction(action);
                        case 'delete':
                          onDelete();
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'amount',
                        child: Text('סכום ותשלום'),
                      ),
                      const PopupMenuItem(value: 'edit', child: Text('עריכה')),
                      if (isOpen && !executionCompleted)
                        const PopupMenuItem(
                          value: 'cancel',
                          child: Text('ביטול'),
                        )
                      else
                        const PopupMenuItem(
                          value: 'reopen',
                          child: Text('פתיחה מחדש'),
                        ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('מחיקה'),
                      ),
                    ],
                  ),
                ],
              ),
              if (item.startsAt != null) ...[
                const SizedBox(height: 8),
                _DetailLine(
                  icon: Icons.schedule_outlined,
                  text: displayActivityWindow(context, item),
                ),
              ],
              if (item.locationSnapshot != null) ...[
                const SizedBox(height: 5),
                _DetailLine(
                  icon: Icons.location_on_outlined,
                  text: item.locationSnapshot!,
                ),
              ],
              const SizedBox(height: 10),
              if (isUnscheduled)
                FilledButton.tonalIcon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: const Text('קבע מועד'),
                )
              else if (isOpen && !executionCompleted)
                FilledButton.tonalIcon(
                  onPressed: () => onAction('report-completed'),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('דיווח סיום'),
                )
              else if (isOpen)
                FilledButton.tonalIcon(
                  onPressed: onAmount,
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                  label: const Text('הביצוע הושלם · עדכון תשלום'),
                )
              else
                OutlinedButton(
                  onPressed: () => onAction('reopen'),
                  child: const Text('פתיחה מחדש'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 17, color: AppColors.muted),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.muted),
        ),
      ),
    ],
  );
}

String displayActivityWindow(BuildContext context, V2Activity activity) {
  final startsAt = activity.startsAt?.toLocal();
  if (startsAt == null) return '';
  final endsAt = activity.effectiveEndsAt?.toLocal();
  final startText = TimeOfDay.fromDateTime(startsAt).format(context);
  if (endsAt == null) return '${_displayDate(startsAt)} · $startText';
  final endText = TimeOfDay.fromDateTime(endsAt).format(context);
  final sameDay =
      startsAt.year == endsAt.year &&
      startsAt.month == endsAt.month &&
      startsAt.day == endsAt.day;
  return sameDay
      ? '${_displayDate(startsAt)} · $startText–$endText'
      : '${_displayDate(startsAt)} $startText – ${_displayDate(endsAt)} $endText';
}

String _displayDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
