import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../core/network/idempotency_key.dart';
import '../../core/paging/paged_list_view.dart';
import '../../core/paging/paging_controller.dart';
import '../../core/state/data_invalidator.dart';
import '../../models/page.dart' as pagination;
import '../../models/v2_customer.dart';
import '../../models/v2_task.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_confirmation_dialog.dart';
import '../auth/session_controller.dart';

class V2CustomersScreen extends StatefulWidget {
  const V2CustomersScreen({super.key, required this.controller});

  final SessionController controller;

  @override
  State<V2CustomersScreen> createState() => _V2CustomersScreenState();
}

class _V2CustomersScreenState extends State<V2CustomersScreen> {
  late final PagingController<V2Customer> _paging;
  Future<List<V2Customer>>? _future;

  @override
  void initState() {
    super.initState();
    _paging = PagingController<V2Customer>(
      _loadPage,
      itemKey: (customer) => customer.id,
    );
    _refresh();
  }

  @override
  void dispose() {
    _paging.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _V2CustomersHero(
            businessName: widget.controller.session?.businessName,
            onCreateCustomer: _createCustomer,
            onCreateTask: () => _createTask(),
          ),
          Expanded(
            child: PagedListView<V2Customer>(
              future: _future,
              onRefresh: _refresh,
              canLoadMore: _paging.canLoadMore,
              onLoadMore: _loadMore,
              loadMoreLabel: 'טען עוד לקוחות',
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              empty: const _V2StateCard(
                icon: Icons.people_alt_outlined,
                title: 'עדיין אין לקוחות',
                body: 'אפשר ליצור לקוח בשם בלבד ולהשלים פרטים בהמשך.',
              ),
              errorBuilder: (_, error) => _V2StateCard(
                icon: Icons.cloud_off_outlined,
                title: 'לא הצלחנו לטעון לקוחות',
                body: _errorMessage(error),
              ),
              itemBuilder: (_, customer) => _V2CustomerCard(
                customer: customer,
                onTap: () => _openCustomer(customer.id),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<pagination.Page<V2Customer>> _loadPage(String? cursor) {
    final session = widget.controller.session!;
    return widget.controller.apiClient.v2Customers.list(
      businessId: session.businessId!,
      firebaseUid: session.firebaseUid,
      mockPhoneNumber: session.mockPhoneNumber,
      cursor: cursor,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _paging.refresh().then((_) => _paging.items);
    });
    await _future;
  }

  Future<void> _loadMore() async {
    await _paging.loadMore();
    if (mounted) setState(() => _future = Future.value(_paging.items));
  }

  Future<void> _createCustomer() async {
    final customer = await showModalBottomSheet<V2Customer>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => V2CustomerFormScreen(controller: widget.controller),
    );
    if (customer == null || !mounted) return;
    widget.controller.markDataChanged({DataScope.crm});
    await _refresh();
    if (!mounted) return;
    await _openCustomer(customer.id);
  }

  Future<void> _createTask() async {
    final task = await showModalBottomSheet<V2Task>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _V2TaskForm(controller: widget.controller),
    );
    if (task != null) widget.controller.markDataChanged({DataScope.crm});
  }

  Future<void> _openCustomer(String customerId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => V2CustomerDetailScreen(
          controller: widget.controller,
          customerId: customerId,
        ),
      ),
    );
    await _refresh();
  }
}

class V2CustomerDetailScreen extends StatefulWidget {
  const V2CustomerDetailScreen({
    super.key,
    required this.controller,
    required this.customerId,
  });

  final SessionController controller;
  final String customerId;

  @override
  State<V2CustomerDetailScreen> createState() => _V2CustomerDetailScreenState();
}

