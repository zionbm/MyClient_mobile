import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.actions = const [],
    this.showBack = true,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> actions;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        12,
        MediaQuery.paddingOf(context).top + 6,
        12,
        14,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (showBack)
            IconButton(
              tooltip: 'חזרה',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(
                Icons.arrow_forward,
                textDirection: TextDirection.ltr,
              ),
            ),
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}
