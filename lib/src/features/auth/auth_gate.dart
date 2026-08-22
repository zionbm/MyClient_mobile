import 'package:flutter/material.dart';

import '../shell/app_shell.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';
import 'session_controller.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.controller});

  final SessionController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return switch (controller.status) {
          SessionStatus.signedIn => AppShell(controller: controller),
          SessionStatus.needsBusiness => OnboardingScreen(
            controller: controller,
          ),
          _ => LoginScreen(controller: controller),
        };
      },
    );
  }
}
