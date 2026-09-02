import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../core/network/idempotency_key.dart';
import '../../core/state/data_invalidator.dart';
import '../../models/page.dart' as pagination;
import '../../models/v2_activity.dart';
import '../../models/v2_customer.dart';
import '../../models/v2_task.dart';
import '../../theme/app_theme.dart';
import '../../utils/json_read.dart';
import '../auth/session_controller.dart';
import 'v2_amount_sheet.dart';
import 'v2_activity_detail_screen.dart';
import 'v2_customers_screen.dart';
import 'v2_reports_screen.dart';
import 'v2_search_screen.dart';
import 'v2_tasks_screen.dart';

class V2HomeScreen extends StatefulWidget {
  const V2HomeScreen({
    super.key,
    required this.controller,
    this.onOpenCalendar,
  });

  final SessionController controller;
  final VoidCallback? onOpenCalendar;

  @override
  State<V2HomeScreen> createState() => _V2HomeScreenState();
}

class _V2HomeScreenState extends State<V2HomeScreen> {
  DateTime _selectedDate = DateTime.now();
  Future<_HomeData>? _future;

  @override
  void initState() {
    super.initState();
    widget.controller.dataInvalidator.addListener(_dataChanged);
    _load();
  }

  @override
  void dispose() {
    widget.controller.dataInvalidator.removeListener(_dataChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HomeData>(
      future: _future,
      builder: (context, snapshot) => RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 130),
          children: [
            _TodayHeader(
              businessName: widget.controller.session?.businessName,
              onSearch: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => V2SearchScreen(controller: widget.controller),
                ),
              ),
              onReports: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      V2ReportsScreen(controller: widget.controller),
                ),
              ),
              onCalendar: widget.onOpenCalendar,
            ),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (snapshot.hasError)
              _message('לא הצלחנו לטעון את היום בעסק')
            else
              _buildToday(snapshot.data ?? const _HomeData()),
          ],
        ),
      ),
    );
  }

  Widget _buildToday(_HomeData data) {
    final dueTasks = [...data.overdueTasks, ...data.todayTasks];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MorningBriefing(data: data),
          const SizedBox(height: 18),
          _QuickCreateBar(
            onTask: _createTask,
            onJob: () => _create(V2ActivityKind.job),
            onVisit: () => _create(V2ActivityKind.visit),
          ),
          const SizedBox(height: 24),
          _HomeSectionHeader(
            title: 'דורש טיפול',
            count: dueTasks.length,
            onOpenAll: _openTasks,
          ),
          const SizedBox(height: 8),
          if (dueTasks.isEmpty)
            const _HomeEmptyCard(
              icon: Icons.task_alt,
              text: 'אין משימות באיחור או להיום',
            )
          else
            ...dueTasks
                .take(4)
                .map(
                  (task) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _HomeTaskCard(
                      task: task,
                      overdue: data.overdueTasks.contains(task),
                      onComplete: () => _completeTask(task),
                      onPostpone: () => _postponeTask(task),
                      onEdit: () => _editTask(task),
                    ),
                  ),
                ),
          const SizedBox(height: 24),
          const _HomeSectionHeader(title: 'היום ביומן'),
          const SizedBox(height: 8),
          if (data.todayActivities.isEmpty)
            const _HomeEmptyCard(
              icon: Icons.event_available_outlined,
              text: 'אין עבודות או ביקורים להיום',
            )
          else
            ...data.todayActivities
                .take(4)
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: V2ActivityCard(
                      item: item,
                      onOpen: () => _openActivity(item),
                      onAction: (action) => _lifecycle(item, action),
                      onAmount: () => _openAmount(item),
                      onEdit: () => _edit(item),
                      onDelete: () => _delete(item),
                    ),
                  ),
                ),
          const SizedBox(height: 24),
          _HomeSectionHeader(
            title: 'עדיין לא נקבע',
            count: data.unscheduledActivities.length,
          ),
          const SizedBox(height: 8),
          if (data.unscheduledActivities.isEmpty)
            const _HomeEmptyCard(
              icon: Icons.event_busy_outlined,
              text: 'כל העבודות והביקורים הפתוחים משובצים',
            )
          else
            ...data.unscheduledActivities
                .take(3)
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: V2ActivityCard(
                      item: item,
                      onOpen: () => _openActivity(item),
                      onAction: (action) => _lifecycle(item, action),
                      onAmount: () => _openAmount(item),
                      onEdit: () => _edit(item),
                      onDelete: () => _delete(item),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Future<void> _load() async {
    final session = widget.controller.session!;
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day);
    final next = from.add(const Duration(days: 1));
    _selectedDate = from;
    final future =
        Future.wait([
          widget.controller.apiClient.v2Activities.schedule(
            businessId: session.businessId!,
            firebaseUid: session.firebaseUid,
            mockPhoneNumber: session.mockPhoneNumber,
            from: from,
            to: next,
          ),
          widget.controller.apiClient.v2Tasks.list(
            businessId: session.businessId!,
            firebaseUid: session.firebaseUid,
            mockPhoneNumber: session.mockPhoneNumber,
            limit: 50,
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
          final activities = values[0] as List<V2Activity>;
          final tasks = (values[1] as pagination.Page<V2Task>).items;
          final jobs = (values[2] as pagination.Page<V2Activity>).items;
          final visits = (values[3] as pagination.Page<V2Activity>).items;
          return _HomeData.from(
            now: now,
            tasks: tasks,
            todayActivities: activities,
            allActivities: [...jobs, ...visits],
          );
        });
    setState(() {
      _future = future;
    });
    await future;
  }

  Future<void> _openTasks() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => V2TasksScreen(controller: widget.controller),
      ),
    );
    await _load();
  }

  Future<void> _createTask() async {
    final task = await showModalBottomSheet<V2Task>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => V2TaskForm(controller: widget.controller),
    );
    if (task == null) return;
    widget.controller.markDataChanged({DataScope.crm});
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('נפתחה המשימה: ${task.title}')));
    }
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
        idempotencyKey: IdempotencyKey.create('home_task_complete'),
      );
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

  Future<void> _postponeTask(V2Task task) async {
    final session = widget.controller.session!;
    final currentDue = task.dueAt?.toLocal();
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final nextDue = DateTime(
      tomorrow.year,
      tomorrow.month,
      tomorrow.day,
      currentDue?.hour ?? 9,
      currentDue?.minute ?? 0,
    );
    try {
      await widget.controller.apiClient.v2Tasks.update(
        businessId: session.businessId!,
        taskId: task.id,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        idempotencyKey: IdempotencyKey.create('home_task_postpone'),
        body: {
          'dueAt': nextDue.toUtc().toIso8601String(),
          'version': task.version,
        },
      );
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
    if (confirmed != true || !mounted) return;
    final session = widget.controller.session!;
    try {
      await widget.controller.apiClient.v2Activities.delete(
        kind: activity.kind,
        businessId: session.businessId!,
        entityId: activity.id,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        idempotencyKey: IdempotencyKey.create(
          '${activity.kind.apiPath}_delete',
        ),
      );
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

  void _dataChanged() {
    if (mounted) _load();
  }

  Widget _message(String text) => Padding(
    padding: const EdgeInsets.all(32),
    child: Center(child: Text(text)),
  );
}

class _HomeData {
  const _HomeData({
    this.overdueTasks = const [],
    this.todayTasks = const [],
    this.todayActivities = const [],
    this.unscheduledActivities = const [],
  });

  final List<V2Task> overdueTasks;
  final List<V2Task> todayTasks;
  final List<V2Activity> todayActivities;
  final List<V2Activity> unscheduledActivities;

  factory _HomeData.from({
    required DateTime now,
    required List<V2Task> tasks,
    required List<V2Activity> todayActivities,
    required List<V2Activity> allActivities,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final openTasks =
        tasks.where((task) => task.status == V2TaskStatus.open).toList()
          ..sort((left, right) {
            if (left.dueAt == null) return 1;
            if (right.dueAt == null) return -1;
            return left.dueAt!.compareTo(right.dueAt!);
          });
    final overdue = openTasks.where((task) {
      final due = task.dueAt?.toLocal();
      return due != null && due.isBefore(today);
    }).toList();
    final dueToday = openTasks.where((task) {
      final due = task.dueAt?.toLocal();
      return due != null && !due.isBefore(today) && due.isBefore(tomorrow);
    }).toList();
    final scheduled =
        todayActivities
            .where((item) => item.status == V2ActivityStatus.open)
            .toList()
          ..sort((left, right) {
            if (left.startsAt == null) return 1;
            if (right.startsAt == null) return -1;
            return left.startsAt!.compareTo(right.startsAt!);
          });
    final unscheduled =
        allActivities
            .where(
              (item) =>
                  item.status == V2ActivityStatus.open && item.startsAt == null,
            )
            .toList()
          ..sort((left, right) => left.title.compareTo(right.title));
    return _HomeData(
      overdueTasks: overdue,
      todayTasks: dueToday,
      todayActivities: scheduled,
      unscheduledActivities: unscheduled,
    );
  }
}

class _TodayHeader extends StatelessWidget {
  const _TodayHeader({
    required this.businessName,
    required this.onSearch,
    required this.onReports,
    this.onCalendar,
  });

  final String? businessName;
  final VoidCallback onSearch;
  final VoidCallback onReports;
  final VoidCallback? onCalendar;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Container(
      padding: EdgeInsets.fromLTRB(
        18,
        MediaQuery.paddingOf(context).top + 10,
        18,
        18,
      ),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'היום',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${MaterialLocalizations.of(context).formatFullDate(now)} · ${businessName ?? 'העסק שלי'}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'חיפוש',
                color: Colors.white,
                onPressed: onSearch,
                icon: const Icon(Icons.search),
              ),
              if (onCalendar != null)
                IconButton(
                  tooltip: 'יומן',
                  color: Colors.white,
                  onPressed: onCalendar,
                  icon: const Icon(Icons.calendar_month_outlined),
                ),
              IconButton(
                tooltip: 'תשלומים ויתרות',
                color: Colors.white,
                onPressed: onReports,
                icon: const Icon(Icons.bar_chart_outlined),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MorningBriefing extends StatelessWidget {
  const _MorningBriefing({required this.data});

  final _HomeData data;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (data.overdueTasks.isNotEmpty) '${data.overdueTasks.length} באיחור',
      if (data.todayTasks.isNotEmpty) '${data.todayTasks.length} להיום',
      if (data.todayActivities.isNotEmpty)
        '${data.todayActivities.length} ביומן',
      if (data.unscheduledActivities.isNotEmpty)
        '${data.unscheduledActivities.length} טרם נקבעו',
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.wb_sunny_outlined, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'תדריך קצר',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  parts.isEmpty
                      ? 'הכול מסודר כרגע. אפשר להתחיל את היום.'
                      : parts.join(' · '),
                  style: const TextStyle(height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickCreateBar extends StatelessWidget {
  const _QuickCreateBar({
    required this.onTask,
    required this.onJob,
    required this.onVisit,
  });

  final VoidCallback onTask;
  final VoidCallback onJob;
  final VoidCallback onVisit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onTask,
            icon: const Icon(Icons.add_task),
            label: const Text('משימה'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onJob,
            icon: const Icon(Icons.work_outline),
            label: const Text('עבודה'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onVisit,
            icon: const Icon(Icons.home_work_outlined),
            label: const Text('ביקור'),
          ),
        ),
      ],
    );
  }
}

class _HomeSectionHeader extends StatelessWidget {
  const _HomeSectionHeader({this.title = '', this.count, this.onOpenAll});

  final String title;
  final int? count;
  final VoidCallback? onOpenAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            count == null ? title : '$title · $count',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
        ),
        if (onOpenAll != null)
          TextButton(onPressed: onOpenAll, child: const Text('הצג הכול')),
      ],
    );
  }
}

