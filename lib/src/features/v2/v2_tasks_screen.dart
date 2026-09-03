import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../core/network/idempotency_key.dart';
import '../../core/paging/paging_controller.dart';
import '../../core/state/data_invalidator.dart';
import '../../models/page.dart' as pagination;
import '../../models/v2_task.dart';
import '../../theme/app_theme.dart';
import '../auth/session_controller.dart';
import 'v2_customers_screen.dart';

enum _TaskView { open, completed }

class V2TasksScreen extends StatefulWidget {
  const V2TasksScreen({super.key, required this.controller});

  final SessionController controller;

  @override
  State<V2TasksScreen> createState() => _V2TasksScreenState();
}

class _V2TasksScreenState extends State<V2TasksScreen> {
  Future<List<V2Task>>? _future;
  late final PagingController<V2Task> _paging;
  _TaskView _view = _TaskView.open;

  @override
  void initState() {
    super.initState();
    _paging = PagingController<V2Task>(_loadPage, itemKey: (task) => task.id);
    _load();
  }

  @override
  void dispose() {
    _paging.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('משימות וחזרות'),
        actions: [
          IconButton(
            tooltip: 'משימה חדשה',
            onPressed: _create,
            icon: const Icon(Icons.add_task),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('משימה'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SegmentedButton<_TaskView>(
              segments: const [
                ButtonSegment(value: _TaskView.open, label: Text('פתוחות')),
                ButtonSegment(
                  value: _TaskView.completed,
                  label: Text('הושלמו ובוטלו'),
                ),
              ],
              selected: {_view},
              onSelectionChanged: (value) => _changeView(value.first),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: FutureBuilder<List<V2Task>>(
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
                    return _message('לא הצלחנו לטעון את המשימות');
                  }
                  final tasks = snapshot.data ?? const <V2Task>[];
                  return _view == _TaskView.open
                      ? _openTasks(tasks)
                      : _closedTasks(tasks);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _openTasks(List<V2Task> allTasks) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final open =
        allTasks.where((task) => task.status == V2TaskStatus.open).toList()
          ..sort(_compareTasks);
    final overdue = open.where((task) {
      final due = task.dueAt?.toLocal();
      return due != null && due.isBefore(today);
    }).toList();
    final dueToday = open.where((task) {
      final due = task.dueAt?.toLocal();
      return due != null && !due.isBefore(today) && due.isBefore(tomorrow);
    }).toList();
    final later = open.where((task) {
      final due = task.dueAt?.toLocal();
      return due != null && !due.isBefore(tomorrow);
    }).toList();
    final withoutDate = open.where((task) => task.dueAt == null).toList();
    if (open.isEmpty) return _message('אין משימות פתוחות');
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      children: [
        if (overdue.isNotEmpty)
          _TaskSection(
            title: 'באיחור',
            color: AppColors.error,
            tasks: overdue,
            builder: _taskCard,
          ),
        if (dueToday.isNotEmpty)
          _TaskSection(
            title: 'היום',
            color: AppColors.warning,
            tasks: dueToday,
            builder: _taskCard,
          ),
        if (later.isNotEmpty)
          _TaskSection(
            title: 'בהמשך',
            color: AppColors.primary,
            tasks: later,
            builder: _taskCard,
          ),
        if (withoutDate.isNotEmpty)
          _TaskSection(
            title: 'ללא מועד',
            color: AppColors.muted,
            tasks: withoutDate,
            builder: _taskCard,
          ),
        if (_paging.canLoadMore) _loadMoreButton(),
      ],
    );
  }

  Widget _closedTasks(List<V2Task> tasks) {
    final closed = tasks.toList()..sort(_compareClosedTasks);
    if (closed.isEmpty) return _message('עדיין אין משימות שהסתיימו');
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      itemCount: closed.length + (_paging.canLoadMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        if (index == closed.length) return _loadMoreButton();
        return _TaskCard(
          task: closed[index],
          onEdit: () => _edit(closed[index]),
          onComplete: null,
          onPostpone: null,
        );
      },
    );
  }

  Widget _taskCard(V2Task task) => _TaskCard(
    task: task,
    onEdit: () => _edit(task),
    onComplete: () => _complete(task),
    onPostpone: () => _postpone(task),
  );

  Widget _message(String text) => ListView(
    padding: const EdgeInsets.all(32),
    children: [
      const SizedBox(height: 72),
      const Icon(Icons.task_alt, size: 42, color: AppColors.muted),
      const SizedBox(height: 12),
      Text(text, textAlign: TextAlign.center),
    ],
  );

  Widget _loadMoreButton() => OutlinedButton.icon(
    onPressed: _paging.isLoading ? null : _loadMore,
    icon: const Icon(Icons.expand_more),
    label: const Text('טען עוד משימות'),
  );

  Future<pagination.Page<V2Task>> _loadPage(String? cursor) {
    final session = widget.controller.session!;
    return widget.controller.apiClient.v2Tasks.list(
      businessId: session.businessId!,
      firebaseUid: session.firebaseUid,
      mockPhoneNumber: session.mockPhoneNumber,
      cursor: cursor,
      state: _view == _TaskView.open ? 'OPEN' : 'CLOSED',
    );
  }

  Future<void> _load() async {
    final future = _paging.refresh().then((_) => _paging.items);
    setState(() => _future = future);
    await future;
  }

  Future<void> _loadMore() async {
    await _paging.loadMore();
    if (mounted) setState(() => _future = Future.value(_paging.items));
  }

  void _changeView(_TaskView view) {
    if (view == _view) return;
    setState(() => _view = view);
    _load();
  }

  Future<void> _create() async {
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

  Future<void> _edit(V2Task task) async {
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

  Future<void> _complete(V2Task task) => _runTaskAction(task, () {
    final session = widget.controller.session!;
    return widget.controller.apiClient.v2Tasks.lifecycle(
      businessId: session.businessId!,
      taskId: task.id,
      action: 'complete',
      firebaseUid: session.firebaseUid,
      mockPhoneNumber: session.mockPhoneNumber,
      idempotencyKey: IdempotencyKey.create('task_complete'),
    );
  }, 'המשימה הושלמה');

  Future<void> _postpone(V2Task task) => _runTaskAction(task, () {
    final session = widget.controller.session!;
    final localDue = task.dueAt?.toLocal();
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final dueAt = DateTime(
      tomorrow.year,
      tomorrow.month,
      tomorrow.day,
      localDue?.hour ?? 9,
      localDue?.minute ?? 0,
    );
    return widget.controller.apiClient.v2Tasks.update(
      businessId: session.businessId!,
      taskId: task.id,
      firebaseUid: session.firebaseUid,
      mockPhoneNumber: session.mockPhoneNumber,
      idempotencyKey: IdempotencyKey.create('task_postpone'),
      body: {'dueAt': dueAt.toUtc().toIso8601String(), 'version': task.version},
    );
  }, 'המשימה נדחתה למחר');

  Future<void> _runTaskAction(
    V2Task task,
    Future<V2Task> Function() action,
    String message,
  ) async {
    try {
      await action();
      widget.controller.markDataChanged({DataScope.crm});
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$message: ${task.title}')));
      }
      await _load();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  static int _compareTasks(V2Task left, V2Task right) {
    if (left.dueAt == null && right.dueAt == null) {
      return left.title.compareTo(right.title);
    }
    if (left.dueAt == null) return 1;
    if (right.dueAt == null) return -1;
    return left.dueAt!.compareTo(right.dueAt!);
  }

  static int _compareClosedTasks(V2Task left, V2Task right) {
    final leftDate = left.completedAt ?? left.dueAt;
    final rightDate = right.completedAt ?? right.dueAt;
    if (leftDate == null && rightDate == null) {
      return left.title.compareTo(right.title);
    }
    if (leftDate == null) return 1;
    if (rightDate == null) return -1;
    return rightDate.compareTo(leftDate);
  }
}

class _TaskSection extends StatelessWidget {
  const _TaskSection({
    required this.title,
    required this.color,
    required this.tasks,
    required this.builder,
  });

  final String title;
  final Color color;
  final List<V2Task> tasks;
  final Widget Function(V2Task task) builder;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 12,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Text(
                  '${tasks.length}',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...tasks.map(
            (task) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: builder(task),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.onEdit,
    required this.onComplete,
    required this.onPostpone,
  });

  final V2Task task;
  final VoidCallback onEdit;
  final VoidCallback? onComplete;
  final VoidCallback? onPostpone;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  task.status == V2TaskStatus.open
                      ? Icons.radio_button_unchecked
                      : Icons.task_alt,
                  color: task.status == V2TaskStatus.open
                      ? AppColors.primary
                      : AppColors.success,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    task.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'עריכה',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
            if (task.customerName != null)
              Text(
                task.customerName!,
                style: const TextStyle(color: AppColors.muted),
              ),
            if (task.dueAt != null) ...[
              const SizedBox(height: 4),
              Text(_formatDueAt(context, task.dueAt!.toLocal())),
            ],
            if (task.completedAt != null) ...[
              const SizedBox(height: 4),
              Text(
                'הושלמה ${_formatDueAt(context, task.completedAt!.toLocal())}',
                style: const TextStyle(color: AppColors.success),
              ),
            ],
            if (onComplete != null || onPostpone != null) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (onComplete != null)
                    FilledButton.tonalIcon(
                      onPressed: onComplete,
                      icon: const Icon(Icons.check),
                      label: const Text('בוצע'),
                    ),
                  if (onPostpone != null)
                    TextButton.icon(
                      onPressed: onPostpone,
                      icon: const Icon(Icons.update),
                      label: const Text('דחה למחר'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatDueAt(BuildContext context, DateTime dueAt) {
    final date = MaterialLocalizations.of(context).formatMediumDate(dueAt);
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(dueAt));
    return '$date · $time';
  }
}
