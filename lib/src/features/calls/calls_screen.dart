import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../core/state/data_invalidator.dart';
import '../../core/paging/paging_controller.dart';
import '../../core/paging/paged_list_view.dart';
import '../../models/customer.dart';
import '../../models/page.dart' as pagination;
import '../../navigation/linked_entity_navigation.dart';
import '../../utils/date_formatting.dart';
import '../../utils/json_read.dart';
import '../auth/session_controller.dart';
import '../customers/customer_form_screen.dart';

class CallsScreen extends StatefulWidget {
  const CallsScreen({super.key, required this.controller});

  final SessionController controller;

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> {
  Future<List<_CallItem>>? _future;
  late final PagingController<_CallItem> _paging;
  late int _seenDataVersion;

  @override
  void initState() {
    super.initState();
    _seenDataVersion = widget.controller.dataInvalidator.revision(
      DataScope.calls,
    );
    widget.controller.dataInvalidator.addListener(_handleDataChanged);
    _paging = PagingController<_CallItem>(
      _loadPage,
      itemKey: (item) => item.id,
    );
    _future = _paging.refresh().then((_) => _paging.items);
  }

  @override
  void dispose() {
    widget.controller.dataInvalidator.removeListener(_handleDataChanged);
    _paging.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PagedListView<_CallItem>(
      future: _future,
      onRefresh: _refresh,
      canLoadMore: _paging.canLoadMore,
      onLoadMore: _loadMore,
      loadMoreLabel: 'טען עוד שיחות',
      empty: const _InfoCard(
        icon: Icons.call_outlined,
        title: 'עדיין אין שיחות נכנסות למזכירה',
        body: 'שיחות מהמזכירה הווירטואלית יופיעו כאן.',
      ),
      errorBuilder: (context, error) => _InfoCard(
        icon: Icons.cloud_off_outlined,
        title: 'לא הצלחנו לטעון שיחות',
        body: error is ApiException ? error.message : 'בדוק שהשרת המקומי זמין.',
      ),
      itemBuilder: (context, call) => Card(
        child: ListTile(
          leading: CircleAvatar(
            child: Icon(call.urgent ? Icons.priority_high : Icons.call),
          ),
          title: Text(call.fromNumber ?? 'מספר לא ידוע'),
          subtitle: Text(
            [
              _label(call.ivrSelection),
              _label(call.displayStatus),
              if (call.calledAt != null) formatDateTime(call.calledAt),
              if (call.transcriptPreview != null) call.transcriptPreview!,
            ].where((value) => value.isNotEmpty).join(' · '),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.chevron_left),
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _CallDetailScreen(
                  controller: widget.controller,
                  call: call,
                ),
              ),
            );
            _refresh();
          },
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    _seenDataVersion = widget.controller.dataInvalidator.revision(
      DataScope.calls,
    );
    setState(() => _future = _paging.refresh().then((_) => _paging.items));
    await _future;
  }

  void _handleDataChanged() {
    if (!mounted) return;
    final currentVersion = widget.controller.dataInvalidator.revision(
      DataScope.calls,
    );
    if (currentVersion == _seenDataVersion) return;
    _refresh();
  }

  Future<pagination.Page<_CallItem>> _loadPage(String? cursor) async {
    final session = widget.controller.session!;
    final json = await widget.controller.apiClient.calls.list(
      businessId: session.businessId!,
      firebaseUid: session.firebaseUid,
      mockPhoneNumber: session.mockPhoneNumber,
      limit: 50,
      cursor: cursor,
    );
    return pagination.Page(
      items: mapListValue(json['calls']).map(_CallItem.fromJson).toList(),
      pageInfo: pagination.PageInfo.fromJson(json['pageInfo']),
    );
  }

  Future<void> _loadMore() async {
    await _paging.loadMore();
    if (mounted) setState(() => _future = Future.value(_paging.items));
  }

  String _label(String? value) {
    return switch (value) {
      'CALLBACK_REQUESTED' => 'בקשת חזרה',
      'MESSAGE_RECORDED' => 'הוקלטה הודעה',
      'URGENT_MESSAGE' => 'דחוף',
      'NO_SELECTION' => 'לא נבחרה אפשרות',
      'REMINDER_CREATED' => 'נוצרה תזכורת',
      'REMINDER_DONE' => 'טופל',
      'NO_ACTION' => 'ללא פעולה',
      null => '',
      _ => value,
    };
  }
}

class _CallDetailScreen extends StatelessWidget {
  const _CallDetailScreen({required this.controller, required this.call});

