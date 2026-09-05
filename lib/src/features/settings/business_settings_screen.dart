import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../theme/app_theme.dart';
import '../../utils/json_read.dart';
import '../../widgets/app_section_header.dart';
import '../auth/session_controller.dart';
import 'business_phone_numbers_screen.dart';

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

const _workingDayLabels = <String, String>{
  'sunday': 'ראשון',
  'monday': 'שני',
  'tuesday': 'שלישי',
  'wednesday': 'רביעי',
  'thursday': 'חמישי',
  'friday': 'שישי',
  'saturday': 'שבת',
};

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
  final _reminderPromptController = TextEditingController();
  final _urgentPromptController = TextEditingController();

  Future<_SettingsPayload>? _future;
  String _timezone = 'Asia/Jerusalem';
  String _locale = 'he-IL';
  bool _allowUrgentCalls = true;
  String _assistantResponseMode = 'TEXT_ONLY';
  Map<String, _WorkingDay> _workingHours = _defaultWorkingHours();
  bool _saving = false;
  String? _savingField;
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
    _reminderPromptController.dispose();
    _urgentPromptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<_SettingsPayload>(
        future: _future,
        builder: (context, snapshot) {
          final loading = snapshot.connectionState == ConnectionState.waiting;
          return Form(
            key: _formKey,
            child: CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(child: _SettingsHero()),
                if (loading)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (snapshot.hasError)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _StateCard(
                      icon: Icons.cloud_off_outlined,
                      title: 'לא הצלחנו לטעון הגדרות',
                      body: _messageFor(snapshot.error),
                      onRetry: _load,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 22, 16, 32),
                    sliver: SliverList.list(
                      children: [
                        const _SettingsSectionTitle('פרטי העסק'),
                        const SizedBox(height: 9),
                        _SettingsCard(
                          children: [
                            _EditableSettingsField(
                              controller: _businessNameController,
                              label: 'שם העסק',
                              icon: Icons.storefront_outlined,
                              required: true,
                              saving: _savingField == 'businessName',
                              onSave: (value) =>
                                  _saveTopField('businessName', value),
                              validator: _required,
                            ),
                            const Divider(height: 1),
                            _EditableSettingsField(
                              controller: _ownerNameController,
                              label: 'שם בעל העסק',
                              icon: Icons.person_outline,
                              required: true,
                              saving: _savingField == 'ownerDisplayName',
                              onSave: (value) =>
                                  _saveTopField('ownerDisplayName', value),
                              validator: _required,
                            ),
                            const Divider(height: 1),
                            _EditableSettingsField(
                              controller: _notificationPhoneController,
                              label: 'טלפון לקבלת התראות',
                              icon: Icons.notifications_active_outlined,
                              keyboardType: TextInputType.phone,
                              saving: _savingField == 'notificationPhone',
                              onSave: (value) =>
                                  _saveTopField('notificationPhone', value),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const _SettingsSectionTitle('המזכירה הווירטואלית'),
                        const SizedBox(height: 9),
                        _SettingsCard(
                          children: [
                            _PhoneNumbersCard(
                              phoneNumbers: snapshot.data!.phoneNumbers,
                              onManage: _openPhoneNumbers,
                            ),
                            const Divider(height: 1),
                            SwitchListTile.adaptive(
                              contentPadding:
                                  const EdgeInsetsDirectional.fromSTEB(
                                    18,
                                    4,
                                    12,
                                    4,
                                  ),
                              secondary: const _SettingsIcon(
                                icon: Icons.emergency_outlined,
                              ),
                              title: const Text(
                                'לאפשר שיחות דחופות',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              subtitle: const Text(
                                'אפשרו ללקוחות לסמן פנייה כדחופה',
                              ),
                              activeTrackColor: AppColors.primary,
                              value: _allowUrgentCalls,
                              onChanged: (value) =>
                                  setState(() => _allowUrgentCalls = value),
                            ),
                            ...[
                              const Divider(height: 1),
                              SwitchListTile.adaptive(
                                contentPadding:
                                    const EdgeInsetsDirectional.fromSTEB(
                                      18,
                                      4,
                                      12,
                                      4,
                                    ),
                                secondary: const _SettingsIcon(
                                  icon: Icons.record_voice_over_outlined,
                                ),
                                title: const Text(
                                  'להקריא את תשובות העוזרת',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                subtitle: const Text(
                                  'הטקסט תמיד יוצג גם כשהקראה פעילה',
                                ),
                                activeTrackColor: AppColors.primary,
                                value:
                                    _assistantResponseMode == 'TEXT_AND_VOICE',
                                onChanged: (value) => setState(
                                  () => _assistantResponseMode = value
                                      ? 'TEXT_AND_VOICE'
                                      : 'TEXT_ONLY',
                                ),
                              ),
                            ],
                            const Divider(height: 1),
                            _PromptField(
                              controller: _greetingController,
                              label: 'פתיח למזכירה',
                              icon: Icons.chat_bubble_outline,
                            ),
                            const Divider(height: 1),
                            _PromptField(
                              controller: _reminderPromptController,
                              label: 'נוסח חזרה ללקוח',
                              icon: Icons.keyboard_return_rounded,
                            ),
                            const Divider(height: 1),
                            _PromptField(
                              controller: _urgentPromptController,
                              label: 'נוסח שיחה דחופה',
                              icon: Icons.notifications_none_rounded,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const _SettingsSectionTitle('שפה ואזור זמן'),
                        const SizedBox(height: 9),
                        _SettingsCard(
                          children: [
                            _SettingsDropdown<String>(
                              icon: Icons.language,
                              label: 'שפה',
                              value: _locale,
                              items: const [
                                DropdownMenuItem(
                                  value: 'he-IL',
                                  child: Text('עברית'),
                                ),
                                DropdownMenuItem(
                                  value: 'en-US',
                                  child: Text('English'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _locale = value);
                                }
                              },
                            ),
                            const Divider(height: 1),
                            _SettingsDropdown<String>(
                              icon: Icons.schedule_outlined,
                              label: 'אזור זמן',
                              value: _timezone,
                              items: _timezones
                                  .map(
                                    (timezone) => DropdownMenuItem(
                                      value: timezone,
                                      child: Text(timezone),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _timezone = value);
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const _SettingsSectionTitle('שעות עבודה'),
                        const SizedBox(height: 9),
                        _SettingsCard(
                          children: _workingDayLabels.entries
                              .expand(
                                (entry) => [
                                  _WorkingHoursRow(
                                    label: entry.value,
                                    value: _workingHours[entry.key]!,
                                    onToggle: (enabled) => setState(
                                      () => _workingHours = {
                                        ..._workingHours,
                                        entry.key: _workingHours[entry.key]!
                                            .copyWith(closed: !enabled),
                                      },
                                    ),
                                    onOpen: () => _pickWorkingTime(
                                      entry.key,
                                      opening: true,
                                    ),
                                    onClose: () => _pickWorkingTime(
                                      entry.key,
                                      opening: false,
                                    ),
                                  ),
                                  if (entry.key != 'saturday')
                                    const Divider(height: 1),
                                ],
                              )
                              .toList(),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          _InlineError(message: _error!),
                        ],
                        const SizedBox(height: 22),
                        FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                            backgroundColor: AppColors.accent,
                            foregroundColor: AppColors.onPrimary,
                            disabledBackgroundColor: AppColors.accent
                                .withValues(alpha: 0.45),
                          ),
                          icon: _saving
                              ? const SizedBox.square(
                                  dimension: 19,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.onPrimary,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(
                            _saving ? 'שומר...' : 'שמירת הגדרות',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
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
            widget.controller.apiClient.business.getSettings(
              businessId: session.businessId!,
              firebaseUid: session.firebaseUid,
              mockPhoneNumber: session.mockPhoneNumber,
            ),
            widget.controller.apiClient.business.listPhoneNumbers(
              businessId: session.businessId!,
              firebaseUid: session.firebaseUid,
              mockPhoneNumber: session.mockPhoneNumber,
            ),
            widget.controller.apiClient.actionBatches.preferences(
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
            final greetingText = stringValue(settings['greetingText']);
            _greetingController.text =
                greetingText.isEmpty || _isLegacyGreeting(greetingText)
                ? _defaultGreetingText()
                : greetingText;
            _reminderPromptController.text = stringValue(
              settings['reminderPrompt'],
            );
            _urgentPromptController.text = stringValue(
              settings['urgentPrompt'],
            );
            _allowUrgentCalls = settings['allowUrgentCalls'] != false;
            _workingHours = _parseWorkingHours(settings['workingHours']);
            _assistantResponseMode = stringValue(
              mapValue(responses[2]['preferences'])['assistantResponseMode'],
              fallback: 'TEXT_ONLY',
            );
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
    final invalidDays = _workingHours.entries
        .where((entry) => !entry.value.closed)
        .where((entry) => entry.value.open.compareTo(entry.value.close) >= 0)
        .toList();
    final invalidDay = invalidDays.isEmpty ? null : invalidDays.first;
    if (invalidDay != null) {
      setState(
        () => _error =
            'בשעות העבודה של יום ${_workingDayLabels[invalidDay.key]} שעת הפתיחה חייבת להיות לפני שעת הסגירה.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    final session = widget.controller.session!;
    try {
      await widget.controller.apiClient.business.updateSettings(
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
          'reminderPrompt': _nullableText(_reminderPromptController),
          'urgentPrompt': _nullableText(_urgentPromptController),
          'allowUrgentCalls': _allowUrgentCalls,
          'workingHours': _workingHours.map(
            (key, value) => MapEntry(key, value.toJson()),
          ),
        },
      );
      await widget.controller.apiClient.actionBatches.updatePreferences(
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        mode: _assistantResponseMode,
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

  Future<void> _saveTopField(String field, String value) async {
    final trimmed = value.trim();
    if ((field == 'businessName' || field == 'ownerDisplayName') &&
        trimmed.isEmpty) {
      setState(() => _error = 'שדה חובה');
      return;
    }

    final session = widget.controller.session!;
    setState(() {
      _savingField = field;
      _error = null;
    });

    try {
      await widget.controller.apiClient.business.updateSettings(
        businessId: session.businessId!,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        body: {
          field: field == 'notificationPhone' && trimmed.isEmpty
              ? null
              : trimmed,
        },
      );
      await widget.controller.refreshSession();
      widget.controller.markDataChanged();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('השדה נשמר')));
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _savingField = null);
    }
  }

  Future<void> _openPhoneNumbers() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            BusinessPhoneNumbersScreen(controller: widget.controller),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _pickWorkingTime(String day, {required bool opening}) async {
    final current = _workingHours[day]!;
    final selected = await showTimePicker(
      context: context,
      initialTime: _parseTime(opening ? current.open : current.close),
      helpText: opening ? 'שעת פתיחה' : 'שעת סגירה',
    );
    if (selected == null || !mounted) return;
    setState(() {
      _workingHours = {
        ..._workingHours,
        day: current.copyWith(
          open: opening ? _formatTime(selected) : current.open,
          close: opening ? current.close : _formatTime(selected),
        ),
      };
    });
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

  String _defaultGreetingText() {
    final businessName = _businessNameController.text.trim().isEmpty
        ? 'שם העסק'
        : _businessNameController.text.trim();
    final ownerName = _ownerNameController.text.trim().isEmpty
        ? 'שם בעל העסק'
        : _ownerNameController.text.trim();
    return 'שלום הגעתם ל$businessName, $ownerName לא יכול לענות כרגע אבל יחזור אליכם בהקדם האפשרי. הקישו 1 לבקשת חזרה. הקישו 2 לבקשת חזרה עם השארת הודעה. הקישו 3 לפנייה דחופה.';
  }

  bool _isLegacyGreeting(String text) {
    return text.contains('לחזרה טלפונית') ||
        text.contains('לחזרה הקישו') ||
        text.contains('הודעה 2, דחוף 3');
  }
}

class _WorkingDay {
  const _WorkingDay({
    required this.open,
    required this.close,
    this.closed = false,
  });

  final String open;
  final String close;
  final bool closed;

  _WorkingDay copyWith({String? open, String? close, bool? closed}) =>
      _WorkingDay(
        open: open ?? this.open,
        close: close ?? this.close,
        closed: closed ?? this.closed,
      );

  Map<String, Object?> toJson() => {
    'open': open,
    'close': close,
    if (closed) 'closed': true,
  };
}

Map<String, _WorkingDay> _defaultWorkingHours() => {
  'sunday': const _WorkingDay(open: '08:00', close: '18:00'),
  'monday': const _WorkingDay(open: '08:00', close: '18:00'),
  'tuesday': const _WorkingDay(open: '08:00', close: '18:00'),
  'wednesday': const _WorkingDay(open: '08:00', close: '18:00'),
  'thursday': const _WorkingDay(open: '08:00', close: '18:00'),
  'friday': const _WorkingDay(open: '08:00', close: '14:00'),
  'saturday': const _WorkingDay(open: '00:00', close: '00:00', closed: true),
};

Map<String, _WorkingDay> _parseWorkingHours(Object? value) {
  final result = _defaultWorkingHours();
  final json = mapValue(value);
  for (final key in _workingDayLabels.keys) {
    final day = mapValue(json[key]);
    if (day.isEmpty) continue;
    result[key] = _WorkingDay(
      open: stringValue(day['open'], fallback: result[key]!.open),
      close: stringValue(day['close'], fallback: result[key]!.close),
      closed: day['closed'] == true,
    );
  }
  return result;
}

TimeOfDay _parseTime(String value) {
  final parts = value.split(':');
  return TimeOfDay(
    hour: int.tryParse(parts.first) ?? 8,
    minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
  );
}

String _formatTime(TimeOfDay value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

class _WorkingHoursRow extends StatelessWidget {
  const _WorkingHoursRow({
    required this.label,
    required this.value,
    required this.onToggle,
    required this.onOpen,
    required this.onClose,
  });

  final String label;
  final _WorkingDay value;
  final ValueChanged<bool> onToggle;
  final VoidCallback onOpen;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 10, 8),
    child: Row(
      children: [
        Switch.adaptive(value: !value.closed, onChanged: onToggle),
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const Spacer(),
        if (value.closed)
          const Text('סגור', style: TextStyle(color: AppColors.muted))
        else ...[
          TextButton(onPressed: onOpen, child: Text(value.open)),
          const Text('–', style: TextStyle(color: AppColors.muted)),
          TextButton(onPressed: onClose, child: Text(value.close)),
        ],
      ],
    ),
  );
}

class _SettingsHero extends StatelessWidget {
  const _SettingsHero();

  @override
  Widget build(BuildContext context) => const AppSectionHeader(
    title: 'הגדרות העסק',
    subtitle: 'פרטים, שעות עבודה והעדפות',
    icon: Icons.storefront_outlined,
  );
}

class _SettingsSectionTitle extends StatelessWidget {
  const _SettingsSectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
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
      child: Column(children: children),
    );
  }
}

class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: AppColors.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: AppColors.primary, size: 21),
    );
  }
}

class _EditableSettingsField extends StatefulWidget {
  const _EditableSettingsField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.onSave,
    this.keyboardType,
    this.required = false,
    this.saving = false,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool required;
  final bool saving;
  final String? Function(String?)? validator;
  final Future<void> Function(String value) onSave;

  @override
  State<_EditableSettingsField> createState() => _EditableSettingsFieldState();
}

class _EditableSettingsFieldState extends State<_EditableSettingsField> {
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
      child: Row(
        children: [
          _SettingsIcon(icon: widget.icon),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: widget.controller,
              readOnly: !_editing || widget.saving,
              keyboardType: widget.keyboardType,
              validator: widget.validator,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                labelText: widget.label,
                labelStyle: const TextStyle(color: AppColors.muted),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onFieldSubmitted: (_) {
                if (_editing && !widget.saving) _toggleOrSave();
              },
            ),
          ),
          IconButton(
            tooltip: _editing ? 'שמור' : 'ערוך',
            onPressed: widget.saving ? null : _toggleOrSave,
            color: AppColors.primary,
            icon: widget.saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(_editing ? Icons.check : Icons.edit_outlined),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleOrSave() async {
    if (!_editing) {
      setState(() => _editing = true);
      return;
    }
    if (widget.required && widget.controller.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('שדה חובה')));
      return;
    }
    await widget.onSave(widget.controller.text);
    if (!mounted) return;
    setState(() => _editing = false);
  }
}

class _PromptField extends StatelessWidget {
  const _PromptField({
    required this.controller,
    required this.label,
    required this.icon,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _SettingsIcon(icon: icon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                filled: false,
                labelText: label,
                alignLabelWithHint: true,
                labelStyle: const TextStyle(color: AppColors.muted),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsDropdown<T> extends StatelessWidget {
  const _SettingsDropdown({
    required this.icon,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 12, 8),
      child: Row(
        children: [
          _SettingsIcon(icon: icon),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<T>(
              initialValue: value,
              isExpanded: true,
              decoration: InputDecoration(
                filled: false,
                labelText: label,
                labelStyle: const TextStyle(color: AppColors.muted),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhoneNumbersCard extends StatelessWidget {
  const _PhoneNumbersCard({required this.phoneNumbers, required this.onManage});

  final List<_BusinessPhoneNumber> phoneNumbers;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onManage,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 12),
        child: Row(
          children: [
            const _SettingsIcon(icon: Icons.phone_in_talk_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'מספר וירטואלי',
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 3),
                  if (phoneNumbers.isEmpty)
                    const Text(
                      'עדיין לא שויך מספר לעסק',
                      style: TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else
                    ...phoneNumbers.map(
                      (phone) => Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                phone.number,
                                style: const TextStyle(
                                  color: AppColors.ink,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _PhoneStatus(status: phone.status),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_left, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

class _PhoneStatus extends StatelessWidget {
  const _PhoneStatus({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final active = status.toUpperCase() == 'ACTIVE';
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

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
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
