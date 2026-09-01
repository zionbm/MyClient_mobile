import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../core/network/idempotency_key.dart';
import '../../core/state/data_invalidator.dart';
import '../../models/v2_activity.dart';
import '../../models/v2_customer.dart';
import '../../theme/app_theme.dart';
import '../../utils/json_read.dart';
import '../auth/session_controller.dart';
import '../home/home_screen.dart';
import '../voice/voice_command_recorder.dart';
import '../voice/voice_command_result_sheet.dart';
import 'v2_search_screen.dart';
import 'v2_amount_sheet.dart';
import 'v2_reports_screen.dart';
import 'v2_pending_actions_screen.dart';

class V2HomeScreen extends StatefulWidget {
  const V2HomeScreen({
    super.key,
    required this.controller,
    this.voiceStartRequests,
    this.voicePhase,
  });

  final SessionController controller;
  final ValueListenable<int>? voiceStartRequests;
  final ValueNotifier<VoiceRecordingPhase>? voicePhase;

  @override
  State<V2HomeScreen> createState() => _V2HomeScreenState();
}

class _V2HomeScreenState extends State<V2HomeScreen> {
  final VoiceCommandRecorder _voiceRecorder = VoiceCommandRecorder();
  final TextEditingController _searchController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  Future<List<V2Activity>>? _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _voiceRecorder.addListener(_voiceChanged);
    widget.voiceStartRequests?.addListener(_voiceRequested);
    widget.controller.dataInvalidator.addListener(_dataChanged);
    _load();
  }

  @override
  void dispose() {
    _voiceRecorder.removeListener(_voiceChanged);
    widget.voiceStartRequests?.removeListener(_voiceRequested);
    widget.controller.dataInvalidator.removeListener(_dataChanged);
    _voiceRecorder.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 130),
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 54, 20, 22),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(30),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'היום בעסק',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'תשלומים ויתרות',
                          color: Colors.white,
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => V2ReportsScreen(
                                controller: widget.controller,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.bar_chart_outlined),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.controller.session?.businessName ?? '',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _create(V2ActivityKind.job),
                            icon: const Icon(Icons.work_outline),
                            label: const Text('עבודה'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: () => _create(V2ActivityKind.visit),
                            icon: const Icon(Icons.home_work_outlined),
                            label: const Text('ביקור'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text(_displayDate(_selectedDate)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: _showAvailability,
                      icon: const Icon(Icons.event_available_outlined),
                      label: const Text('זמינות'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  readOnly: true,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          V2SearchScreen(controller: widget.controller),
                    ),
                  ),
                  decoration: const InputDecoration(
                    hintText: 'חיפוש בעבודות ובביקורים',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() => _query = value.trim()),
                ),
              ),
              FutureBuilder<List<V2Activity>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return _message('לא הצלחנו לטעון את לוח הפעילות');
                  }
                  final query = _query.toLowerCase();
                  final items = (snapshot.data ?? const <V2Activity>[])
                      .where(
                        (item) =>
                            query.isEmpty ||
                            item.title.toLowerCase().contains(query) ||
                            (item.customerName?.toLowerCase().contains(query) ??
                                false),
                      )
                      .toList();
                  if (items.isEmpty) {
                    return _message('אין עבודות או ביקורים ביום הזה');
                  }
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: items
                          .map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _ActivityCard(
                                item: item,
                                onAction: (action) => _lifecycle(item, action),
                                onAmount: () => _openAmount(item),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        PositionedDirectional(
          start: 16,
          end: 16,
          bottom: 16,
          child: VoiceRecordingStatusCard(
            recorder: _voiceRecorder,
            onStopForReview: _voiceRecorder.stopForReview,
            onSubmit: _submitVoice,
            onRecordAgain: () => _voiceRecorder.start(widget.controller),
            onCancel: _voiceRecorder.cancel,
          ),
        ),
      ],
    );
  }

  Future<void> _load() async {
    final session = widget.controller.session!;
    final from = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final next = from.add(const Duration(days: 1));
    setState(() {
      _future = widget.controller.apiClient.v2Activities.schedule(
        businessId: session.businessId!,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        from: from,
        to: next,
      );
    });
    await _future;
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (selected == null) return;
    _selectedDate = selected;
    await _load();
  }

  Future<void> _create(V2ActivityKind kind) async {
    final created = await showModalBottomSheet<V2Activity>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _V2ActivityForm(
        controller: widget.controller,
        kind: kind,
        initialDate: _selectedDate,
      ),
    );
    if (created == null) return;
    widget.controller.markDataChanged({DataScope.crm});
    await _load();
  }

  Future<void> _lifecycle(V2Activity item, String action) async {
    final session = widget.controller.session!;
    var body = const <String, Object?>{};
    if (action == 'report-completed') {
      final choice = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('סיום הפעילות'),
          content: const Text('האם היה חיוב עבור הפעילות?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'charge'),
              child: const Text('כן, יש חיוב'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'no_charge'),
              child: const Text('לא היה חיוב'),
            ),
          ],
        ),
      );
      if (choice == null) return;
      if (choice == 'charge') {
        await _openAmount(item);
      } else {
        body = const {'noCharge': true};
      }
    }
    try {
      final updated = await widget.controller.apiClient.v2Activities.lifecycle(
        kind: item.kind,
        businessId: session.businessId!,
        entityId: item.id,
        action: action,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        idempotencyKey: IdempotencyKey.create('${item.kind.apiPath}_$action'),
        body: body,
      );
      if (!mounted) return;
      final message =
          action == 'report-completed' &&
              updated.status == V2ActivityStatus.open
          ? 'הביצוע סומן. הפעילות נשארה פתוחה עד להשלמת פרטי החיוב.'
          : 'הפעילות עודכנה';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      widget.controller.markDataChanged({DataScope.crm});
      await _load();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _openAmount(V2Activity item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          V2AmountSheet(controller: widget.controller, activity: item),
    );
    widget.controller.markDataChanged({DataScope.crm});
    await _load();
  }

  Future<void> _showAvailability() async {
    final session = widget.controller.session!;
    try {
      final result = await widget.controller.apiClient.v2Activities
          .availability(
            businessId: session.businessId!,
            firebaseUid: session.firebaseUid,
            mockPhoneNumber: session.mockPhoneNumber,
            date: _selectedDate,
            durationMinutes: 60,
          );
      final slots = (result['freeSlots'] as List? ?? const [])
          .whereType<Map<String, Object?>>()
          .take(8)
          .map(
            (slot) =>
                DateTime.tryParse(stringValue(slot['startsAt']))?.toLocal(),
          )
          .whereType<DateTime>()
          .map((date) => TimeOfDay.fromDateTime(date).format(context))
          .toList();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('חלונות פנויים לשעה'),
          content: Text(
            slots.isEmpty ? 'לא נמצאו חלונות פנויים' : slots.join('  •  '),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('סגור'),
            ),
          ],
        ),
      );
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  void _voiceRequested() {
    if (_voiceRecorder.preparing || _voiceRecorder.uploading) return;
    if (_voiceRecorder.recording) {
      _voiceRecorder.stopForReview();
    } else {
      _voiceRecorder.start(widget.controller);
    }
  }

  void _voiceChanged() {
    final notifier = widget.voicePhase;
    if (notifier != null && notifier.value != _voiceRecorder.phase) {
      notifier.value = _voiceRecorder.phase;
    }
    if (mounted) setState(() {});
  }

  void _dataChanged() {
    if (mounted) _load();
  }

  Future<void> _submitVoice() async {
    final result = await _voiceRecorder.submitReviewedTranscript(
      widget.controller,
    );
    if (result == null || !mounted) return;
    await _load();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => VoiceCommandResultSheet(
        result: result.result,
        actionBatchId: result.actionBatchId,
        controller: widget.controller,
        onOpenPendingActions: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                V2PendingActionsScreen(controller: widget.controller),
          ),
        ),
        onRecordAgain: () => _voiceRecorder.start(widget.controller),
        onResolved: _load,
      ),
    );
    _voiceRecorder.acknowledgeResult();
  }

  Widget _message(String text) => Padding(
    padding: const EdgeInsets.all(32),
    child: Center(child: Text(text)),
  );
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.item,
    required this.onAction,
    required this.onAmount,
  });
  final V2Activity item;
  final ValueChanged<String> onAction;
  final VoidCallback onAmount;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                item.kind == V2ActivityKind.job
                    ? Icons.work_outline
                    : Icons.home_work_outlined,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(item.kind.hebrewLabel),
            ],
          ),
          if (item.customerName != null) Text(item.customerName!),
          if (item.startsAt != null)
            Text(
              '${_displayDate(item.startsAt!.toLocal())} · ${TimeOfDay.fromDateTime(item.startsAt!.toLocal()).format(context)}',
            ),
          if (item.locationSnapshot != null) Text(item.locationSnapshot!),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: item.status == V2ActivityStatus.open
                ? [
                    TextButton(
                      onPressed: () => onAction('report-completed'),
                      child: const Text('דיווח סיום'),
                    ),
                    TextButton(
                      onPressed: () => onAction('cancel'),
                      child: const Text('ביטול'),
                    ),
                  ]
                : [
                    TextButton(
                      onPressed: () => onAction('reopen'),
                      child: const Text('פתיחה מחדש'),
                    ),
                  ],
          ),
          TextButton.icon(
            onPressed: onAmount,
            icon: const Icon(Icons.payments_outlined),
            label: const Text('סכום ותשלום'),
          ),
        ],
      ),
    ),
  );
}

