import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/pending_actions_icon_button.dart';
import '../auth/session_controller.dart';
import '../v2/v2_pending_actions_screen.dart';
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
    required this.onStartVoice,
    required this.onStopVoice,
    required this.onCancelVoice,
    required this.onOpenPendingActions,
    required this.onResolved,
    required this.pendingActionsCountFuture,
  });

  final SessionController controller;
  final VoiceCommandRecorder recorder;
  final List<AssistantConversationEntry> entries;
  final Future<void> Function(String transcript) onSubmitText;
  final VoidCallback onStartVoice;
  final VoidCallback onStopVoice;
  final VoidCallback onCancelVoice;
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
                  onMicPressed: widget.recorder.recording
                      ? widget.onStopVoice
                      : widget.onStartVoice,
                  onCancel: widget.onCancelVoice,
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
        onRecordAgain: widget.onStartVoice,
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
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'העוזרת שלך',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                Text(
                  'אפשר לדבר או לכתוב',
                  style: TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          ),
          PendingActionsIconButton(
            countFuture: pendingActionsCountFuture,
            onPressed: onOpenPendingActions,
          ),
        ],
      ),
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
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.result.title,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              if (entry.result.summary.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(entry.result.summary, style: const TextStyle(height: 1.4)),
              ],
              if (visibleItems.isNotEmpty) ...[
                const SizedBox(height: 14),
                ...visibleItems.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: VoiceResultItemCard(item: item),
                  ),
                ),
              ],
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: onOpenDetails,
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('קבלה ופעולות'),
              ),
            ],
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
}

class _AssistantComposer extends StatelessWidget {
  const _AssistantComposer({
    required this.controller,
    required this.busy,
    required this.recording,
    required this.onSend,
    required this.onMicPressed,
    required this.onCancel,
  });

  final TextEditingController controller;
  final bool busy;
  final bool recording;
  final VoidCallback onSend;
  final VoidCallback onMicPressed;
  final VoidCallback onCancel;

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
              return IconButton.filled(
                tooltip: recording ? 'סיום לבדיקה' : 'הקלטה',
                onPressed: onMicPressed,
                style: IconButton.styleFrom(
                  backgroundColor: recording
                      ? AppColors.accent
                      : AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                icon: Icon(recording ? Icons.stop_rounded : Icons.mic_rounded),
              );
            },
          ),
          if (recording)
            IconButton(
              tooltip: 'ביטול הקלטה',
              onPressed: onCancel,
              icon: const Icon(Icons.close),
            ),
        ],
      ),
    );
  }
}
