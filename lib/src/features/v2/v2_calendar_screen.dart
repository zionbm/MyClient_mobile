import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../core/network/idempotency_key.dart';
import '../../core/state/data_invalidator.dart';
import '../../models/page.dart' as pagination;
import '../../models/v2_activity.dart';
import '../../models/v2_completed_item.dart';
import '../../models/v2_task.dart';
import '../../theme/app_theme.dart';
import '../../utils/json_read.dart';
import '../../widgets/main_top_bar.dart';
import '../auth/session_controller.dart';
import 'v2_amount_sheet.dart';
import 'v2_activity_detail_screen.dart';
import 'v2_customers_screen.dart';
import 'v2_home_screen.dart';
import 'widgets/v2_activity_card.dart';
import 'widgets/v2_completed_item_card.dart';

enum _CalendarView { day, week }

enum _CalendarCreateType { task, job, visit }

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
              onToday: _goToToday,
              onPickDate: _pickDate,
              onViewChanged: (value) {
                setState(() => _view = value);
                _load();
              },
              onDateSelected: (date) {
                setState(() {
                  _selectedDate = date;
                  _view = _CalendarView.day;
                });
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
    final entries = [
      ...data.scheduled.map(_AgendaEntry.activity),
      ...data.tasks.map(_AgendaEntry.task),
    ]..sort((left, right) => left.startsAt.compareTo(right.startsAt));
    if (entries.isEmpty) {
      children.add(
        const _CalendarEmpty(
          icon: Icons.event_available_outlined,
          text: 'אין משימות, עבודות או ביקורים בטווח הזה',
        ),
      );
    } else if (_view == _CalendarView.day) {
      children.addAll(entries.map(_agendaCard));
    } else {
      final grouped = <DateTime, List<_AgendaEntry>>{};
      for (final entry in entries) {
        final local = entry.startsAt.toLocal();
        final date = DateTime(local.year, local.month, local.day);
        grouped.putIfAbsent(date, () => []).add(entry);
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
        children.addAll(entry.value.map(_agendaCard));
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
    children.add(
      Padding(
        padding: const EdgeInsets.fromLTRB(0, 24, 0, 8),
        child: Text(
          _view == _CalendarView.day ? 'בוצעו ביום הזה' : 'בוצעו בטווח הזה',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
      ),
    );
    if (data.completed.isEmpty) {
      children.add(
        const _CalendarEmpty(
          icon: Icons.check_circle_outline,
          text: 'אין פריטים שבוצעו בתאריך הזה',
        ),
      );
    } else {
      children.addAll(
        data.completed.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: V2CompletedItemCard(
              item: item,
              onOpen: () => item.task != null
                  ? _editTask(item.task!)
                  : _openActivity(item.activity!),
            ),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
      children: children,
    );
  }

  Widget _agendaCard(_AgendaEntry entry) {
    final local = entry.startsAt.toLocal();
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(local),
      alwaysUse24HourFormat: true,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                time,
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: entry.task != null
                ? _CalendarTaskCard(
                    task: entry.task!,
                    onOpen: () => _editTask(entry.task!),
                    onComplete: () => _completeTask(entry.task!),
                  )
                : _CalendarActivityCard(
                    activity: entry.activity!,
                    onOpen: () => _openActivity(entry.activity!),
                  ),
          ),
        ],
      ),
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
          widget.controller.apiClient.v2Tasks.list(
            businessId: session.businessId!,
            firebaseUid: session.firebaseUid,
            mockPhoneNumber: session.mockPhoneNumber,
            limit: 100,
          ),
          widget.controller.apiClient.v2Activities.completed(
            businessId: session.businessId!,
            firebaseUid: session.firebaseUid,
            mockPhoneNumber: session.mockPhoneNumber,
            from: range.$1,
            to: range.$2,
          ),
        ]).then((values) {
          final scheduled = (values[0] as List<V2Activity>)
              .where((item) => item.executionCompletedAt == null)
              .toList();
          final jobs = (values[1] as pagination.Page<V2Activity>).items;
          final visits = (values[2] as pagination.Page<V2Activity>).items;
          final tasks = (values[3] as pagination.Page<V2Task>).items.where((
            task,
          ) {
            final dueAt = task.dueAt;
            return task.status == V2TaskStatus.open &&
                dueAt != null &&
                !dueAt.isBefore(range.$1.toUtc()) &&
                dueAt.isBefore(range.$2.toUtc());
          }).toList();
          final completed = values[4] as List<V2CompletedItem>;
          final unscheduled =
              [...jobs, ...visits]
                  .where(
                    (item) =>
                        item.status == V2ActivityStatus.open &&
                        item.startsAt == null &&
                        item.executionCompletedAt == null,
                  )
                  .toList()
                ..sort((left, right) => left.title.compareTo(right.title));
          scheduled.sort((left, right) {
            if (left.startsAt == null) return 1;
            if (right.startsAt == null) return -1;
            return left.startsAt!.compareTo(right.startsAt!);
          });
          return _CalendarData(
            scheduled: scheduled,
            tasks: tasks,
            unscheduled: unscheduled,
            completed: completed,
          );
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

  void _goToToday() {
    setState(() {
      _selectedDate = DateTime.now();
      _view = _CalendarView.day;
    });
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
    final type = await showModalBottomSheet<_CalendarCreateType>(
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
                onPressed: () =>
                    Navigator.pop(context, _CalendarCreateType.task),
                icon: const Icon(Icons.add_task),
                label: const Text('משימה או תזכורת'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.pop(context, _CalendarCreateType.job),
                icon: const Icon(Icons.work_outline),
                label: const Text('עבודה'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.pop(context, _CalendarCreateType.visit),
                icon: const Icon(Icons.home_work_outlined),
                label: const Text('ביקור'),
              ),
            ],
          ),
        ),
      ),
    );
    if (type == _CalendarCreateType.task) await _createTask();
    if (type == _CalendarCreateType.job) await _create(V2ActivityKind.job);
    if (type == _CalendarCreateType.visit) await _create(V2ActivityKind.visit);
  }

  Future<void> _createTask() async {
    final created = await showModalBottomSheet<V2Task>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => V2TaskForm(controller: widget.controller),
    );
    if (created == null) return;
    widget.controller.markDataChanged({DataScope.crm});
    await _load();
  }

  Future<void> _editTask(V2Task task) async {
    final updated = await showModalBottomSheet<V2Task>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => V2TaskForm(
        controller: widget.controller,
        customerId: task.customerId,
        task: task,
      ),
    );
    if (updated == null) return;
    widget.controller.markDataChanged({DataScope.crm});
    await _load();
  }

  Future<void> _completeTask(V2Task task) async {
    final session = widget.controller.session!;
    try {
      await widget.controller.apiClient.v2Tasks.lifecycle(
        businessId: session.businessId!,
        taskId: task.id,
        action: 'complete',
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        idempotencyKey: IdempotencyKey.create('calendar_task_complete'),
      );
      widget.controller.markDataChanged({DataScope.crm});
      await _load();
    } on ApiException catch (error) {
      _showError(error.message);
    }
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
  const _CalendarData({
    this.scheduled = const [],
    this.tasks = const [],
    this.unscheduled = const [],
    this.completed = const [],
  });

  final List<V2Activity> scheduled;
  final List<V2Task> tasks;
  final List<V2Activity> unscheduled;
  final List<V2CompletedItem> completed;
}