class _HomeEmptyCard extends StatelessWidget {
  const _HomeEmptyCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.muted),
          const SizedBox(width: 10),
          Text(text, style: const TextStyle(color: AppColors.muted)),
        ],
      ),
    );
  }
}

class _HomeTaskCard extends StatelessWidget {
  const _HomeTaskCard({
    required this.task,
    required this.overdue,
    required this.onComplete,
    required this.onPostpone,
    required this.onEdit,
  });

  final V2Task task;
  final bool overdue;
  final VoidCallback onComplete;
  final VoidCallback onPostpone;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final statusColor = overdue ? AppColors.error : AppColors.warning;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications_active_outlined, color: statusColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    task.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton(onPressed: onEdit, child: const Text('עריכה')),
              ],
            ),
            if (task.customerName != null)
              Text(
                task.customerName!,
                style: const TextStyle(color: AppColors.muted),
              ),
            if (task.dueAt != null)
              Text(
                _formatTaskDue(context, task.dueAt!.toLocal()),
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: onComplete,
                  icon: const Icon(Icons.check),
                  label: const Text('בוצע'),
                ),
                TextButton.icon(
                  onPressed: onPostpone,
                  icon: const Icon(Icons.update),
                  label: const Text('דחה למחר'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatTaskDue(BuildContext context, DateTime due) {
    final date = MaterialLocalizations.of(context).formatMediumDate(due);
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(due));
    return '$date · $time';
  }
}

