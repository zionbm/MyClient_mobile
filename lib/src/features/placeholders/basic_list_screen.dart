import 'package:flutter/material.dart';

class BasicListScreen extends StatelessWidget {
  const BasicListScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.emptyText,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final IconData icon;
  final String emptyText;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: 44,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(emptyText, textAlign: TextAlign.center),
                if (actionLabel != null) ...[
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed:
                        onAction ??
                        () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('$actionLabel יתווסף בשלב הבא'),
                            ),
                          );
                        },
                    child: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
