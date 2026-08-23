import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../utils/json_read.dart';
import '../auth/session_controller.dart';

const _timezones = [
  'Asia/Jerusalem',
  'UTC',
  'Europe/London',
  'Europe/Paris',
  'America/New_York',
  'America/Chicago',
  'America/Denver',
  'America/Los_Angeles',
  'Asia/Dubai',
  'Asia/Tokyo',
  'Australia/Sydney',
];

class BusinessSettingsScreen extends StatefulWidget {
  const BusinessSettingsScreen({super.key, required this.controller});

  final SessionController controller;

  @override
  State<BusinessSettingsScreen> createState() => _BusinessSettingsScreenState();
}

class _BusinessSettingsScreenState extends State<BusinessSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _notificationPhoneController = TextEditingController();
  final _greetingController = TextEditingController();
  final _callbackPromptController = TextEditingController();
  final _urgentPromptController = TextEditingController();

  Future<_SettingsPayload>? _future;
  String _timezone = 'Asia/Jerusalem';
  String _locale = 'he-IL';
  bool _allowUrgentCalls = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _ownerNameController.dispose();
    _notificationPhoneController.dispose();
    _greetingController.dispose();
    _callbackPromptController.dispose();
    _urgentPromptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('הגדרות עסק')),
      body: FutureBuilder<_SettingsPayload>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _StateCard(
              icon: Icons.cloud_off_outlined,
              title: 'לא הצלחנו לטעון הגדרות',
              body: _messageFor(snapshot.error),
              onRetry: _load,
            );
          }
          return SafeArea(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _PhoneNumbersCard(phoneNumbers: snapshot.data!.phoneNumbers),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _businessNameController,
                    decoration: const InputDecoration(labelText: 'שם העסק'),
                    validator: _required,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _ownerNameController,
                    decoration: const InputDecoration(labelText: 'שם בעל העסק'),
                    validator: _required,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notificationPhoneController,
                    decoration: const InputDecoration(
                      labelText: 'טלפון לקבלת התראות',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _locale,
                    decoration: const InputDecoration(labelText: 'שפה'),
                    items: const [
                      DropdownMenuItem(value: 'he-IL', child: Text('עברית')),
                      DropdownMenuItem(value: 'en-US', child: Text('English')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _locale = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _timezone,
                    decoration: const InputDecoration(labelText: 'אזור זמן'),
                    items: _timezones
                        .map(
                          (timezone) => DropdownMenuItem(
                            value: timezone,
                            child: Text(timezone),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _timezone = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('לאפשר שיחות דחופות'),
                    value: _allowUrgentCalls,
                    onChanged: (value) =>
                        setState(() => _allowUrgentCalls = value),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _greetingController,
                    decoration: const InputDecoration(
                      labelText: 'פתיח למזכירה',
                    ),
                    minLines: 2,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _callbackPromptController,
                    decoration: const InputDecoration(
                      labelText: 'נוסח חזרה ללקוח',
                    ),
                    minLines: 2,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _urgentPromptController,
                    decoration: const InputDecoration(
                      labelText: 'נוסח שיחה דחופה',
                    ),
                    minLines: 2,
                    maxLines: 4,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: _saving
                        ? const Text('שומר...')
                        : const Text('שמור הגדרות'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _load() {
    final session = widget.controller.session!;
    setState(() {
      _future =
          Future.wait([
            widget.controller.apiClient.getSettings(
              businessId: session.businessId!,
              firebaseUid: session.firebaseUid,
              mockPhoneNumber: session.mockPhoneNumber,
            ),
            widget.controller.apiClient.listPhoneNumbers(
              businessId: session.businessId!,
              firebaseUid: session.firebaseUid,
              mockPhoneNumber: session.mockPhoneNumber,
            ),
          ]).then((responses) {
            final settings = mapValue(responses[0]['settings']);
            _businessNameController.text = stringValue(
              settings['businessName'],
              fallback: session.businessName ?? 'MyClient',
            );
            _ownerNameController.text = stringValue(
              settings['ownerDisplayName'],
              fallback: session.displayName ?? '',
            );
            _timezone = stringValue(
              settings['timezone'],
              fallback: 'Asia/Jerusalem',
            );
            if (!_timezones.contains(_timezone)) {
              _timezone = 'Asia/Jerusalem';
            }
            _locale = stringValue(settings['locale'], fallback: 'he-IL');
            if (_locale != 'he-IL' && _locale != 'en-US') {
              _locale = 'he-IL';
            }
            _notificationPhoneController.text = stringValue(
              settings['notificationPhone'],
            );
            _greetingController.text = stringValue(settings['greetingText']);
            _callbackPromptController.text = stringValue(
              settings['callbackPrompt'],
            );
            _urgentPromptController.text = stringValue(
              settings['urgentPrompt'],
            );
            _allowUrgentCalls = settings['allowUrgentCalls'] != false;
            return _SettingsPayload(
              phoneNumbers: mapListValue(
                responses[1]['phoneNumbers'],
              ).map(_BusinessPhoneNumber.fromJson).toList(),
            );
          });
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final session = widget.controller.session!;
    try {
      await widget.controller.apiClient.updateSettings(
        businessId: session.businessId!,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        body: {
          'businessName': _businessNameController.text.trim(),
          'ownerDisplayName': _ownerNameController.text.trim(),
          'timezone': _timezone,
          'locale': _locale,
          'notificationPhone': _nullableText(_notificationPhoneController),
          'greetingText': _nullableText(_greetingController),
          'callbackPrompt': _nullableText(_callbackPromptController),
          'urgentPrompt': _nullableText(_urgentPromptController),
          'allowUrgentCalls': _allowUrgentCalls,
        },
      );
      await widget.controller.refreshSession();
      widget.controller.markDataChanged();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ההגדרות נשמרו')));
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'שדה חובה' : null;
  }

  String? _nullableText(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  String _messageFor(Object? error) {
    if (error is ApiException) return error.message;
    return 'בדוק שהשרת המקומי זמין.';
  }
}

class _PhoneNumbersCard extends StatelessWidget {
  const _PhoneNumbersCard({required this.phoneNumbers});

  final List<_BusinessPhoneNumber> phoneNumbers;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'מספר וירטואלי',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (phoneNumbers.isEmpty)
              const Text('עדיין לא שויך מספר וירטואלי לעסק')
            else
              ...phoneNumbers.map(
                (phone) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.phone_in_talk_outlined),
                  title: Text(phone.number),
                  subtitle: Text([phone.displayName, phone.status].join(' · ')),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BusinessPhoneNumber {
  const _BusinessPhoneNumber({
    required this.number,
    required this.status,
    required this.displayName,
  });

  final String number;
  final String status;
  final String displayName;

  factory _BusinessPhoneNumber.fromJson(Map<String, Object?> json) {
    return _BusinessPhoneNumber(
      number: stringValue(json['plivoNumber'] ?? json['phoneNumber']),
      status: stringValue(json['status'], fallback: 'ACTIVE'),
      displayName: stringValue(json['displayName'], fallback: 'MyClient'),
    );
  }
}

class _SettingsPayload {
  const _SettingsPayload({required this.phoneNumbers});

  final List<_BusinessPhoneNumber> phoneNumbers;
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.onRetry,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 40,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(body, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onRetry, child: const Text('נסה שוב')),
            ],
          ),
        ),
      ),
    );
  }
}
