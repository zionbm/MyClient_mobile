import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../models/customer.dart';
import '../../models/page.dart' as pagination;
import '../../models/work_item.dart';
import '../../navigation/linked_entity_navigation.dart';
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

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        if (_future == null) return;
        _runSearch();
        await _future;
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          TextField(
            controller: _queryController,
            decoration: InputDecoration(
              labelText: 'מה לחפש?',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                tooltip: 'נקה',
                onPressed: () {
                  _queryController.clear();
                  _clearSearch();
                },
                icon: const Icon(Icons.close),
              ),
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _runSearch(),
          ),
          const SizedBox(height: 12),
          SegmentedButton<_SearchTarget>(
            segments: const [
              ButtonSegment(
                value: _SearchTarget.customers,
                icon: Icon(Icons.people_alt_outlined),
                label: Text('לקוחות'),
              ),
              ButtonSegment(
                value: _SearchTarget.tasks,
                icon: Icon(Icons.task_alt_outlined),
                label: Text('משימות'),
              ),
            ],
            selected: {_target},
            onSelectionChanged: (value) {
              setState(() => _target = value.first);
              _clearSearch();
            },
          ),
          if (_target == _SearchTarget.tasks) ...[
            const SizedBox(height: 8),
            SegmentedButton<_TaskStateFilter>(
              segments: const [
                ButtonSegment(
                  value: _TaskStateFilter.open,
                  label: Text('פתוחות'),
                ),
                ButtonSegment(
                  value: _TaskStateFilter.done,
                  label: Text('בוצעו'),
                ),
                ButtonSegment(value: _TaskStateFilter.all, label: Text('הכל')),
              ],
              selected: {_taskFilter},
              onSelectionChanged: (value) {
                setState(() => _taskFilter = value.first);
                _clearSearch();
              },
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _runSearch,
            icon: const Icon(Icons.search),
            label: const Text('חיפוש'),
          ),
          const SizedBox(height: 16),
          FutureBuilder<_SearchResults>(
            future: _future,
            builder: (context, snapshot) {
              if (_future == null) {
                return const _StateCard(
                  icon: Icons.manage_search_outlined,
                  title: 'הקלד חיפוש ולחץ חיפוש',
                  body: 'אפשר לחפש לפי שם, טלפון, כתובת, כותרת או תיאור.',
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return _StateCard(
                  icon: Icons.cloud_off_outlined,
                  title: 'לא הצלחנו לחפש',
                  body: _messageForError(snapshot.error),
                );
              }
              final results = snapshot.data ?? const _SearchResults();
              final resultList = _target == _SearchTarget.customers
                  ? _CustomerResults(
                      controller: widget.controller,
                      customers: results.customers,
                      onChanged: _runSearch,
                    )
                  : _TaskResults(
                      controller: widget.controller,
                      tasks: results.tasks,
                      onChanged: _runSearch,
                    );
              return Column(
                children: [
                  resultList,
                  if (results.pageInfo.hasMore) ...[
                    const SizedBox(height: 8),
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
        ],
      ),
    );
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
      children: customers
          .map(
            (customer) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(customer.name),
                  subtitle: Text(
                    [
                      if (customer.phone != null) customer.phone!,
                      if (customer.address != null) customer.address!,
                    ].join(' · '),
                  ),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CustomerDetailScreen(
                          controller: controller,
                          customerId: customer.id,
                        ),
                      ),
                    );
                    onChanged();
                  },
                ),
              ),
            ),
          )
          .toList(),
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
              child: Card(
                child: ListTile(
                  leading: CircleAvatar(child: Icon(_iconFor(task))),
                  title: Text(task.title),
                  subtitle: Text(
                    [
                      _typeLabel(task),
                      _statusLabel(task),
                      if (task.customer != null) task.customer!.name,
                      if (task.dueAt != null) formatDateTime(task.dueAt),
                    ].join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () async {
                    final changed = await openLinkedEntity(
                      context: context,
                      controller: controller,
                      type: task.linkedEntityType ?? task.type.apiValue,
                      id: task.linkedEntityId ?? task.id,
                      customer: task.customer,
                      title: task.title,
                    );
                    if (changed) onChanged();
                  },
                ),
              ),
            ),
          )
          .toList(),
    );
  }

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
          children: [
            Icon(icon, size: 36),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(body, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