class _V2CustomerDetailScreenState extends State<V2CustomerDetailScreen> {
  Future<V2Customer>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('פרטי לקוח'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'merge') _mergeCustomer();
              if (value == 'delete') _deleteCustomer();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'merge', child: Text('מיזוג עם לקוח אחר')),
              PopupMenuItem(value: 'delete', child: Text('מחיקת לקוח')),
            ],
          ),
        ],
      ),
      body: FutureBuilder<V2Customer>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return Center(
              child: _V2StateCard(
                icon: Icons.cloud_off_outlined,
                title: 'לא הצלחנו לטעון את הלקוח',
                body: _errorMessage(snapshot.error),
              ),
            );
          }
          return _content(snapshot.data!);
        },
      ),
    );
  }

  Widget _content(V2Customer customer) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: const Color(0xFFDDEEE9),
                        child: Text(
                          customer.name.characters.first,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          customer.name,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      IconButton(
                        tooltip: 'עריכת לקוח',
                        onPressed: () => _editCustomer(customer),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ],
                  ),
                  if (customer.email != null) ...[
                    const SizedBox(height: 10),
                    Text(customer.email!),
                  ],
                  if (customer.generalNotes != null) ...[
                    const SizedBox(height: 8),
                    Text(customer.generalNotes!),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _showTimeline,
            icon: const Icon(Icons.timeline_outlined),
            label: const Text('ציר הזמן של הלקוח'),
          ),
          const SizedBox(height: 14),
          _section(
            title: 'מספרי טלפון',
            onAdd: _addPhone,
            emptyText: 'אין עדיין מספר טלפון',
            children: customer.phones
                .map(
                  (phone) => ListTile(
                    leading: Icon(
                      phone.isPrimary
                          ? Icons.star_rounded
                          : Icons.phone_outlined,
                      color: phone.isPrimary ? AppColors.accent : null,
                    ),
                    title: Text(
                      phone.rawPhone,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.right,
                    ),
                    subtitle: phone.label == null ? null : Text(phone.label!),
                    trailing: PopupMenuButton<String>(
                      onSelected: (action) => action == 'edit'
                          ? _editPhone(phone)
                          : _deletePhone(phone),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('עריכה')),
                        PopupMenuItem(value: 'delete', child: Text('מחיקה')),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          _section(
            title: 'כתובות שירות',
            onAdd: _addAddress,
            emptyText: 'אין עדיין כתובת שירות',
            children: customer.addresses
                .map(
                  (address) => ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text(address.addressText),
                    subtitle: address.label == null
                        ? null
                        : Text(address.label!),
                    trailing: PopupMenuButton<String>(
                      onSelected: (action) => action == 'edit'
                          ? _editAddress(address)
                          : _deleteAddress(address),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('עריכה')),
                        PopupMenuItem(value: 'delete', child: Text('מחיקה')),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          _section(
            title: 'משימות',
            onAdd: () => _addTask(customer.id),
            emptyText: 'אין משימות ללקוח הזה',
            children: customer.tasks
                .map(
                  (task) => _V2TaskTile(
                    task: task,
                    onAction: (action) => _taskAction(task, action),
                    onEdit: () => _editTask(task),
                    onDelete: () => _deleteTask(task),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Future<void> _showTimeline() async {
    final session = widget.controller.session!;
    try {
      final items = await widget.controller.apiClient.v2Customers.timeline(
        businessId: session.businessId!,
        customerId: widget.customerId,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
      );
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        builder: (_) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('ציר הזמן', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            if (items.isEmpty) const Text('אין עדיין פעילות ללקוח הזה'),
            ...items.map((entry) {
              final type = entry['type'] as String? ?? 'activity';
              final item = entry['item'] as Map<String, Object?>? ?? const {};
              final title =
                  item['title'] as String? ??
                  item['body'] as String? ??
                  'פעילות';
              return ListTile(
                leading: Icon(switch (type) {
                  'task' => Icons.task_alt_outlined,
                  'job' => Icons.work_outline,
                  'visit' => Icons.home_work_outlined,
                  _ => Icons.notes_outlined,
                }),
                title: Text(title),
                subtitle: Text(switch (type) {
                  'task' => 'משימה',
                  'job' => 'עבודה',
                  'visit' => 'ביקור',
                  _ => 'הערה',
                }),
              );
            }),
          ],
        ),
      );
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Widget _section({
    required String title,
    required VoidCallback onAdd,
    required String emptyText,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                  label: const Text('הוספה'),
                ),
              ],
            ),
            if (children.isEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  emptyText,
                  style: const TextStyle(color: AppColors.muted),
                ),
              )
            else
              ...children,
          ],
        ),
      ),
    );
  }

  Future<void> _load() async {
    final session = widget.controller.session!;
    setState(() {
      _future = widget.controller.apiClient.v2Customers.get(
        businessId: session.businessId!,
        customerId: widget.customerId,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
      );
    });
    await _future;
  }

  Future<void> _editCustomer(V2Customer customer) async {
    final updated = await showModalBottomSheet<V2Customer>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => V2CustomerFormScreen(
        controller: widget.controller,
        customer: customer,
      ),
    );
    if (updated != null) await _load();
  }

  Future<void> _addPhone() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _V2PhoneForm(
        controller: widget.controller,
        customerId: widget.customerId,
      ),
    );
    if (added == true) await _load();
  }

  Future<void> _editPhone(V2CustomerPhone phone) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _V2PhoneForm(
        controller: widget.controller,
        customerId: widget.customerId,
        phone: phone,
      ),
    );
    if (updated == true) await _load();
  }

  Future<void> _deletePhone(V2CustomerPhone phone) async {
    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: 'למחוק את מספר הטלפון?',
      body: phone.rawPhone,
      confirmLabel: 'מחיקה',
      destructive: true,
      icon: Icons.delete_outline,
    );
    if (confirmed != true || !mounted) return;
    final session = widget.controller.session!;
    try {
      await widget.controller.apiClient.v2Customers.deletePhone(
        businessId: session.businessId!,
        customerId: widget.customerId,
        phoneId: phone.id,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        idempotencyKey: IdempotencyKey.create('customer_phone_delete'),
      );
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
      }
    }
  }

  Future<void> _addAddress() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _V2AddressForm(
        controller: widget.controller,
        customerId: widget.customerId,
      ),
    );
    if (added == true) await _load();
  }

  Future<void> _editAddress(V2ServiceAddress address) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _V2AddressForm(
        controller: widget.controller,
        customerId: widget.customerId,
        address: address,
      ),
    );
    if (updated == true) await _load();
  }

  Future<void> _deleteAddress(V2ServiceAddress address) async {
    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: 'למחוק את כתובת השירות?',
      body: address.addressText,
      confirmLabel: 'מחיקה',
      destructive: true,
      icon: Icons.delete_outline,
    );
    if (confirmed != true || !mounted) return;
    final session = widget.controller.session!;
    try {
      await widget.controller.apiClient.v2Customers.deleteAddress(
        businessId: session.businessId!,
        customerId: widget.customerId,
        addressId: address.id,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        idempotencyKey: IdempotencyKey.create('service_address_delete'),
      );
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
      }
    }
  }

  Future<void> _addTask(String customerId) async {
    final task = await showModalBottomSheet<V2Task>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          _V2TaskForm(controller: widget.controller, customerId: customerId),
    );
    if (task != null) await _load();
  }

  Future<void> _editTask(V2Task task) async {
    final updated = await showModalBottomSheet<V2Task>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _V2TaskForm(
        controller: widget.controller,
        customerId: widget.customerId,
        task: task,
      ),
    );
    if (updated != null) await _load();
  }

  Future<void> _deleteTask(V2Task task) async {
    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: 'למחוק את המשימה?',
      body: task.title,
      confirmLabel: 'מחיקה',
      destructive: true,
      icon: Icons.delete_outline,
    );
    if (confirmed != true || !mounted) return;
    final session = widget.controller.session!;
    try {
      await widget.controller.apiClient.v2Tasks.delete(
        businessId: session.businessId!,
        taskId: task.id,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        idempotencyKey: IdempotencyKey.create('task_delete'),
      );
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
      }
    }
  }

  Future<void> _taskAction(V2Task task, String action) async {
    final session = widget.controller.session!;
    try {
      await widget.controller.apiClient.v2Tasks.lifecycle(
        businessId: session.businessId!,
        taskId: task.id,
        action: action,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        idempotencyKey: IdempotencyKey.create('task_$action'),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
    }
  }

  Future<void> _deleteCustomer() async {
    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: 'למחוק את הלקוח?',
      body:
          'הלקוח והפעילות הקשורה אליו יימחקו מתצוגת האפליקציה. הפעולה אינה ניתנת לשחזור באפליקציה.',
      confirmLabel: 'מחיקה',
      destructive: true,
      icon: Icons.delete_outline,
    );
    if (confirmed != true || !mounted) return;
    final session = widget.controller.session!;
    try {
      await widget.controller.apiClient.v2Customers.delete(
        businessId: session.businessId!,
        customerId: widget.customerId,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        idempotencyKey: IdempotencyKey.create('customer_delete'),
      );
      widget.controller.markDataChanged({DataScope.crm});
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
    }
  }

  Future<void> _mergeCustomer() async {
    final session = widget.controller.session!;
    try {
      final page = await widget.controller.apiClient.v2Customers.list(
        businessId: session.businessId!,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        limit: 100,
      );
      if (!mounted) return;
      final candidates = page.items
          .where((customer) => customer.id != widget.customerId)
          .toList();
      final target = await showModalBottomSheet<V2Customer>(
        context: context,
        useSafeArea: true,
        builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'בחירת הלקוח שיישאר',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              for (final customer in candidates)
                ListTile(
                  title: Text(customer.name),
                  subtitle: customer.primaryPhone == null
                      ? null
                      : Text(customer.primaryPhone!.rawPhone),
                  onTap: () => Navigator.of(context).pop(customer),
                ),
            ],
          ),
        ),
      );
      if (target == null || !mounted) return;
      final confirmed = await showAppConfirmationDialog(
        context: context,
        title: 'למזג את הלקוחות?',
        body:
            'הפרטים והפעילות יעברו אל ${target.name}, והלקוח הנוכחי יסומן כממוזג.',
        confirmLabel: 'מיזוג',
        icon: Icons.merge,
      );
      if (confirmed != true) return;
      await widget.controller.apiClient.v2Customers.merge(
        businessId: session.businessId!,
        sourceCustomerId: widget.customerId,
        targetCustomerId: target.id,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        idempotencyKey: IdempotencyKey.create('customer_merge'),
      );
      widget.controller.markDataChanged({DataScope.crm});
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
    }
  }
}