class _V2ActivityForm extends StatefulWidget {
  const _V2ActivityForm({
    required this.controller,
    required this.kind,
    required this.initialDate,
  });
  final SessionController controller;
  final V2ActivityKind kind;
  final DateTime initialDate;

  @override
  State<_V2ActivityForm> createState() => _V2ActivityFormState();
}

class _V2ActivityFormState extends State<_V2ActivityForm> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  Future<List<V2Customer>>? _customers;
  String? _customerId;
  DateTime? _startsAt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final session = widget.controller.session!;
    _customers = widget.controller.apiClient.v2Customers
        .list(
          businessId: session.businessId!,
          firebaseUid: session.firebaseUid,
          mockPhoneNumber: session.mockPhoneNumber,
        )
        .then((page) => page.items);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${widget.kind.hebrewLabel} חדשה',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<V2Customer>>(
            future: _customers,
            builder: (context, snapshot) => DropdownButtonFormField<String>(
              initialValue: _customerId,
              decoration: const InputDecoration(labelText: 'לקוח *'),
              items: (snapshot.data ?? const <V2Customer>[])
                  .map(
                    (customer) => DropdownMenuItem(
                      value: customer.id,
                      child: Text(customer.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _customerId = value),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'כותרת *'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            decoration: const InputDecoration(labelText: 'תיאור (אופציונלי)'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickDateTime,
            icon: const Icon(Icons.schedule),
            label: Text(
              _startsAt == null
                  ? 'הוספת מועד (אופציונלי)'
                  : '${_displayDate(_startsAt!)} · ${TimeOfDay.fromDateTime(_startsAt!).format(context)}',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : () => _save(),
            child: Text(_saving ? 'שומר...' : 'שמירה'),
          ),
        ],
      ),
    ),
  );

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: widget.initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (time == null) return;
    setState(
      () => _startsAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }

  Future<void> _save({String? scheduleConflictToken}) async {
    if (_customerId == null || _title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('צריך לבחור לקוח ולהוסיף כותרת')),
      );
      return;
    }
    setState(() => _saving = true);
    final session = widget.controller.session!;
    try {
      final activity = await widget.controller.apiClient.v2Activities.create(
        kind: widget.kind,
        businessId: session.businessId!,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        idempotencyKey: IdempotencyKey.create('${widget.kind.apiPath}_create'),
        body: {
          'customerId': _customerId,
          'title': _title.text.trim(),
          if (_description.text.trim().isNotEmpty)
            'description': _description.text.trim(),
          if (_startsAt != null)
            'startsAt': _startsAt!.toUtc().toIso8601String(),
          'scheduleConflictToken': ?scheduleConflictToken,
        },
      );
      if (mounted) Navigator.pop(context, activity);
    } on ApiException catch (error) {
      final envelope = mapValue(error.details);
      final apiError = mapValue(envelope['error']);
      final conflict = mapValue(apiError['details']);
      final token = stringValue(conflict['scheduleConflictToken']);
      if (error.statusCode == 409 &&
          conflict['code'] == 'SCHEDULE_CONFLICT' &&
          token.isNotEmpty &&
          mounted) {
        final conflictCount = (conflict['conflicts'] as List?)?.length ?? 0;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('יש התנגשות בלוח'),
            content: Text(
              conflictCount == 1
                  ? 'כבר קיימת פעילות בזמן הזה. ליצור בכל זאת? האישור תקף לחמש דקות ורק להתנגשות שהוצגה.'
                  : 'קיימות $conflictCount פעילויות בזמן הזה. ליצור בכל זאת? האישור תקף לחמש דקות ורק להתנגשויות שהוצגו.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('חזרה'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('יצירה בכל זאת'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await _save(scheduleConflictToken: token);
        }
      } else if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

String _displayDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
