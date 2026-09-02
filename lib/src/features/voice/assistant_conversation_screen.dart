import 'package:flutter/material.dart';

import '../../core/network/idempotency_key.dart';
import '../../core/state/data_invalidator.dart';
import '../../models/v2_activity.dart';
import '../../models/v2_customer.dart';
import '../../theme/app_theme.dart';
import '../../utils/json_read.dart';
import '../../widgets/pending_actions_icon_button.dart';
import '../../widgets/main_top_bar.dart';
import '../auth/session_controller.dart';
import '../v2/v2_pending_actions_screen.dart';
import '../v2/v2_activity_detail_screen.dart';
import '../v2/v2_customers_screen.dart';
import 'voice_command_recorder.dart';
import 'voice_command_result.dart';
import 'voice_command_result_sheet.dart';
import 'voice_command_result_widgets.dart';

class AssistantConversationEntry {
  const AssistantConversationEntry({
    required this.transcript,
    required this.result,
    this.actionBatchId,
  });

  final String transcript;
  final VoiceCommandResult result;
  final String? actionBatchId;
}

class AssistantConversationScreen extends StatefulWidget {
  const AssistantConversationScreen({
    super.key,
    required this.controller,
    required this.recorder,
    required this.entries,
    required this.onSubmitText,
    required this.onOpenPendingActions,
    required this.onResolved,
    required this.pendingActionsCountFuture,
  });

  final SessionController controller;
  final VoiceCommandRecorder recorder;
  final List<AssistantConversationEntry> entries;
  final Future<void> Function(String transcript) onSubmitText;
  final VoidCallback onOpenPendingActions;
  final VoidCallback onResolved;
  final Future<int>? pendingActionsCountFuture;

  @override
  State<AssistantConversationScreen> createState() =>
      _AssistantConversationScreenState();
}

