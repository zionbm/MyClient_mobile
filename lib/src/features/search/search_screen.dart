import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../models/customer.dart';
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
                  setState(() => _future = null);
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
              setState(() {
                _target = value.first;
                _future = null;
              });
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
                setState(() {
                  _taskFilter = value.first;
                  _future = null;
                });
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
              return _target == _SearchTarget.customers
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
            },
          ),
        ],
      ),
    );
  }

  void _runSearch() {
    setState(() => _future = _loadResults());
  }

  Future<_SearchResults> _loadResults() async {
    final query = _queryController.text.trim();
    if (_target == _SearchTarget.customers) {
      return _SearchResults(customers: await _loadCustomers(query));
    }
    return _SearchResults(tasks: await _loadTasks(query));
  }

  Future<List<Customer>> _loadCustomers(String query) async {
    final session = widget.controller.session!;
    final json = await widget.controller.apiClient.listCustomers(
      businessId: session.businessId!,
      firebaseUid: session.firebaseUid,
      mockPhoneNumber: session.mockPhoneNumber,
    );
    final customers = mapListValue(json['customers'])
        .map(Customer.fromJson)
        .where((customer) => _matchesCustomer(customer, query))
        .toList();
    customers.sort(
      (a, b) => _customerDateFor(b).compareTo(_customerDateFor(a)),
    );
    return customers;
  }

  Future<List<WorkItem>> _loadTasks(String query) async {
    final session = widget.controller.session!;
    final responses = await Future.wait([
      widget.controller.apiClient.listCallbacks(
        businessId: session.businessId!,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
      ),
      widget.controller.apiClient.listHomeVisits(
        businessId: session.businessId!,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
      ),
      widget.controller.apiClient.listQuotes(
        businessId: session.businessId!,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
      ),
    ]);
    final tasks =
        [
          ...mapListValue(responses[0]['callbacks']).map(_callbackToWorkItem),
          ...mapListValue(responses[1]['homeVisits']).map(_homeVisitToWorkItem),
          ...mapListValue(responses[2]['quotes']).map(_quoteToWorkItem),
        ].where((item) {
          final matchesState = switch (_taskFilter) {
            _TaskStateFilter.open => !item.isFinished,
            _TaskStateFilter.done => item.isFinished,
            _TaskStateFilter.all => true,
          };
          return matchesState && _matchesWorkItem(item, query);
        }).toList();
    tasks.sort((a, b) => _dateFor(b).compareTo(_dateFor(a)));
    return tasks;
  }

  WorkItem _callbackToWorkItem(Map<String, Object?> json) {
    return WorkItem(
      id: stringValue(json['id']),
      type: 'callback',
      title: stringValue(json['title'], fallback: 'חזרה ללקוח'),
      description: nullableString(json['description']),
      customer: _customerFrom(json['customer']),
      dueAt: dateValue(json['dueAt'] ?? json['createdAt']),
      priority: nullableString(json['priority']),
      status: nullableString(json['status']),
      linkedEntityType: 'callback',
      linkedEntityId: stringValue(json['id']),
    );
  }

  WorkItem _homeVisitToWorkItem(Map<String, Object?> json) {
    return WorkItem(
      id: stringValue(json['id']),
      type: 'home_visit',
      title: stringValue(json['title'], fallback: 'ביקור בית'),
      description: nullableString(json['notes'] ?? json['location']),
      location: nullableString(json['location']),
      notes: nullableString(json['notes']),
      customer: _customerFrom(json['customer']),
      dueAt: dateValue(json['startsAt'] ?? json['createdAt']),
      priority: 'NORMAL',
      status: nullableString(json['status']),
      linkedEntityType: 'home_visit',
      linkedEntityId: stringValue(json['id']),
    );
  }

  WorkItem _quoteToWorkItem(Map<String, Object?> json) {
    return WorkItem(
      id: stringValue(json['id']),
      type: 'quote',
      title: stringValue(json['title'], fallback: 'הצעת מחיר'),
      description: nullableString(json['description']),
      customer: _customerFrom(json['customer']),
      dueAt: dateValue(json['dueAt'] ?? json['createdAt']),
      priority: 'NORMAL',
      status: nullableString(json['status']),
      linkedEntityType: 'quote',
      linkedEntityId: stringValue(json['id']),
    );
  }

  Customer? _customerFrom(Object? value) {
    return value is Map<String, Object?> ? Customer.fromJson(value) : null;
  }

  bool _matchesCustomer(Customer customer, String query) {
    if (query.isEmpty) return true;
    return _contains(customer.name, query) ||
        _contains(customer.phone, query) ||
        _contains(customer.email, query) ||
        _contains(customer.address, query);
  }

  bool _matchesWorkItem(WorkItem item, String query) {
    if (query.isEmpty) return true;
    return _contains(item.title, query) ||
        _contains(item.description, query) ||
        _contains(item.location, query) ||
        _contains(item.notes, query) ||
        _contains(item.customer?.name, query) ||
        _contains(item.customer?.phone, query);
  }

  bool _contains(String? value, String query) {
    return value?.toLowerCase().contains(query.toLowerCase()) ?? false;
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
                      type: task.linkedEntityType ?? task.type,
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
      'home_visit' => Icons.home_repair_service_outlined,
      'quote' => Icons.request_quote_outlined,
      _ => Icons.phone_callback_outlined,
    };
  }

  String _typeLabel(WorkItem task) {
    return switch (task.type) {
      'home_visit' => 'ביקור בית',
      'quote' => 'הצעת מחיר',
      _ => 'חזרה ללקוח',
    };
  }

  String _statusLabel(WorkItem task) => task.isFinished ? 'בוצע' : 'פתוח';
}

class _SearchResults {
  const _SearchResults({this.customers = const [], this.tasks = const []});

  final List<Customer> customers;
  final List<WorkItem> tasks;
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
