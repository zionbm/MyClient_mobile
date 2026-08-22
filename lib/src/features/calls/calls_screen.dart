import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../auth/session_controller.dart';

class CallsScreen extends StatefulWidget {
  const CallsScreen({super.key, required this.controller});

  final SessionController controller;

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> {
  Future<List<Map<String, Object?>>>? _future;
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
          FutureBuilder<List<Map<String, Object?>>>(
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
                                call['urgent'] == true
                                    ? Icons.priority_high
                                    : Icons.call,
                              ),
                            ),
                            title: Text(
                              _string(call['fromNumber']) ?? 'מספר לא ידוע',
                            ),
                            subtitle: Text(
                              [
                                _label(_string(call['ivrSelection'])),
                                _label(_string(call['displayStatus'])),
                                if (_string(call['transcriptPreview']) != null)
                                  _string(call['transcriptPreview'])!,
                              ].join(' · '),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
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

  Future<List<Map<String, Object?>>> _load() async {
    final session = widget.controller.session!;
    final json = await widget.controller.apiClient.listCalls(
      businessId: session.businessId!,
      firebaseUid: session.firebaseUid,
      mockPhoneNumber: session.mockPhoneNumber,
    );
    return (json['calls'] as List?)
            ?.whereType<Map<String, Object?>>()
            .toList() ??
        const [];
  }

  String? _string(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

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