class _AssistantConversationScreenState
    extends State<AssistantConversationScreen> {
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant AssistantConversationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entries.length != widget.entries.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
    }
  }

  @override
  void dispose() {
    _composer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.recorder,
      builder: (context, _) {
        final busy = widget.recorder.preparing || widget.recorder.uploading;
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _AssistantHeader(
                  onOpenPendingActions: widget.onOpenPendingActions,
                  pendingActionsCountFuture: widget.pendingActionsCountFuture,
                ),
                Expanded(
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    children: [
                      if (widget.entries.isEmpty)
                        _AssistantWelcome(onSuggestion: _submitSuggestion)
                      else
                        ...widget.entries.map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(top: 12, bottom: 6),
                            child: _ConversationTurn(
                              entry: entry,
                              controller: widget.controller,
                              pendingActionsRefreshKey:
                                  widget.pendingActionsCountFuture,
                              onResolved: widget.onResolved,
                              onOpenDetails: () => _openDetails(entry),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                _AssistantComposer(
                  controller: _composer,
                  busy: busy,
                  recording: widget.recorder.recording,
                  onSend: _submitComposer,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitComposer() async {
    final text = _composer.text.trim();
    if (text.length < 2) return;
    _composer.clear();
    await widget.onSubmitText(text);
  }

  void _submitSuggestion(String text) {
    _composer.text = text;
    _submitComposer();
  }

  Future<void> _openDetails(AssistantConversationEntry entry) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => VoiceCommandResultSheet(
        result: entry.result,
        actionBatchId: entry.actionBatchId,
        controller: widget.controller,
        onOpenPendingActions: widget.onOpenPendingActions,
        onResolved: widget.onResolved,
      ),
    );
  }

  void _scrollToEnd() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }
}

class _AssistantHeader extends StatelessWidget {
  const _AssistantHeader({
    required this.onOpenPendingActions,
    required this.pendingActionsCountFuture,
  });

  final VoidCallback onOpenPendingActions;
  final Future<int>? pendingActionsCountFuture;

  @override
  Widget build(BuildContext context) {
    return MainTopBar(
      title: 'העוזרת שלך',
      subtitle: 'אפשר לדבר מהכפתור הראשי או לכתוב כאן',
      includeSafeArea: false,
      leading: Container(
        width: 42,
        height: 42,
        decoration: const BoxDecoration(
          color: AppColors.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.auto_awesome, color: AppColors.primary),
      ),
      actions: [
        PendingActionsIconButton(
          countFuture: pendingActionsCountFuture,
          onPressed: onOpenPendingActions,
        ),
      ],
    );
  }
}

class _AssistantWelcome extends StatelessWidget {
  const _AssistantWelcome({required this.onSuggestion});

  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    const suggestions = [
      'מה נשאר לי פתוח היום?',
      'מצא לי שעה פנויה מחר',
      'אני רוצה לרשום פנייה חדשה',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 32, 4, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome, size: 46, color: AppColors.primary),
          const SizedBox(height: 16),
          Text(
            'מה תרצה לעשות?',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'אפשר לרשום לקוח, לקבוע עבודה, לעדכן תשלום או לשאול על היום שלך.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, height: 1.45),
          ),
          const SizedBox(height: 24),
          ...suggestions.map(
            (suggestion) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OutlinedButton(
                onPressed: () => onSuggestion(suggestion),
                style: OutlinedButton.styleFrom(
                  alignment: AlignmentDirectional.centerStart,
                  minimumSize: const Size.fromHeight(52),
                ),
                child: Text(suggestion),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 16, color: AppColors.muted),
              SizedBox(width: 6),
              Text(
                'האודיו אינו נשמר',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConversationTurn extends StatelessWidget {
  const _ConversationTurn({
    required this.entry,
    required this.controller,
    required this.pendingActionsRefreshKey,
    required this.onResolved,
    required this.onOpenDetails,
  });

  final AssistantConversationEntry entry;
  final SessionController controller;
  final Object? pendingActionsRefreshKey;
  final VoidCallback onResolved;
  final VoidCallback onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final actionBatchId = entry.actionBatchId;
    final visibleItems = entry.result.items
        .where(
          (item) =>
              !item.isReadOnly &&
              (actionBatchId == null || item.status != 'pending'),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 330),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(entry.transcript),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 340),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.auto_awesome,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.result.summary.isNotEmpty
                        ? entry.result.summary
                        : entry.result.title,
                    style: const TextStyle(height: 1.45),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (visibleItems.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsetsDirectional.only(start: 4, bottom: 6),
            child: Text(
              'פעולות שבוצעו',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ...visibleItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: VoiceResultItemCard(
                item: item,
                compact: true,
                onTap: () => _openItem(context, item),
                footer: _shouldOfferPhone(item, visibleItems)
                    ? _CreatedCustomerPhoneField(
                        item: item,
                        controller: controller,
                        onSaved: onResolved,
                      )
                    : null,
              ),
            ),
          ),
        ],
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: onOpenDetails,
            icon: const Icon(Icons.receipt_long_outlined, size: 18),
            label: const Text('פרטי הפעולה'),
          ),
        ),
        if (actionBatchId != null) ...[
          const SizedBox(height: 10),
          V2PendingActionsPanel(
            key: ValueKey(
              '$actionBatchId:${identityHashCode(pendingActionsRefreshKey)}',
            ),
            controller: controller,
            compact: true,
            showHeader: false,
            status: 'ALL',
            actionBatchId: actionBatchId,
            onChanged: onResolved,
          ),
        ],
      ],
    );
  }

  bool _shouldOfferPhone(
    VoiceCommandResultItem item,
    List<VoiceCommandResultItem> turnItems,
  ) {
    final phoneWasAddedInTurn = turnItems.any(
      (candidate) =>
          candidate.actionType == 'ADD_CUSTOMER_PHONE' &&
          candidate.payload['customerId'] == item.entityId,
    );
    return item.actionType == 'CREATE_CUSTOMER' &&
        item.status != 'pending' &&
        item.entityId != null &&
        !phoneWasAddedInTurn &&
        (item.payload['phone']?.toString().trim().isEmpty ?? true);
  }

  Future<void> _openItem(
    BuildContext context,
    VoiceCommandResultItem item,
  ) async {
    final session = controller.session;
    if (session?.businessId == null) return;
    final customerId =
        item.actionType.contains('CUSTOMER') &&
            item.actionType != 'ADD_CUSTOMER_PHONE' &&
            !item.actionType.contains('PHONE')
        ? item.entityId
        : nullableString(item.payload['customerId']);
    if (customerId != null &&
        (item.actionType.contains('CUSTOMER') ||
            item.actionType == 'ADD_CUSTOMER_PHONE')) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => V2CustomerDetailScreen(
            controller: controller,
            customerId: customerId,
          ),
        ),
      );
      onResolved();
      return;
    }
    if (item.actionType.contains('NOTE') &&
        item.entityId != null &&
        customerId != null) {
      final customer = await controller.apiClient.v2Customers.get(
        businessId: session!.businessId!,
        customerId: customerId,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
      );
      V2Note? note;
      for (final candidate in customer.notes) {
        if (candidate.id == item.entityId) {
          note = candidate;
          break;
        }
      }
      if (!context.mounted) return;
      if (note == null) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => V2CustomerDetailScreen(
              controller: controller,
              customerId: customerId,
            ),
          ),
        );
      } else {
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => V2NoteForm(
            controller: controller,
            customerId: customerId,
            note: note,
          ),
        );
      }
      onResolved();
      return;
    }
    if (item.actionType.contains('TASK') && item.entityId != null) {
      final task = await controller.apiClient.v2Tasks.get(
        businessId: session!.businessId!,
        taskId: item.entityId!,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
      );
      if (!context.mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => V2TaskForm(controller: controller, task: task),
      );
      onResolved();
      return;
    }
    final kind = item.actionType.contains('JOB')
        ? V2ActivityKind.job
        : item.actionType.contains('VISIT')
        ? V2ActivityKind.visit
        : null;
    if (kind != null && item.entityId != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => V2ActivityDetailScreen(
            controller: controller,
            kind: kind,
            activityId: item.entityId!,
          ),
        ),
      );
      onResolved();
      return;
    }
    onOpenDetails();
  }
}

