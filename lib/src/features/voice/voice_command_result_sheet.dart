import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../auth/session_controller.dart';
import 'voice_command_result.dart';
import 'voice_command_result_widgets.dart';

class VoiceCommandResultSheet extends StatefulWidget {
  const VoiceCommandResultSheet({
    super.key,
    required this.result,
    required this.controller,
    this.onOpenPendingActions,
    this.onRecordAgain,
    this.onResolved,
  });

  final VoiceCommandResult result;
  final SessionController controller;
  final VoidCallback? onOpenPendingActions;
  final VoidCallback? onRecordAgain;
  final VoidCallback? onResolved;

  @override
  State<VoiceCommandResultSheet> createState() =>
      _VoiceCommandResultSheetState();
}

class _VoiceCommandResultSheetState extends State<VoiceCommandResultSheet> {
  late VoiceCommandResult _result;
  final Set<String> _submittingItems = {};
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    _result = widget.result;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = _statusColor(colorScheme);
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.78,
        minChildSize: 0.48,
        maxChildSize: 0.94,
        builder: (context, scrollController) {
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    tooltip: 'סגור',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Icon(_statusIcon(), color: statusColor, size: 30),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                _result.title,
                                textAlign: TextAlign.end,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _result.summary,
                          textAlign: TextAlign.end,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_result.transcript != null) ...[
                const SizedBox(height: 16),
                _TranscriptCard(transcript: _result.transcript!),
              ],
              const SizedBox(height: 16),
              if (_result.items.isEmpty)
                _EmptyResultCard(
                  state: _result.state,
                  onCreateCustomer: () =>
                      _createManualAction('CREATE_CUSTOMER'),
                  onCreateTask: () => _createManualAction('CREATE_TASK'),
                )
              else
                ..._result.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: VoiceResultItemCard(
                      item: item,
                      submitting: _submittingItems.contains(item.id),
                      onTap: item.status == 'pending'
                          ? () => _editPendingItem(item)
                          : null,
                      onApprove: _canApprove(item)
                          ? () => _approvePendingItem(item)
                          : null,
                      onReject: item.status == 'pending'
                          ? () => _rejectPendingItem(item)
                          : null,
                    ),
                  ),
                ),
              if (_inlineError != null) ...[
                const SizedBox(height: 4),
                Text(
                  _inlineError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.error),
                ),
              ],
              const SizedBox(height: 8),
              if (_result.primaryAction != null)
                FilledButton(
                  onPressed: () =>
                      _handleAction(context, _result.primaryAction!),
                  child: Text(_result.primaryAction!),
                ),
              if (_result.secondaryActions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: _result.secondaryActions
                      .map(
                        (action) => TextButton(
                          onPressed: () => _handleAction(context, action),
                          child: Text(action),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  void _handleAction(BuildContext context, String action) {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    if (action == 'אשר מאוחר יותר' || action == 'פתח פעולות AI') {
      widget.controller.markDataChanged();
      messenger.showSnackBar(
        const SnackBar(content: Text('שמרתי לאישור מאוחר יותר')),
      );
      return;
    }
    if (action == 'הקלט שוב') {
      widget.onRecordAgain?.call();
    }
  }

  Future<void> _editPendingItem(VoiceCommandResultItem item) async {
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
    await _approvePendingItem(item, edited);
  }

  bool _canApprove(VoiceCommandResultItem item) =>
      item.status == 'pending' &&
      item.pendingActionId != null &&
      item.missingFields.isEmpty;

  Future<void> _approvePendingItem(
    VoiceCommandResultItem item, [
    Map<String, Object?>? editedPayload,
  ]) async {
    final pendingActionId = item.pendingActionId;
    if (pendingActionId == null) return;
    setState(() {
      _inlineError = null;
      _submittingItems.add(item.id);
    });
    try {
      final session = widget.controller.session!;
      await widget.controller.apiClient.approveAiPendingAction(
        businessId: session.businessId!,
        pendingActionId: pendingActionId,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        payload: editedPayload ?? item.payload,
      );
      widget.controller.markDataChanged();
      widget.onResolved?.call();
      if (!mounted) return;
      setState(() {
        _result = _result.markItemCompleted(item.id);
        _submittingItems.remove(item.id);
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _inlineError = error.message;
        _submittingItems.remove(item.id);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _inlineError = 'לא הצלחנו להשלים את הפעולה';
        _submittingItems.remove(item.id);
      });
    }
  }

  Future<void> _rejectPendingItem(VoiceCommandResultItem item) async {
    final pendingActionId = item.pendingActionId;
    if (pendingActionId == null) return;
    setState(() {
      _inlineError = null;
      _submittingItems.add(item.id);
    });
    try {
      final session = widget.controller.session!;
      await widget.controller.apiClient.rejectAiPendingAction(
        businessId: session.businessId!,
        pendingActionId: pendingActionId,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
      );
      widget.controller.markDataChanged();
      widget.onResolved?.call();
      if (!mounted) return;
      setState(() {
        _result = _result.removeItem(item.id);
        _submittingItems.remove(item.id);
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _inlineError = error.message;
        _submittingItems.remove(item.id);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _inlineError = 'לא הצלחנו למחוק את הפעולה';
        _submittingItems.remove(item.id);
      });
    }
  }

  Future<void> _createManualAction(String actionType) async {
    final item = VoiceCommandResultItem.manual(
      actionType: actionType,
      transcript: _result.transcript,
    );
    final payload = await showModalBottomSheet<Map<String, Object?>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: VoicePayloadEditorSheet(item: item),
      ),
    );
    if (payload == null) return;
    setState(() {
      _inlineError = null;
      _submittingItems.add(item.id);
    });
    try {
      final session = widget.controller.session!;
      if (actionType == 'CREATE_CUSTOMER') {
        await widget.controller.apiClient.createCustomer(
          businessId: session.businessId!,
          firebaseUid: session.firebaseUid,
          mockPhoneNumber: session.mockPhoneNumber,
          body: _withoutEmptyValues(payload),
        );
      } else {
        await widget.controller.apiClient.createCallback(
          businessId: session.businessId!,
          firebaseUid: session.firebaseUid,
          mockPhoneNumber: session.mockPhoneNumber,
          body: _withoutEmptyValues(payload),
        );
      }
      widget.controller.markDataChanged();
      widget.onResolved?.call();
      if (!mounted) return;
      setState(() {
        _result = _result.addCompletedManualItem(item.updatePayload(payload));
        _submittingItems.remove(item.id);
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _inlineError = error.message;
        _submittingItems.remove(item.id);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _inlineError = 'לא הצלחנו ליצור את הפעולה';
        _submittingItems.remove(item.id);
      });
    }
  }

  IconData _statusIcon() {
    return switch (_result.state) {
      VoiceCommandResultState.done => Icons.check_circle_outline,
      VoiceCommandResultState.needsReview => Icons.fact_check_outlined,
      VoiceCommandResultState.needsInput => Icons.error_outline,
      VoiceCommandResultState.failed => Icons.mic_off_outlined,
      VoiceCommandResultState.unsupported => Icons.help_outline,
    };
  }

  Color _statusColor(ColorScheme colorScheme) {
    return switch (_result.state) {
      VoiceCommandResultState.done => colorScheme.primary,
      VoiceCommandResultState.needsReview => colorScheme.primary,
      VoiceCommandResultState.needsInput => colorScheme.tertiary,
      VoiceCommandResultState.failed => colorScheme.error,
      VoiceCommandResultState.unsupported => colorScheme.secondary,
    };
  }
}

