import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../models/customer.dart';
import '../../models/work_item.dart';
import '../../navigation/app_route_observer.dart';
import '../../utils/date_formatting.dart';
import '../auth/session_controller.dart';
import '../work_items/work_item_form_screen.dart';

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

class _CustomerDetailScreenState extends State<CustomerDetailScreen>
    with RouteAware {
  Future<_CustomerDetail>? _future;
  late int _seenDataVersion;
  bool _subscribedToRoute = false;

  @override
  void initState() {
    super.initState();
    _seenDataVersion = widget.controller.dataVersion;
    widget.controller.addListener(_handleDataChanged);
    _future = _load();
  }

  @override
  void dispose() {
    if (_subscribedToRoute) {
      appRouteObserver.unsubscribe(this);
    }
    widget.controller.removeListener(_handleDataChanged);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_subscribedToRoute) return;
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic>) {
      appRouteObserver.subscribe(this, route);
      _subscribedToRoute = true;
    }
  }

  @override
  void didPopNext() {
    _refresh();
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
                  tooltip: 'מיזוג לקוח',
                  onPressed: () => _merge(snapshot.data!.customer),
                  icon: const Icon(Icons.merge_type_outlined),
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
                  _CustomerHeader(
                    customer: snapshot.data!.customer,
                    onSaveField: (field, value) => _updateCustomerField(
                      snapshot.data!.customer,
                      field,
                      value,
                    ),
                  ),
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
                        child: _ActivityTile(
                          item: item,
                          onOpen: _canEdit(item) ? () => _editItem(item) : null,
                          onComplete: item.canComplete
                              ? () => _completeItem(item)
                              : null,
                          onMarkPaid: item.canMarkPaid
                              ? () => _markPaid(item)
                              : null,
                          onDelete: _canDelete(item)
                              ? () => _deleteItem(item)
                              : null,
                        ),
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

  Future<void> _editItem(WorkItem item) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => WorkItemFormScreen(
          controller: widget.controller,
          kind: _kindFor(item),
          initialCustomer: item.customer,
          existingItem: item,
        ),
      ),
    );
    if (changed == true) {
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

  Future<void> _updateCustomerField(
    Customer customer,
    String field,
    String value,
  ) async {
    final session = widget.controller.session!;
    try {
      await widget.controller.apiClient.updateCustomer(
        businessId: session.businessId!,
        customerId: customer.id,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        body: {field: _fieldValue(field, value)},
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

  Object? _fieldValue(String field, String value) {
    final text = value.trim();
    if (field == 'name') return text;
    return text.isEmpty ? null : text;
  }

  Future<void> _completeItem(WorkItem item) async {
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
      await _refresh();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
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
      await _refresh();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _deleteItem(WorkItem item) async {
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
      await _refresh();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _merge(Customer source) async {
    final session = widget.controller.session!;
    try {
      final json = await widget.controller.apiClient.listCustomers(
        businessId: session.businessId!,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
      );
      final customers =
          (json['customers'] as List?)
              ?.whereType<Map<String, Object?>>()
              .map(Customer.fromJson)
              .where((customer) => customer.id != source.id)
              .toList() ??
          const <Customer>[];
      if (!mounted) return;
      final target = await showDialog<Customer>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('בחר לקוח יעד למיזוג'),
          children: customers.isEmpty
              ? [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('אין לקוחות נוספים למיזוג'),
                  ),
                ]
              : customers
                    .map(
                      (customer) => SimpleDialogOption(
                        onPressed: () => Navigator.of(context).pop(customer),
                        child: Text(customer.name),
                      ),
                    )
                    .toList(),
        ),
      );
      if (target == null) return;
      if (!mounted) return;
      final approved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('לאשר מיזוג?'),
          content: Text('הלקוח ${source.name} ימוזג לתוך ${target.name}.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('ביטול'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('מזג'),
            ),
          ],
        ),
      );
      if (approved != true) return;
      await widget.controller.apiClient.mergeCustomer(
        businessId: session.businessId!,
        sourceCustomerId: source.id,
        targetCustomerId: target.id,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
      );
      widget.controller.markDataChanged();
      if (!mounted) return;
      Navigator.of(context).pop(true);
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

  bool _canEdit(WorkItem item) {
    return item.type == 'callback' ||
        item.type == 'home_visit' ||
        item.type == 'quote';
  }

  bool _canDelete(WorkItem item) => _canEdit(item);

  WorkItemKind _kindFor(WorkItem item) {
    return switch (item.type) {
      'home_visit' => WorkItemKind.homeVisit,
      'quote' => WorkItemKind.quote,
      _ => WorkItemKind.callback,
    };
  }
}

class _CustomerDetail {
  const _CustomerDetail({required this.customer, required this.activity});

  final Customer customer;
  final List<WorkItem> activity;
}

class _CustomerHeader extends StatelessWidget {
  const _CustomerHeader({required this.customer, required this.onSaveField});

  final Customer customer;
  final Future<void> Function(String field, String value) onSaveField;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _EditableCustomerField(
              label: 'שם',
              value: customer.name,
              field: 'name',
              icon: Icons.person_outline,
              onSave: onSaveField,
            ),
            const SizedBox(height: 12),
            _EditableCustomerField(
              label: 'טלפון',
              value: customer.phone ?? '',
              field: 'phone',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              onSave: onSaveField,
            ),
            const SizedBox(height: 12),
            _EditableCustomerField(
              label: 'אימייל',
              value: customer.email ?? '',
              field: 'email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              onSave: onSaveField,
            ),
            const SizedBox(height: 12),
            _EditableCustomerField(
              label: 'כתובת',
              value: customer.address ?? '',
              field: 'address',
              icon: Icons.location_on_outlined,
              onSave: onSaveField,
            ),
          ],
        ),
      ),
    );
  }
}

