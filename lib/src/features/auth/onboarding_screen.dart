import 'package:flutter/material.dart';

import 'session_controller.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.controller});

  final SessionController controller;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _displayNameController = TextEditingController();

  @override
  void dispose() {
    _businessNameController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.controller.session;

    return Scaffold(
      appBar: AppBar(
        title: const Text('הקמת עסק'),
        actions: [
          IconButton(
            tooltip: 'התנתקות',
            onPressed: widget.controller.signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'לא מצאנו עסק מחובר למשתמש הזה',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text('משתמש: ${session?.firebaseUid ?? ''}'),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _businessNameController,
                            decoration: const InputDecoration(
                              labelText: 'שם העסק',
                            ),
                            validator: _required,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _displayNameController,
                            decoration: const InputDecoration(
                              labelText: 'שם בעל העסק',
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
                                : const Text('צור עסק והמשך'),
                          ),
                        ],
                      ),
                    ),
                  ),
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
    widget.controller.registerBusiness(
      businessName: _businessNameController.text,
      displayName: _displayNameController.text,
    );
  }
}
