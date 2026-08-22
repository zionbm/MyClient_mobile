import 'package:flutter/material.dart';

import '../auth/session_controller.dart';
import '../calls/calls_screen.dart';
import '../customers/customers_screen.dart';
import '../home/home_screen.dart';
import '../more/more_screen.dart';
import '../notifications/notifications_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.controller});

  final SessionController controller;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(controller: widget.controller),
      CustomersScreen(controller: widget.controller),
      CallsScreen(controller: widget.controller),
      MoreScreen(controller: widget.controller),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_titleForIndex(_index)),
        actions: [
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
      1 => 'לקוחות',
      2 => 'שיחות',
      _ => 'עוד',
    };
  }
}
