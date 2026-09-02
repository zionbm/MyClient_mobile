import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../core/network/idempotency_key.dart';
import '../../core/state/data_invalidator.dart';
import '../../services/assistant_speech_player.dart';
import '../../theme/app_theme.dart';
import '../../utils/json_read.dart';
import '../auth/session_controller.dart';
import 'voice_command_result.dart';
import 'voice_command_result_widgets.dart';

class VoiceCommandResultSheet extends StatefulWidget {
  const VoiceCommandResultSheet({
    super.key,
    required this.result,
    required this.controller,
    this.actionBatchId,
    this.onOpenPendingActions,
    this.onRecordAgain,
    this.onResolved,
  });

  final VoiceCommandResult result;
  final SessionController controller;
  final String? actionBatchId;
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
  bool _undoing = false;
  bool _undone = false;

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
      child: ColoredBox(
        color: AppColors.background,
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.82,
          minChildSize: 0.52,
          maxChildSize: 0.96,
          builder: (context, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _ResultHeader(
                  title: _result.title,
                  summary: _result.summary,
                  icon: _statusIcon(),
                  color: statusColor,
                  onClose: () => Navigator.of(context).pop(),
                ),
                if (_result.transcript != null) ...[
                  const SizedBox(height: 14),
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
                            ? widget.onOpenPendingActions
                            : null,
                        onApprove: null,
                        onReject: null,
                      ),
                    ),
                  ),
                if (_inlineError != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _inlineError!,
                            style: TextStyle(
                              color: colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                if (widget.actionBatchId != null) ...[
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _speakActionBatch,
                        icon: const Icon(Icons.volume_up_outlined),
                        label: const Text('השמעה'),
                      ),
                      TextButton.icon(
                        onPressed: AssistantSpeechPlayer.stop,
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: const Text('עצירה'),
                      ),
                      if (!_undone)
                        OutlinedButton.icon(
                          onPressed: _undoing ? null : _undoActionBatch,
                          icon: _undoing
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.undo),
                          label: const Text('ביטול הפעולה'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                if (_result.primaryAction != null)
                  FilledButton(
                    onPressed: () =>
                        _handleAction(context, _result.primaryAction!),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      _result.primaryAction!,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
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
      ),
    );
  }

  Future<void> _undoActionBatch() async {
    final session = widget.controller.session!;
    setState(() {
      _undoing = true;
      _inlineError = null;
    });
    try {
      final preview = await widget.controller.apiClient.v2ActionBatches.preview(
        businessId: session.businessId!,
        actionBatchId: widget.actionBatchId!,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
      );
      if (preview['eligible'] != true) {
        throw ApiException(
          stringValue(preview['reason'], fallback: 'לא ניתן לבטל את הפעולה'),
        );
      }
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('ביטול הפעולה'),
          content: Text(
            'הפעולה תשחזר ${preview['mutationCount']} שינויים. להמשיך?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('חזרה'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('ביטול הפעולה'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await widget.controller.apiClient.v2ActionBatches.undo(
        businessId: session.businessId!,
        actionBatchId: widget.actionBatchId!,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        idempotencyKey: IdempotencyKey.create('voice_result_undo'),
      );
      widget.controller.markDataChanged({DataScope.crm, DataScope.ai});
      widget.onResolved?.call();
      if (!mounted) return;
      setState(() => _undone = true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('הפעולה בוטלה')));
    } on ApiException catch (error) {
      if (mounted) setState(() => _inlineError = error.message);
    } finally {
      if (mounted) setState(() => _undoing = false);
    }
  }

  Future<void> _speakActionBatch() async {
    final session = widget.controller.session!;
    try {
      final speech = await widget.controller.apiClient.v2ActionBatches.speech(
        businessId: session.businessId!,
        actionBatchId: widget.actionBatchId!,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
      );
      final audio = nullableString(speech['audioBase64']);
      if (audio == null) {
        throw const ApiException(
          'שירות הקול עדיין במצב הדמיה; הטקסט נשאר זמין.',
        );
      }
      await AssistantSpeechPlayer.playBase64(audio);
    } on ApiException catch (error) {
      if (mounted) setState(() => _inlineError = error.message);
    }
  }

  void _handleAction(BuildContext context, String action) {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    if (action == 'אשר מאוחר יותר') {
      widget.controller.refreshPendingActions();
      messenger.showSnackBar(
        const SnackBar(content: Text('שמרתי לאישור מאוחר יותר')),
      );
      return;
    }
    if (action == 'פתח פעולות AI') {
      widget.onOpenPendingActions?.call();
      return;
    }
    if (action == 'הקלט שוב') {
      widget.onRecordAgain?.call();
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
        final customer = await widget.controller.apiClient.v2Customers.create(
          businessId: session.businessId!,
          firebaseUid: session.firebaseUid,
          mockPhoneNumber: session.mockPhoneNumber,
          idempotencyKey: IdempotencyKey.create('manual_customer'),
          body: {
            'name': payload['name'],
            if (payload['email'] != null) 'email': payload['email'],
          },
        );
        final phone = payload['phone']?.toString().trim();
        if (phone?.isNotEmpty == true) {
          await widget.controller.apiClient.v2Customers.addPhone(
            businessId: session.businessId!,
            customerId: customer.id,
            firebaseUid: session.firebaseUid,
            mockPhoneNumber: session.mockPhoneNumber,
            idempotencyKey: IdempotencyKey.create('manual_customer_phone'),
            body: {'phone': phone, 'isPrimary': true},
          );
        }
      } else {
        await widget.controller.apiClient.v2Tasks.create(
          businessId: session.businessId!,
          firebaseUid: session.firebaseUid,
          mockPhoneNumber: session.mockPhoneNumber,
          idempotencyKey: IdempotencyKey.create('manual_task'),
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

class _ResultHeader extends StatelessWidget {
  const _ResultHeader({
    required this.title,
    required this.summary,
    required this.icon,
    required this.color,
    required this.onClose,
  });

  final String title;
  final String summary;
  final IconData icon;
  final Color color;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  summary,
                  style: const TextStyle(color: AppColors.muted, height: 1.4),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'סגור',
            onPressed: onClose,
            color: AppColors.muted,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _TranscriptCard extends StatelessWidget {
  const _TranscriptCard({required this.transcript});

  final String transcript;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Text(
                  'מה שמעתי',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.mic_none_outlined, color: AppColors.primary),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              transcript,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 16,
                height: 1.45,
              ),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                unsupported
                    ? Icons.rule_folder_outlined
                    : Icons.mic_off_outlined,
                color: AppColors.primary,
                size: 30,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              unsupported
                  ? 'אפשר ליצור לקוחות, תזכורות, ביקורי בית, הצעות מחיר והערות.'
                  : 'לא נוצרו שינויים במערכת.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, height: 1.4),
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
