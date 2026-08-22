import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../models/work_item.dart';
import '../../utils/date_formatting.dart';
import '../auth/session_controller.dart';
import '../work_items/work_item_form_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});

  final SessionController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _selectedFilter = 'הכל';
  Future<Map<String, Object?>>? _homeFuture;
  late int _seenDataVersion;

  @override
  void initState() {
    super.initState();
    _seenDataVersion = widget.controller.dataVersion;
    widget.controller.addListener(_handleDataChanged);
    _loadHome();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleDataChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.controller.session!;

    return RefreshIndicator(
      onRefresh: () async => _loadHome(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            'שלום${session.displayName == null ? '' : ', ${session.displayName}'}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            _formatDate(_selectedDate),
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          _CreateActions(
            onCallback: () => _create(WorkItemKind.callback),
            onHomeVisit: () => _create(WorkItemKind.homeVisit),
            onQuote: () => _create(WorkItemKind.quote),
          ),
          const SizedBox(height: 12),
          _DateStrip(
            selectedDate: _selectedDate,
            onChanged: (date) {
              setState(() => _selectedDate = date);
              _loadHome();
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: 'חיפוש בבית',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                tooltip: 'חפש',
                onPressed: _loadHome,
                icon: const Icon(Icons.arrow_forward),
              ),
            ),
            onSubmitted: (_) => _loadHome(),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  ['הכל', 'דחוף', 'חזרות', 'ביקורי בית', 'הצעות מחיר', 'שיחות']
                      .map(
                        (filter) => Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: FilterChip(
                            selected: _selectedFilter == filter,
                            label: Text(filter),
                            onSelected: (_) {
                              setState(() => _selectedFilter = filter);
                              _loadHome();
                            },
                          ),
                        ),
                      )
                      .toList(),
            ),
          ),
          const SizedBox(height: 16),
          FutureBuilder<Map<String, Object?>>(
            future: _homeFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return _StateCard(
                  icon: Icons.cloud_off_outlined,
                  title: 'לא הצלחנו לטעון את הבית',
                  body: _messageForError(snapshot.error),
                  actionLabel: 'נסה שוב',
                  onAction: _loadHome,
                );
              }

              final items = _extractItems(snapshot.data ?? const {});
              if (items.isEmpty) {
                return const _StateCard(
                  icon: Icons.check_circle_outline,
                  title: 'אין דברים לטפל בהם ביום הזה',
                  body:
                      'כשתהיה חזרה ללקוח, ביקור בית או הצעת מחיר, הם יופיעו כאן.',
                );
              }

              return Column(
                children: items
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _WorkItemCard(
                          item: item,
                          onComplete: item.canComplete
                              ? () => _complete(item)
                              : null,
                          onMarkPaid: item.canMarkPaid
                              ? () => _markPaid(item)
                              : null,
                          onDelete: _canDelete(item)
                              ? () => _delete(item)
                              : null,
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 96),
        ],
      ),
    );
  }

  void _loadHome() {
    final session = widget.controller.session!;
    setState(() {
      _seenDataVersion = widget.controller.dataVersion;
      _homeFuture = widget.controller.apiClient.getHome(
        businessId: session.businessId!,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        date: _selectedDate,
        query: _searchController.text,
        filter: _apiFilter,
      );
    });
  }

  void _handleDataChanged() {
    if (!mounted) return;
    final currentVersion = widget.controller.dataVersion;
    if (currentVersion == _seenDataVersion) return;
    _loadHome();
  }

  Future<void> _create(WorkItemKind kind) async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            WorkItemFormScreen(controller: widget.controller, kind: kind),
      ),
    );
    if (created == true) {
      widget.controller.markDataChanged();
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      _loadHome();
    }
  }

  Future<void> _complete(WorkItem item) async {
    final session = widget.controller.session!;
    try {
      if (item.type == 'callback') {
        await widget.controller.apiClient.completeCallback(
          businessId: session.businessId!,
          callbackId: item.id,
          firebaseUid: session.firebaseUid,
          mockPhoneNumber: session.mockPhoneNumber,
        );
      } else if (item.type == 'home_visit') {
        await widget.controller.apiClient.completeHomeVisit(
          businessId: session.businessId!,
          homeVisitId: item.id,
          firebaseUid: session.firebaseUid,
          mockPhoneNumber: session.mockPhoneNumber,
        );
      }
      widget.controller.markDataChanged();
      _loadHome();
    } on ApiException catch (error) {
      _showError(error.message);
    }
  }

  Future<void> _markPaid(WorkItem item) async {
    final session = widget.controller.session!;
    try {
      await widget.controller.apiClient.markQuotePaid(
        businessId: session.businessId!,
        quoteId: item.id,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
      );
      widget.controller.markDataChanged();
      _loadHome();
    } on ApiException catch (error) {
      _showError(error.message);
    }
  }

  Future<void> _delete(WorkItem item) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('למחוק פריט?'),
        content: Text(item.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ביטול'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('מחק'),
          ),
        ],
      ),
    );
    if (approved != true) return;

    final session = widget.controller.session!;
    try {
      if (item.type == 'callback') {
        await widget.controller.apiClient.deleteCallback(
          businessId: session.businessId!,
          callbackId: item.id,
          firebaseUid: session.firebaseUid,
          mockPhoneNumber: session.mockPhoneNumber,
        );
      } else if (item.type == 'home_visit') {
        await widget.controller.apiClient.deleteHomeVisit(
          businessId: session.businessId!,
          homeVisitId: item.id,
          firebaseUid: session.firebaseUid,
          mockPhoneNumber: session.mockPhoneNumber,
        );
      } else if (item.type == 'quote') {
        await widget.controller.apiClient.deleteQuote(
          businessId: session.businessId!,
          quoteId: item.id,
          firebaseUid: session.firebaseUid,
          mockPhoneNumber: session.mockPhoneNumber,
        );
      }
      widget.controller.markDataChanged();
      _loadHome();
    } on ApiException catch (error) {
      _showError(error.message);
    }
  }

  bool _canDelete(WorkItem item) {
    return item.type == 'callback' ||
        item.type == 'home_visit' ||
        item.type == 'quote';
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String get _apiFilter {
    return switch (_selectedFilter) {
      'דחוף' => 'urgent',
      'חזרות' => 'callbacks',
      'ביקורי בית' => 'home_visits',
      'הצעות מחיר' => 'quotes',
      'שיחות' => 'calls',
      _ => 'all',
    };
  }

  List<WorkItem> _extractItems(Map<String, Object?> payload) {
    final candidates = [
      payload['items'],
      payload['workItems'],
      payload['homeItems'],
      payload['callbacks'],
      payload['homeVisits'],
      payload['quotes'],
    ];

    final items = <WorkItem>[];
    for (final candidate in candidates) {
      if (candidate is List) {
        items.addAll(
          candidate.whereType<Map<String, Object?>>().map(WorkItem.fromJson),
        );
      }
    }
    return items;
  }

  String _formatDate(DateTime date) {
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final diff = normalizedDate.difference(normalizedToday).inDays;

    final label = switch (diff) {
      -1 => 'אתמול',
      0 => 'היום',
      1 => 'מחר',
      _ => '${date.day}.${date.month}.${date.year}',
    };
    return '$label, ${date.day}.${date.month}.${date.year}';
  }

  String _messageForError(Object? error) {
    if (error is ApiException) return error.message;
    return 'בדוק שהשרת המקומי רץ על הכתובת שהוגדרה.';
  }
}

