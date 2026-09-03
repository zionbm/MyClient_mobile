import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import 'session_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.controller});

  final SessionController controller;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _mockVerificationCode = '123456';
  static const _demoPhoneNumber = '+972501111111';

  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _smsCodeController = TextEditingController();
  String? _verificationId;
  String? _verifiedPhoneNumber;
  String? _phoneAuthError;
  bool _mockCodeSent = false;
  bool _isSendingCode = false;
  bool _isVerifyingCode = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _smsCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            const _LoginBrandHero(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Transform.translate(
                    offset: const Offset(0, -52),
                    child: _buildLoginCard(context),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
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
              _awaitingCode ? 'הקוד בדרך אליך' : 'נעים להכיר',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _awaitingCode
                  ? 'הזינו את הקוד שנשלח למספר ${_displayPhoneNumber()}'
                  : 'הכניסו מספר טלפון ונשלח אליכם קוד כניסה',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 16),
            ),
            const SizedBox(height: 24),
            if (_awaitingCode) _buildCodeFields() else _buildPhoneField(),
            if (_errorMessage != null) ...[
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
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _isBusy ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: _isBusy
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onPrimary,
                      ),
                    )
                  : Text(
                      _awaitingCode ? 'אימות וכניסה' : 'שלחו לי קוד',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
            const SizedBox(height: 14),
            if (_awaitingCode)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: _isBusy ? null : _resetPhoneVerification,
                    child: const Text('שינוי מספר'),
                  ),
                  const Text('·', style: TextStyle(color: AppColors.muted)),
                  TextButton(
                    onPressed: _isBusy ? null : _sendCode,
                    child: const Text('שליחה מחדש'),
                  ),
                ],
              )
            else ...[
              const _SecurityNote(),
              const Divider(height: 32),
              Text(
                'כניסה ראשונה?',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                'אחרי האימות נגדיר יחד את העסק',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneField() {
    return TextFormField(
      controller: _phoneController,
      autofocus: true,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.done,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.right,
      autofillHints: const [AutofillHints.telephoneNumber],
      decoration: const InputDecoration(
        labelText: 'מספר טלפון',
        hintText: '054-123-4567',
        helperText: 'ישראל +972',
        prefixIcon: Icon(Icons.phone_outlined),
      ),
      validator: _validateIsraeliPhoneNumber,
      onFieldSubmitted: (_) => _submit(),
    );
  }

  Widget _buildCodeFields() {
    return TextFormField(
      controller: _smsCodeController,
      autofocus: true,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLength: 6,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      autofillHints: const [AutofillHints.oneTimeCode],
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: 8,
      ),
      decoration: const InputDecoration(
        labelText: 'קוד אימות',
        hintText: '••••••',
        counterText: '',
        prefixIcon: Icon(Icons.lock_outline),
      ),
      validator: _validateVerificationCode,
      onFieldSubmitted: (_) => _submit(),
    );
  }

  bool get _awaitingCode => _mockCodeSent || _verificationId != null;

  String? get _errorMessage =>
      _phoneAuthError ?? widget.controller.errorMessage;

  bool get _isBusy =>
      widget.controller.isLoading || _isSendingCode || _isVerifyingCode;

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_awaitingCode) {
      _verifyCode();
    } else {
      _sendCode();
    }
  }

  Future<void> _sendCode() async {
    final phoneNumber = _normalizeIsraeliPhoneNumber(_phoneController.text);
    setState(() {
      _isSendingCode = true;
      _phoneAuthError = null;
      _verifiedPhoneNumber = phoneNumber;
    });

    if (widget.controller.isMockAuth) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      setState(() {
        _mockCodeSent = true;
        _smsCodeController.text = _mockVerificationCode;
        _isSendingCode = false;
      });
      return;
    }

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phoneNumber,
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
      if (widget.controller.isMockAuth) {
        if (_smsCodeController.text.trim() != _mockVerificationCode) {
          setState(() => _phoneAuthError = 'קוד האימות לא תקין');
          return;
        }
        final phone = _verifiedPhoneNumber!;
        await widget.controller.devSignIn(
          firebaseUid: _mockFirebaseUid(phone),
          phoneNumber: phone,
        );
        return;
      }

      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _smsCodeController.text.trim(),
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      await widget.controller.firebaseSignIn();
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(() => _phoneAuthError = _messageForPhoneAuthError(error));
      }
    } finally {
      if (mounted) setState(() => _isVerifyingCode = false);
    }
  }

  void _resetPhoneVerification() {
    setState(() {
      _verificationId = null;
      _verifiedPhoneNumber = null;
      _mockCodeSent = false;
      _smsCodeController.clear();
      _phoneAuthError = null;
    });
  }

  String _mockFirebaseUid(String phoneNumber) {
    if (phoneNumber == _demoPhoneNumber) return 'firebase_demo_1';
    final digits = phoneNumber.replaceAll(RegExp(r'\D'), '');
    return 'mock_phone_$digits';
  }

  String _displayPhoneNumber() {
    final value = _verifiedPhoneNumber ?? _phoneController.text;
    return value.replaceFirst('+972', '0');
  }

  String? _validateVerificationCode(String? value) {
    final code = value?.trim() ?? '';
    if (code.isEmpty) return 'יש להזין את קוד האימות';
    if (code.length != 6) return 'הקוד צריך להכיל 6 ספרות';
    return null;
  }

  String _messageForPhoneAuthError(FirebaseAuthException error) {
    return switch (error.code) {
      'invalid-phone-number' => 'מספר הטלפון לא תקין',
      'invalid-verification-code' => 'קוד האימות לא תקין',
      'too-many-requests' => 'בוצעו יותר מדי ניסיונות. נסו שוב מאוחר יותר',
      _ => error.message ?? 'אימות הטלפון נכשל',
    };
  }

  String? _validateIsraeliPhoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) return 'יש להזין מספר טלפון';
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('972') && digits.length == 12) return null;
    if (digits.startsWith('0') && digits.length == 10) return null;
    if (!digits.startsWith('0') && digits.length == 9) return null;
    return 'מספר טלפון ישראלי לא תקין';
  }

  String _normalizeIsraeliPhoneNumber(String value) {
    final trimmed = value.trim();
    if (trimmed.startsWith('+')) {
      return trimmed.replaceAll(RegExp(r'[\s-]'), '');
    }
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('972')) return '+$digits';
    final localNumber = digits.startsWith('0') ? digits.substring(1) : digits;
    return '+972$localNumber';
  }
}

class _LoginBrandHero extends StatelessWidget {
  const _LoginBrandHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 430,
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 44),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(48)),
      ),
      child: Column(
        children: [
          const _BrandMark(),
          const SizedBox(height: 16),
          const Text(
            'MyClient',
            textDirection: TextDirection.ltr,
            style: TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'העסק שלך, מסודר ופשוט',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primaryContainer, width: 3),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(Icons.people_alt, size: 48, color: AppColors.primary),
          PositionedDirectional(
            end: 14,
            top: 18,
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SecurityNote extends StatelessWidget {
  const _SecurityNote();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.verified_user_outlined, color: AppColors.accent, size: 21),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'הקוד תקף לזמן קצר ונועד לשמור על החשבון שלכם',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
