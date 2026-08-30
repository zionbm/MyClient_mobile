import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../models/customer.dart';
import '../../theme/app_theme.dart';
import '../auth/session_controller.dart';
import 'phone_number_picker.dart';

class CustomerFormScreen extends StatefulWidget {
  const CustomerFormScreen({
    super.key,
    required this.controller,
    this.customer,
    this.initialName,
    this.initialPhone,
    this.returnCreatedCustomer = false,
  });

  final SessionController controller;
  final Customer? customer;
  final String? initialName;
  final String? initialPhone;
  final bool returnCreatedCustomer;

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  final _noteController = TextEditingController();

  bool _saving = false;
  String? _error;
  String? _initialSnapshot;

  bool get _isEdit => widget.customer != null;

  @override
  void initState() {
    super.initState();
    final customer = widget.customer;
    _nameController = TextEditingController(
      text: customer?.name ?? widget.initialName ?? '',
    );
    _phoneController = TextEditingController(
      text: customer?.phone ?? widget.initialPhone ?? '',
    );
    _emailController = TextEditingController(text: customer?.email ?? '');
    _addressController = TextEditingController(text: customer?.address ?? '');
    _initialSnapshot = _formSnapshot();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        body: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _CustomerFormHero(isEdit: _isEdit, onBack: _cancel),
                Transform.translate(
                  offset: const Offset(0, -44),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildDetailsCard(),
                            if (!_isEdit) ...[
                              const SizedBox(height: 14),
                              _buildInitialNoteCard(),
                            ],
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              _FormErrorMessage(message: _error!),
                            ],
                            const SizedBox(height: 18),
                            FilledButton(
                              onPressed: _saving ? null : _save,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(56),
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: _saving
                                  ? const SizedBox.square(
                                      dimension: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      _isEdit ? 'שמירת שינויים' : 'שמירת לקוח',
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 12),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.edit_outlined,
                                  size: 17,
                                  color: AppColors.accent,
                                ),
                                SizedBox(width: 7),
                                Flexible(
                                  child: Text(
                                    'אפשר לעדכן את הפרטים בכל שלב',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                          ],
                        ),
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

  Widget _buildDetailsCard() {
    return _CustomerFormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CustomerFieldLabel(label: 'שם הלקוח', required: true),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              hintText: 'לדוגמה: ישראל ישראלי',
              prefixIcon: Icon(Icons.person_outline),
            ),
            textInputAction: TextInputAction.next,
            validator: _required,
          ),
          const SizedBox(height: 18),
          const _CustomerFieldLabel(label: 'מספר טלפון'),
          TextFormField(
            controller: _phoneController,
            decoration: InputDecoration(
              hintText: '054-123-4567',
              prefixIcon: const Icon(Icons.phone_outlined),
              suffixIconConstraints: const BoxConstraints(
                minHeight: 44,
                minWidth: 124,
              ),
              suffixIcon: Padding(
                padding: const EdgeInsetsDirectional.only(end: 6),
                child: TextButton.icon(
                  onPressed: _saving ? null : _pickPhoneSource,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                  icon: const Icon(Icons.contact_phone_outlined, size: 19),
                  label: const Text(
                    'בחירת מספר',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.right,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 18),
          const _CustomerFieldLabel(label: 'אימייל'),
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              hintText: 'name@example.com',
              prefixIcon: Icon(Icons.mail_outline),
            ),
            keyboardType: TextInputType.emailAddress,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.right,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 18),
          const _CustomerFieldLabel(label: 'כתובת'),
          TextFormField(
            controller: _addressController,
            decoration: const InputDecoration(
              hintText: 'רחוב, מספר ועיר',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
            textInputAction: _isEdit
                ? TextInputAction.done
                : TextInputAction.next,
          ),
        ],
      ),
    );
  }

  Widget _buildInitialNoteCard() {
    return _CustomerFormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Expanded(child: _CustomerFieldLabel(label: 'הערה ראשונית')),
              Text(
                'לא חובה',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
          ),
          TextFormField(
            controller: _noteController,
            decoration: const InputDecoration(
              hintText: 'פרטים שכדאי לזכור על הלקוח',
              alignLabelWithHint: true,
            ),
            minLines: 3,
            maxLines: 5,
          ),
        ],
      ),
    );
  }

  Future<void> _pickPhoneFromCalls() async {
    final phone = await pickPhoneFromBusinessCalls(
      context: context,
      controller: widget.controller,
    );
    if (phone == null || !mounted) return;
    setState(() => _phoneController.text = phone);
  }

  Future<void> _pickPhoneFromContacts() async {
    final phone = await pickPhoneFromDeviceContacts(context);
    if (phone == null || !mounted) return;
    setState(() => _phoneController.text = phone);
  }

  Future<void> _pickPhoneSource() async {
    final source = await showModalBottomSheet<_PhoneSource>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => const _PhoneSourceSheet(),
    );
    if (!mounted || source == null) return;
    if (source == _PhoneSource.contacts) {
      await _pickPhoneFromContacts();
    } else {
      await _pickPhoneFromCalls();
    }
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'שדה חובה' : null;
  }

  Future<void> _save() async {
    if (_isEdit && !_hasUnsavedChanges) {
      Navigator.of(context).pop(false);
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final session = widget.controller.session!;
    final body = _customerPayload(includeInitialNote: true);

    try {
      Customer? savedCustomer;
      if (_isEdit) {
        await widget.controller.apiClient.customers.update(
          businessId: session.businessId!,
          customerId: widget.customer!.id,
          firebaseUid: session.firebaseUid,
          mockPhoneNumber: session.mockPhoneNumber,
          body: body,
        );
      } else {
        savedCustomer = await widget.controller.apiClient.customers.create(
          businessId: session.businessId!,
          firebaseUid: session.firebaseUid,
          mockPhoneNumber: session.mockPhoneNumber,
          body: body,
        );
      }
      widget.controller.markDataChanged();
      if (!mounted) return;
      Navigator.of(context).pop(
        widget.returnCreatedCustomer && savedCustomer != null
            ? savedCustomer
            : true,
      );
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _cancel() async {
    if (_saving) return;
    if (!_hasUnsavedChanges) {
      Navigator.of(context).pop(false);
      return;
    }

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('לשמור את השינויים?'),
        content: const Text('יש שינויים שלא נשמרו במסמך הזה.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('לא'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('כן'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (shouldSave == true) {
      await _save();
    } else if (shouldSave == false) {
      Navigator.of(context).pop(false);
    }
  }

  bool get _hasUnsavedChanges => _formSnapshot() != _initialSnapshot;

  String _formSnapshot() {
    final entries = _customerPayload(
      includeInitialNote: true,
    ).entries.map((entry) => '${entry.key}:${entry.value}').toList()..sort();
    return entries.join('|');
  }

  Map<String, Object?> _customerPayload({required bool includeInitialNote}) {
    return {
      'name': _nameController.text.trim(),
      if (_phoneController.text.trim().isNotEmpty)
        'phone': _phoneController.text.trim(),
      if (_emailController.text.trim().isNotEmpty)
        'email': _emailController.text.trim(),
      if (_addressController.text.trim().isNotEmpty)
        'address': _addressController.text.trim(),
      if (includeInitialNote &&
          !_isEdit &&
          _noteController.text.trim().isNotEmpty)
        'initialNote': _noteController.text.trim(),
    };
  }
}

enum _PhoneSource { contacts, businessCalls }

class _CustomerFormHero extends StatelessWidget {
  const _CustomerFormHero({required this.isEdit, required this.onBack});

  final bool isEdit;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 300,
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top + 8,
        16,
        34,
      ),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          PositionedDirectional(
            top: 0,
            start: 0,
            child: IconButton(
              tooltip: 'חזרה',
              onPressed: onBack,
              style: IconButton.styleFrom(foregroundColor: Colors.white),
              icon: const Icon(
                Icons.arrow_forward,
                textDirection: TextDirection.ltr,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isEdit ? 'עריכת לקוח' : 'לקוח חדש',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isEdit
                    ? 'מעדכנים את הפרטים ושומרים'
                    : 'מוסיפים פרטים ומתחילים לעבוד',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFD4E6E4), fontSize: 16),
              ),
              const SizedBox(height: 20),
              Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(
                  color: Color(0xFF2B6669),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isEdit
                      ? Icons.manage_accounts_outlined
                      : Icons.person_add_alt,
                  color: Colors.white,
                  size: 38,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CustomerFormCard extends StatelessWidget {
  const _CustomerFormCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 20,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CustomerFieldLabel extends StatelessWidget {
  const _CustomerFieldLabel({required this.label, this.required = false});

  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4, bottom: 7),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: label),
            if (required)
              const TextSpan(
                text: ' *',
                style: TextStyle(color: AppColors.accent),
              ),
          ],
        ),
        style: const TextStyle(
          color: AppColors.ink,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PhoneSourceSheet extends StatelessWidget {
  const _PhoneSourceSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'בחירת מספר',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'מאיפה תרצו לבחור את מספר הטלפון?',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            _PhoneSourceTile(
              icon: Icons.contacts_outlined,
              title: 'מאנשי הקשר',
              subtitle: 'בחירה מאנשי הקשר במכשיר',
              onTap: () => Navigator.of(context).pop(_PhoneSource.contacts),
            ),
            const SizedBox(height: 10),
            _PhoneSourceTile(
              icon: Icons.phone_callback_outlined,
              title: 'משיחות העסק',
              subtitle: 'בחירה משיחה אחרונה במערכת',
              onTap: () =>
                  Navigator.of(context).pop(_PhoneSource.businessCalls),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhoneSourceTile extends StatelessWidget {
  const _PhoneSourceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_left,
                color: AppColors.muted,
                textDirection: TextDirection.ltr,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormErrorMessage extends StatelessWidget {
  const _FormErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.errorContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}