class _CreateActions extends StatelessWidget {
  const _CreateActions({
    required this.onCallback,
    required this.onHomeVisit,
    required this.onQuote,
  });

  final VoidCallback onCallback;
  final VoidCallback onHomeVisit;
  final VoidCallback onQuote;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed: onCallback,
          icon: const Icon(Icons.alarm_add_outlined),
          label: const Text('תזכורת'),
        ),
        FilledButton.icon(
          onPressed: onHomeVisit,
          icon: const Icon(Icons.home_repair_service_outlined),
          label: const Text('ביקור'),
        ),
        OutlinedButton.icon(
          onPressed: onQuote,
          icon: const Icon(Icons.request_quote_outlined),
          label: const Text('הצעה'),
        ),
      ],
    );
  }
}

class _DateStrip extends StatelessWidget {
  const _DateStrip({required this.selectedDate, required this.onChanged});

  final DateTime selectedDate;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final dates = List.generate(7, (index) {
      final offset = index - 2;
      return DateTime(
        today.year,
        today.month,
        today.day,
      ).add(Duration(days: offset));
    });

    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: dates.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final date = dates[index];
          final selected = _sameDay(date, selectedDate);
          return ChoiceChip(
            selected: selected,
            label: SizedBox(
              width: 56,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_weekday(date)),
                  const SizedBox(height: 2),
                  Text(
                    '${date.day}.${date.month}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            onSelected: (_) => onChanged(date),
          );
        },
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _weekday(DateTime date) {
    return switch (date.weekday) {
      DateTime.sunday => 'א׳',
      DateTime.monday => 'ב׳',
      DateTime.tuesday => 'ג׳',
      DateTime.wednesday => 'ד׳',
      DateTime.thursday => 'ה׳',
      DateTime.friday => 'ו׳',
      _ => 'ש׳',
    };
  }
}

class _WorkItemCard extends StatelessWidget {
  const _WorkItemCard({
    required this.item,
    this.onComplete,
    this.onMarkPaid,
    this.onDelete,
  });

  final WorkItem item;
  final VoidCallback? onComplete;
  final VoidCallback? onMarkPaid;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 8, 8),
        child: Column(
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundColor: item.isUrgent
                    ? Theme.of(context).colorScheme.errorContainer
                    : Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  _iconForType(item.type),
                  color: item.isUrgent
                      ? Theme.of(context).colorScheme.onErrorContainer
                      : Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              title: Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                [
                  _labelForType(item.type),
                  if (item.customer != null) item.customer!.name,
                  if (item.dueAt != null) formatDateTime(item.dueAt),
                  if (item.description != null) item.description!,
                ].join(' · '),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onComplete != null || onMarkPaid != null || onDelete != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Wrap(
                  spacing: 8,
                  children: [
                    if (onComplete != null)
                      TextButton.icon(
                        onPressed: onComplete,
                        icon: const Icon(Icons.check),
                        label: const Text('בוצע'),
                      ),
                    if (onMarkPaid != null)
                      TextButton.icon(
                        onPressed: onMarkPaid,
                        icon: const Icon(Icons.payments_outlined),
                        label: const Text('שולם'),
                      ),
                    if (onDelete != null)
                      TextButton.icon(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('מחק'),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    return switch (type.toLowerCase()) {
      'callback' => Icons.phone_callback_outlined,
      'home_visit' => Icons.home_repair_service_outlined,
      'quote' => Icons.request_quote_outlined,
      'call' => Icons.call_outlined,
      'notification' => Icons.notifications_none,
      _ => Icons.task_alt,
    };
  }

  String _labelForType(String type) {
    return switch (type.toLowerCase()) {
      'callback' => 'חזרה ללקוח',
      'home_visit' => 'ביקור בית',
      'quote' => 'הצעת מחיר',
      'call' => 'שיחה',
      'notification' => 'התראה',
      _ => type,
    };
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
