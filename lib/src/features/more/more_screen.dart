import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/main_top_bar.dart';
import '../calls/calls_screen.dart';
import '../v2/v2_pending_actions_screen.dart';
import '../v2/v2_recent_actions_screen.dart';
import '../v2/v2_reports_screen.dart';
import '../auth/session_controller.dart';
import '../notifications/notifications_screen.dart';
import '../settings/business_settings_screen.dart';
import '../team/team_screen.dart';
import '../v2/v2_search_screen.dart';

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
                  _push(context, V2SearchScreen(controller: controller)),
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
                      icon: Icons.call_outlined,
                      title: 'פניות ושיחות',
                      subtitle: 'שיחות שהמזכירה טיפלה בהן',
                      onTap: () => _push(
                        context,
                        CallsScreen(
                          controller: controller,
                          pendingActionsCountFuture: pendingActionsCountFuture,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    _MoreTile(
                      icon: Icons.auto_awesome_outlined,
                      title: 'מחכה להשלמה',
                      subtitle: 'שאלות ופעולות שמחכות לתשובה שלך',
                      badge: _PendingActionsBadge(
                        countFuture: pendingActionsCountFuture,
                      ),
                      onTap: () => _openPendingActions(context),
                    ),
                    const Divider(height: 1),
                    _MoreTile(
                      icon: Icons.history_rounded,
                      title: 'היסטוריית פעולות',
                      subtitle: 'קבלות, השמעה וביטול פעולות',
                      onTap: () => _push(
                        context,
                        V2RecentActionsScreen(controller: controller),
                      ),
                    ),
                    const Divider(height: 1),
                    _MoreTile(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'תשלומים ויתרות',
                      subtitle: 'יתרות פתוחות וסיכום כספי',
                      onTap: () => _push(
                        context,
                        V2ReportsScreen(controller: controller),
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
        builder: (_) => V2PendingActionsScreen(controller: controller),
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
    return MainTopBar(
      title: 'עוד',
      subtitle: '$businessName · $displayName',
      leading: const CircleAvatar(
        radius: 20,
        backgroundColor: AppColors.primaryContainer,
        foregroundColor: AppColors.primary,
        child: Icon(Icons.storefront_outlined),
      ),
      actions: [
        IconButton(
          onPressed: onSearch,
          icon: const Icon(Icons.search),
          tooltip: 'חיפוש',
        ),
        IconButton(
          onPressed: onNotifications,
          icon: const Icon(Icons.notifications_none),
          tooltip: 'התראות',
        ),
      ],
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
              backgroundColor: AppColors.primaryContainer,
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