class _AgendaEntry {
  const _AgendaEntry._({this.activity, this.task, required this.startsAt});

  factory _AgendaEntry.activity(V2Activity activity) =>
      _AgendaEntry._(activity: activity, startsAt: activity.startsAt!);
  factory _AgendaEntry.task(V2Task task) =>
      _AgendaEntry._(task: task, startsAt: task.dueAt!);

  final V2Activity? activity;
  final V2Task? task;
  final DateTime startsAt;
}

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({
    required this.selectedDate,
    required this.view,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
    required this.onPickDate,
    required this.onViewChanged,
    required this.onDateSelected,
    required this.onAvailability,
  });

  final DateTime selectedDate;
  final _CalendarView view;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final VoidCallback onPickDate;
  final ValueChanged<_CalendarView> onViewChanged;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback onAvailability;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final isToday = DateUtils.isSameDay(today, selectedDate);
    return ColoredBox(
      color: AppColors.background,
      child: Column(
        children: [
          MainTopBar(
            title: 'יומן',
            subtitle: 'משימות ופעילויות לפי זמן',
            includeSafeArea: false,
            actions: [
              if (!isToday)
                TextButton(onPressed: onToday, child: const Text('היום')),
              IconButton(
                tooltip: 'זמינות',
                onPressed: onAvailability,
                icon: const Icon(Icons.event_available_outlined),
              ),
              PopupMenuButton<_CalendarView>(
                tooltip: 'בחירת תצוגה',
                initialValue: view,
                onSelected: onViewChanged,
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: _CalendarView.day,
                    child: Text('תצוגת יום'),
                  ),
                  PopupMenuItem(
                    value: _CalendarView.week,
                    child: Text('תצוגת שבוע'),
                  ),
                ],
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'הקודם',
                      onPressed: onPrevious,
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
                      tooltip: 'הבא',
                      onPressed: onNext,
                      icon: const Icon(Icons.chevron_left),
                    ),
                  ],
                ),
                if (view == _CalendarView.day) ...[
                  const SizedBox(height: 10),
                  _WeekStrip(
                    selectedDate: selectedDate,
                    onSelected: onDateSelected,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.selectedDate, required this.onSelected});

  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final day = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final weekStart = day.subtract(Duration(days: day.weekday % 7));
    return Row(
      children: List.generate(7, (index) {
        final date = weekStart.add(Duration(days: index));
        final selected = DateUtils.isSameDay(date, selectedDate);
        final weekday = const ['א', 'ב', 'ג', 'ד', 'ה', 'ו', 'ש'][index];
        return Expanded(
          child: Padding(
            padding: EdgeInsetsDirectional.only(end: index == 6 ? 0 : 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onSelected(date),
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text(
                      weekday,
                      style: TextStyle(
                        fontSize: 11,
                        color: selected ? AppColors.onPrimary : AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${date.day}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: selected ? AppColors.onPrimary : AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _CalendarTaskCard extends StatelessWidget {
  const _CalendarTaskCard({
    required this.task,
    required this.onOpen,
    required this.onComplete,
  });

  final V2Task task;
  final VoidCallback onOpen;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(15),
    child: InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 8, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: 'סימון כהושלם',
              onPressed: onComplete,
              icon: const Icon(Icons.radio_button_unchecked),
              color: AppColors.primary,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  if (task.customerName != null)
                    Text(
                      task.customerName!,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_left, color: AppColors.muted),
          ],
        ),
      ),
    ),
  );
}

class _CalendarActivityCard extends StatelessWidget {
  const _CalendarActivityCard({required this.activity, required this.onOpen});

  final V2Activity activity;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(15),
    child: InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: BorderDirectional(
            start: BorderSide(
              color: activity.kind == V2ActivityKind.job
                  ? AppColors.primary
                  : AppColors.visit,
              width: 4,
            ),
            top: const BorderSide(color: AppColors.border),
            bottom: const BorderSide(color: AppColors.border),
            end: const BorderSide(color: AppColors.border),
          ),
        ),
        child: Row(
          children: [
            Icon(
              activity.kind == V2ActivityKind.job
                  ? Icons.work_outline
                  : Icons.home_work_outlined,
              color: activity.kind == V2ActivityKind.job
                  ? AppColors.primary
                  : AppColors.visit,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    [
                      activity.kind.hebrewLabel,
                      activity.customerName,
                    ].whereType<String>().join(' • '),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_left, color: AppColors.muted),
          ],
        ),
      ),
    ),
  );
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
        color: AppColors.surface,
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
