import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/api_client.dart';
import '../../core/network/idempotency_key.dart';
import '../../core/paging/paged_list_view.dart';
import '../../core/paging/paging_controller.dart';
import '../../core/presentation/user_error_message.dart';
import '../../core/state/data_invalidator.dart';
import '../../models/page.dart' as pagination;
import '../../models/session.dart';
import '../../models/v2_activity.dart';
import '../../models/v2_customer.dart';
import '../../models/v2_task.dart';
import '../../navigation/linked_entity_navigation.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_confirmation_dialog.dart';
import '../../widgets/main_top_bar.dart';
import '../../utils/date_formatting.dart';
import '../auth/session_controller.dart';
import 'customers/v2_customer_forms.dart';
import 'tasks/v2_task_form.dart';
import 'v2_search_screen.dart';

class V2CustomersScreen extends StatefulWidget {
  const V2CustomersScreen({super.key, required this.controller});

  final SessionController controller;

  @override
  State<V2CustomersScreen> createState() => _V2CustomersScreenState();
}

class _V2CustomersScreenState extends State<V2CustomersScreen> {
  late final PagingController<V2Customer> _paging;
  Future<List<V2Customer>>? _future;
  late int _seenDataVersion;

  @override
  void initState() {
    super.initState();
    _paging = PagingController<V2Customer>(
      _loadPage,
      itemKey: (customer) => customer.id,
    );
    _seenDataVersion = widget.controller.dataInvalidator.revision(
      DataScope.crm,
    );
    widget.controller.dataInvalidator.addListener(_handleDataChanged);
    _refresh();
  }

  @override
  void dispose() {
    widget.controller.dataInvalidator.removeListener(_handleDataChanged);
    _paging.dispose();
    super.dispose();
  }

