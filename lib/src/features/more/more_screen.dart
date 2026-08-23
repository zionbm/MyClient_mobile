import 'package:flutter/material.dart';

import '../ai/pending_actions_screen.dart';
import '../auth/session_controller.dart';
import '../settings/business_settings_screen.dart';
import '../team/team_screen.dart';
import '../voice/voice_commands_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key, required this.controller});

  final SessionController controller;

  @override
  Widget build(BuildContext context) {
    final session = controller.session!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.storefront_outlined)),
            title: Text(session.businessName ?? 'MyClient'),
            subtitle: Text(session.displayName ?? 'חשבון פעיל'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () =>
                _push(context, BusinessSettingsScreen(controller: controller)),
          ),
        ),
        const SizedBox(height: 12),
        _MoreTile(
          icon: Icons.groups_outlined,
          title: 'צוות',
          subtitle: 'הוספת עובדים והשבתת גישה',
          onTap: () => _push(context, TeamScreen(controller: controller)),
        ),
        _MoreTile(
          icon: Icons.auto_awesome_outlined,
          title: 'פעולות AI',
          subtitle: 'אישור, עריכה ודחייה של פעולות ממתינות',
          onTap: () =>
              _push(context, PendingActionsScreen(controller: controller)),
        ),
        _MoreTile(
          icon: Icons.mic_none,
          title: 'פקודות קוליות',
          subtitle: 'הקלטה והיסטוריית פקודות',
          onTap: () =>
              _push(context, VoiceCommandsScreen(controller: controller)),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: controller.signOut,
          icon: const Icon(Icons.logout),
          label: const Text('התנתקות'),
        ),
      ],
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_left),
        onTap: onTap,
      ),
    );
  }
}
