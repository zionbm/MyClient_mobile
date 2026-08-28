import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../models/customer.dart';
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
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leadingWidth: 150,
          leading: _TopFormActions(
            saving: _saving,
            onSave: _save,
            onCancel: _cancel,
          ),
          title: Text(_isEdit ? 'עריכת לקוח' : 'לקוח חדש'),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'שם לקוח'),
                  textInputAction: TextInputAction.next,
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'טלפון'),
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 8),
                PhoneSourceButtons(
                  onBusinessCalls: _pickPhoneFromCalls,
                  onContacts: _pickPhoneFromContacts,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'אימייל'),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(labelText: 'כתובת'),
                  textInputAction: _isEdit
                      ? TextInputAction.done
                      : TextInputAction.next,
                ),
                if (!_isEdit) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _noteController,
                    decoration: const InputDecoration(
                      labelText: 'הערה ראשונית',
                    ),
                    minLines: 2,
                    maxLines: 4,
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
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

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'שדה חובה' : null;
  }

  Future<void> _save() async {
    if (!_hasUnsavedChanges) {
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
        await widget.controller.apiClient.updateCustomer(
          businessId: session.businessId!,
          customerId: widget.customer!.id,
          firebaseUid: session.firebaseUid,
          mockPhoneNumber: session.mockPhoneNumber,
          body: body,
        );
      } else {
        final response = await widget.controller.apiClient.createCustomer(
          businessId: session.businessId!,
          firebaseUid: session.firebaseUid,
          mockPhoneNumber: session.mockPhoneNumber,
          body: body,
        );
        final customerJson = response['customer'];
        if (customerJson is Map<String, Object?>) {
          savedCustomer = Customer.fromJson(customerJson);
        }
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

class _TopFormActions extends StatelessWidget {
  const _TopFormActions({
    required this.saving,
    required this.onSave,
    required this.onCancel,
  });

  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton(
            onPressed: saving ? null : onSave,
            style: FilledButton.styleFrom(
              minimumSize: const Size(56, 36),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: saving
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('שמור'),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: saving ? null : onCancel,
            style: TextButton.styleFrom(
              minimumSize: const Size(52, 36),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('ביטול'),
          ),
        ],
      ),
    );
  }
}
