import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/api_client.dart';
import '../../models/customer.dart';
import '../../models/page.dart' as pagination;
import '../../models/work_item.dart';
import '../../navigation/linked_entity_navigation.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_formatting.dart';
import '../../utils/json_read.dart';
import '../auth/session_controller.dart';
import '../customers/customer_detail_screen.dart';

enum _SearchTarget { customers, tasks }

enum _TaskStateFilter { all, open, done }

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.controller});

  final SessionController controller;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _queryController = TextEditingController();
  _SearchTarget _target = _SearchTarget.customers;
  _TaskStateFilter _taskFilter = _TaskStateFilter.all;
  Future<_SearchResults>? _future;
  _SearchResults _results = const _SearchResults();
  bool _loadingMore = false;
  int _searchGeneration = 0;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _queryController.addListener(_scheduleSearch);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.removeListener(_scheduleSearch);
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _SearchHero(
            controller: _queryController,
            onBack: () => Navigator.of(context).maybePop(),
            onSubmitted: _runSearch,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Column(
              children: [
                _SearchTargetSelector(
                  selected: _target,
                  onChanged: (target) {
                    setState(() => _target = target);
                    _restartSearch();
                  },
                ),
                if (_target == _SearchTarget.tasks) ...[
                  const SizedBox(height: 10),
                  _TaskFilterSelector(
                    selected: _taskFilter,
                    onChanged: (filter) {
                      setState(() => _taskFilter = filter);
                      _restartSearch();
                    },
                  ),
                ],
              ],
            ),
          ),
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildResults() {
    return RefreshIndicator(
      onRefresh: () async {
        if (_future == null) return;
        _runSearch();
        await _future;
      },
      child: FutureBuilder<_SearchResults>(
        future: _future,
        builder: (context, snapshot) {
          if (_future == null) {
            return const _SearchStateList(
              child: _StateCard(
                icon: Icons.manage_search_outlined,
                title: 'מה תרצה למצוא?',
                body: 'אפשר לחפש לפי שם, טלפון, כתובת, כותרת או תיאור.',
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _SearchStateList(
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return _SearchStateList(
              child: _StateCard(
                icon: Icons.cloud_off_outlined,
                title: 'לא הצלחנו לחפש',
                body: _messageForError(snapshot.error),
              ),
            );
          }
          final results = snapshot.data ?? const _SearchResults();
          final count = _target == _SearchTarget.customers
              ? results.customers.length
              : results.tasks.length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            children: [
              if (count > 0) ...[
                Text(
                  _target == _SearchTarget.customers
                      ? '$count לקוחות נמצאו'
                      : '$count פריטי עבודה נמצאו',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (_target == _SearchTarget.customers)
                _CustomerResults(
                  controller: widget.controller,
                  customers: results.customers,
                  onChanged: _runSearch,
                )
              else
                _TaskResults(
                  controller: widget.controller,
                  tasks: results.tasks,
                  onChanged: _runSearch,
                ),
              if (results.pageInfo.hasMore) ...[
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  onPressed: _loadingMore ? null : _loadMore,
                  icon: _loadingMore
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.expand_more),
                  label: const Text('טען עוד תוצאות'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  void _scheduleSearch() {
    _debounce?.cancel();
    if (_queryController.text.trim().isEmpty) {
      _clearSearch();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), _runSearch);
  }

  void _restartSearch() {
    if (_queryController.text.trim().isEmpty) {
      _clearSearch();
    } else {
      _runSearch();
    }
  }

  void _runSearch() {
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      _clearSearch();
      return;
    }
    final generation = ++_searchGeneration;
    final future = _loadResults(query: query).then((results) {
      if (generation == _searchGeneration) _results = results;
      return results;
    });
    setState(() => _future = future);
  }

  Future<_SearchResults> _loadResults({
    required String query,
    String? cursor,
  }) async {
    if (_target == _SearchTarget.customers) {
      return _loadCustomers(query, cursor);
    }
    return _loadTasks(query, cursor);
  }

  Future<_SearchResults> _loadCustomers(String query, String? cursor) async {
    final session = widget.controller.session!;
    final json = await widget.controller.apiClient.search.search(
      businessId: session.businessId!,
      firebaseUid: session.firebaseUid,
      mockPhoneNumber: session.mockPhoneNumber,
      query: query,
      target: 'customers',
      cursor: cursor,
    );
    final customers = mapListValue(
      json['items'],
    ).map(Customer.fromJson).toList();
    customers.sort(
      (a, b) => _customerDateFor(b).compareTo(_customerDateFor(a)),
    );
    return _SearchResults(
      customers: customers,
      pageInfo: pagination.PageInfo.fromJson(json['pageInfo']),
    );
  }

  Future<_SearchResults> _loadTasks(String query, String? cursor) async {
    final session = widget.controller.session!;
    final json = await widget.controller.apiClient.search.search(
      businessId: session.businessId!,
      firebaseUid: session.firebaseUid,
      mockPhoneNumber: session.mockPhoneNumber,
      query: query,
      target: 'work_items',
      cursor: cursor,
      status: switch (_taskFilter) {
        _TaskStateFilter.open => 'open',
        _TaskStateFilter.done => 'done',
        _TaskStateFilter.all => 'all',
      },
    );
    final tasks = mapListValue(json['items'])
        .map(
          (item) => switch (item['type']) {
            'reminder' => _reminderToWorkItem(item),
            'home_visit' => _homeVisitToWorkItem(item),
            'appointment' => _appointmentToWorkItem(item),
            _ => _quoteToWorkItem(item),
          },
        )
        .toList();
    tasks.sort((a, b) => _dateFor(b).compareTo(_dateFor(a)));
    return _SearchResults(
      tasks: tasks,
      pageInfo: pagination.PageInfo.fromJson(json['pageInfo']),
    );
  }

  Future<void> _loadMore() async {
    final cursor = _results.pageInfo.nextCursor;
    if (_loadingMore || cursor == null) return;
    final generation = _searchGeneration;
    setState(() => _loadingMore = true);
    try {
      final next = await _loadResults(
        query: _queryController.text.trim(),
        cursor: cursor,
      );
      if (!mounted || generation != _searchGeneration) return;
      final merged = _results.append(next);
      setState(() {
        _results = merged;
        _future = Future.value(merged);
      });
    } on ApiException catch (error) {
      if (!mounted || generation != _searchGeneration) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted && generation == _searchGeneration) {
        setState(() => _loadingMore = false);
      }
    }
  }

  void _clearSearch() {
    _searchGeneration += 1;
    setState(() {
      _results = const _SearchResults();
      _future = null;
      _loadingMore = false;
    });
  }

  WorkItem _reminderToWorkItem(Map<String, Object?> json) {
    return WorkItem(
      id: stringValue(json['id']),
      type: WorkItemType.reminder,
      title: stringValue(json['title'], fallback: 'תזכורת'),
      description: nullableString(json['description']),
      customer: _customerFrom(json['customer']),
      dueAt: dateValue(json['dueAt'] ?? json['createdAt']),
      priority: WorkItemPriorityApi.parse(json['priority']),
      status: WorkItemStatusApi.parse(json['status']),
      linkedEntityType: 'reminder',
      linkedEntityId: stringValue(json['id']),
    );
  }

  WorkItem _homeVisitToWorkItem(Map<String, Object?> json) {
    return WorkItem(
      id: stringValue(json['id']),
      type: WorkItemType.homeVisit,
      title: stringValue(json['title'], fallback: 'ביקור בית'),
      description: nullableString(json['notes'] ?? json['location']),
      location: nullableString(json['location']),
      notes: nullableString(json['notes']),
      customer: _customerFrom(json['customer']),
      dueAt: dateValue(json['startsAt'] ?? json['createdAt']),
      priority: WorkItemPriority.normal,
      status: WorkItemStatusApi.parse(json['status']),
      linkedEntityType: 'home_visit',
      linkedEntityId: stringValue(json['id']),
    );
  }

  WorkItem _quoteToWorkItem(Map<String, Object?> json) {
    return WorkItem(
      id: stringValue(json['id']),
      type: WorkItemType.quote,
      title: stringValue(json['title'], fallback: 'הצעת מחיר'),
      description: nullableString(json['description']),
      customer: _customerFrom(json['customer']),
      dueAt: dateValue(json['dueAt'] ?? json['createdAt']),
      priority: WorkItemPriority.normal,
      status: WorkItemStatusApi.parse(json['status']),
      linkedEntityType: 'quote',
      linkedEntityId: stringValue(json['id']),
    );
  }

  WorkItem _appointmentToWorkItem(Map<String, Object?> json) {
    return WorkItem(
      id: stringValue(json['id']),
      type: WorkItemType.appointment,
      title: stringValue(json['title'], fallback: 'פגישה'),
      description: nullableString(json['notes'] ?? json['location']),
      location: nullableString(json['location']),
      notes: nullableString(json['notes']),
      customer: _customerFrom(json['customer']),
      dueAt: dateValue(json['startsAt'] ?? json['createdAt']),
      startsAt: dateValue(json['startsAt']),
      endsAt: dateValue(json['endsAt']),
      priority: WorkItemPriority.normal,
      status: WorkItemStatusApi.parse(json['status']),
      linkedEntityType: 'appointment',
      linkedEntityId: stringValue(json['id']),
    );
  }

  Customer? _customerFrom(Object? value) {
    return value is Map<String, Object?> ? Customer.fromJson(value) : null;
  }

  DateTime _dateFor(WorkItem item) =>
      item.dueAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  DateTime _customerDateFor(Customer customer) =>
      customer.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  String _messageForError(Object? error) {
    if (error is ApiException) return error.message;
    return 'בדוק שהשרת המקומי זמין.';
  }
}

class _SearchHero extends StatelessWidget {
  const _SearchHero({
    required this.controller,
    required this.onBack,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final VoidCallback onBack;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top + 12,
        16,
        22,
      ),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(34)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onBack,
                color: Colors.white,
                icon: const Icon(Icons.arrow_forward),
                tooltip: 'חזרה',
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'חיפוש',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    Text(
                      'לקוחות ופריטי עבודה',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => onSubmitted(),
            decoration: InputDecoration(
              hintText: 'שם, טלפון, כתובת או תוכן',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) => value.text.isEmpty
                    ? const SizedBox.shrink()
                    : IconButton(
                        tooltip: 'נקה',
                        onPressed: controller.clear,
                        icon: const Icon(Icons.close),
                      ),
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchTargetSelector extends StatelessWidget {
  const _SearchTargetSelector({
    required this.selected,
    required this.onChanged,
  });

  final _SearchTarget selected;
  final ValueChanged<_SearchTarget> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SearchChoiceButton(
            label: 'לקוחות',
            icon: Icons.people_alt_outlined,
            selected: selected == _SearchTarget.customers,
            onTap: () => onChanged(_SearchTarget.customers),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SearchChoiceButton(
            label: 'פריטי עבודה',
            icon: Icons.task_alt_outlined,
            selected: selected == _SearchTarget.tasks,
            onTap: () => onChanged(_SearchTarget.tasks),
          ),
        ),
      ],
    );
  }
}

class _SearchChoiceButton extends StatelessWidget {
  const _SearchChoiceButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accent : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: selected ? AppColors.accent : AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? Colors.white : AppColors.primary,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskFilterSelector extends StatelessWidget {
  const _TaskFilterSelector({required this.selected, required this.onChanged});

  final _TaskStateFilter selected;
  final ValueChanged<_TaskStateFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_TaskStateFilter>(
      segments: const [
        ButtonSegment(value: _TaskStateFilter.all, label: Text('הכול')),
        ButtonSegment(value: _TaskStateFilter.open, label: Text('פתוחים')),
        ButtonSegment(value: _TaskStateFilter.done, label: Text('הושלמו')),
      ],
      selected: {selected},
      onSelectionChanged: (value) => onChanged(value.first),
      showSelectedIcon: false,
      style: ButtonStyle(
        visualDensity: VisualDensity.comfortable,
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

class _SearchStateList extends StatelessWidget {
  const _SearchStateList({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [SizedBox(height: 160, child: child)],
    );
  }
}

class _CustomerResults extends StatelessWidget {
  const _CustomerResults({
    required this.controller,
    required this.customers,
    required this.onChanged,
  });

  final SessionController controller;
  final List<Customer> customers;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    if (customers.isEmpty) {
      return const _StateCard(
        icon: Icons.people_alt_outlined,
        title: 'לא נמצאו לקוחות',
        body: 'נסה לחפש לפי שם, טלפון, אימייל או כתובת.',
      );
    }
    return Column(
      children: customers.map((customer) => _card(context, customer)).toList(),
    );
  }

  Widget _card(BuildContext context, Customer customer) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openCustomer(context, customer),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 27,
                  backgroundColor: _avatarColor(customer.name),
                  child: Text(
                    _initials(customer.name),
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (customer.phone != null)
                        Text(
                          customer.phone!,
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.right,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      if (customer.address != null || customer.email != null)
                        Text(
                          customer.address ?? customer.email!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                    ],
                  ),
                ),
                if (customer.phone != null) ...[
                  _SearchQuickAction(
                    tooltip: 'התקשר',
                    icon: Icons.call_outlined,
                    onPressed: () => _launchPhone(customer.phone!),
                  ),
                  _SearchQuickAction(
                    tooltip: 'WhatsApp',
                    icon: Icons.chat_bubble_outline,
                    color: const Color(0xFF169B62),
                    onPressed: () => _launchWhatsApp(customer.phone!),
                  ),
                ],
                const Icon(Icons.chevron_left, color: AppColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openCustomer(BuildContext context, Customer customer) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomerDetailScreen(
          controller: controller,
          customerId: customer.id,
        ),
      ),
    );
    onChanged();
  }

  Future<void> _launchPhone(String phone) =>
      launchUrl(Uri(scheme: 'tel', path: phone));

  Future<void> _launchWhatsApp(String phone) {
    final normalized = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return launchUrl(
      Uri.parse('https://wa.me/$normalized'),
      mode: LaunchMode.externalApplication,
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1);
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}';
  }

  Color _avatarColor(String value) {
    const colors = [
      Color(0xFFDDEFF5),
      Color(0xFFDDEEE9),
      Color(0xFFFFEDD0),
      Color(0xFFE9E5F1),
      Color(0xFFFFE4DA),
    ];
    return colors[value.hashCode.abs() % colors.length];
  }
}

class _SearchQuickAction extends StatelessWidget {
  const _SearchQuickAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.color = AppColors.primary,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      color: color,
      icon: Icon(icon, size: 21),
    );
  }
}

class _TaskResults extends StatelessWidget {
  const _TaskResults({
    required this.controller,
    required this.tasks,
    required this.onChanged,
  });

  final SessionController controller;
  final List<WorkItem> tasks;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const _StateCard(
        icon: Icons.task_alt_outlined,
        title: 'לא נמצאו משימות',
        body: 'נסה לחפש לפי כותרת, תיאור, לקוח או טלפון.',
      );
    }
    return Column(
      children: tasks
          .map(
            (task) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border(
                    right: BorderSide(color: _colorFor(task), width: 5),
                    top: const BorderSide(color: AppColors.border),
                    bottom: const BorderSide(color: AppColors.border),
                    left: const BorderSide(color: AppColors.border),
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => _openTask(context, task),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: _colorFor(
                            task,
                          ).withValues(alpha: 0.14),
                          foregroundColor: _colorFor(task),
                          child: Icon(_iconFor(task)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.customer?.name ?? task.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (task.customer != null)
                                Text(
                                  task.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Text(
                                [
                                  _typeLabel(task),
                                  _statusLabel(task),
                                  if (task.dueAt != null)
                                    formatDateTime(task.dueAt),
                                ].join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 13,
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
              ),
            ),
          )
          .toList(),
    );
  }

  Future<void> _openTask(BuildContext context, WorkItem task) async {
    final changed = await openLinkedEntity(
      context: context,
      controller: controller,
      type: task.linkedEntityType ?? task.type.apiValue,
      id: task.linkedEntityId ?? task.id,
      customer: task.customer,
      title: task.title,
    );
    if (changed) onChanged();
  }

  Color _colorFor(WorkItem task) => switch (task.type) {
    WorkItemType.homeVisit => AppColors.visit,
    WorkItemType.appointment => AppColors.primarySoft,
    WorkItemType.quote => AppColors.quote,
    _ => AppColors.accent,
  };

  IconData _iconFor(WorkItem task) {
    return switch (task.type) {
      WorkItemType.homeVisit => Icons.home_repair_service_outlined,
      WorkItemType.appointment => Icons.event_outlined,
      WorkItemType.quote => Icons.request_quote_outlined,
      _ => Icons.alarm_outlined,
    };
  }

  String _typeLabel(WorkItem task) {
    return switch (task.type) {
      WorkItemType.homeVisit => 'ביקור בית',
      WorkItemType.appointment => 'פגישה',
      WorkItemType.quote => 'הצעת מחיר',
      _ => 'תזכורת',
    };
  }

  String _statusLabel(WorkItem task) => task.isFinished ? 'בוצע' : 'פתוח';
}

class _SearchResults {
  const _SearchResults({
    this.customers = const [],
    this.tasks = const [],
    this.pageInfo = const pagination.PageInfo(hasMore: false),
  });

  final List<Customer> customers;
  final List<WorkItem> tasks;
  final pagination.PageInfo pageInfo;

  _SearchResults append(_SearchResults next) {
    final customerIds = customers.map((customer) => customer.id).toSet();
    final taskIds = tasks.map((task) => task.id).toSet();
    return _SearchResults(
      customers: [
        ...customers,
        ...next.customers.where((customer) => customerIds.add(customer.id)),
      ],
      tasks: [...tasks, ...next.tasks.where((task) => taskIds.add(task.id))],
      pageInfo: next.pageInfo,
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: AppColors.primary),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(body, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
