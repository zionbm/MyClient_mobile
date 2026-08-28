import 'package:flutter/material.dart';

import '../ai/pending_actions_screen.dart';
import '../auth/session_controller.dart';
import '../calls/calls_screen.dart';
import '../customers/customers_screen.dart';
import '../home/home_screen.dart';
import '../more/more_screen.dart';
import '../notifications/notifications_screen.dart';
import '../search/search_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.controller});

  final SessionController controller;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  Future<int>? _pendingActionsCountFuture;
  late int _seenDataVersion;

  @override
  void initState() {
    super.initState();
    _seenDataVersion = widget.controller.dataVersion;
    widget.controller.addListener(_handleDataChanged);
    _loadPendingActionsCount(notify: false);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleDataChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(controller: widget.controller),
      SearchScreen(controller: widget.controller),
      CustomersScreen(controller: widget.controller),
      CallsScreen(controller: widget.controller),
      MoreScreen(controller: widget.controller),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_titleForIndex(_index)),
        actions: [
          _PendingActionsIconButton(
            countFuture: _pendingActionsCountFuture,
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      PendingActionsScreen(controller: widget.controller),
                ),
              );
              _loadPendingActionsCount();
            },
          ),
          IconButton(
            tooltip: 'התראות',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      NotificationsScreen(controller: widget.controller),
                ),
              );
            },
            icon: const Icon(Icons.notifications_none),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'בית',
          ),
          NavigationDestination(
            icon: Icon(Icons.manage_search_outlined),
            selectedIcon: Icon(Icons.manage_search),
            label: 'חיפוש',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_alt_outlined),
            selectedIcon: Icon(Icons.people_alt),
            label: 'לקוחות',
          ),
          NavigationDestination(
            icon: Icon(Icons.call_outlined),
            selectedIcon: Icon(Icons.call),
            label: 'שיחות',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz),
            selectedIcon: Icon(Icons.more),
            label: 'עוד',
          ),
        ],
      ),
    );
  }

  String _titleForIndex(int index) {
    return switch (index) {
      0 => 'בית',
      1 => 'חיפוש',
      2 => 'לקוחות',
      3 => 'שיחות',
      _ => 'עוד',
    };
  }

  void _handleDataChanged() {
    if (!mounted) return;
    final currentVersion = widget.controller.dataVersion;
    if (currentVersion == _seenDataVersion) return;
    _seenDataVersion = currentVersion;
    _loadPendingActionsCount();
  }

  void _loadPendingActionsCount({bool notify = true}) {
    final session = widget.controller.session;
    if (session?.businessId == null) return;
    final nextFuture = widget.controller.apiClient
        .listAiPendingActions(
          businessId: session!.businessId!,
          firebaseUid: session.firebaseUid,
          mockPhoneNumber: session.mockPhoneNumber,
          status: 'PENDING',
        )
        .then((json) => (json['pendingActions'] as List?)?.length ?? 0);
    if (!notify) {
      _pendingActionsCountFuture = nextFuture;
      return;
    }
    setState(() => _pendingActionsCountFuture = nextFuture);
  }
}

class _PendingActionsIconButton extends StatelessWidget {
  const _PendingActionsIconButton({
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
        return IconButton(
          tooltip: count > 0 ? 'פעולות AI לאישור: $count' : 'פעולות AI',
          onPressed: onPressed,
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.fact_check_outlined),
              if (count > 0)
                PositionedDirectional(
                  top: -8,
                  end: -10,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onError,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
