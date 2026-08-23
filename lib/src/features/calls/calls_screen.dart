import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../models/customer.dart';
import '../../navigation/linked_entity_navigation.dart';
import '../../utils/date_formatting.dart';
import '../../utils/json_read.dart';
import '../auth/session_controller.dart';

class CallsScreen extends StatefulWidget {
  const CallsScreen({super.key, required this.controller});

  final SessionController controller;

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> {
  Future<List<_CallItem>>? _future;
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
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FutureBuilder<List<_CallItem>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return _InfoCard(
                  icon: Icons.cloud_off_outlined,
                  title: 'לא הצלחנו לטעון שיחות',
                  body: snapshot.error is ApiException
                      ? (snapshot.error as ApiException).message
                      : 'בדוק שהשרת המקומי זמין.',
                );
              }
              final calls = snapshot.data ?? const [];
              if (calls.isEmpty) {
                return const _InfoCard(
                  icon: Icons.call_outlined,
                  title: 'עדיין אין שיחות נכנסות למזכירה',
                  body: 'שיחות מהמזכירה הווירטואלית יופיעו כאן.',
                );
              }
              return Column(
                children: calls
                    .map(
                      (call) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Icon(
                                call.urgent ? Icons.priority_high : Icons.call,
                              ),
                            ),
                            title: Text(call.fromNumber ?? 'מספר לא ידוע'),
                            subtitle: Text(
                              [
                                _label(call.ivrSelection),
                                _label(call.displayStatus),
                                if (call.calledAt != null)
                                  formatDateTime(call.calledAt),
                                if (call.transcriptPreview != null)
                                  call.transcriptPreview!,
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
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
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

  Future<List<_CallItem>> _load() async {
    final session = widget.controller.session!;
    final json = await widget.controller.apiClient.listCalls(
      businessId: session.businessId!,
      firebaseUid: session.firebaseUid,
      mockPhoneNumber: session.mockPhoneNumber,
    );
    return mapListValue(json['calls']).map(_CallItem.fromJson).toList();
  }

  String _label(String? value) {
    return switch (value) {
      'CALLBACK_REQUESTED' => 'בקשת חזרה',
      'MESSAGE_RECORDED' => 'הוקלטה הודעה',
      'URGENT_MESSAGE' => 'דחוף',
      'NO_SELECTION' => 'לא נבחרה אפשרות',
      'TASK_CREATED' => 'נוצרה חזרה',
      'TASK_COMPLETED' => 'טופל',
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
          if (call.relatedTaskId != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => openLinkedEntity(
                context: context,
                controller: controller,
                type: 'callback',
                id: call.relatedTaskId,
                customer: call.customer,
                title: 'חזרה ללקוח מהשיחה',
              ),
              icon: const Icon(Icons.phone_callback_outlined),
              label: const Text('פתח חזרה קשורה'),
            ),
          ],
        ],
      ),
    );
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
    this.relatedTaskId,
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
  final String? relatedTaskId;
  final Customer? customer;

  factory _CallItem.fromJson(Map<String, Object?> json) {
    final relatedTask = mapValue(json['relatedTask']);
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
      relatedTaskId: nullableString(
        json['callbackId'] ?? json['taskId'] ?? relatedTask['id'],
      ),
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
