import 'package:flutter/material.dart';

import '../shell/app_shell.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';
import 'session_controller.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.controller});

  final SessionController controller;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.restorePersistedSession();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        return switch (widget.controller.status) {
          SessionStatus.signedIn => AppShell(controller: widget.controller),
          SessionStatus.needsBusiness => OnboardingScreen(
            controller: widget.controller,
          ),
          SessionStatus.loading => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          _ => LoginScreen(controller: widget.controller),
        };
      },
    );
  }
}