class V2ActivityCard extends StatelessWidget {
  const V2ActivityCard({
    super.key,
    required this.item,
    required this.onOpen,
    required this.onAction,
    required this.onAmount,
    required this.onEdit,
    required this.onDelete,
  });
  final V2Activity item;
  final VoidCallback onOpen;
  final ValueChanged<String> onAction;
  final VoidCallback onAmount;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(18),
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
                PopupMenuButton<String>(
                  onSelected: (action) =>
                      action == 'edit' ? onEdit() : onDelete(),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('עריכה')),
                    PopupMenuItem(value: 'delete', child: Text('מחיקה')),
                  ],
                ),
              ],
            ),
            if (item.customerName != null) Text(item.customerName!),
            if (item.startsAt != null)
              Text(_displayActivityWindow(context, item)),
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
    ),
  );
}

class V2ActivityForm extends StatefulWidget {
  const V2ActivityForm({
    super.key,
    required this.controller,
    required this.kind,
    required this.initialDate,
    this.activity,
  });
  final SessionController controller;
  final V2ActivityKind kind;
  final DateTime initialDate;
  final V2Activity? activity;

  @override
  State<V2ActivityForm> createState() => _V2ActivityFormState();
}

class _V2ActivityFormState extends State<V2ActivityForm> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  Future<List<V2Customer>>? _customers;
  String? _customerId;
  String? _serviceAddressId;
  DateTime? _startsAt;
  DateTime? _endsAt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final session = widget.controller.session!;
    final activity = widget.activity;
    if (activity != null) {
      _customerId = activity.customerId;
      _serviceAddressId = activity.serviceAddressId;
      _title.text = activity.title;
      _description.text = activity.description ?? '';
      _startsAt = activity.startsAt?.toLocal();
      _endsAt = activity.endsAt?.toLocal();
    }
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
            widget.activity == null
                ? widget.kind == V2ActivityKind.job
                      ? 'עבודה חדשה'
                      : 'ביקור חדש'
                : 'עריכת ${widget.kind.hebrewLabel}',
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
              onChanged: (value) => setState(() {
                _customerId = value;
                _serviceAddressId = null;
              }),
            ),
          ),
          FutureBuilder<List<V2Customer>>(
            future: _customers,
            builder: (context, snapshot) {
              final customers = snapshot.data ?? const <V2Customer>[];
              final selected = customers
                  .where((customer) => customer.id == _customerId)
                  .firstOrNull;
              final addresses =
                  selected?.addresses ?? const <V2ServiceAddress>[];
              return DropdownButtonFormField<String?>(
                initialValue:
                    addresses.any((address) => address.id == _serviceAddressId)
                    ? _serviceAddressId
                    : null,
                decoration: const InputDecoration(
                  labelText: 'כתובת שירות (אופציונלי)',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('ללא כתובת'),
                  ),
                  ...addresses.map(
                    (address) => DropdownMenuItem<String?>(
                      value: address.id,
                      child: Text(address.addressText),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _serviceAddressId = value),
              );
            },
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
          if (_startsAt != null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _pickEndTime,
              icon: const Icon(Icons.timelapse_outlined),
              label: Text(
                _endsAt == null
                    ? 'בחירת שעת סיום'
                    : 'סיום: ${TimeOfDay.fromDateTime(_endsAt!).format(context)}',
              ),
            ),
          ],
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
    final previousDuration = _startsAt != null && _endsAt != null
        ? _endsAt!.difference(_startsAt!)
        : Duration(minutes: widget.kind == V2ActivityKind.job ? 120 : 60);
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
    setState(() {
      _startsAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      _endsAt = _startsAt!.add(previousDuration);
    });
  }

  Future<void> _pickEndTime() async {
    final startsAt = _startsAt;
    if (startsAt == null) return;
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _endsAt ?? startsAt.add(const Duration(hours: 1)),
      ),
    );
    if (selected == null) return;
    var value = DateTime(
      startsAt.year,
      startsAt.month,
      startsAt.day,
      selected.hour,
      selected.minute,
    );
    if (!value.isAfter(startsAt)) value = value.add(const Duration(days: 1));
    setState(() => _endsAt = value);
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
      final body = <String, Object?>{
        'customerId': _customerId,
        'title': _title.text.trim(),
        if (widget.activity != null || _description.text.trim().isNotEmpty)
          'description': _description.text.trim().isEmpty
              ? null
              : _description.text.trim(),
        if (widget.activity != null || _startsAt != null)
          'startsAt': _startsAt?.toUtc().toIso8601String(),
        if (widget.activity != null || _endsAt != null)
          'endsAt': _endsAt?.toUtc().toIso8601String(),
        if (widget.activity != null || _serviceAddressId != null)
          'serviceAddressId': _serviceAddressId,
        if (widget.activity != null) 'version': widget.activity!.version,
        'scheduleConflictToken': ?scheduleConflictToken,
      };
      final activity = widget.activity == null
          ? await widget.controller.apiClient.v2Activities.create(
              kind: widget.kind,
              businessId: session.businessId!,
              firebaseUid: session.firebaseUid,
              mockPhoneNumber: session.mockPhoneNumber,
              idempotencyKey: IdempotencyKey.create(
                '${widget.kind.apiPath}_create',
              ),
              body: body,
            )
          : await widget.controller.apiClient.v2Activities.update(
              kind: widget.kind,
              businessId: session.businessId!,
              entityId: widget.activity!.id,
              firebaseUid: session.firebaseUid,
              mockPhoneNumber: session.mockPhoneNumber,
              idempotencyKey: IdempotencyKey.create(
                '${widget.kind.apiPath}_update',
              ),
              body: body,
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

String _displayActivityWindow(BuildContext context, V2Activity activity) {
  final startsAt = activity.startsAt?.toLocal();
  if (startsAt == null) return '';
  final endsAt = activity.effectiveEndsAt?.toLocal();
  final startText = TimeOfDay.fromDateTime(startsAt).format(context);
  if (endsAt == null) return '${_displayDate(startsAt)} · $startText';
  final endText = TimeOfDay.fromDateTime(endsAt).format(context);
  final sameDay =
      startsAt.year == endsAt.year &&
      startsAt.month == endsAt.month &&
      startsAt.day == endsAt.day;
  return sameDay
      ? '${_displayDate(startsAt)} · $startText–$endText'
      : '${_displayDate(startsAt)} $startText – ${_displayDate(endsAt)} $endText';
}
