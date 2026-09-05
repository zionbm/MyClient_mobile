import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../core/network/idempotency_key.dart';
import '../../core/state/data_invalidator.dart';
import '../../models/v2_activity.dart';
import '../../models/v2_task.dart';
import '../../theme/app_theme.dart';
import '../../widgets/main_top_bar.dart';
import '../auth/session_controller.dart';
import '../notifications/notifications_screen.dart';
import 'activities/v2_activity_form.dart';
import 'tasks/v2_task_form.dart';
import 'v2_amount_sheet.dart';
import 'v2_activity_detail_screen.dart';
import 'v2_search_screen.dart';
import 'v2_tasks_screen.dart';
import 'home/v2_today_overview.dart';
import 'widgets/v2_activity_card.dart';
import 'widgets/v2_completed_item_card.dart';

class V2HomeScreen extends StatefulWidget {
  const V2HomeScreen({super.key, required this.controller});

  final SessionController controller;

  @override
  State<V2HomeScreen> createState() => _V2HomeScreenState();
}

class _V2HomeScreenState extends State<V2HomeScreen> {
  DateTime _selectedDate = DateTime.now();
  Future<V2TodayOverview>? _future;
  late final V2TodayOverviewLoader _overviewLoader;
  bool _showAllTodayActivities = false;
  bool _showAllUnscheduled = false;
  bool _showAllAwaitingPayment = false;

