import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../core/network/idempotency_key.dart';
import '../../core/state/data_invalidator.dart';
import '../../models/page.dart' as pagination;
import '../../models/v2_activity.dart';
import '../../theme/app_theme.dart';
import '../../utils/json_read.dart';
import '../auth/session_controller.dart';
import 'v2_amount_sheet.dart';
import 'v2_activity_detail_screen.dart';
import 'v2_home_screen.dart';

enum _CalendarView { day, week }

class V2CalendarScreen extends StatefulWidget {
  const V2CalendarScreen({super.key, required this.controller});

  final SessionController controller;

  @override
  State<V2CalendarScreen> createState() => _V2CalendarScreenState();
}

class _V2CalendarScreenState extends State<V2CalendarScreen> {
  DateTime _selectedDate = DateTime.now();
  _CalendarView _view = _CalendarView.day;
  Future<_CalendarData>? _future;

  @override
  void initState() {
    super.initState();
    widget.controller.dataInvalidator.addListener(_handleDataChanged);
    _load();
  }

  @override
  void dispose() {
    widget.controller.dataInvalidator.removeListener(_handleDataChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _CalendarHeader(
              selectedDate: _selectedDate,
              view: _view,
              onPrevious: () => _moveDate(-1),
              onNext: () => _moveDate(1),
              onPickDate: _pickDate,
              onViewChanged: (value) {
                setState(() => _view = value);
                _load();
              },
              onAvailability: _showAvailability,
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: FutureBuilder<_CalendarData>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return ListView(
                        children: const [
                          SizedBox(height: 120),
                          Center(child: CircularProgressIndicator()),
                        ],
                      );
                    }
                    if (snapshot.hasError) {
                      return _message('לא הצלחנו לטעון את היומן');
                    }
                    return _calendarBody(
                      snapshot.data ?? const _CalendarData(),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateMenu,
        icon: const Icon(Icons.add),
        label: const Text('פעילות'),
      ),
    );
  }

  Widget _calendarBody(_CalendarData data) {
    final children = <Widget>[];
    if (data.scheduled.isEmpty) {
      children.add(
        const _CalendarEmpty(
          icon: Icons.event_available_outlined,
          text: 'אין פעילויות בטווח הזה',
        ),
      );
    } else if (_view == _CalendarView.day) {
      children.addAll(data.scheduled.map(_activityCard));
    } else {
      final grouped = <DateTime, List<V2Activity>>{};
      for (final activity in data.scheduled) {
        final local = activity.startsAt!.toLocal();
        final date = DateTime(local.year, local.month, local.day);
        grouped.putIfAbsent(date, () => []).add(activity);
      }
      for (final entry in grouped.entries) {
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
            child: Text(
              MaterialLocalizations.of(context).formatFullDate(entry.key),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
        );
        children.addAll(entry.value.map(_activityCard));
      }
    }
    children.add(
      const Padding(
        padding: EdgeInsets.fromLTRB(0, 24, 0, 8),
        child: Text(
          'עדיין לא נקבע',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
      ),
    );
    if (data.unscheduled.isEmpty) {
      children.add(
        const _CalendarEmpty(
          icon: Icons.event_busy_outlined,
          text: 'אין פעילויות פתוחות שמחכות לשיבוץ',
        ),
      );
    } else {
      children.addAll(data.unscheduled.map(_activityCard));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
      children: children,
    );
  }

  Widget _activityCard(V2Activity activity) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: V2ActivityCard(
      item: activity,
      onOpen: () => _openActivity(activity),
      onAction: (action) => _lifecycle(activity, action),
      onAmount: () => _openAmount(activity),
      onEdit: () => _edit(activity),
      onDelete: () => _delete(activity),
    ),
  );

  Widget _message(String text) => ListView(
    padding: const EdgeInsets.all(32),
    children: [
      const SizedBox(height: 100),
      const Icon(Icons.cloud_off_outlined, size: 42),
      const SizedBox(height: 12),
      Text(text, textAlign: TextAlign.center),
    ],
  );

  Future<void> _load() async {
    final session = widget.controller.session!;
    final range = _range();
    final future =
        Future.wait<Object>([
          widget.controller.apiClient.v2Activities.schedule(
            businessId: session.businessId!,
            firebaseUid: session.firebaseUid,
            mockPhoneNumber: session.mockPhoneNumber,
            from: range.$1,
            to: range.$2,
          ),
          widget.controller.apiClient.v2Activities.list(
            kind: V2ActivityKind.job,
            businessId: session.businessId!,
            firebaseUid: session.firebaseUid,
            mockPhoneNumber: session.mockPhoneNumber,
          ),
          widget.controller.apiClient.v2Activities.list(
            kind: V2ActivityKind.visit,
            businessId: session.businessId!,
            firebaseUid: session.firebaseUid,
            mockPhoneNumber: session.mockPhoneNumber,
          ),
        ]).then((values) {
          final scheduled = values[0] as List<V2Activity>;
          final jobs = (values[1] as pagination.Page<V2Activity>).items;
          final visits = (values[2] as pagination.Page<V2Activity>).items;
          final unscheduled =
              [...jobs, ...visits]
                  .where(
                    (item) =>
                        item.status == V2ActivityStatus.open &&
                        item.startsAt == null,
                  )
                  .toList()
                ..sort((left, right) => left.title.compareTo(right.title));
          scheduled.sort((left, right) {
            if (left.startsAt == null) return 1;
            if (right.startsAt == null) return -1;
            return left.startsAt!.compareTo(right.startsAt!);
          });
          return _CalendarData(scheduled: scheduled, unscheduled: unscheduled);
        });
    setState(() => _future = future);
    await future;
  }