  void _handleDataChanged() {
    final current = widget.controller.dataInvalidator.revision(DataScope.crm);
    if (!mounted || current == _seenDataVersion) return;
    _seenDataVersion = current;
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _V2CustomersHero(
            businessName: widget.controller.session?.businessName,
            onCreateCustomer: _createCustomer,
            onSearch: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => V2SearchScreen(controller: widget.controller),
              ),
            ),
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
                body: userErrorMessage(error),
              ),
              itemBuilder: (_, customer) => _V2CustomerCard(
                customer: customer,
                onTap: () => _openCustomer(customer.id),
                onCall: customer.primaryPhone == null
                    ? null
                    : () => _call(customer.primaryPhone!.rawPhone),
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

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (!await launchUrl(uri)) return;
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
  Future<_CustomerDetailData>? _future;
  late int _seenDataVersion;

  @override
  void initState() {
    super.initState();
    _seenDataVersion = widget.controller.dataInvalidator.revision(
      DataScope.crm,
    );
    widget.controller.dataInvalidator.addListener(_handleDataChanged);
    _load();
  }

  @override
  void dispose() {
    widget.controller.dataInvalidator.removeListener(_handleDataChanged);
    super.dispose();
  }

  void _handleDataChanged() {
    final current = widget.controller.dataInvalidator.revision(DataScope.crm);
    if (!mounted || current == _seenDataVersion) return;
    _seenDataVersion = current;
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
      body: FutureBuilder<_CustomerDetailData>(
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
                body: userErrorMessage(snapshot.error),
              ),
            );
          }
          return _content(snapshot.data!);
        },
      ),
    );
  }

  Widget _content(_CustomerDetailData data) {
    final customer = data.customer;
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
                        backgroundColor: AppColors.primaryContainer,
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
          if (customer.primaryPhone != null ||
              customer.addresses.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (customer.primaryPhone != null)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _call(customer.primaryPhone!.rawPhone),
                      icon: const Icon(Icons.call_outlined),
                      label: const Text('התקשר'),
                    ),
                  ),
                if (customer.primaryPhone != null &&
                    customer.addresses.isNotEmpty)
                  const SizedBox(width: 8),
                if (customer.addresses.isNotEmpty)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _navigate(customer.addresses.first.addressText),
                      icon: const Icon(Icons.navigation_outlined),
                      label: const Text('נווט'),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _showTimeline,
            icon: const Icon(Icons.timeline_outlined),
            label: const Text('ציר הזמן של הלקוח'),
          ),
          const SizedBox(height: 14),
          _section(
            title: 'עבודות',
            icon: Icons.work_outline,
            emptyText: 'אין עבודות ללקוח הזה',
            children: data.jobs
                .map((activity) => _activityTile(activity))
                .toList(),
          ),
          const SizedBox(height: 14),
          _section(
            title: 'ביקורים',
            icon: Icons.home_work_outlined,
            emptyText: 'אין ביקורים ללקוח הזה',
            children: data.visits
                .map((activity) => _activityTile(activity))
                .toList(),
          ),
          const SizedBox(height: 14),
          _section(
            title: 'מספרי טלפון',
            icon: Icons.phone_outlined,
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
            icon: Icons.location_on_outlined,
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
            title: 'הערות',
            icon: Icons.notes_outlined,
            onAdd: _addNote,
            emptyText: 'אין עדיין הערות ללקוח הזה',
            children: customer.notes
                .map(
                  (note) => ListTile(
                    leading: Icon(
                      note.status == V2NoteStatus.done
                          ? Icons.check_circle_outline
                          : Icons.notes_outlined,
                    ),
                    title: Text(note.text),
                    subtitle: Text(note.status.hebrewLabel),
                    trailing: PopupMenuButton<String>(
                      onSelected: (action) => action == 'edit'
                          ? _editNote(note)
                          : _deleteNote(note),
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
            icon: Icons.task_alt_outlined,
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

  Widget _activityTile(V2Activity activity) => ListTile(
    leading: Icon(
      activity.kind == V2ActivityKind.job
          ? Icons.work_outline
          : Icons.home_work_outlined,
    ),
    title: Text(activity.title),
    subtitle: Text(
      [
        _activityStatusLabel(activity),
        if (activity.startsAt != null) formatDateTime(activity.startsAt),
      ].join(' · '),
    ),
    trailing: const Icon(Icons.chevron_left_rounded),
    onTap: () async {
      await openLinkedEntity(
        context: context,
        controller: widget.controller,
        type: activity.kind.apiPath,
        id: activity.id,
      );
      if (mounted) await _load();
    },
  );

  Future<void> _call(String phone) async {
    await launchUrl(Uri(scheme: 'tel', path: phone));
  }

  Future<void> _navigate(String address) async {
    await launchUrl(
      Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': address,
      }),
      mode: LaunchMode.externalApplication,
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
                  item['text'] as String? ??
                  item['body'] as String? ??
                  'פעילות';
              final occurredAt = DateTime.tryParse(
                entry['occurredAt'] as String? ?? '',
              );
              final status = item['status'] as String?;
              return ListTile(
                leading: Icon(switch (type) {
                  'task' => Icons.task_alt_outlined,
                  'job' => Icons.work_outline,
                  'visit' => Icons.home_work_outlined,
                  _ => Icons.notes_outlined,
                }),
                title: Text(title),
                subtitle: Text(
                  [
                    switch (type) {
                      'task' => 'משימה',
                      'job' => 'עבודה',
                      'visit' => 'ביקור',
                      _ => 'הערה',
                    },
                    if (status != null) _apiStatusLabel(status),
                    if (occurredAt != null) formatDateTime(occurredAt),
                  ].join(' · '),
                ),
                trailing: type == 'note'
                    ? null
                    : const Icon(Icons.chevron_left_rounded),
                onTap: type == 'note'
                    ? null
                    : () async {
                        Navigator.of(context).pop();
                        await openLinkedEntity(
                          context: context,
                          controller: widget.controller,
                          type: type,
                          id: item['id'] as String?,
                        );
                        if (mounted) await _load();
                      },
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
    required IconData icon,
    VoidCallback? onAdd,
    required String emptyText,
    required List<Widget> children,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Icon(icon, color: AppColors.primary),
        tilePadding: const EdgeInsetsDirectional.fromSTEB(14, 2, 6, 2),
        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${children.length}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (onAdd != null)
              IconButton(
                tooltip: 'הוספה',
                onPressed: onAdd,
                icon: const Icon(Icons.add_circle_outline),
              ),
          ],
        ),
        children: [
          const Divider(height: 1),
          if (children.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                emptyText,
                style: const TextStyle(color: AppColors.muted),
              ),
            )
          else
            ListTileTheme.merge(
              dense: true,
              visualDensity: VisualDensity.compact,
              child: Column(children: children),
            ),
        ],
      ),
    );
  }

  Future<void> _load() async {
    final session = widget.controller.session!;
    setState(() => _future = _loadCustomerDetails(session));
    await _future;
  }

  Future<_CustomerDetailData> _loadCustomerDetails(AppSession session) async {
    final customerFuture = widget.controller.apiClient.v2Customers.get(
      businessId: session.businessId!,
      customerId: widget.customerId,
      firebaseUid: session.firebaseUid,
      mockPhoneNumber: session.mockPhoneNumber,
    );
    final jobsFuture = widget.controller.apiClient.v2Activities.listAll(
      kind: V2ActivityKind.job,
      businessId: session.businessId!,
      customerId: widget.customerId,
      firebaseUid: session.firebaseUid,
      mockPhoneNumber: session.mockPhoneNumber,
    );
    final visitsFuture = widget.controller.apiClient.v2Activities.listAll(
      kind: V2ActivityKind.visit,
      businessId: session.businessId!,
      customerId: widget.customerId,
      firebaseUid: session.firebaseUid,
      mockPhoneNumber: session.mockPhoneNumber,
    );
    late V2Customer customer;
    late List<V2Activity> jobs;
    late List<V2Activity> visits;
    await Future.wait<void>([
      customerFuture.then((value) => customer = value),
      jobsFuture.then((value) => jobs = value),
      visitsFuture.then((value) => visits = value),
    ]);
    return _CustomerDetailData(customer: customer, jobs: jobs, visits: visits);
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
      builder: (_) => V2PhoneForm(
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
      builder: (_) => V2PhoneForm(
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
        ).showSnackBar(SnackBar(content: Text(userErrorMessage(error))));
      }
    }
  }

  Future<void> _addAddress() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => V2AddressForm(
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
      builder: (_) => V2AddressForm(
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
        ).showSnackBar(SnackBar(content: Text(userErrorMessage(error))));
      }
    }
  }

  Future<void> _addTask(String customerId) async {
    final task = await showModalBottomSheet<V2Task>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          V2TaskForm(controller: widget.controller, customerId: customerId),
    );
    if (task == null) return;
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_taskSavedMessage(context, task))));
  }

  Future<void> _addNote() async {
    final note = await showModalBottomSheet<V2Note>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => V2NoteForm(
        controller: widget.controller,
        customerId: widget.customerId,
      ),
    );
    if (note != null) await _load();
  }

  Future<void> _editNote(V2Note note) async {
    final updated = await showModalBottomSheet<V2Note>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => V2NoteForm(
        controller: widget.controller,
        customerId: widget.customerId,
        note: note,
      ),
    );
    if (updated != null) await _load();
  }

  Future<void> _deleteNote(V2Note note) async {
    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: 'למחוק את ההערה?',
      body: note.text,
      confirmLabel: 'מחיקה',
      destructive: true,
      icon: Icons.delete_outline,
    );
    if (confirmed != true || !mounted) return;
    final session = widget.controller.session!;
    try {
      await widget.controller.apiClient.v2Customers.deleteNote(
        businessId: session.businessId!,
        customerId: widget.customerId,
        noteId: note.id,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        idempotencyKey: IdempotencyKey.create('note_delete'),
      );
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userErrorMessage(error))));
      }
    }
  }

  Future<void> _editTask(V2Task task) async {
    final updated = await showModalBottomSheet<V2Task>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => V2TaskForm(
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
        ).showSnackBar(SnackBar(content: Text(userErrorMessage(error))));
      }
    }
  }

  Future<void> _taskAction(V2Task task, V2TaskAction action) async {
    final session = widget.controller.session!;
    try {
      await widget.controller.apiClient.v2Tasks.lifecycle(
        businessId: session.businessId!,
        taskId: task.id,
        action: action,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        idempotencyKey: IdempotencyKey.create('task_${action.apiValue}'),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userErrorMessage(error))));
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
      ).showSnackBar(SnackBar(content: Text(userErrorMessage(error))));
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
      ).showSnackBar(SnackBar(content: Text(userErrorMessage(error))));
    }
  }
}

