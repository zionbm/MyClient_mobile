import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/api_client.dart';
import '../../core/state/data_invalidator.dart';
import '../../data/repositories/work_item_repository.dart';
import '../../models/customer.dart';
import '../../models/work_item.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_formatting.dart';
import '../auth/session_controller.dart';
import '../work_items/work_item_form_screen.dart';
import 'customer_picker_screen.dart';
import 'customer_form_screen.dart';

part 'customer_detail_components.dart';

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
  bool _openExpanded = true;
  bool _doneExpanded = false;
  int _activityRevision = 0;
  late int _seenDataVersion;
  bool _suppressNextDataChange = false;
  bool _deletingCustomer = false;
  WorkItemType? _activityFilter;

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
    widget.controller.dataInvalidator.removeListener(_handleDataChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_CustomerDetail>(
      future: _future,
      builder: (context, snapshot) {
        return Scaffold(
          body: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                if (snapshot.connectionState == ConnectionState.waiting)
                  const SizedBox(
                    height: 640,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (snapshot.hasError)
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _InfoCard(
                        icon: Icons.cloud_off_outlined,
                        title: 'לא הצלחנו לטעון לקוח',
                        body: _messageForError(snapshot.error),
                      ),
                    ),
                  )
                else if (snapshot.hasData) ...[
                  _CustomerDetailHero(
                    customer: snapshot.data!.customer,
                    onBack: () => Navigator.of(context).pop(),
                    onCall: snapshot.data!.customer.phone == null
                        ? null
                        : () => _launchPhone(snapshot.data!.customer.phone!),
                    onWhatsApp: snapshot.data!.customer.phone == null
                        ? null
                        : () => _launchWhatsApp(snapshot.data!.customer.phone!),
                    onEdit: () => _editCustomer(snapshot.data!.customer),
                    onMerge: _deletingCustomer
                        ? null
                        : () => _merge(snapshot.data!.customer),
                    onDelete: _deletingCustomer
                        ? null
                        : () => _deleteCustomer(snapshot.data!.customer),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _CustomerHeader(customer: snapshot.data!.customer),
                        const SizedBox(height: 18),
                        Text(
                          'פעולה חדשה',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 10),
                        _ActionGrid(
                          onReminder: () => _create(
                            WorkItemKind.reminder,
                            snapshot.data!.customer,
                          ),
                          onHomeVisit: () => _create(
                            WorkItemKind.homeVisit,
                            snapshot.data!.customer,
                          ),
                          onAppointment: () => _create(
                            WorkItemKind.appointment,
                            snapshot.data!.customer,
                          ),
                          onQuote: () => _create(
                            WorkItemKind.quote,
                            snapshot.data!.customer,
                          ),
                          onNote: () => _create(
                            WorkItemKind.note,
                            snapshot.data!.customer,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Text(
                              'פעילות',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const Spacer(),
                            OutlinedButton.icon(
                              onPressed: _pickActivityFilter,
                              icon: const Icon(Icons.filter_list, size: 20),
                              label: Text(_activityFilterLabel),
                            ),
                          ],
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
                            title: 'פתוחות',
                            count: _filteredActivity(
                              snapshot.data!.openActivity,
                            ).length,
                            expanded: _openExpanded,
                            emptyText: 'אין משימות פתוחות ללקוח הזה',
                            onToggle: () =>
                                setState(() => _openExpanded = !_openExpanded),
                            children: _filteredActivity(
                              snapshot.data!.openActivity,
                            ).map((item) => _buildActivityCard(item)).toList(),
                          ),
                          const SizedBox(height: 12),
                          _ActivitySection(
                            key: ValueKey(
                              'customer-done-$_activityRevision-${_itemsStateKey(snapshot.data!.doneActivity)}',
                            ),
                            title: 'הושלמו',
                            count: _filteredActivity(
                              snapshot.data!.doneActivity,
                            ).length,
                            expanded: _doneExpanded,
                            emptyText: 'אין משימות שבוצעו ללקוח הזה',
                            onToggle: () =>
                                setState(() => _doneExpanded = !_doneExpanded),
                            children: _filteredActivity(
                              snapshot.data!.doneActivity,
                            ).map((item) => _buildActivityCard(item)).toList(),
                          ),
                        ],
                      ],
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

  Future<void> _editCustomer(Customer customer) async {
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
      await _refresh();
    }
  }

  Future<void> _launchPhone(String phone) async {
    if (!await launchUrl(Uri(scheme: 'tel', path: phone))) {
      _showMessage('לא ניתן לפתוח שיחה');
    }
  }

  Future<void> _launchWhatsApp(String phone) async {
    final normalized = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (!await launchUrl(
      Uri.parse('https://wa.me/$normalized'),
      mode: LaunchMode.externalApplication,
    )) {
      _showMessage('לא ניתן לפתוח WhatsApp');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  List<WorkItem> _filteredActivity(List<WorkItem> items) {
    final filter = _activityFilter;
    if (filter == null) return items;
    return items.where((item) => item.type == filter).toList();
  }

  String get _activityFilterLabel => switch (_activityFilter) {
    WorkItemType.reminder => 'תזכורות',
    WorkItemType.homeVisit => 'ביקורים',
    WorkItemType.appointment => 'פגישות',
    WorkItemType.quote => 'הצעות',
    WorkItemType.note => 'הערות',
    _ => 'סינון',
  };

  Future<void> _pickActivityFilter() async {
    final selected = await showModalBottomSheet<Object?>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'סינון פעילות',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
            ListTile(
              leading: Icon(
                _activityFilter == null
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              title: const Text('הכול'),
              onTap: () => Navigator.of(context).pop('all'),
            ),
            for (final option in const [
              (WorkItemType.reminder, Icons.alarm_outlined, 'תזכורות'),
              (WorkItemType.homeVisit, Icons.home_outlined, 'ביקורים'),
              (WorkItemType.appointment, Icons.event_outlined, 'פגישות'),
              (WorkItemType.quote, Icons.request_quote_outlined, 'הצעות'),
              (WorkItemType.note, Icons.note_outlined, 'הערות'),
            ])
              ListTile(
                leading: Icon(option.$2),
                title: Text(option.$3),
                trailing: _activityFilter == option.$1
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.of(context).pop(option.$1),
              ),
          ],
        ),
      ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _activityFilter = selected == 'all' ? null : selected as WorkItemType;
    });
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
    final json = await widget.controller.apiClient.customers.getDetail(
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

  Future<void> _completeItem(WorkItem item) async {
    final session = widget.controller.session!;
    try {
      final type = CrmWorkItemTypeParsing.fromApiType(item.type);
      if (type != null) {
        await widget.controller.apiClient.workItems.complete(
          type: type,
          businessId: session.businessId!,
          itemId: item.id,
          firebaseUid: session.firebaseUid,
          mockPhoneNumber: session.mockPhoneNumber,
        );
      } else if (item.type == WorkItemType.note) {
        await widget.controller.apiClient.notes.update(
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
      await widget.controller.apiClient.workItems.complete(
        type: CrmWorkItemType.quote,
        businessId: session.businessId!,
        itemId: item.id,
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
      final type = CrmWorkItemTypeParsing.fromApiType(item.type);
      if (type != null) {
        await widget.controller.apiClient.workItems.reopen(
          type: type,
          businessId: session.businessId!,
          itemId: item.id,
          firebaseUid: session.firebaseUid,
          mockPhoneNumber: session.mockPhoneNumber,
        );
      } else if (item.type == WorkItemType.note) {
        await widget.controller.apiClient.notes.update(
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
      final type = CrmWorkItemTypeParsing.fromApiType(item.type);
      if (type != null) {
        await widget.controller.apiClient.workItems.delete(
          type: type,
          businessId: session.businessId!,
          itemId: item.id,
          firebaseUid: session.firebaseUid,
          mockPhoneNumber: session.mockPhoneNumber,
        );
      } else if (item.type == WorkItemType.note) {
        await widget.controller.apiClient.notes.delete(
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
      await widget.controller.apiClient.customers.delete(
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
      final target = await Navigator.of(context).push<Customer>(
        MaterialPageRoute(
          builder: (_) => CustomerPickerScreen(controller: widget.controller),
        ),
      );
      if (target == null) return;
      if (target.id == source.id) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('יש לבחור לקוח אחר כיעד למיזוג')),
        );
        return;
      }
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
      await widget.controller.apiClient.customers.merge(
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
    return item.type == WorkItemType.reminder ||
        item.type == WorkItemType.homeVisit ||
        item.type == WorkItemType.appointment ||
        item.type == WorkItemType.note ||
        item.type == WorkItemType.quote;
  }

  bool _canDelete(WorkItem item) => _canEdit(item);

  bool _canReopen(WorkItem item) =>
      item.isFinished && (_canEdit(item) || item.type == WorkItemType.note);

  WorkItemKind _kindFor(WorkItem item) {
    return switch (item.type) {
      WorkItemType.homeVisit => WorkItemKind.homeVisit,
      WorkItemType.appointment => WorkItemKind.appointment,
      WorkItemType.quote => WorkItemKind.quote,
      WorkItemType.note => WorkItemKind.note,
      _ => WorkItemKind.reminder,
    };
  }
}