  @override
  void initState() {
    super.initState();
    _overviewLoader = V2TodayOverviewLoader(widget.controller.apiClient);
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
    return FutureBuilder<V2TodayOverview>(
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
              onNotifications: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      NotificationsScreen(controller: widget.controller),
                ),
              ),
            ),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (snapshot.hasError)
              _message('לא הצלחנו לטעון את היום בעסק')
            else
              _buildToday(snapshot.data ?? const V2TodayOverview()),
          ],
        ),
      ),
    );
  }

  Widget _buildToday(V2TodayOverview data) {
    final dueTasks = [
      ...data.overdueTasks,
      ...data.todayTasks,
      ...data.undatedTasks,
    ];
    final priority = data.priority;
    final priorityTask = priority.task;
    final priorityActivity = priority.activity;
    final remainingTasks = dueTasks
        .where((task) => task.id != priorityTask?.id)
        .toList(growable: false);
    final remainingActivities = data.todayActivities
        .where((activity) => activity.id != priorityActivity?.id)
        .toList(growable: false);
    final remainingUnscheduled = data.unscheduledActivities
        .where((activity) => activity.id != priorityActivity?.id)
        .toList(growable: false);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NextActionCard(
            task: priorityTask,
            activity: priorityActivity,
            onOpenTask: priorityTask == null
                ? null
                : () => _editTask(priorityTask),
            onCompleteTask: priorityTask == null
                ? null
                : () => _completeTask(priorityTask),
            onPostponeTask: priorityTask == null
                ? null
                : () => _postponeTask(priorityTask),
            onOpenActivity: priorityActivity == null
                ? null
                : () => _openActivity(priorityActivity),
          ),
          const SizedBox(height: 24),
          _HomeSectionHeader(
            title: 'דורש טיפול',
            count: remainingTasks.length,
            onOpenAll: _openTasks,
          ),
          const SizedBox(height: 8),
          if (remainingTasks.isEmpty)
            const _HomeEmptyCard(
              icon: Icons.task_alt,
              text: 'אין משימות באיחור או להיום',
            )
          else
            ...remainingTasks
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
          _HomeSectionHeader(
            title: 'אחר כך היום',
            count: remainingActivities.length,
            onOpenAll: remainingActivities.length > 4
                ? () => setState(
                    () => _showAllTodayActivities = !_showAllTodayActivities,
                  )
                : null,
            actionLabel: _showAllTodayActivities ? 'הצג פחות' : 'הצג הכול',
          ),
          const SizedBox(height: 8),
          if (remainingActivities.isEmpty)
            const _HomeEmptyCard(
              icon: Icons.event_available_outlined,
              text: 'אין עבודות או ביקורים להיום',
            )
          else
            ...remainingActivities
                .take(_showAllTodayActivities ? remainingActivities.length : 4)
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
            count: remainingUnscheduled.length,
            onOpenAll: remainingUnscheduled.length > 3
                ? () =>
                      setState(() => _showAllUnscheduled = !_showAllUnscheduled)
                : null,
            actionLabel: _showAllUnscheduled ? 'הצג פחות' : 'הצג הכול',
          ),
          const SizedBox(height: 8),
          if (remainingUnscheduled.isEmpty)
            const _HomeEmptyCard(
              icon: Icons.event_busy_outlined,
              text: 'כל העבודות והביקורים הפתוחים משובצים',
            )
          else
            ...remainingUnscheduled
                .take(_showAllUnscheduled ? remainingUnscheduled.length : 3)
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
          if (data.awaitingPaymentActivities.isNotEmpty) ...[
            const SizedBox(height: 24),
            _HomeSectionHeader(
              title: 'בוצעו וממתינים לתשלום',
              count: data.awaitingPaymentActivities.length,
              onOpenAll: data.awaitingPaymentActivities.length > 3
                  ? () => setState(
                      () => _showAllAwaitingPayment = !_showAllAwaitingPayment,
                    )
                  : null,
              actionLabel: _showAllAwaitingPayment ? 'הצג פחות' : 'הצג הכול',
            ),
            const SizedBox(height: 8),
            ...data.awaitingPaymentActivities
                .take(
                  _showAllAwaitingPayment
                      ? data.awaitingPaymentActivities.length
                      : 3,
                )
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
          const SizedBox(height: 24),
          _HomeSectionHeader(
            title: 'בוצעו היום',
            count: data.completedItems.length,
          ),
          const SizedBox(height: 8),
          if (data.completedItems.isEmpty)
            const _HomeEmptyCard(
              icon: Icons.check_circle_outline,
              text: 'עדיין לא הושלמו פריטים היום',
            )
          else
            ...data.completedItems.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: V2CompletedItemCard(
                  item: item,
                  onOpen: () => item.task != null
                      ? _editTask(item.task!)
                      : _openActivity(item.activity!),
                ),
              ),
            ),
          const SizedBox(height: 24),
          const _HomeSectionHeader(title: 'יצירה מהירה'),
          const SizedBox(height: 8),
          _QuickCreateBar(
            onTask: _createTask,
            onJob: () => _create(V2ActivityKind.job),
            onVisit: () => _create(V2ActivityKind.visit),
          ),
        ],
      ),
    );
  }

  Future<void> _load() async {
    final session = widget.controller.session!;
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day);
    _selectedDate = from;
    final future = _overviewLoader.load(session: session, at: now);
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
        action: V2TaskAction.complete,
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

  Future<void> _lifecycle(V2Activity item, V2ActivityAction action) async {
    final session = widget.controller.session!;
    var body = const <String, Object?>{};
    if (action == V2ActivityAction.reportCompleted) {
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
        final hasAmount = await _openAmount(item);
        if (!mounted) return;
        if (!hasAmount) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('כדי לדווח סיום עם חיוב צריך לשמור סכום'),
            ),
          );
          return;
        }
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
        idempotencyKey: IdempotencyKey.create(
          '${item.kind.apiPath}_${action.apiValue}',
        ),
        body: body,
      );
      if (!mounted) return;
      final message =
          action == V2ActivityAction.reportCompleted &&
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

  Future<bool> _openAmount(V2Activity item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          V2AmountSheet(controller: widget.controller, activity: item),
    );
    widget.controller.markDataChanged({DataScope.crm});
    await _load();
    final session = widget.controller.session!;
    try {
      await widget.controller.apiClient.v2Amounts.get(
        kind: item.kind,
        businessId: session.businessId!,
        entityId: item.id,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
      );
      return true;
    } on ApiException catch (error) {
      if (error.statusCode == 404) return false;
      rethrow;
    }
  }

  void _dataChanged() {
    if (mounted) _load();
  }

  Widget _message(String text) => Padding(
    padding: const EdgeInsets.all(32),
    child: Center(child: Text(text)),
  );
}

class _TodayHeader extends StatelessWidget {
  const _TodayHeader({
    required this.businessName,
    required this.onSearch,
    required this.onNotifications,
  });

