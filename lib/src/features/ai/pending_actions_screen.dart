import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../utils/json_read.dart';
import '../auth/session_controller.dart';
import '../voice/voice_command_result.dart';
import '../voice/voice_command_result_widgets.dart';
import '../work_items/work_item_form_screen.dart';

class PendingActionsScreen extends StatefulWidget {
  const PendingActionsScreen({super.key, required this.controller});

  final SessionController controller;

  @override
  State<PendingActionsScreen> createState() => _PendingActionsScreenState();
}

class _PendingActionsScreenState extends State<PendingActionsScreen> {
  Future<List<VoiceCommandResultItem>>? _future;
  final Set<String> _submittingItems = {};
  String _status = 'PENDING';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('פעולות AI')),
      body: RefreshIndicator(
        onRefresh: () async => _load(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'PENDING', label: Text('ממתינות')),
                ButtonSegment(value: 'EXECUTED', label: Text('בוצעו')),
                ButtonSegment(value: 'REJECTED', label: Text('נדחו')),
              ],
              selected: {_status},
              onSelectionChanged: (value) {
                setState(() => _status = value.first);
                _load();
              },
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<VoiceCommandResultItem>>(
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
                    title: 'לא הצלחנו לטעון פעולות',
                    body: _messageFor(snapshot.error),
                  );
                }
                final items = snapshot.data ?? const <VoiceCommandResultItem>[];
                if (items.isEmpty) {
                  return const _InfoCard(
                    icon: Icons.auto_awesome_outlined,
                    title: 'אין פעולות שממתינות לאישור',
                    body: 'כאשר פקודה קולית תדרוש אישור, היא תופיע כאן.',
                  );
                }
                return Column(
                  children: items
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: VoiceResultItemCard(
                            item: item,
                            submitting: _submittingItems.contains(item.id),
                            onTap: item.status == 'pending'
                                ? () => _editAndApprove(item)
                                : null,
                            onApprove: item.status == 'pending'
                                ? () => _approve(item)
                                : null,
                            onReject: item.status == 'pending'
                                ? () => _reject(item)
                                : null,
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _load() {
    final session = widget.controller.session!;
    setState(() {
      _future = widget.controller.apiClient
          .listAiPendingActions(
            businessId: session.businessId!,
            firebaseUid: session.firebaseUid,
            mockPhoneNumber: session.mockPhoneNumber,
            status: _status,
          )
          .then(
            (json) => mapListValue(
              json['pendingActions'],
            ).map(VoiceCommandResultItem.fromPendingActionJson).toList(),
          );
    });
  }

  Future<void> _editAndApprove(VoiceCommandResultItem item) async {
    final kind = _workItemKindForActionType(item.actionType);
    if (kind != null && item.pendingActionId != null) {
      final completed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => WorkItemFormScreen(
            controller: widget.controller,
            kind: kind,
            initialPayload: item.payload,
            pendingActionId: item.pendingActionId,
          ),
        ),
      );
      if (completed == true) {
        widget.controller.markDataChanged();
        _load();
      }
      return;
    }

    final edited = await showModalBottomSheet<Map<String, Object?>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: VoicePayloadEditorSheet(item: item),
      ),
    );
    if (edited == null) return;
    await _approve(item, edited);
  }

  Future<void> _approve(
    VoiceCommandResultItem item, [
    Map<String, Object?>? editedPayload,
  ]) async {
    final pendingActionId = item.pendingActionId;
    if (pendingActionId == null) return;
    if (editedPayload == null && item.missingFields.isNotEmpty) {
      _showError('לא ניתן לבצע בלי להשלים את הפרטים החסרים.');
      return;
    }

    final session = widget.controller.session!;
    setState(() => _submittingItems.add(item.id));
    try {
      await widget.controller.apiClient.approveAiPendingAction(
        businessId: session.businessId!,
        pendingActionId: pendingActionId,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        payload: editedPayload ?? item.payload,
      );
      widget.controller.markDataChanged();
      _load();
    } on ApiException catch (error) {
      if (mounted) setState(() => _submittingItems.remove(item.id));
      _showError(error.message);
    } catch (_) {
      if (mounted) setState(() => _submittingItems.remove(item.id));
      _showError('לא הצלחנו להשלים את הפעולה');
    }
  }

  Future<void> _reject(VoiceCommandResultItem item) async {
    final pendingActionId = item.pendingActionId;
    if (pendingActionId == null) return;

    final session = widget.controller.session!;
    setState(() => _submittingItems.add(item.id));
    try {
      await widget.controller.apiClient.rejectAiPendingAction(
        businessId: session.businessId!,
        pendingActionId: pendingActionId,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
      );
      widget.controller.markDataChanged();
      _load();
    } on ApiException catch (error) {
      if (mounted) setState(() => _submittingItems.remove(item.id));
      _showError(error.message);
    } catch (_) {
      if (mounted) setState(() => _submittingItems.remove(item.id));
      _showError('לא הצלחנו למחוק את הפעולה');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _messageFor(Object? error) {
    if (error is ApiException) return error.message;
    return 'בדוק שהשרת המקומי זמין.';
  }
}

WorkItemKind? _workItemKindForActionType(String actionType) {
  return switch (voiceWorkItemKindName(actionType)) {
    'callback' => WorkItemKind.callback,
    'homeVisit' => WorkItemKind.homeVisit,
    'quote' => WorkItemKind.quote,
    _ => null,
  };
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