class _CreatedCustomerPhoneField extends StatefulWidget {
  const _CreatedCustomerPhoneField({
    required this.item,
    required this.controller,
    required this.onSaved,
  });

  final VoiceCommandResultItem item;
  final SessionController controller;
  final VoidCallback onSaved;

  @override
  State<_CreatedCustomerPhoneField> createState() =>
      _CreatedCustomerPhoneFieldState();
}

class _CreatedCustomerPhoneFieldState
    extends State<_CreatedCustomerPhoneField> {
  final TextEditingController _phone = TextEditingController();
  bool _saving = false;
  bool _saved = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_saved) {
      return Row(
        children: [
          const Icon(Icons.check_circle, size: 18, color: AppColors.success),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              'הטלפון ${_phone.text.trim()} נוסף ללקוח',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'אפשר להדביק כאן מספר טלפון ולהוסיף אותו ללקוח שנוצר.',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 7),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _phone,
                enabled: !_saving,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.left,
                decoration: InputDecoration(
                  hintText: 'הדבקת מספר טלפון',
                  errorText: _error,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 10,
                  ),
                ),
                onSubmitted: (_) => _save(),
              ),
            ),
            const SizedBox(width: 7),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size(68, 42),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              child: _saving
                  ? const SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('שמור'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _save() async {
    final phone = _phone.text.trim();
    if (phone.length < 7) {
      setState(() => _error = 'יש להזין מספר טלפון תקין');
      return;
    }
    final session = widget.controller.session;
    if (session?.businessId == null || widget.item.entityId == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.controller.apiClient.v2Customers.addPhone(
        businessId: session!.businessId!,
        customerId: widget.item.entityId!,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        idempotencyKey: IdempotencyKey.create('assistant_customer_phone'),
        body: {'phone': phone, 'isPrimary': true},
      );
      widget.controller.markDataChanged({DataScope.crm, DataScope.ai});
      widget.onSaved();
      if (mounted) setState(() => _saved = true);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'לא הצלחנו לשמור את המספר');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _AssistantComposer extends StatelessWidget {
  const _AssistantComposer({
    required this.controller,
    required this.busy,
    required this.recording,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool busy;
  final bool recording;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        10,
        12,
        10 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !busy && !recording,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: const InputDecoration(
                hintText: 'כתבו לעוזרת…',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (busy) {
                return const SizedBox.square(
                  dimension: 48,
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                );
              }
              if (value.text.trim().isNotEmpty && !recording) {
                return IconButton.filled(
                  tooltip: 'שליחה',
                  onPressed: onSend,
                  icon: const Icon(Icons.send_rounded),
                );
              }
              return const SizedBox(width: 4);
            },
          ),
        ],
      ),
    );
  }
}
