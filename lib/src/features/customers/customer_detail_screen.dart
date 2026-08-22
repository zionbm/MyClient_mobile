import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../models/customer.dart';
import '../../models/work_item.dart';
import '../../utils/date_formatting.dart';
import '../auth/session_controller.dart';
import '../work_items/work_item_form_screen.dart';
import 'customer_form_screen.dart';

class CustomerDetailScreen extends StatefulWidget {
  const CustomerDetailScreen({
    super.key,
    required this.controller,
    required this.customerId,
  });

  final SessionController controller;
  final String customerId;

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  Future<_CustomerDetail>? _future;
  late int _seenDataVersion;

  @override
  void initState() {
    super.initState();
    _seenDataVersion = widget.controller.dataVersion;
    widget.controller.addListener(_handleDataChanged);
    _future = _load();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleDataChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_CustomerDetail>(
      future: _future,
      builder: (context, snapshot) {
        final title = snapshot.data?.customer.name ?? 'לקוח';
        return Scaffold(
          appBar: AppBar(
            title: Text(title),
            actions: [
              if (snapshot.hasData)
                IconButton(
                  tooltip: 'עריכה',
                  onPressed: () => _edit(snapshot.data!.customer),
                  icon: const Icon(Icons.edit_outlined),
                ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (snapshot.hasError)
                  _InfoCard(
                    icon: Icons.cloud_off_outlined,
                    title: 'לא הצלחנו לטעון לקוח',
                    body: _messageForError(snapshot.error),
                  )
                else if (snapshot.hasData) ...[
                  _CustomerHeader(customer: snapshot.data!.customer),
                  const SizedBox(height: 12),
                  _ActionGrid(
                    onCallback: () =>
                        _create(WorkItemKind.callback, snapshot.data!.customer),
                    onHomeVisit: () => _create(
                      WorkItemKind.homeVisit,
                      snapshot.data!.customer,
                    ),
                    onQuote: () =>
                        _create(WorkItemKind.quote, snapshot.data!.customer),
                    onNote: () => _addNote(snapshot.data!.customer),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'פעילות',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (snapshot.data!.activity.isEmpty)
                    const _InfoCard(
                      icon: Icons.history,
                      title: 'אין עדיין פעילות ללקוח הזה',
                      body: 'חזרות, ביקורים, הצעות והערות יופיעו כאן.',
                    )
                  else
                    ...snapshot.data!.activity.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ActivityTile(item: item),
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _refresh() async {
    _seenDataVersion = widget.controller.dataVersion;
    setState(() => _future = _load());
    await _future;
  }

  void _handleDataChanged() {
    if (!mounted) return;
    final currentVersion = widget.controller.dataVersion;
    if (currentVersion == _seenDataVersion) return;
    _refresh();
  }

  Future<_CustomerDetail> _load() async {
    final session = widget.controller.session!;
    final json = await widget.controller.apiClient.getCustomer(
      businessId: session.businessId!,
      customerId: widget.customerId,
      firebaseUid: session.firebaseUid,
      mockPhoneNumber: session.mockPhoneNumber,
    );
    final customer = Customer.fromJson(
      json['customer'] as Map<String, Object?>,
    );
    final activity =
        (json['activity'] as List?)
            ?.whereType<Map<String, Object?>>()
            .map(WorkItem.fromJson)
            .toList() ??
        const <WorkItem>[];
    return _CustomerDetail(customer: customer, activity: activity);
  }

  Future<void> _edit(Customer customer) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CustomerFormScreen(
          controller: widget.controller,
          customer: customer,
        ),
      ),
    );
    if (changed == true) {
      widget.controller.markDataChanged();
      await _refreshAfterReturn();
    }
  }

  Future<void> _create(WorkItemKind kind, Customer customer) async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => WorkItemFormScreen(
          controller: widget.controller,
          kind: kind,
          initialCustomer: customer,
        ),
      ),
    );
    if (created == true) {
      widget.controller.markDataChanged();
      await _refreshAfterReturn();
    }
  }

  Future<void> _refreshAfterReturn() async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await _refresh();
  }

  Future<void> _addNote(Customer customer) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('הערה ל${customer.name}'),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(labelText: 'טקסט הערה'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ביטול'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('שמור'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text == null || text.trim().isEmpty) return;

    final session = widget.controller.session!;
    try {
      await widget.controller.apiClient.createCustomerNote(
        businessId: session.businessId!,
        customerId: customer.id,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        text: text,
      );
      widget.controller.markDataChanged();
      await _refresh();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  String _messageForError(Object? error) {
    if (error is ApiException) return error.message;
    return 'בדוק שהשרת המקומי זמין.';
  }
}

class _CustomerDetail {
  const _CustomerDetail({required this.customer, required this.activity});

  final Customer customer;
  final List<WorkItem> activity;
}

class _CustomerHeader extends StatelessWidget {
  const _CustomerHeader({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              customer.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            if (customer.phone != null) Text(customer.phone!),
            if (customer.email != null) Text(customer.email!),
            if (customer.address != null) Text(customer.address!),
          ],
        ),
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({
    required this.onCallback,
    required this.onHomeVisit,
    required this.onQuote,
    required this.onNote,
  });

  final VoidCallback onCallback;
  final VoidCallback onHomeVisit;
  final VoidCallback onQuote;
  final VoidCallback onNote;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed: onCallback,
          icon: const Icon(Icons.alarm),
          label: const Text('תזכורת'),
        ),
        FilledButton.icon(
          onPressed: onHomeVisit,
          icon: const Icon(Icons.home_repair_service_outlined),
          label: const Text('ביקור'),
        ),
        FilledButton.icon(
          onPressed: onQuote,
          icon: const Icon(Icons.request_quote_outlined),
          label: const Text('הצעה'),
        ),
        OutlinedButton.icon(
          onPressed: onNote,
          icon: const Icon(Icons.note_add_outlined),
          label: const Text('הערה'),
        ),
      ],
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.item});

  final WorkItem item;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Icon(_icon)),
        title: Text(item.title),
        subtitle: Text(
          [
            _label,
            if (item.dueAt != null) formatDateTime(item.dueAt),
            if (item.description != null) item.description!,
          ].join(' · '),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  IconData get _icon {
    return switch (item.type) {
      'callback' => Icons.alarm,
      'home_visit' => Icons.home_repair_service_outlined,
      'quote' => Icons.request_quote_outlined,
      'note' => Icons.note_outlined,
      _ => Icons.task_alt,
    };
  }

  String get _label {
    return switch (item.type) {
      'callback' => 'תזכורת / חזרה',
      'home_visit' => 'ביקור בית',
      'quote' => 'הצעת מחיר',
      'note' => 'הערה',
      _ => item.type,
    };
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
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
            Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
