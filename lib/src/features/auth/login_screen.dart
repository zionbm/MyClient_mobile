import 'package:flutter/material.dart';

import 'session_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.controller});

  final SessionController controller;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firebaseUidController = TextEditingController(text: 'firebase_demo_1');
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _firebaseUidController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(24),
              shrinkWrap: true,
              children: [
                const SizedBox(height: 24),
                Text(
                  'MyClient',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'העוזר הוירטואלי לניהול הלקוחות שלך',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 32),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'התחברות מקומית',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _firebaseUidController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Firebase UID',
                              hintText: 'firebase_demo_1',
                            ),
                            validator: _required,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.done,
                            decoration: const InputDecoration(
                              labelText: 'מספר טלפון mock (אופציונלי)',
                              hintText: '+972501111111',
                            ),
                          ),
                          if (widget.controller.errorMessage != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              widget.controller.errorMessage!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: widget.controller.isLoading
                                ? null
                                : _submit,
                            child: widget.controller.isLoading
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('בדוק התחברות'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'בשלב הזה Firebase Phone Auth עדיין לא מחובר באפליקציה. המסך הזה עובד מול AUTH_PROVIDER=mock בשרת המקומי.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'שדה חובה' : null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    widget.controller.devSignIn(
      firebaseUid: _firebaseUidController.text,
      phoneNumber: _phoneController.text,
    );
  }
}