class _TranscriptCard extends StatelessWidget {
  const _TranscriptCard({required this.transcript});

  final String transcript;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'מה שמעתי',
                  textAlign: TextAlign.end,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 8),
                Icon(Icons.mic_none_outlined, color: colorScheme.primary),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(transcript, textAlign: TextAlign.end),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyResultCard extends StatelessWidget {
  const _EmptyResultCard({
    required this.state,
    required this.onCreateCustomer,
    required this.onCreateTask,
  });

  final VoiceCommandResultState state;
  final VoidCallback onCreateCustomer;
  final VoidCallback onCreateTask;

  @override
  Widget build(BuildContext context) {
    final unsupported = state == VoiceCommandResultState.unsupported;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              unsupported ? Icons.rule_folder_outlined : Icons.mic_off_outlined,
              size: 36,
            ),
            const SizedBox(height: 10),
            Text(
              unsupported
                  ? 'אפשר ליצור לקוחות, תזכורות, ביקורי בית, הצעות מחיר והערות.'
                  : 'לא נוצרו שינויים במערכת.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onCreateTask,
                  icon: const Icon(Icons.add_task_outlined),
                  label: const Text('פתח משימה'),
                ),
                OutlinedButton.icon(
                  onPressed: onCreateCustomer,
                  icon: const Icon(Icons.person_add_alt_outlined),
                  label: const Text('פתח לקוח'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Map<String, Object?> _withoutEmptyValues(Map<String, Object?> payload) {
  final next = <String, Object?>{};
  for (final entry in payload.entries) {
    final value = entry.value;
    if (value == null) continue;
    if (value is String && value.trim().isEmpty) continue;
    next[entry.key] = value;
  }
  return next;
}