class _V2CustomersHero extends StatelessWidget {
  const _V2CustomersHero({
    required this.businessName,
    required this.onCreateCustomer,
    required this.onCreateTask,
  });

  final String? businessName;
  final VoidCallback onCreateCustomer;
  final VoidCallback onCreateTask;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 54, 20, 22),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            businessName ?? 'העסק שלי',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 4),
          const Text(
            'לקוחות ומשימות',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: onCreateCustomer,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                ),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('לקוח חדש'),
              ),
              OutlinedButton.icon(
                onPressed: onCreateTask,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                ),
                icon: const Icon(Icons.add_task),
                label: const Text('משימה כללית'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _V2CustomerCard extends StatelessWidget {
  const _V2CustomerCard({required this.customer, required this.onTap});
  final V2Customer customer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final phone = customer.primaryPhone;
    final address = customer.addresses.isEmpty
        ? null
        : customer.addresses.first;
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFDDEEE9),
          child: Text(
            customer.name.characters.first,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        title: Text(
          customer.name,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          phone?.rawPhone ?? address?.addressText ?? 'אפשר להשלים פרטים בהמשך',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_left),
      ),
    );
  }
}

class _V2TaskTile extends StatelessWidget {
  const _V2TaskTile({
    required this.task,
    required this.onAction,
    required this.onEdit,
    required this.onDelete,
  });
  final V2Task task;
  final ValueChanged<String> onAction;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final open = task.status == V2TaskStatus.open;
    return ListTile(
      leading: Icon(
        open ? Icons.radio_button_unchecked : Icons.task_alt,
        color: open ? AppColors.accent : AppColors.primary,
      ),
      title: Text(task.title),
      subtitle: task.dueAt == null
          ? null
          : Text(
              MaterialLocalizations.of(context).formatMediumDate(task.dueAt!),
            ),
      trailing: PopupMenuButton<String>(
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'edit', child: Text('עריכה')),
          if (open) ...const [
            PopupMenuItem(value: 'complete', child: Text('השלמה')),
            PopupMenuItem(value: 'cancel', child: Text('ביטול')),
          ] else
            const PopupMenuItem(value: 'reopen', child: Text('פתיחה מחדש')),
          const PopupMenuItem(value: 'delete', child: Text('מחיקה')),
        ],
        onSelected: (action) {
          if (action == 'edit') {
            onEdit();
          } else if (action == 'delete') {
            onDelete();
          } else {
            onAction(action);
          }
        },
      ),
    );
  }
}

