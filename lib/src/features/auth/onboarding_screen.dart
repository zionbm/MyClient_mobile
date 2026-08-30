import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
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
  late final TextEditingController _displayNameController;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(
      text: widget.controller.session?.displayName ?? '',
    );
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            _OnboardingHero(onExit: widget.controller.signOut),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 540),
                  child: Transform.translate(
                    offset: const Offset(0, -56),
                    child: Column(
                      children: [
                        _buildFormCard(context),
                        const SizedBox(height: 18),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: AppColors.accent,
                            ),
                            SizedBox(width: 7),
                            Flexible(
                              child: Text(
                                'אפשר לשנות את הפרטים האלה בכל שלב בהגדרות העסק',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'בואו נכיר את העסק',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'כמה פרטים קצרים ומתחילים לעבוד',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 16),
            ),
            const SizedBox(height: 26),
            const _OnboardingFieldLabel(label: 'שם העסק', required: true),
            TextFormField(
              controller: _businessNameController,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: 'לדוגמה: משה התקנות',
                helperText: 'השם שיופיע ללקוחות ולצוות',
                prefixIcon: Icon(Icons.storefront_outlined),
              ),
              validator: _required,
            ),
            const SizedBox(height: 18),
            const _OnboardingFieldLabel(label: 'השם שלך'),
            TextFormField(
              controller: _displayNameController,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                hintText: 'איך לפנות אליך?',
                helperText: 'כך נפנה אליך באפליקציה',
                prefixIcon: Icon(Icons.person_outline),
              ),
              onFieldSubmitted: (_) => _submit(),
            ),
            if (widget.controller.errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.errorContainer.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.controller.errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
            const SizedBox(height: 22),
            FilledButton(
              onPressed: widget.controller.isLoading ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: widget.controller.isLoading
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'יצירת העסק והמשך',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'יש להזין שם לעסק' : null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    widget.controller.registerBusiness(
      businessName: _businessNameController.text,
      displayName: _displayNameController.text,
    );
  }
}

class _OnboardingHero extends StatelessWidget {
  const _OnboardingHero({required this.onExit});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 410,
      padding: EdgeInsets.fromLTRB(
        18,
        MediaQuery.paddingOf(context).top + 12,
        18,
        80,
      ),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(48)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Spacer(),
              const Text(
                'MyClient',
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onExit,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                icon: const Icon(Icons.logout, size: 19),
                label: const Text('יציאה'),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const Text(
            'שלב 2 מתוך 2',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          const _CompletedSteps(),
          const SizedBox(height: 26),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Color(0xFF8DD8C9)),
                SizedBox(width: 8),
                Text(
                  'הטלפון אומת בהצלחה',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletedSteps extends StatelessWidget {
  const _CompletedSteps();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Row(
        children: [
          const _StepCheck(),
          Expanded(child: Container(height: 3, color: const Color(0xFF8DD8C9))),
          const _StepCheck(),
        ],
      ),
    );
  }
}

class _StepCheck extends StatelessWidget {
  const _StepCheck();

  @override
  Widget build(BuildContext context) {
    return const CircleAvatar(
      radius: 13,
      backgroundColor: Color(0xFF8DD8C9),
      foregroundColor: AppColors.primary,
      child: Icon(Icons.check, size: 17),
    );
  }
}

class _OnboardingFieldLabel extends StatelessWidget {
  const _OnboardingFieldLabel({required this.label, this.required = false});

  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text.rich(
        TextSpan(
          text: label,
          children: required
              ? const [
                  TextSpan(
                    text: ' *',
                    style: TextStyle(color: AppColors.accent),
                  ),
                ]
              : const [],
        ),
        style: const TextStyle(
          color: AppColors.ink,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
