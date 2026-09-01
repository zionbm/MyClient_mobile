import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../ai/pending_actions_screen.dart';
import '../v2/v2_pending_actions_screen.dart';
import '../v2/v2_recent_actions_screen.dart';
import '../auth/session_controller.dart';
import '../notifications/notifications_screen.dart';
import '../search/search_screen.dart';
import '../settings/business_settings_screen.dart';
import '../team/team_screen.dart';
import '../voice/voice_commands_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({
    super.key,
    required this.controller,
    this.pendingActionsCountFuture,
  });

  final SessionController controller;
  final Future<int>? pendingActionsCountFuture;

  @override
  Widget build(BuildContext context) {
    final session = controller.session!;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _MoreHero(
              businessName: session.businessName ?? 'MyClient',
              displayName: session.displayName ?? 'חשבון פעיל',
              onSearch: () =>
                  _push(context, SearchScreen(controller: controller)),
              onNotifications: () =>
                  _push(context, NotificationsScreen(controller: controller)),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            sliver: SliverList.list(
              children: [
                const _MoreSectionTitle('ניהול העסק'),
                const SizedBox(height: 8),
                _MoreSectionCard(
                  children: [
                    _MoreTile(
                      icon: Icons.storefront_outlined,
                      title: 'הגדרות העסק',
                      subtitle: 'פרטי העסק, שעות פעילות והעדפות',
                      onTap: () => _push(
                        context,
                        BusinessSettingsScreen(controller: controller),
                      ),
                    ),
                    const Divider(height: 1),
                    _MoreTile(
                      icon: Icons.groups_outlined,
                      title: 'צוות',
                      subtitle: 'עובדים והרשאות גישה',
                      onTap: () =>
                          _push(context, TeamScreen(controller: controller)),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const _MoreSectionTitle('כלים ואוטומציה'),
                const SizedBox(height: 8),
                _MoreSectionCard(
                  children: [
                    _MoreTile(
                      icon: Icons.auto_awesome_outlined,
                      title: 'פעולות AI',
                      subtitle: 'אישור ועריכה של פעולות ממתינות',
                      badge: _PendingActionsBadge(
                        countFuture: pendingActionsCountFuture,
                      ),
                      onTap: () => _openPendingActions(context),
                    ),
                    const Divider(height: 1),
                    _MoreTile(
                      icon: Icons.history_rounded,
                      title: controller.session?.v2AssistantEnabled == true
                          ? 'פעולות אחרונות'
                          : 'פקודות קוליות',
                      subtitle: controller.session?.v2AssistantEnabled == true
                          ? 'קבלות, השמעה ו-Undo'
                          : 'היסטוריה ופעולות שנוצרו מהקול',
                      onTap: () => _push(
                        context,
                        controller.session?.v2AssistantEnabled == true
                            ? V2RecentActionsScreen(controller: controller)
                            : VoiceCommandsScreen(controller: controller),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: controller.signOut,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    side: const BorderSide(color: AppColors.accent),
                    minimumSize: const Size.fromHeight(52),
                  ),
                  icon: const Icon(Icons.logout),
                  label: const Text('התנתקות'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _openPendingActions(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => controller.session?.v2AssistantEnabled == true
            ? V2PendingActionsScreen(controller: controller)
            : PendingActionsScreen(controller: controller),
      ),
    );
    controller.refreshPendingActions();
  }
}

class _MoreHero extends StatelessWidget {
  const _MoreHero({
    required this.businessName,
    required this.displayName,
    required this.onSearch,
    required this.onNotifications,
  });

  final String businessName;
  final String displayName;
  final VoidCallback onSearch;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 294,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 236,
            padding: EdgeInsets.fromLTRB(
              18,
              MediaQuery.paddingOf(context).top + 12,
              18,
              30,
            ),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(34)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'עוד',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          Text(
                            'ניהול העסק והכלים שלך',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onSearch,
                      color: Colors.white,
                      icon: const Icon(Icons.search),
                      tooltip: 'חיפוש',
                    ),
                    IconButton(
                      onPressed: onNotifications,
                      color: Colors.white,
                      icon: const Icon(Icons.notifications_none),
                      tooltip: 'התראות',
                    ),
                  ],
                ),
              ],
            ),
          ),
          PositionedDirectional(
            start: 16,
            end: 16,
            bottom: 0,
            child: _BusinessIdentityCard(
              businessName: businessName,
              displayName: displayName,
            ),
          ),
        ],
      ),
    );
  }
}

class _BusinessIdentityCard extends StatelessWidget {
  const _BusinessIdentityCard({
    required this.businessName,
    required this.displayName,
  });

  final String businessName;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$businessName, $displayName',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x16000000),
              blurRadius: 18,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 31,
              backgroundColor: Color(0xFFDDEEE9),
              foregroundColor: AppColors.primary,
              child: Icon(Icons.storefront_outlined, size: 31),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    businessName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const _ActiveAccountPill(),
          ],
        ),
      ),
    );
  }
}

class _ActiveAccountPill extends StatelessWidget {
  const _ActiveAccountPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFDDEEE9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'פעיל',
        style: TextStyle(
          color: AppColors.primary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MoreSectionTitle extends StatelessWidget {
  const _MoreSectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        color: AppColors.primary,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _MoreSectionCard extends StatelessWidget {
  const _MoreSectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            CircleAvatar(
              radius: 23,
              backgroundColor: const Color(0xFFDDEEE9),
              foregroundColor: AppColors.primary,
              child: Icon(icon, size: 23),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (badge != null) ...[badge!, const SizedBox(width: 6)],
            const Icon(Icons.chevron_left, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _PendingActionsBadge extends StatelessWidget {
  const _PendingActionsBadge({required this.countFuture});

  final Future<int>? countFuture;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: countFuture,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        if (count <= 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            count > 99 ? '99+ ממתינות' : '$count ממתינות',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        );
      },
    );
  }
}