class _V2CustomersHero extends StatelessWidget {
  const _V2CustomersHero({
    required this.businessName,
    required this.onCreateCustomer,
    required this.onSearch,
  });

  final String? businessName;
  final VoidCallback onCreateCustomer;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        MainTopBar(
          title: 'לקוחות',
          subtitle: businessName ?? 'העסק שלי',
          actions: [
            IconButton.filled(
              tooltip: 'לקוח חדש',
              onPressed: onCreateCustomer,
              icon: const Icon(Icons.person_add_alt_1),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Semantics(
            button: true,
            label: 'חיפוש לקוחות לפי שם, טלפון או כתובת',
            child: InkWell(
              onTap: onSearch,
              borderRadius: BorderRadius.circular(16),
              child: IgnorePointer(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'שם, טלפון או כתובת',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _V2CustomerCard extends StatelessWidget {
  const _V2CustomerCard({
    required this.customer,
    required this.onTap,
    this.onCall,
  });
  final V2Customer customer;
  final VoidCallback onTap;
  final VoidCallback? onCall;

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
          backgroundColor: AppColors.primaryContainer,
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
        trailing: onCall == null
            ? const Icon(Icons.chevron_left)
            : IconButton(
                tooltip: 'התקשר אל ${customer.name}',
                onPressed: onCall,
                icon: const Icon(Icons.call_outlined),
              ),
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
  final ValueChanged<V2TaskAction> onAction;
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
            onAction(switch (action) {
              'complete' => V2TaskAction.complete,
              'cancel' => V2TaskAction.cancel,
              'reopen' => V2TaskAction.reopen,
              _ => throw StateError('Unsupported task action: $action'),
            });
          }
        },
      ),
    );
  }
}

class _CustomerDetailData {
  const _CustomerDetailData({
    required this.customer,
    required this.jobs,
    required this.visits,
  });

  final V2Customer customer;
  final List<V2Activity> jobs;
  final List<V2Activity> visits;
}

String _activityStatusLabel(V2Activity activity) {
  if (activity.executionCompletedAt != null &&
      activity.status == V2ActivityStatus.open) {
    return 'הביצוע הושלם · נותר תשלום';
  }
  return _apiStatusLabel(activity.status.apiValue);
}

String _apiStatusLabel(String status) => switch (status) {
  'OPEN' => 'פתוח',
  'DONE' || 'CLOSED' => 'בוצע',
  'CANCELLED' => 'בוטל',
  _ => status,
};

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

String _taskSavedMessage(BuildContext context, V2Task task) {
  final dueAt = task.dueAt?.toLocal();
  if (dueAt == null) return 'נפתחה המשימה: ${task.title}';
  final localizations = MaterialLocalizations.of(context);
  final date = localizations.formatMediumDate(dueAt);
  final time = localizations.formatTimeOfDay(TimeOfDay.fromDateTime(dueAt));
  return 'נפתחה המשימה: ${task.title} · $date בשעה $time';
}