class _EditableCustomerField extends StatefulWidget {
  const _EditableCustomerField({
    required this.label,
    required this.value,
    required this.field,
    required this.icon,
    required this.onSave,
    this.keyboardType,
  });

  final String label;
  final String value;
  final String field;
  final IconData icon;
  final TextInputType? keyboardType;
  final Future<void> Function(String field, String value) onSave;

  @override
  State<_EditableCustomerField> createState() => _EditableCustomerFieldState();
}

class _EditableCustomerFieldState extends State<_EditableCustomerField> {
  late final TextEditingController _controller;
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _EditableCustomerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && oldWidget.value != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      enabled: _editing && !_saving,
      keyboardType: widget.keyboardType,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: Icon(widget.icon),
        suffixIcon: IconButton(
          tooltip: _editing ? 'שמור' : 'ערוך',
          onPressed: _saving ? null : _toggleOrSave,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(_editing ? Icons.check : Icons.edit_outlined),
        ),
      ),
      onSubmitted: (_) {
        if (_editing && !_saving) _toggleOrSave();
      },
    );
  }

  Future<void> _toggleOrSave() async {
    if (!_editing) {
      setState(() => _editing = true);
      return;
    }
    if (widget.field == 'name' && _controller.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('שם לקוח הוא שדה חובה')));
      return;
    }
    setState(() => _saving = true);
    await widget.onSave(widget.field, _controller.text);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _editing = false;
    });
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
      alignment: WrapAlignment.center,
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
  const _ActivityTile({
    required this.item,
    this.onOpen,
    this.onComplete,
    this.onMarkPaid,
    this.onDelete,
  });

  final WorkItem item;
  final VoidCallback? onOpen;
  final VoidCallback? onComplete;
  final VoidCallback? onMarkPaid;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onOpen,
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
        trailing: Wrap(
          spacing: 2,
          children: [
            if (onComplete != null)
              IconButton(
                tooltip: 'סמן כבוצע',
                onPressed: onComplete,
                icon: const Icon(Icons.check_circle_outline),
              ),
            if (onMarkPaid != null)
              IconButton(
                tooltip: 'סמן כשולם',
                onPressed: onMarkPaid,
                icon: const Icon(Icons.payments_outlined),
              ),
            if (onDelete != null)
              IconButton(
                tooltip: 'מחק',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
          ],
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
