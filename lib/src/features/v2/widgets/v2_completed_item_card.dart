import 'package:flutter/material.dart';

import '../../../models/v2_completed_item.dart';
import '../../../theme/app_theme.dart';

class V2CompletedItemCard extends StatelessWidget {
  const V2CompletedItemCard({
    super.key,
    required this.item,
    required this.onOpen,
  });

  final V2CompletedItem item;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final completedAt = item.completedAt.toLocal();
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(completedAt),
      alwaysUse24HourFormat: true,
    );
    final date =
        '${completedAt.day.toString().padLeft(2, '0')}/${completedAt.month.toString().padLeft(2, '0')}';
    final details = [
      item.kindLabel,
      item.customerName,
      '$date · $time',
    ].whereType<String>().join(' · ');

    return Card(
      color: AppColors.successContainer,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: AppColors.success),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      details,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