  (DateTime, DateTime) _range() {
    final day = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    if (_view == _CalendarView.day) {
      return (day, day.add(const Duration(days: 1)));
    }
    final weekStart = day.subtract(Duration(days: day.weekday % 7));
    return (weekStart, weekStart.add(const Duration(days: 7)));
  }

  void _moveDate(int direction) {
    final days = _view == _CalendarView.day ? direction : direction * 7;
    setState(() => _selectedDate = _selectedDate.add(Duration(days: days)));
    _load();
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (selected == null) return;
    setState(() => _selectedDate = selected);
    await _load();
  }

  Future<void> _showCreateMenu() async {
    final kind = await showModalBottomSheet<V2ActivityKind>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'פעילות חדשה',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, V2ActivityKind.job),
                icon: const Icon(Icons.work_outline),
                label: const Text('עבודה'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context, V2ActivityKind.visit),
                icon: const Icon(Icons.home_work_outlined),
                label: const Text('ביקור'),
              ),
            ],
          ),
        ),
      ),
    );
    if (kind != null) await _create(kind);
  }

  Future<void> _create(V2ActivityKind kind) async {
    final created = await showModalBottomSheet<V2Activity>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => V2ActivityForm(
        controller: widget.controller,
        kind: kind,
        initialDate: _selectedDate,
      ),
    );
    if (created == null) return;
    widget.controller.markDataChanged({DataScope.crm});
    await _load();
  }

  Future<void> _edit(V2Activity activity) async {
    final updated = await showModalBottomSheet<V2Activity>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => V2ActivityForm(
        controller: widget.controller,
        kind: activity.kind,
        initialDate: activity.startsAt?.toLocal() ?? _selectedDate,
        activity: activity,
      ),
    );
    if (updated == null) return;
    widget.controller.markDataChanged({DataScope.crm});
    await _load();
  }

  Future<void> _openActivity(V2Activity activity) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => V2ActivityDetailScreen(
          controller: widget.controller,
          kind: activity.kind,
          activityId: activity.id,
          initialActivity: activity,
        ),
      ),
    );
    await _load();
  }

  Future<void> _delete(V2Activity activity) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('למחוק את ה${activity.kind.hebrewLabel}?'),
        content: Text(activity.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('חזרה'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('מחיקה'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final session = widget.controller.session!;
    try {
      await widget.controller.apiClient.v2Activities.delete(
        kind: activity.kind,
        businessId: session.businessId!,
        entityId: activity.id,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        idempotencyKey: IdempotencyKey.create('calendar_delete'),
      );
      widget.controller.markDataChanged({DataScope.crm});
      await _load();
    } on ApiException catch (error) {
      _showError(error.message);
    }
  }

  Future<void> _lifecycle(V2Activity activity, String action) async {
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
        await _openAmount(activity);
        return;
      }
      body = const {'noCharge': true};
    }
    try {
      await widget.controller.apiClient.v2Activities.lifecycle(
        kind: activity.kind,
        businessId: session.businessId!,
        entityId: activity.id,
        action: action,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        idempotencyKey: IdempotencyKey.create('calendar_$action'),
        body: body,
      );
      widget.controller.markDataChanged({DataScope.crm});
      await _load();
    } on ApiException catch (error) {
      _showError(error.message);
    }
  }

  Future<void> _openAmount(V2Activity activity) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          V2AmountSheet(controller: widget.controller, activity: activity),
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
      _showError(error.message);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _handleDataChanged() {
    if (mounted) _load();
  }
}

class _CalendarData {
  const _CalendarData({this.scheduled = const [], this.unscheduled = const []});

  final List<V2Activity> scheduled;
  final List<V2Activity> unscheduled;
}

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({
    required this.selectedDate,
    required this.view,
    required this.onPrevious,
    required this.onNext,
    required this.onPickDate,
    required this.onViewChanged,
    required this.onAvailability,
  });

  final DateTime selectedDate;
  final _CalendarView view;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPickDate;
  final ValueChanged<_CalendarView> onViewChanged;
  final VoidCallback onAvailability;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'יומן',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(
                tooltip: 'זמינות',
                onPressed: onAvailability,
                icon: const Icon(Icons.event_available_outlined),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                tooltip: 'הבא',
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right),
              ),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPickDate,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(
                    MaterialLocalizations.of(
                      context,
                    ).formatMediumDate(selectedDate),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'הקודם',
                onPressed: onPrevious,
                icon: const Icon(Icons.chevron_left),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SegmentedButton<_CalendarView>(
            segments: const [
              ButtonSegment(value: _CalendarView.day, label: Text('יום')),
              ButtonSegment(value: _CalendarView.week, label: Text('שבוע')),
            ],
            selected: {view},
            onSelectionChanged: (value) => onViewChanged(value.first),
          ),
        ],
      ),
    );
  }
}

class _CalendarEmpty extends StatelessWidget {
  const _CalendarEmpty({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(color: AppColors.muted)),
          ),
        ],
      ),
    );
  }
}
