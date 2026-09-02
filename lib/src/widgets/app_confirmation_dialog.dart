import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

Future<bool?> showAppConfirmationDialog({
  required BuildContext context,
  required String title,
  required String body,
  required String confirmLabel,
  String cancelLabel = 'ביטול',
  IconData icon = Icons.help_outline_rounded,
  bool destructive = false,
}) {
  final actionColor = destructive ? AppColors.accent : AppColors.primary;
  final iconBackground = destructive
      ? AppColors.errorContainer
      : AppColors.primaryContainer;

  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      icon: DecoratedBox(
        decoration: BoxDecoration(
          color: iconBackground,
          shape: BoxShape.circle,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: actionColor, size: 28),
        ),
      ),
      title: Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.ink,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: Text(
        body,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.muted, height: 1.45),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(cancelLabel),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: actionColor),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(confirmLabel),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
