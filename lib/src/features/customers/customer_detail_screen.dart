import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../core/state/data_invalidator.dart';
import '../../models/customer.dart';
import '../../models/work_item.dart';
import '../../navigation/app_route_observer.dart';
import '../../utils/date_formatting.dart';
import '../../utils/json_read.dart';
import '../auth/session_controller.dart';
import '../work_items/work_item_form_screen.dart';
import 'phone_number_picker.dart';

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
  bool _openExpanded = true;
  bool _doneExpanded = false;
  int _activityRevision = 0;
  late int _seenDataVersion;
  bool _subscribedToRoute = false;
  bool _suppressNextDataChange = false;
  bool _deletingCustomer = false;

  @override
  void initState() {
    super.initState();
    _seenDataVersion = widget.controller.dataInvalidator.revision(
      DataScope.crm,
    );
    widget.controller.dataInvalidator.addListener(_handleDataChanged);
    _future = _load();
  }

  @override
  void dispose() {
    if (_subscribedToRoute) {
      appRouteObserver.unsubscribe(this);
    }
    widget.controller.dataInvalidator.removeListener(_handleDataChanged);
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
                  tooltip: 'מחיקת לקוח',
                  onPressed: _deletingCustomer
                      ? null
                      : () => _deleteCustomer(snapshot.data!.customer),
                  icon: const Icon(Icons.delete_outline),
                ),
              if (snapshot.hasData)
                IconButton(
                  tooltip: 'מיזוג לקוח',
                  onPressed: _deletingCustomer
                      ? null
                      : () => _merge(snapshot.data!.customer),
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
                    controller: widget.controller,
                    onSaveField: (field, value) => _updateCustomerField(
                      snapshot.data!.customer,
                      field,
                      value,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ActionGrid(
                    onReminder: () =>
                        _create(WorkItemKind.reminder, snapshot.data!.customer),
                    onHomeVisit: () => _create(
                      WorkItemKind.homeVisit,
                      snapshot.data!.customer,
                    ),
                    onAppointment: () => _create(
                      WorkItemKind.appointment,
                      snapshot.data!.customer,
                    ),
                    onQuote: () =>
                        _create(WorkItemKind.quote, snapshot.data!.customer),
                    onNote: () =>
                        _create(WorkItemKind.note, snapshot.data!.customer),
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
                      body:
                          'תזכורות, ביקורים, פגישות, הצעות והערות יופיעו כאן.',
                    )
                  else ...[
                    _ActivitySection(
                      key: ValueKey(
                        'customer-open-$_activityRevision-${_itemsStateKey(snapshot.data!.openActivity)}',
                      ),
                      title: 'משימות פתוחות',
                      count: snapshot.data!.openActivity.length,
                      expanded: _openExpanded,
                      emptyText: 'אין משימות פתוחות ללקוח הזה',
                      onToggle: () =>
                          setState(() => _openExpanded = !_openExpanded),
                      children: snapshot.data!.openActivity
                          .map((item) => _buildActivityCard(item))
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    _ActivitySection(
                      key: ValueKey(
                        'customer-done-$_activityRevision-${_itemsStateKey(snapshot.data!.doneActivity)}',
                      ),
                      title: 'בוצעו',
                      count: snapshot.data!.doneActivity.length,
                      expanded: _doneExpanded,
                      emptyText: 'אין משימות שבוצעו ללקוח הזה',
                      onToggle: () =>
                          setState(() => _doneExpanded = !_doneExpanded),
                      children: snapshot.data!.doneActivity
                          .map((item) => _buildActivityCard(item))
                          .toList(),
                    ),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActivityCard(WorkItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _ActivityCard(
        item: item,
        onOpen: _canEdit(item) ? () => _editItem(item) : null,
        onComplete: item.canComplete ? () => _completeItem(item) : null,
        onMarkPaid: item.canMarkPaid ? () => _markPaid(item) : null,
        onReopen: _canReopen(item) ? () => _reopenItem(item) : null,
        onDelete: _canDelete(item) ? () => _deleteItem(item) : null,
      ),
    );
  }

  Future<void> _refresh() async {
    final detail = await _load();
    if (!mounted) return;
    setState(() {
      _seenDataVersion = widget.controller.dataInvalidator.revision(
        DataScope.crm,
      );
      _activityRevision += 1;
      _future = Future.value(detail);
    });
  }

  void _handleDataChanged() {
    if (!mounted) return;
    final currentVersion = widget.controller.dataInvalidator.revision(
      DataScope.crm,
    );
    if (_suppressNextDataChange) {
      _suppressNextDataChange = false;
      _seenDataVersion = currentVersion;
      return;
    }
    if (currentVersion == _seenDataVersion) return;
    _refresh();
  }

  Future<_CustomerDetail> _load() async {
    final session = widget.controller.session!;
    final responses = await Future.wait([
      widget.controller.apiClient.getCustomer(
        businessId: session.businessId!,
        customerId: widget.customerId,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
      ),
      widget.controller.apiClient.listAppointments(
        businessId: session.businessId!,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
      ),
    ]);
    final json = responses[0];
    final customer = Customer.fromJson(
      json['customer'] as Map<String, Object?>,
    );
    final List<WorkItem> activity = [
      ...(json['activity'] as List?)
              ?.whereType<Map<String, Object?>>()
              .map(WorkItem.fromJson)
              .toList() ??
          const <WorkItem>[],
      ...mapListValue(responses[1]['appointments'])
          .where((appointment) => appointment['customerId'] == customer.id)
          .map(
            (appointment) => WorkItem.fromJson({
              ...appointment,
              'type': 'appointment',
              'linkedEntity': {'type': 'appointment', 'id': appointment['id']},
              'actions': appointment['status'] == 'DONE'
                  ? ['open']
                  : ['complete', 'open'],
            }),
          ),
    ];
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
      await _refreshAfterReturn();
      _notifyExternalTaskDataChanged();
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
      await _refreshAfterReturn();
      _notifyExternalTaskDataChanged();
    }
  }

  Future<void> _refreshAfterReturn() async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await _refresh();
  }

  String _itemsStateKey(List<WorkItem> items) {
    return items.map((item) => '${item.id}:${item.status ?? ''}').join('|');
  }

  void _notifyExternalTaskDataChanged() {
    _suppressNextDataChange = true;
    widget.controller.markDataChanged();
    _seenDataVersion = widget.controller.dataInvalidator.revision(
      DataScope.crm,
    );
  }

  Future<bool> _updateCustomerField(
    Customer customer,
    String field,
    String value,
  ) async {
    final session = widget.controller.session!;
    try {
      final json = await widget.controller.apiClient.updateCustomer(
        businessId: session.businessId!,
        customerId: customer.id,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        body: {field: _fieldValue(field, value)},
      );
      if (!mounted) return false;
      final updatedJson = json['customer'];
      if (updatedJson is Map<String, Object?>) {
        _replaceCustomer(Customer.fromJson(updatedJson));
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('הלקוח נשמר')));
      return true;
    } on ApiException catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      return false;
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
      if (item.type == 'reminder') {
        await widget.controller.apiClient.completeReminder(
          businessId: session.businessId!,
          reminderId: item.id,
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
      } else if (item.type == 'appointment') {
        await widget.controller.apiClient.completeAppointment(
          businessId: session.businessId!,
          appointmentId: item.id,
          firebaseUid: session.firebaseUid,
          mockPhoneNumber: session.mockPhoneNumber,
        );
      } else if (item.type == 'note') {
        await widget.controller.apiClient.updateCustomerNote(
          businessId: session.businessId!,
          customerId: widget.customerId,
          noteId: item.id,
          firebaseUid: session.firebaseUid,
          mockPhoneNumber: session.mockPhoneNumber,
          body: const {'status': 'DONE'},
        );
      }
      await _refresh();
      _notifyExternalTaskDataChanged();
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
      await _refresh();
      _notifyExternalTaskDataChanged();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _reopenItem(WorkItem item) async {
    final session = widget.controller.session!;
    try {
      if (item.type == 'reminder') {
        await widget.controller.apiClient.reopenReminder(
          businessId: session.businessId!,
          reminderId: item.id,
          firebaseUid: session.firebaseUid,
          mockPhoneNumber: session.mockPhoneNumber,
        );
      } else if (item.type == 'home_visit') {
        await widget.controller.apiClient.reopenHomeVisit(
          businessId: session.businessId!,
          homeVisitId: item.id,
          firebaseUid: session.firebaseUid,
          mockPhoneNumber: session.mockPhoneNumber,
        );
      } else if (item.type == 'quote') {
        await widget.controller.apiClient.reopenQuote(
          businessId: session.businessId!,
          quoteId: item.id,
          firebaseUid: session.firebaseUid,
          mockPhoneNumber: session.mockPhoneNumber,
        );
      } else if (item.type == 'appointment') {
        await widget.controller.apiClient.reopenAppointment(
          businessId: session.businessId!,
          appointmentId: item.id,
          firebaseUid: session.firebaseUid,
          mockPhoneNumber: session.mockPhoneNumber,
        );
      } else if (item.type == 'note') {
        await widget.controller.apiClient.updateCustomerNote(
          businessId: session.businessId!,
          customerId: widget.customerId,
          noteId: item.id,
          firebaseUid: session.firebaseUid,
          mockPhoneNumber: session.mockPhoneNumber,
          body: const {'status': 'OPEN'},
        );
      }
      await _refresh();
      _notifyExternalTaskDataChanged();
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
      if (item.type == 'reminder') {
        await widget.controller.apiClient.deleteReminder(
          businessId: session.businessId!,
          reminderId: item.id,
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
      } else if (item.type == 'appointment') {
        await widget.controller.apiClient.deleteAppointment(
          businessId: session.businessId!,
          appointmentId: item.id,
          firebaseUid: session.firebaseUid,
          mockPhoneNumber: session.mockPhoneNumber,
        );
      } else if (item.type == 'note') {
        await widget.controller.apiClient.deleteCustomerNote(
          businessId: session.businessId!,
          customerId: widget.customerId,
          noteId: item.id,
          firebaseUid: session.firebaseUid,
          mockPhoneNumber: session.mockPhoneNumber,
        );
      }
      await _refresh();
      _notifyExternalTaskDataChanged();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _deleteCustomer(Customer customer) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('למחוק את הלקוח?'),
        content: Text(
          'הלקוח ${customer.name} יימחק מהרשימה, וגם התזכורות, ביקורי הבית וההצעות שמשויכים אליו יוסרו מהתצוגה.',
        ),
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
    setState(() => _deletingCustomer = true);
    try {
      await widget.controller.apiClient.deleteCustomer(
        businessId: session.businessId!,
        customerId: customer.id,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
      );
      widget.controller.markDataChanged();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _deletingCustomer = false);
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
      final fieldChoices = await _pickMergeFieldChoices(
        source: source,
        target: target,
      );
      if (fieldChoices == null) return;
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
        fieldChoices: fieldChoices,
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

  Future<Map<String, String>?> _pickMergeFieldChoices({
    required Customer source,
    required Customer target,
  }) async {
    final conflicts = _mergeFieldConflicts(source: source, target: target);
    if (conflicts.isEmpty) return const {};

    final choices = {
      for (final conflict in conflicts) conflict.field: 'target',
    };

    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('איזה פרטים לשמור?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: conflicts
                  .map(
                    (conflict) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            conflict.label,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              choices[conflict.field] == 'target'
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                            ),
                            title: Text(conflict.targetValue),
                            subtitle: Text(target.name),
                            onTap: () {
                              setDialogState(
                                () => choices[conflict.field] = 'target',
                              );
                            },
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              choices[conflict.field] == 'source'
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                            ),
                            title: Text(conflict.sourceValue),
                            subtitle: Text(source.name),
                            onTap: () {
                              setDialogState(
                                () => choices[conflict.field] = 'source',
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ביטול'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(choices),
              child: const Text('המשך'),
            ),
          ],
        ),
      ),
    );
  }

  List<_MergeFieldConflict> _mergeFieldConflicts({
    required Customer source,
    required Customer target,
  }) {
    final fields = [
      _MergeFieldConflict.fromValues(
        field: 'name',
        label: 'שם',
        sourceValue: source.name,
        targetValue: target.name,
      ),
      _MergeFieldConflict.fromValues(
        field: 'phone',
        label: 'טלפון',
        sourceValue: source.phone,
        targetValue: target.phone,
      ),
      _MergeFieldConflict.fromValues(
        field: 'email',
        label: 'אימייל',
        sourceValue: source.email,
        targetValue: target.email,
      ),
      _MergeFieldConflict.fromValues(
        field: 'address',
        label: 'כתובת',
        sourceValue: source.address,
        targetValue: target.address,
      ),
    ];
    return fields.whereType<_MergeFieldConflict>().toList();
  }

  String _messageForError(Object? error) {
    if (error is ApiException) return error.message;
    return 'בדוק שהשרת המקומי זמין.';
  }

  bool _canEdit(WorkItem item) {
    return item.type == 'reminder' ||
        item.type == 'home_visit' ||
        item.type == 'appointment' ||
        item.type == 'note' ||
        item.type == 'quote';
  }

  bool _canDelete(WorkItem item) => _canEdit(item);

  bool _canReopen(WorkItem item) =>
      item.isFinished && (_canEdit(item) || item.type == 'note');

  void _replaceCustomer(Customer customer) {
    final currentFuture = _future;
    if (currentFuture == null) return;
    setState(() {
      _future = currentFuture.then(
        (detail) =>
            _CustomerDetail(customer: customer, activity: detail.activity),
      );
    });
  }

  WorkItemKind _kindFor(WorkItem item) {
    return switch (item.type) {
      'home_visit' => WorkItemKind.homeVisit,
      'appointment' => WorkItemKind.appointment,
      'quote' => WorkItemKind.quote,
      'note' => WorkItemKind.note,
      _ => WorkItemKind.reminder,
    };
  }
}

class _CustomerDetail {
  const _CustomerDetail({required this.customer, required this.activity});

  final Customer customer;
  final List<WorkItem> activity;

  List<WorkItem> get openActivity =>
      activity.where((item) => !item.isFinished).toList();

  List<WorkItem> get doneActivity =>
      activity.where((item) => item.isFinished).toList();
}

class _MergeFieldConflict {
  const _MergeFieldConflict({
    required this.field,
    required this.label,
    required this.sourceValue,
    required this.targetValue,
  });

  final String field;
  final String label;
  final String sourceValue;
  final String targetValue;

  static _MergeFieldConflict? fromValues({
    required String field,
    required String label,
    required String? sourceValue,
    required String? targetValue,
  }) {
    final source = sourceValue?.trim();
    final target = targetValue?.trim();
    if (source == null || source.isEmpty || target == null || target.isEmpty) {
      return null;
    }
    if (source == target) return null;
    return _MergeFieldConflict(
      field: field,
      label: label,
      sourceValue: source,
      targetValue: target,
    );
  }
}

class _CustomerHeader extends StatelessWidget {
  const _CustomerHeader({
    required this.customer,
    required this.controller,
    required this.onSaveField,
  });

  final Customer customer;
  final SessionController controller;
  final Future<bool> Function(String field, String value) onSaveField;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _EditableCustomerField(
              label: 'שם',
              value: customer.name,
              field: 'name',
              icon: Icons.person_outline,
              onSave: onSaveField,
            ),
            const SizedBox(height: 8),
            _EditableCustomerField(
              label: 'טלפון',
              value: customer.phone ?? '',
              field: 'phone',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              phonePickerController: controller,
              onSave: onSaveField,
            ),
            const SizedBox(height: 8),
            _EditableCustomerField(
              label: 'אימייל',
              value: customer.email ?? '',
              field: 'email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              onSave: onSaveField,
            ),
            const SizedBox(height: 8),
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
    this.phonePickerController,
  });

  final String label;
  final String value;
  final String field;
  final IconData icon;
  final TextInputType? keyboardType;
  final SessionController? phonePickerController;
  final Future<bool> Function(String field, String value) onSave;

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
      readOnly: !_editing || _saving,
      keyboardType: widget.keyboardType,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        labelText: widget.label,
        prefixIcon: Icon(widget.icon),
        prefixIconConstraints: const BoxConstraints(minWidth: 40),
        suffixIcon: _buildSuffix(),
      ),
      onSubmitted: (_) {
        if (_editing && !_saving) _toggleOrSave();
      },
    );
  }

  Widget _buildSuffix() {
    final editButton = IconButton(
      tooltip: _editing ? 'שמור' : 'ערוך',
      onPressed: _saving ? null : _toggleOrSave,
      icon: _saving
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(_editing ? Icons.check : Icons.edit_outlined),
    );
    final pickerController = widget.phonePickerController;
    if (!_editing || widget.field != 'phone' || pickerController == null) {
      return editButton;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PhoneSourceIconButtons(
          onBusinessCalls: () => _pickPhoneFromCalls(pickerController),
          onContacts: _pickPhoneFromContacts,
        ),
        editButton,
      ],
    );
  }

  Future<void> _pickPhoneFromCalls(SessionController controller) async {
    final phone = await pickPhoneFromBusinessCalls(
      context: context,
      controller: controller,
    );
    if (phone == null || !mounted) return;
    setState(() => _controller.text = phone);
  }

  Future<void> _pickPhoneFromContacts() async {
    final phone = await pickPhoneFromDeviceContacts(context);
    if (phone == null || !mounted) return;
    setState(() => _controller.text = phone);
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
    final saved = await widget.onSave(widget.field, _controller.text);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (saved) _editing = false;
    });
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({
    required this.onReminder,
    required this.onHomeVisit,
    required this.onAppointment,
    required this.onQuote,
    required this.onNote,
  });

  final VoidCallback onReminder;
  final VoidCallback onHomeVisit;
  final VoidCallback onAppointment;
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
          onPressed: onReminder,
          icon: const Icon(Icons.alarm),
          label: const Text('תזכורת'),
        ),
        FilledButton.icon(
          onPressed: onHomeVisit,
          icon: const Icon(Icons.home_repair_service_outlined),
          label: const Text('ביקור'),
        ),
        FilledButton.icon(
          onPressed: onAppointment,
          icon: const Icon(Icons.event_outlined),
          label: const Text('פגישה'),
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

class _ActivitySection extends StatelessWidget {
  const _ActivitySection({
    super.key,
    required this.title,
    required this.count,
    required this.expanded,
    required this.emptyText,
    required this.onToggle,
    required this.children,
  });

  final String title;
  final int count;
  final bool expanded;
  final String emptyText;
  final VoidCallback onToggle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(expanded ? Icons.expand_less : Icons.expand_more),
                const SizedBox(width: 4),
                Text(
                  '$title ($count)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          if (children.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(emptyText),
            )
          else
            ...children,
      ],
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.item,
    this.onOpen,
    this.onComplete,
    this.onMarkPaid,
    this.onReopen,
    this.onDelete,
  });

  final WorkItem item;
  final VoidCallback? onOpen;
  final VoidCallback? onComplete;
  final VoidCallback? onMarkPaid;
  final VoidCallback? onReopen;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(8, 2, 8, 6),
        child: Column(
          children: [
            ListTile(
              dense: true,
              visualDensity: const VisualDensity(vertical: -2),
              contentPadding: const EdgeInsetsDirectional.only(
                start: 4,
                end: 4,
              ),
              onTap: onOpen,
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: item.isUrgent
                    ? Theme.of(context).colorScheme.errorContainer
                    : Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  _icon,
                  color: item.isUrgent
                      ? Theme.of(context).colorScheme.onErrorContainer
                      : Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              title: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: _ActivitySubtitle(
                typeLabel: _label,
                dueAt: item.dueAt,
                description: item.description,
              ),
            ),
            if (onComplete != null ||
                onMarkPaid != null ||
                onReopen != null ||
                onDelete != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Wrap(
                  spacing: 4,
                  children: [
                    if (onComplete != null)
                      TextButton.icon(
                        onPressed: onComplete,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.check),
                        label: const Text('בוצע'),
                      ),
                    if (onMarkPaid != null)
                      TextButton.icon(
                        onPressed: onMarkPaid,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.payments_outlined),
                        label: const Text('שולם'),
                      ),
                    if (onReopen != null)
                      TextButton.icon(
                        onPressed: onReopen,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.refresh),
                        label: const Text('פתח מחדש'),
                      ),
                    if (onDelete != null)
                      TextButton.icon(
                        onPressed: onDelete,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
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

  IconData get _icon {
    return switch (item.type) {
      'reminder' => Icons.alarm,
      'home_visit' => Icons.home_repair_service_outlined,
      'appointment' => Icons.event_outlined,
      'quote' => Icons.request_quote_outlined,
      'note' => Icons.note_outlined,
      _ => Icons.task_alt,
    };
  }

  String get _label {
    return switch (item.type) {
      'reminder' => 'תזכורת',
      'home_visit' => 'ביקור בית',
      'appointment' => 'פגישה',
      'quote' => 'הצעת מחיר',
      'note' => 'הערה',
      _ => item.type,
    };
  }
}

class _ActivitySubtitle extends StatelessWidget {
  const _ActivitySubtitle({
    required this.typeLabel,
    required this.dueAt,
    required this.description,
  });

  final String typeLabel;
  final DateTime? dueAt;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    return Wrap(
      spacing: 4,
      runSpacing: 1,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(typeLabel, style: style),
        if (dueAt != null) ...[
          Text('·', style: style),
          Text(formatDateTime(dueAt), style: style),
        ],
        if (description != null) ...[
          Text('·', style: style),
          Text(
            description!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ],
      ],
    );
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