class V2CustomerFormScreen extends StatefulWidget {
  const V2CustomerFormScreen({
    super.key,
    required this.controller,
    this.customer,
    this.initialName,
    this.initialPhone,
  });
  final SessionController controller;
  final V2Customer? customer;
  final String? initialName;
  final String? initialPhone;

  @override
  State<V2CustomerFormScreen> createState() => _V2CustomerFormState();
}

class _V2CustomerFormState extends State<V2CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _notes;
  late final String _idempotencyKey;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: widget.customer?.name ?? widget.initialName ?? '',
    );
    _email = TextEditingController(text: widget.customer?.email ?? '');
    _notes = TextEditingController(text: widget.customer?.generalNotes ?? '');
    _idempotencyKey = IdempotencyKey.create('customer_form');
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _V2FormShell(
      title: widget.customer == null ? 'לקוח חדש' : 'עריכת לקוח',
      saving: _saving,
      error: _error,
      onSave: _save,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'שם הלקוח *'),
              validator: (value) =>
                  value?.trim().isEmpty ?? true ? 'צריך להזין שם לקוח' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'אימייל'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'הערות כלליות'),
              minLines: 2,
              maxLines: 4,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final session = widget.controller.session!;
    final body = <String, Object?>{
      'name': _name.text.trim(),
      if (_email.text.trim().isNotEmpty) 'email': _email.text.trim(),
      if (_notes.text.trim().isNotEmpty) 'generalNotes': _notes.text.trim(),
      if (widget.customer != null) 'version': widget.customer!.version,
    };
    try {
      final customer = widget.customer == null
          ? await widget.controller.apiClient.v2Customers.create(
              businessId: session.businessId!,
              firebaseUid: session.firebaseUid,
              mockPhoneNumber: session.mockPhoneNumber,
              idempotencyKey: _idempotencyKey,
              body: body,
            )
          : await widget.controller.apiClient.v2Customers.update(
              businessId: session.businessId!,
              customerId: widget.customer!.id,
              firebaseUid: session.firebaseUid,
              mockPhoneNumber: session.mockPhoneNumber,
              idempotencyKey: _idempotencyKey,
              body: body,
            );
      if (widget.customer == null &&
          widget.initialPhone?.trim().isNotEmpty == true) {
        await widget.controller.apiClient.v2Customers.addPhone(
          businessId: session.businessId!,
          customerId: customer.id,
          firebaseUid: session.firebaseUid,
          mockPhoneNumber: session.mockPhoneNumber,
          idempotencyKey: IdempotencyKey.create('customer_initial_phone'),
          body: {'phone': widget.initialPhone!.trim(), 'isPrimary': true},
        );
      }
      if (mounted) Navigator.of(context).pop(customer);
    } catch (error) {
      if (mounted) setState(() => _error = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _V2PhoneForm extends StatefulWidget {
  const _V2PhoneForm({
    required this.controller,
    required this.customerId,
    this.phone,
  });
  final SessionController controller;
  final String customerId;
  final V2CustomerPhone? phone;

  @override
  State<_V2PhoneForm> createState() => _V2PhoneFormState();
}

class _V2PhoneFormState extends State<_V2PhoneForm> {
  final _phone = TextEditingController();
  final _label = TextEditingController();
  final _key = IdempotencyKey.create('customer_phone');
  bool _primary = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final phone = widget.phone;
    if (phone != null) {
      _phone.text = phone.rawPhone;
      _label.text = phone.label ?? '';
      _primary = phone.isPrimary;
    }
  }

  @override
  void dispose() {
    _phone.dispose();
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _V2FormShell(
    title: widget.phone == null ? 'הוספת מספר טלפון' : 'עריכת מספר טלפון',
    saving: _saving,
    error: _error,
    onSave: _save,
    child: Column(
      children: [
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.right,
          decoration: const InputDecoration(labelText: 'מספר טלפון *'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _label,
          decoration: const InputDecoration(labelText: 'תווית, למשל נייד'),
        ),
        SwitchListTile(
          value: _primary,
          onChanged: (value) => setState(() => _primary = value),
          title: const Text('מספר ראשי'),
          contentPadding: EdgeInsets.zero,
        ),
      ],
    ),
  );

  Future<void> _save() async {
    if (_phone.text.trim().isEmpty) {
      setState(() => _error = 'צריך להזין מספר טלפון');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final session = widget.controller.session!;
    try {
      final body = <String, Object?>{
        'phone': _phone.text.trim(),
        'label': _label.text.trim().isEmpty ? null : _label.text.trim(),
        'isPrimary': _primary,
      };
      if (widget.phone == null) {
        await widget.controller.apiClient.v2Customers.addPhone(
          businessId: session.businessId!,
          customerId: widget.customerId,
          firebaseUid: session.firebaseUid,
          mockPhoneNumber: session.mockPhoneNumber,
          idempotencyKey: _key,
          body: body,
        );
      } else {
        await widget.controller.apiClient.v2Customers.updatePhone(
          businessId: session.businessId!,
          customerId: widget.customerId,
          phoneId: widget.phone!.id,
          firebaseUid: session.firebaseUid,
          mockPhoneNumber: session.mockPhoneNumber,
          idempotencyKey: _key,
          body: body,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _V2AddressForm extends StatefulWidget {
  const _V2AddressForm({
    required this.controller,
    required this.customerId,
    this.address,
  });
  final SessionController controller;
  final String customerId;
  final V2ServiceAddress? address;

  @override
  State<_V2AddressForm> createState() => _V2AddressFormState();
}

class _V2AddressFormState extends State<_V2AddressForm> {
  final _address = TextEditingController();
  final _label = TextEditingController();
  final _key = IdempotencyKey.create('service_address');
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final address = widget.address;
    if (address != null) {
      _address.text = address.addressText;
      _label.text = address.label ?? '';
    }
  }

  @override
  void dispose() {
    _address.dispose();
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _V2FormShell(
    title: widget.address == null ? 'הוספת כתובת שירות' : 'עריכת כתובת שירות',
    saving: _saving,
    error: _error,
    onSave: _save,
    child: Column(
      children: [
        TextField(
          controller: _address,
          decoration: const InputDecoration(labelText: 'כתובת *'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _label,
          decoration: const InputDecoration(
            labelText: 'תווית, למשל בית או משרד',
          ),
        ),
      ],
    ),
  );

  Future<void> _save() async {
    if (_address.text.trim().isEmpty) {
      setState(() => _error = 'צריך להזין כתובת');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final session = widget.controller.session!;
    try {
      final body = <String, Object?>{
        'addressText': _address.text.trim(),
        'label': _label.text.trim().isEmpty ? null : _label.text.trim(),
      };
      if (widget.address == null) {
        await widget.controller.apiClient.v2Customers.addAddress(
          businessId: session.businessId!,
          customerId: widget.customerId,
          firebaseUid: session.firebaseUid,
          mockPhoneNumber: session.mockPhoneNumber,
          idempotencyKey: _key,
          body: body,
        );
      } else {
        await widget.controller.apiClient.v2Customers.updateAddress(
          businessId: session.businessId!,
          customerId: widget.customerId,
          addressId: widget.address!.id,
          firebaseUid: session.firebaseUid,
          mockPhoneNumber: session.mockPhoneNumber,
          idempotencyKey: _key,
          body: body,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _V2TaskForm extends StatefulWidget {
  const _V2TaskForm({required this.controller, this.customerId, this.task});
  final SessionController controller;
  final String? customerId;
  final V2Task? task;

  @override
  State<_V2TaskForm> createState() => _V2TaskFormState();
}

class _V2TaskFormState extends State<_V2TaskForm> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _key = IdempotencyKey.create('task_create');
  DateTime? _dueAt;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    if (task != null) {
      _title.text = task.title;
      _description.text = task.description ?? '';
      _dueAt = task.dueAt;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _V2FormShell(
    title: widget.task != null
        ? 'עריכת משימה'
        : widget.customerId == null
        ? 'משימה כללית'
        : 'משימה ללקוח',
    saving: _saving,
    error: _error,
    onSave: _save,
    child: Column(
      children: [
        TextField(
          controller: _title,
          decoration: const InputDecoration(labelText: 'מה צריך לעשות? *'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _description,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'פרטים נוספים'),
        ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.notifications_active_outlined),
          title: Text(
            _dueAt == null
                ? 'ללא תזכורת'
                : MaterialLocalizations.of(
                    context,
                  ).formatFullDate(_dueAt!.toLocal()),
          ),
          subtitle: _dueAt == null
              ? const Text('אפשר להוסיף תזכורת גם בהמשך')
              : Text(
                  MaterialLocalizations.of(
                    context,
                  ).formatTimeOfDay(TimeOfDay.fromDateTime(_dueAt!.toLocal())),
                ),
          trailing: _dueAt == null
              ? const Icon(Icons.add)
              : IconButton(
                  onPressed: () => setState(() => _dueAt = null),
                  icon: const Icon(Icons.close),
                ),
          onTap: _pickDueAt,
        ),
      ],
    ),
  );

  Future<void> _pickDueAt() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 3),
      initialDate: _dueAt?.toLocal() ?? now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _dueAt == null
          ? const TimeOfDay(hour: 10, minute: 0)
          : TimeOfDay.fromDateTime(_dueAt!.toLocal()),
    );
    if (time == null) return;
    setState(() {
      _dueAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'צריך לכתוב את המשימה');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final session = widget.controller.session!;
    try {
      final body = <String, Object?>{
        if (widget.customerId != null) 'customerId': widget.customerId,
        'title': _title.text.trim(),
        if (widget.task != null || _description.text.trim().isNotEmpty)
          'description': _description.text.trim().isEmpty
              ? null
              : _description.text.trim(),
        if (widget.task != null || _dueAt != null)
          'dueAt': _dueAt?.toUtc().toIso8601String(),
        if (widget.task != null) 'version': widget.task!.version,
      };
      final task = widget.task == null
          ? await widget.controller.apiClient.v2Tasks.create(
              businessId: session.businessId!,
              firebaseUid: session.firebaseUid,
              mockPhoneNumber: session.mockPhoneNumber,
              idempotencyKey: _key,
              body: body,
            )
          : await widget.controller.apiClient.v2Tasks.update(
              businessId: session.businessId!,
              taskId: widget.task!.id,
              firebaseUid: session.firebaseUid,
              mockPhoneNumber: session.mockPhoneNumber,
              idempotencyKey: _key,
              body: body,
            );
      if (mounted) Navigator.of(context).pop(task);
    } catch (error) {
      if (mounted) setState(() => _error = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _V2FormShell extends StatelessWidget {
  const _V2FormShell({
    required this.title,
    required this.child,
    required this.saving,
    required this.onSave,
    this.error,
  });

  final String title;
  final Widget child;
  final bool saving;
  final VoidCallback onSave;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          10,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 18),
              child,
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton(
                onPressed: saving ? null : onSave,
                child: saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('שמירה'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _V2StateCard extends StatelessWidget {
  const _V2StateCard({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: AppColors.primary),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

String _errorMessage(Object? error) {
  if (error is ApiException) return error.message;
  return 'אירעה שגיאה. אפשר לנסות שוב.';
}
