import 'package:flutter/material.dart';

import '../../../core/network/idempotency_key.dart';
import '../../../core/presentation/user_error_message.dart';
import '../../../models/customer.dart';
import '../../auth/session_controller.dart';
import '../widgets/form_sheet.dart';

class CustomerFormScreen extends StatefulWidget {
  const CustomerFormScreen({
    super.key,
    required this.controller,
    this.customer,
    this.initialName,
    this.initialPhone,
  });
  final SessionController controller;
  final Customer? customer;
  final String? initialName;
  final String? initialPhone;

  @override
  State<CustomerFormScreen> createState() => _CustomerFormState();
}

class _CustomerFormState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _notes;
  late final String _idempotencyKey;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: widget.customer?.name ?? widget.initialName ?? '',
    );
    _email = TextEditingController(text: widget.customer?.email ?? '');
    _notes = TextEditingController(text: widget.customer?.generalNotes ?? '');
    _idempotencyKey = IdempotencyKey.create('customer_form');
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormSheet(
      title: widget.customer == null ? 'לקוח חדש' : 'עריכת לקוח',
      saving: _saving,
      error: _error,
      onSave: _save,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'שם הלקוח *'),
              validator: (value) =>
                  value?.trim().isEmpty ?? true ? 'צריך להזין שם לקוח' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'אימייל'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'הערות כלליות'),
              minLines: 2,
              maxLines: 4,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final session = widget.controller.session!;
    final body = <String, Object?>{
      'name': _name.text.trim(),
      if (_email.text.trim().isNotEmpty) 'email': _email.text.trim(),
      if (_notes.text.trim().isNotEmpty) 'generalNotes': _notes.text.trim(),
      if (widget.customer != null) 'version': widget.customer!.version,
    };
    try {
      final customer = widget.customer == null
          ? await widget.controller.apiClient.customers.create(
              businessId: session.businessId!,
              firebaseUid: session.firebaseUid,
              mockPhoneNumber: session.mockPhoneNumber,
              idempotencyKey: _idempotencyKey,
              body: body,
            )
          : await widget.controller.apiClient.customers.update(
              businessId: session.businessId!,
              customerId: widget.customer!.id,
              firebaseUid: session.firebaseUid,
              mockPhoneNumber: session.mockPhoneNumber,
              idempotencyKey: _idempotencyKey,
              body: body,
            );
      if (widget.customer == null &&
          widget.initialPhone?.trim().isNotEmpty == true) {
        await widget.controller.apiClient.customers.addPhone(
          businessId: session.businessId!,
          customerId: customer.id,
          firebaseUid: session.firebaseUid,
          mockPhoneNumber: session.mockPhoneNumber,
          idempotencyKey: IdempotencyKey.create('customer_initial_phone'),
          body: {'phone': widget.initialPhone!.trim(), 'isPrimary': true},
        );
      }
      if (mounted) Navigator.of(context).pop(customer);
    } catch (error) {
      if (mounted) setState(() => _error = userErrorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class PhoneForm extends StatefulWidget {
  const PhoneForm({
    super.key,
    required this.controller,
    required this.customerId,
    this.phone,
  });
  final SessionController controller;
  final String customerId;
  final CustomerPhone? phone;

  @override
  State<PhoneForm> createState() => _PhoneFormState();
}

class _PhoneFormState extends State<PhoneForm> {
  final _phone = TextEditingController();
  final _label = TextEditingController();
  final _key = IdempotencyKey.create('customer_phone');
  bool _primary = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final phone = widget.phone;
    if (phone != null) {
      _phone.text = phone.rawPhone;
      _label.text = phone.label ?? '';
      _primary = phone.isPrimary;
    }
  }

  @override
  void dispose() {
    _phone.dispose();
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FormSheet(
    title: widget.phone == null ? 'הוספת מספר טלפון' : 'עריכת מספר טלפון',
    saving: _saving,
    error: _error,
    onSave: _save,
    child: Column(
      children: [
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.right,
          decoration: const InputDecoration(labelText: 'מספר טלפון *'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _label,
          decoration: const InputDecoration(labelText: 'תווית, למשל נייד'),
        ),
        SwitchListTile(
          value: _primary,
          onChanged: (value) => setState(() => _primary = value),
          title: const Text('מספר ראשי'),
          contentPadding: EdgeInsets.zero,
        ),
      ],
    ),
  );

  Future<void> _save() async {
    if (_phone.text.trim().isEmpty) {
      setState(() => _error = 'צריך להזין מספר טלפון');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final session = widget.controller.session!;
    try {
      final body = <String, Object?>{
        'phone': _phone.text.trim(),
        'label': _label.text.trim().isEmpty ? null : _label.text.trim(),
        'isPrimary': _primary,
      };
      if (widget.phone == null) {
        await widget.controller.apiClient.customers.addPhone(
          businessId: session.businessId!,
          customerId: widget.customerId,
          firebaseUid: session.firebaseUid,
          mockPhoneNumber: session.mockPhoneNumber,
          idempotencyKey: _key,
          body: body,
        );
      } else {
        await widget.controller.apiClient.customers.updatePhone(
          businessId: session.businessId!,
          customerId: widget.customerId,
          phoneId: widget.phone!.id,
          firebaseUid: session.firebaseUid,
          mockPhoneNumber: session.mockPhoneNumber,
          idempotencyKey: _key,
          body: body,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = userErrorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class AddressForm extends StatefulWidget {
  const AddressForm({
    super.key,
    required this.controller,
    required this.customerId,
    this.address,
  });
  final SessionController controller;
  final String customerId;
  final ServiceAddress? address;

  @override
  State<AddressForm> createState() => _AddressFormState();
}

class _AddressFormState extends State<AddressForm> {
  final _address = TextEditingController();
  final _label = TextEditingController();
  final _key = IdempotencyKey.create('service_address');
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final address = widget.address;
    if (address != null) {
      _address.text = address.addressText;
      _label.text = address.label ?? '';
    }
  }

  @override
  void dispose() {
    _address.dispose();
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FormSheet(
    title: widget.address == null ? 'הוספת כתובת שירות' : 'עריכת כתובת שירות',
    saving: _saving,
    error: _error,
    onSave: _save,
    child: Column(
      children: [
        TextField(
          controller: _address,
          decoration: const InputDecoration(labelText: 'כתובת *'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _label,
          decoration: const InputDecoration(
            labelText: 'תווית, למשל בית או משרד',
          ),
        ),
      ],
    ),
  );

  Future<void> _save() async {
    if (_address.text.trim().isEmpty) {
      setState(() => _error = 'צריך להזין כתובת');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final session = widget.controller.session!;
    try {
      final body = <String, Object?>{
        'addressText': _address.text.trim(),
        'label': _label.text.trim().isEmpty ? null : _label.text.trim(),
      };
      if (widget.address == null) {
        await widget.controller.apiClient.customers.addAddress(
          businessId: session.businessId!,
          customerId: widget.customerId,
          firebaseUid: session.firebaseUid,
          mockPhoneNumber: session.mockPhoneNumber,
          idempotencyKey: _key,
          body: body,
        );
      } else {
        await widget.controller.apiClient.customers.updateAddress(
          businessId: session.businessId!,
          customerId: widget.customerId,
          addressId: widget.address!.id,
          firebaseUid: session.firebaseUid,
          mockPhoneNumber: session.mockPhoneNumber,
          idempotencyKey: _key,
          body: body,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = userErrorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class NoteForm extends StatefulWidget {
  const NoteForm({
    super.key,
    required this.controller,
    required this.customerId,
    this.note,
  });

  final SessionController controller;
  final String customerId;
  final Note? note;

  @override
  State<NoteForm> createState() => _NoteFormState();
}

class _NoteFormState extends State<NoteForm> {
  final _text = TextEditingController();
  final _key = IdempotencyKey.create('customer_note');
  NoteStatus _status = NoteStatus.open;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final note = widget.note;
    if (note != null) {
      _text.text = note.text;
      _status = note.status;
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FormSheet(
    title: widget.note == null ? 'הוספת הערה' : 'עריכת הערה',
    saving: _saving,
    error: _error,
    onSave: _save,
    child: Column(
      children: [
        TextField(
          controller: _text,
          minLines: 3,
          maxLines: 7,
          decoration: const InputDecoration(labelText: 'תוכן ההערה *'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<NoteStatus>(
          initialValue: _status,
          decoration: const InputDecoration(labelText: 'סטטוס'),
          items: NoteStatus.values
              .map(
                (status) => DropdownMenuItem(
                  value: status,
                  child: Text(status.hebrewLabel),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _status = value ?? _status),
        ),
      ],
    ),
  );

  Future<void> _save() async {
    if (_text.text.trim().isEmpty) {
      setState(() => _error = 'צריך לכתוב את ההערה');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final session = widget.controller.session!;
    final body = <String, Object?>{
      'text': _text.text.trim(),
      'status': _status.apiValue,
    };
    try {
      final note = widget.note == null
          ? await widget.controller.apiClient.customers.createNote(
              businessId: session.businessId!,
              customerId: widget.customerId,
              firebaseUid: session.firebaseUid,
              mockPhoneNumber: session.mockPhoneNumber,
              idempotencyKey: _key,
              body: body,
            )
          : await widget.controller.apiClient.customers.updateNote(
              businessId: session.businessId!,
              customerId: widget.customerId,
              noteId: widget.note!.id,
              firebaseUid: session.firebaseUid,
              mockPhoneNumber: session.mockPhoneNumber,
              idempotencyKey: _key,
              body: body,
            );
      if (mounted) Navigator.pop(context, note);
    } catch (error) {
      if (mounted) setState(() => _error = userErrorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
