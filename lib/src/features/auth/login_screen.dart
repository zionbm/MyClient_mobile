import 'package:firebase_auth/firebase_auth.dart';
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
  final _smsCodeController = TextEditingController();
  String? _verificationId;
  String? _phoneAuthError;
  bool _isSendingCode = false;
  bool _isVerifyingCode = false;

  @override
  void dispose() {
    _firebaseUidController.dispose();
    _phoneController.dispose();
    _smsCodeController.dispose();
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
                            _title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          if (widget.controller.isMockAuth)
                            ..._buildMockFields()
                          else
                            ..._buildFirebasePhoneFields(),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _errorMessage!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _isBusy ? null : _submit,
                            child: _isBusy
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(_buttonText),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (widget.controller.isMockAuth) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'מצב פיתוח מקומי מול AUTH_PROVIDER=mock.',
                    textAlign: TextAlign.center,
                  ),
                ],
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

  String get _title =>
      widget.controller.isMockAuth ? 'התחברות מקומית' : 'כניסה עם מספר טלפון';

  String get _buttonText {
    if (widget.controller.isMockAuth) return 'בדוק התחברות';
    return _verificationId == null ? 'שלח קוד' : 'אמת קוד';
  }

  String? get _errorMessage =>
      _phoneAuthError ?? widget.controller.errorMessage;

  bool get _isBusy =>
      widget.controller.isLoading || _isSendingCode || _isVerifyingCode;

  List<Widget> _buildMockFields() {
    return [
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
    ];
  }

  List<Widget> _buildFirebasePhoneFields() {
    return [
      TextFormField(
        controller: _phoneController,
        enabled: _verificationId == null,
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.next,
        decoration: const InputDecoration(
          labelText: 'מספר טלפון',
          hintText: '+972501234567',
        ),
        validator: _required,
      ),
      if (_verificationId != null) ...[
        const SizedBox(height: 12),
        TextFormField(
          controller: _smsCodeController,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'קוד אימות',
            hintText: '123456',
          ),
          validator: _required,
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _isBusy ? null : _resetPhoneVerification,
          child: const Text('שנה מספר טלפון'),
        ),
      ],
    ];
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (!widget.controller.isMockAuth) {
      if (_verificationId == null) {
        _sendCode();
      } else {
        _verifyCode();
      }
      return;
    }
    widget.controller.devSignIn(
      firebaseUid: _firebaseUidController.text,
      phoneNumber: _phoneController.text,
    );
  }

  Future<void> _sendCode() async {
    setState(() {
      _isSendingCode = true;
      _phoneAuthError = null;
    });
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: _phoneController.text.trim(),
      verificationCompleted: (credential) async {
        await FirebaseAuth.instance.signInWithCredential(credential);
        await widget.controller.firebaseSignIn();
      },
      verificationFailed: (error) {
        if (!mounted) return;
        setState(() {
          _phoneAuthError = _messageForPhoneAuthError(error);
          _isSendingCode = false;
        });
      },
      codeSent: (verificationId, _) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _isSendingCode = false;
        });
      },
      codeAutoRetrievalTimeout: (verificationId) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _isSendingCode = false;
        });
      },
    );
  }

  Future<void> _verifyCode() async {
    setState(() {
      _isVerifyingCode = true;
      _phoneAuthError = null;
    });
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _smsCodeController.text.trim(),
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      await widget.controller.firebaseSignIn();
    } on FirebaseAuthException catch (error) {
      setState(() {
        _phoneAuthError = _messageForPhoneAuthError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isVerifyingCode = false;
        });
      }
    }
  }

  void _resetPhoneVerification() {
    setState(() {
      _verificationId = null;
      _smsCodeController.clear();
      _phoneAuthError = null;
    });
  }

  String _messageForPhoneAuthError(FirebaseAuthException error) {
    return switch (error.code) {
      'invalid-phone-number' => 'מספר הטלפון לא תקין',
      'invalid-verification-code' => 'קוד האימות לא תקין',
      'too-many-requests' => 'בוצעו יותר מדי ניסיונות. נסה שוב מאוחר יותר',
      _ => error.message ?? 'אימות הטלפון נכשל',
    };
  }
}
