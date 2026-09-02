import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../theme/app_theme.dart';
import '../../utils/json_read.dart';
import '../../widgets/app_section_header.dart';
import '../auth/session_controller.dart';

class BusinessPhoneNumbersScreen extends StatefulWidget {
  const BusinessPhoneNumbersScreen({super.key, required this.controller});

  final SessionController controller;

  @override
  State<BusinessPhoneNumbersScreen> createState() =>
      _BusinessPhoneNumbersScreenState();
}

class _BusinessPhoneNumbersScreenState
    extends State<BusinessPhoneNumbersScreen> {
  Future<List<_BusinessPhoneNumber>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const _PhoneNumbersHero(),
          Expanded(
            child: FutureBuilder<List<_BusinessPhoneNumber>>(
              future: _future,
              builder: (context, snapshot) {
                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 22, 16, 32),
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'מספרי העסק',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            '${snapshot.data?.length ?? 0} מספרים',
                            style: const TextStyle(color: AppColors.muted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const _PhoneNumbersLoading()
                      else if (snapshot.hasError)
                        _PhoneNumbersState(
                          icon: Icons.cloud_off_outlined,
                          title: 'לא הצלחנו לטעון מספרים',
                          body: _messageFor(snapshot.error),
                          onRetry: _load,
                        )
                      else if (snapshot.data?.isEmpty ?? true)
                        const _PhoneNumbersState(
                          icon: Icons.phone_disabled_outlined,
                          title: 'עדיין לא שויך מספר',
                          body:
                              'הוסיפו את המספר הווירטואלי שמקבל את שיחות העסק.',
                        )
                      else
                        ...snapshot.data!.map(
                          (phone) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _PhoneNumberCard(
                              phone: phone,
                              onEdit: () => _editPhoneNumber(phone),
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: _addPhoneNumber,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.add_call),
                        label: const Text(
                          'הוספת מספר',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const _PhoneNumbersNote(),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _load() {
    final session = widget.controller.session!;
    setState(() {
      _future = widget.controller.apiClient.business
          .listPhoneNumbers(
            businessId: session.businessId!,
            firebaseUid: session.firebaseUid,
            mockPhoneNumber: session.mockPhoneNumber,
          )
          .then(
            (json) => mapListValue(
              json['phoneNumbers'],
            ).map(_BusinessPhoneNumber.fromJson).toList(),
          );
    });
  }

  Future<void> _refresh() async {
    _load();
    await _future;
  }

  Future<void> _addPhoneNumber() async {
    final input = await showModalBottomSheet<_PhoneNumberFormValue>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const Directionality(
        textDirection: TextDirection.rtl,
        child: _PhoneNumberEditorSheet(),
      ),
    );
    if (input == null) return;
    final session = widget.controller.session!;
    try {
      await widget.controller.apiClient.business.createPhoneNumber(
        businessId: session.businessId!,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        phoneNumber: input.phoneNumber,
        displayName: input.displayName,
        status: input.active ? 'ACTIVE' : 'INACTIVE',
      );
      widget.controller.markDataChanged();
      _load();
      _showMessage('המספר נוסף לעסק');
    } on ApiException catch (error) {
      _showMessage(error.message);
    }
  }

  Future<void> _editPhoneNumber(_BusinessPhoneNumber phone) async {
    final input = await showModalBottomSheet<_PhoneNumberFormValue>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: _PhoneNumberEditorSheet(phone: phone),
      ),
    );
    if (input == null) return;
    final session = widget.controller.session!;
    try {
      await widget.controller.apiClient.business.updatePhoneNumber(
        businessId: session.businessId!,
        phoneNumberId: phone.id,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        displayName: input.displayName,
        status: input.active ? 'ACTIVE' : 'INACTIVE',
      );
      widget.controller.markDataChanged();
      _load();
      _showMessage('המספר עודכן');
    } on ApiException catch (error) {
      _showMessage(error.message);
    }
  }

  String _messageFor(Object? error) {
    if (error is ApiException) return error.message;
    return 'בדוק שהשרת המקומי זמין.';
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PhoneNumbersHero extends StatelessWidget {
  const _PhoneNumbersHero();

  @override
  Widget build(BuildContext context) => const AppSectionHeader(
    title: 'מספרי העסק',
    subtitle: 'המספרים שמקבלים את שיחות העסק',
    icon: Icons.call_outlined,
  );
}

class _PhoneNumberCard extends StatelessWidget {
  const _PhoneNumberCard({required this.phone, required this.onEdit});

  final _BusinessPhoneNumber phone;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              color: AppColors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.phone_in_talk, color: AppColors.primary),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  phone.number,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _PhoneStatus(active: phone.active),
                    if (phone.displayName != null) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          phone.displayName!,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'עריכת מספר',
            onPressed: onEdit,
            color: AppColors.primary,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
    );
  }
}

class _PhoneStatus extends StatelessWidget {
  const _PhoneStatus({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: active ? AppColors.successContainer : AppColors.warningContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        active ? 'פעיל' : 'לא פעיל',
        style: TextStyle(
          color: active ? AppColors.success : AppColors.warning,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PhoneNumberEditorSheet extends StatefulWidget {
  const _PhoneNumberEditorSheet({this.phone});

  final _BusinessPhoneNumber? phone;

  @override
  State<_PhoneNumberEditorSheet> createState() =>
      _PhoneNumberEditorSheetState();
}

class _PhoneNumberEditorSheetState extends State<_PhoneNumberEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _phoneController;
  late final TextEditingController _nameController;
  late bool _active;

  bool get _editing => widget.phone != null;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.phone?.number ?? '');
    _nameController = TextEditingController(
      text: widget.phone?.displayName ?? '',
    );
    _active = widget.phone?.active ?? true;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          10,
          16,
          18 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add_call, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _editing ? 'עריכת מספר' : 'הוספת מספר',
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _phoneController,
                readOnly: _editing,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                  labelText: 'מספר וירטואלי',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'שדה חובה' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'שם לתצוגה',
                  hintText: 'לדוגמה: מספר ראשי',
                  prefixIcon: Icon(Icons.label_outline),
                ),
              ),
              const SizedBox(height: 10),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'מספר פעיל',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text('שיחות נכנסות יכולות להגיע למספר'),
                activeTrackColor: AppColors.primary,
                value: _active,
                onChanged: (value) => setState(() => _active = value),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.check),
                label: const Text(
                  'שמירה',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('ביטול'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      _PhoneNumberFormValue(
        phoneNumber: _phoneController.text.trim(),
        displayName: _nameController.text.trim(),
        active: _active,
      ),
    );
  }
}