  final String? businessName;
  final VoidCallback onSearch;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return MainTopBar(
      title: 'היום',
      subtitle:
          '${MaterialLocalizations.of(context).formatFullDate(now)} · ${businessName ?? 'העסק שלי'}',
      actions: [
        IconButton(
          tooltip: 'חיפוש',
          onPressed: onSearch,
          icon: const Icon(Icons.search),
        ),
        IconButton(
          tooltip: 'התראות',
          onPressed: onNotifications,
          icon: const Icon(Icons.notifications_none_rounded),
        ),
      ],
    );
  }
}

class _NextActionCard extends StatelessWidget {
  const _NextActionCard({
    this.task,
    this.activity,
    this.onOpenTask,
    this.onCompleteTask,
    this.onPostponeTask,
    this.onOpenActivity,
  });

  final V2Task? task;
  final V2Activity? activity;
  final VoidCallback? onOpenTask;
  final VoidCallback? onCompleteTask;
  final VoidCallback? onPostponeTask;
  final VoidCallback? onOpenActivity;

  @override
  Widget build(BuildContext context) {
    final task = this.task;
    final activity = this.activity;
    final now = DateTime.now();
    final taskOverdue = task?.dueAt?.toLocal().isBefore(now) ?? false;
    final activityUnscheduled = activity != null && activity.startsAt == null;
    final eyebrow = task != null
        ? taskOverdue
              ? 'הפעולה הבאה · באיחור'
              : 'הפעולה הבאה · להיום'
        : activityUnscheduled
        ? 'הפעולה הבאה · צריך לקבוע'
        : activity != null
        ? 'הפעילות הבאה ביומן'
        : 'היום שלך מסודר';
    final title = task?.title ?? activity?.title ?? 'אין כרגע פעולה דחופה';
    final details = task != null
        ? [
            task.customerName,
            if (task.dueAt != null)
              _HomeTaskCard._formatTaskDue(context, task.dueAt!.toLocal()),
          ].whereType<String>().join(' · ')
        : activity != null
        ? [
            activity.customerName,
            if (activity.startsAt != null)
              displayActivityWindow(context, activity),
            activity.locationSnapshot,
          ].whereType<String>().join(' · ')
        : 'אפשר ליצור משימה, עבודה או ביקור חדש.';
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
          Icon(
            task != null
                ? Icons.notifications_active_outlined
                : activity != null
                ? Icons.route_outlined
                : Icons.task_alt_rounded,
            color: taskOverdue ? AppColors.error : AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: TextStyle(
                    color: taskOverdue ? AppColors.error : AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(details, style: const TextStyle(height: 1.4)),
                if (task != null) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: onCompleteTask,
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('בוצע'),
                      ),
                      OutlinedButton(
                        onPressed: onPostponeTask,
                        child: const Text('דחה למחר'),
                      ),
                      TextButton(
                        onPressed: onOpenTask,
                        child: const Text('פרטים'),
                      ),
                    ],
                  ),
                ] else if (activity != null) ...[
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: onOpenActivity,
                    icon: Icon(
                      activityUnscheduled
                          ? Icons.calendar_month_outlined
                          : Icons.arrow_back_rounded,
                    ),
                    label: Text(
                      activityUnscheduled ? 'קבע מועד' : 'פתח פעילות',
                    ),
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
          child: _QuickCreateButton(
            onPressed: onTask,
            icon: Icons.add_task,
            label: 'משימה',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickCreateButton(
            onPressed: onJob,
            icon: Icons.work_outline,
            label: 'עבודה',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickCreateButton(
            onPressed: onVisit,
            icon: Icons.home_work_outlined,
            label: 'ביקור',
          ),
        ),
      ],
    );
  }
}

class _QuickCreateButton extends StatelessWidget {
  const _QuickCreateButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
    ),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 19),
          const SizedBox(width: 5),
          Text(label, maxLines: 1),
        ],
      ),
    ),
  );
}

class _HomeSectionHeader extends StatelessWidget {
  const _HomeSectionHeader({
    this.title = '',
    this.count,
    this.onOpenAll,
    this.actionLabel = 'הצג הכול',
  });

  final String title;
  final int? count;
  final VoidCallback? onOpenAll;
  final String actionLabel;

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
          TextButton(onPressed: onOpenAll, child: Text(actionLabel)),
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
        color: AppColors.surface,
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
