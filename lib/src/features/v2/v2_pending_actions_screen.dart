import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../core/network/idempotency_key.dart';
import '../../core/state/data_invalidator.dart';
import '../../utils/json_read.dart';
import '../auth/session_controller.dart';

class V2PendingActionsScreen extends StatefulWidget {
  const V2PendingActionsScreen({super.key, required this.controller});
  final SessionController controller;

  @override
  State<V2PendingActionsScreen> createState() => _V2PendingActionsScreenState();
}

class _V2PendingActionsScreenState extends State<V2PendingActionsScreen> {
  Future<Map<String, Object?>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('פעולות שמחכות להשלמה')),
    body: FutureBuilder<Map<String, Object?>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('לא הצלחנו לטעון את הפעולות'));
        }
        final actions = mapListValue(snapshot.data?['actions']);
        if (actions.isEmpty) {
          return const Center(child: Text('אין פעולות שמחכות להשלמה'));
        }
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: actions.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, index) => _PendingCard(
              action: actions[index],
              onResolve: (selectedId, payload, confirmed) =>
                  _resolve(actions[index], selectedId, payload, confirmed),
              onReject: () => _reject(actions[index]),
            ),
          ),
        );
      },
    ),
  );

  Future<void> _load() async {
    final session = widget.controller.session!;
    setState(() {
      _future = widget.controller.apiClient.v2Assistant.listPending(
        businessId: session.businessId!,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
      );
    });
    await _future;
  }

  Future<void> _resolve(
    Map<String, Object?> action,
    String? selectedId,
    Map<String, Object?> payload,
    bool confirmed,
  ) async {
    final session = widget.controller.session!;
    try {
      if (confirmed) {
        final accepted = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('אישור הפעולה'),
            content: Text(
              stringValue(
                action['question'],
                fallback: 'הפעולה דורשת אישור מפורש. להמשיך?',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('חזרה'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('אישור וביצוע'),
              ),
            ],
          ),
        );
        if (accepted != true) return;
      }
      await widget.controller.apiClient.v2Assistant.resolvePending(
        businessId: session.businessId!,
        pendingActionId: stringValue(action['id']),
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        selectedEntityId: selectedId,
        payload: payload,
        confirmed: confirmed,
        idempotencyKey: IdempotencyKey.create('pending_resolve'),
      );
      widget.controller.markDataChanged({DataScope.crm, DataScope.ai});
      await _load();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _reject(Map<String, Object?> action) async {
    final session = widget.controller.session!;
    await widget.controller.apiClient.v2Assistant.rejectPending(
      businessId: session.businessId!,
      pendingActionId: stringValue(action['id']),
      firebaseUid: session.firebaseUid,
      mockPhoneNumber: session.mockPhoneNumber,
      idempotencyKey: IdempotencyKey.create('pending_reject'),
    );
    widget.controller.markDataChanged({DataScope.ai});
    await _load();
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({
    required this.action,
    required this.onResolve,
    required this.onReject,
  });
  final Map<String, Object?> action;
  final void Function(
    String? selectedId,
    Map<String, Object?> payload,
    bool confirmed,
  )
  onResolve;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final candidates = mapListValue(action['candidateEntities']);
    final confirmation = action['requiresExplicitConfirmation'] == true;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              stringValue(action['question'], fallback: 'נדרש מידע נוסף'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            if (candidates.isNotEmpty)
              ...candidates.map(
                (candidate) => ListTile(
                  title: Text(
                    stringValue(
                      candidate['name'],
                      fallback: stringValue(
                        candidate['title'],
                        fallback: 'אפשרות',
                      ),
                    ),
                  ),
                  trailing: confirmation
                      ? const Icon(Icons.verified_user_outlined)
                      : null,
                  onTap: () {
                    final payload = mapValue(candidate['payload']);
                    onResolve(
                      payload.isEmpty ? stringValue(candidate['id']) : null,
                      payload,
                      confirmation,
                    );
                  },
                ),
              )
            else
              FilledButton(
                onPressed: () => onResolve(null, const {}, confirmation),
                child: Text(confirmation ? 'אישור וביצוע' : 'המשך'),
              ),
            TextButton(onPressed: onReject, child: const Text('דחיית הפעולה')),
          ],
        ),
      ),
    );
  }
}