class _PhoneNumberFormValue {
  const _PhoneNumberFormValue({
    required this.phoneNumber,
    required this.displayName,
    required this.active,
  });

  final String phoneNumber;
  final String displayName;
  final bool active;
}

class _BusinessPhoneNumber {
  const _BusinessPhoneNumber({
    required this.id,
    required this.number,
    required this.status,
    this.displayName,
  });

  final String id;
  final String number;
  final String status;
  final String? displayName;

  bool get active => status.toUpperCase() == 'ACTIVE';

  factory _BusinessPhoneNumber.fromJson(Map<String, Object?> json) {
    return _BusinessPhoneNumber(
      id: stringValue(json['id']),
      number: stringValue(json['plivoNumber'] ?? json['phoneNumber']),
      status: stringValue(json['status'], fallback: 'ACTIVE'),
      displayName: nullableString(json['displayName']),
    );
  }
}

class _PhoneNumbersLoading extends StatelessWidget {
  const _PhoneNumbersLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _PhoneNumbersState extends StatelessWidget {
  const _PhoneNumbersState({
    required this.icon,
    required this.title,
    required this.body,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              color: AppColors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 30),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, height: 1.4),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('נסה שוב'),
            ),
          ],
        ],
      ),
    );
  }
}

class _PhoneNumbersNote extends StatelessWidget {
  const _PhoneNumbersNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: AppColors.primary),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'חיבור מספר אמיתי לספק הטלפוניה יושלם בשלב ההטמעה. כרגע המסכים מנהלים את מספרי הדמו.',
              style: TextStyle(color: AppColors.primary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
