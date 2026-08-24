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
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'עריכת לקוח' : 'לקוח חדש')),
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
                  decoration: const InputDecoration(labelText: 'הערה ראשונית'),
                  minLines: 2,
                  maxLines: 4,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEdit ? 'שמור שינויים' : 'צור לקוח'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _saving
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: const Text('ביטול'),
              ),
            ],
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
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final session = widget.controller.session!;
    final body = <String, Object?>{
      'name': _nameController.text.trim(),
      if (_phoneController.text.trim().isNotEmpty)
        'phone': _phoneController.text.trim(),
      if (_emailController.text.trim().isNotEmpty)
        'email': _emailController.text.trim(),
      if (_addressController.text.trim().isNotEmpty)
        'address': _addressController.text.trim(),
      if (!_isEdit && _noteController.text.trim().isNotEmpty)
        'initialNote': _noteController.text.trim(),
    };

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
}