  final SessionController controller;
  final _CallItem call;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('פרטי שיחה')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    call.fromNumber ?? 'מספר לא ידוע',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  _DetailLine(label: 'סטטוס', value: call.displayStatus),
                  _DetailLine(label: 'בחירה במענה', value: call.ivrSelection),
                  if (call.toNumber != null)
                    _DetailLine(label: 'מספר המזכירה', value: call.toNumber),
                  if (call.calledAt != null)
                    _DetailLine(
                      label: 'זמן שיחה',
                      value: formatDateTime(call.calledAt),
                    ),
                  if (call.urgent)
                    const _DetailLine(label: 'דחיפות', value: 'דחוף'),
                ],
              ),
            ),
          ),
          if (call.transcriptPreview != null) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'תמלול',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(call.transcriptPreview!),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (call.customer != null)
            FilledButton.icon(
              onPressed: () => openLinkedEntity(
                context: context,
                controller: controller,
                type: 'customer',
                id: call.customer!.id,
                customer: call.customer,
              ),
              icon: const Icon(Icons.person_outline),
              label: Text('פתח את ${call.customer!.name}'),
            ),
          if (call.customer == null && call.fromNumber != null)
            FilledButton.icon(
              onPressed: () => _createCustomerFromCall(context),
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('צור לקוח מהשיחה'),
            ),
          if (call.relatedReminderId != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => openLinkedEntity(
                context: context,
                controller: controller,
                type: 'reminder',
                id: call.relatedReminderId,
                customer: call.customer,
                title: 'חזרה ללקוח מהשיחה',
              ),
              icon: const Icon(Icons.alarm_outlined),
              label: const Text('פתח תזכורת קשורה'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _createCustomerFromCall(BuildContext context) async {
    final changed = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomerFormScreen(
          controller: controller,
          initialName: 'לקוח מהשיחה',
          initialPhone: call.fromNumber,
        ),
      ),
    );
    if (changed == true) controller.markDataChanged({DataScope.calls});
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text('$label: $value'),
    );
  }
}

class _CallItem {
  const _CallItem({
    required this.id,
    this.fromNumber,
    this.toNumber,
    this.calledAt,
    this.ivrSelection,
    this.displayStatus,
    this.urgent = false,
    this.transcriptPreview,
    this.relatedReminderId,
    this.customer,
  });

  final String id;
  final String? fromNumber;
  final String? toNumber;
  final DateTime? calledAt;
  final String? ivrSelection;
  final String? displayStatus;
  final bool urgent;
  final String? transcriptPreview;
  final String? relatedReminderId;
  final Customer? customer;

  factory _CallItem.fromJson(Map<String, Object?> json) {
    final relatedReminder = mapValue(json['relatedReminder']);
    final customerJson = json['customer'];
    return _CallItem(
      id: stringValue(json['id']),
      fromNumber: nullableString(json['fromNumber']),
      toNumber: nullableString(json['toNumber']),
      calledAt: dateValue(json['calledAt'] ?? json['createdAt']),
      ivrSelection: nullableString(json['ivrSelection']),
      displayStatus: nullableString(json['displayStatus']),
      urgent: json['urgent'] == true,
      transcriptPreview: nullableString(
        json['transcriptPreview'] ?? json['transcript'],
      ),
      relatedReminderId: nullableString(relatedReminder['id']),
      customer: customerJson is Map<String, Object?>
          ? Customer.fromJson(customerJson)
          : null,
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
