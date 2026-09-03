import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class PendingActionsIconButton extends StatelessWidget {
  const PendingActionsIconButton({
    super.key,
    required this.countFuture,
    required this.onPressed,
  });

  final Future<int>? countFuture;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: countFuture,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              tooltip: 'מחכה להשלמה',
              onPressed: onPressed,
              icon: const Icon(
                Icons.auto_awesome_outlined,
                color: AppColors.primary,
              ),
            ),
            if (count > 0)
              PositionedDirectional(
                top: 1,
                end: 1,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.surface, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    count > 9 ? '9+' : '$count',
                    style: const TextStyle(
                      color: AppColors.background,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
