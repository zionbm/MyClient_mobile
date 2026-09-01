import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../core/paging/paging_controller.dart';
import '../../core/paging/paged_list_view.dart';
import '../../models/page.dart' as pagination;
import '../../theme/app_theme.dart';
import '../../utils/date_formatting.dart';
import '../../utils/json_read.dart';
import '../ai/pending_actions_screen.dart';
import '../auth/session_controller.dart';
import 'voice_command_recorder.dart';
import 'voice_command_result_sheet.dart';

class VoiceCommandsScreen extends StatefulWidget {
  const VoiceCommandsScreen({super.key, required this.controller});

  final SessionController controller;

  @override
  State<VoiceCommandsScreen> createState() => _VoiceCommandsScreenState();
}

class _VoiceCommandsScreenState extends State<VoiceCommandsScreen> {
  final VoiceCommandRecorder _recorder = VoiceCommandRecorder();
  Future<List<_VoiceCommand>>? _future;
  late final PagingController<_VoiceCommand> _paging;

  @override
  void initState() {
    super.initState();
    _recorder.addListener(_handleRecorderChanged);
    _paging = PagingController<_VoiceCommand>(
      _loadPage,
      itemKey: (item) => item.id,
    );
    _load();
  }

  @override
  void dispose() {
    _recorder.removeListener(_handleRecorderChanged);
    _recorder.dispose();
    _paging.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const _VoiceCommandsHero(),
          Expanded(
            child: PagedListView<_VoiceCommand>(
              future: _future,
              onRefresh: _refresh,
              canLoadMore: _paging.canLoadMore,
              onLoadMore: _loadMore,
              loadMoreLabel: 'טען עוד פקודות',
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
              header: _VoiceRecorderCard(
                recorder: _recorder,
                onRecord: () => _recorder.start(widget.controller),
                onStop: _stopForReview,
                onSubmit: _submitReviewedTranscript,
                onCancel: _recorder.cancel,
              ),
              empty: const _InfoCard(
                icon: Icons.history_toggle_off_outlined,
                title: 'עדיין אין פקודות קוליות',
                body: 'מהפקודה הראשונה ואילך, ההיסטוריה שלך תופיע כאן.',
              ),
              errorBuilder: (context, error) => _InfoCard(
                icon: Icons.cloud_off_outlined,
                title: 'לא הצלחנו לטעון היסטוריה',
                body: _messageFor(error),
              ),
              itemBuilder: (context, command) =>
                  _VoiceCommandCard(command: command),
            ),
          ),
        ],
      ),
    );
  }

  void _load() {
    setState(() {
      _future = _paging.refresh().then((_) => _paging.items);
    });
  }

  Future<void> _refresh() async {
    _load();
    await _future;
  }

  Future<pagination.Page<_VoiceCommand>> _loadPage(String? cursor) async {
    final session = widget.controller.session!;
    final json = await widget.controller.apiClient.voice.list(
      businessId: session.businessId!,
      firebaseUid: session.firebaseUid,
      mockPhoneNumber: session.mockPhoneNumber,
      limit: 50,
      cursor: cursor,
    );
    return pagination.Page(
      items: mapListValue(
        json['voiceCommands'],
      ).map(_VoiceCommand.fromJson).toList(),
      pageInfo: pagination.PageInfo.fromJson(json['pageInfo']),
    );
  }

  Future<void> _loadMore() async {
    await _paging.loadMore();
    if (mounted) setState(() => _future = Future.value(_paging.items));
  }

  Future<void> _stopForReview() async {
    await _recorder.stopForReview();
  }

  Future<void> _submitReviewedTranscript() async {
    final result = await _recorder.submitReviewedTranscript(widget.controller);
    if (result == null) return;
    _load();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: VoiceCommandResultSheet(
          result: result.result,
          controller: widget.controller,
          onOpenPendingActions: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    PendingActionsScreen(controller: widget.controller),
              ),
            );
          },
          onRecordAgain: () => _recorder.start(widget.controller),
          onResolved: _load,
        ),
      ),
    );
    _recorder.acknowledgeResult();
  }

  String _messageFor(Object? error) {
    if (error is ApiException) return error.message;
    return 'בדוק שהשרת המקומי זמין.';
  }

  void _handleRecorderChanged() {
    if (mounted) setState(() {});
  }
}

class _VoiceCommandsHero extends StatelessWidget {
  const _VoiceCommandsHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 230,
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top + 8,
        16,
        24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          PositionedDirectional(
            top: 0,
            start: 0,
            child: IconButton(
              tooltip: 'חזרה',
              onPressed: () => Navigator.of(context).maybePop(),
              style: IconButton.styleFrom(foregroundColor: Colors.white),
              icon: const Icon(
                Icons.arrow_forward,
                textDirection: TextDirection.ltr,
              ),
            ),
          ),
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 31,
                backgroundColor: AppColors.primarySoft,
                foregroundColor: Colors.white,
                child: Icon(Icons.graphic_eq_rounded, size: 36),
              ),
              SizedBox(height: 13),
              Text(
                'פקודות קוליות',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 29,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'מדברים, ומייקליינט הופך את זה לפעולות',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFD4E6E4), fontSize: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VoiceRecorderCard extends StatelessWidget {
  const _VoiceRecorderCard({
    required this.recorder,
    required this.onRecord,
    required this.onStop,
    required this.onSubmit,
    required this.onCancel,
  });

  final VoiceCommandRecorder recorder;
  final VoidCallback onRecord;
  final VoidCallback onStop;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final active =
        recorder.recording ||
        recorder.preparing ||
        recorder.finalizing ||
        recorder.reviewing ||
        recorder.submitting;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: recorder.recording
              ? AppColors.accent.withValues(alpha: 0.6)
              : AppColors.border,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: active
                      ? const Color(0xFFFFE7E2)
                      : const Color(0xFFDDEEE9),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  recorder.recording
                      ? Icons.mic
                      : recorder.reviewing
                      ? Icons.edit_note_outlined
                      : recorder.preparing
                      ? Icons.hourglass_top
                      : Icons.mic_none,
                  color: active ? AppColors.accent : AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recorder.recording
                          ? 'מקליט פקודה קולית'
                          : recorder.reviewing
                          ? 'בדקו את התמלול לפני השליחה'
                          : recorder.submitting
                          ? 'שולח לעוזרת...'
                          : recorder.preparing
                          ? 'מכין את ההקלטה...'
                          : 'פקודה חדשה',
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      active
                          ? recorder.inputLevelMessage()
                          : 'לחצו על המיקרופון ודברו בטבעיות',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 64,
                height: 64,
                child: FloatingActionButton(
                  heroTag: 'voice-commands-record',
                  tooltip: recorder.recording
                      ? 'עצור לבדיקה'
                      : recorder.preparing
                      ? 'מכין הקלטה'
                      : 'פקודה קולית',
                  backgroundColor: recorder.recording
                      ? AppColors.accent
                      : AppColors.primary,
                  foregroundColor: Colors.white,
                  onPressed: recorder.uploading || recorder.preparing
                      ? null
                      : recorder.reviewing
                      ? onRecord
                      : recorder.recording
                      ? onStop
                      : onRecord,
                  child: Icon(
                    recorder.uploading
                        ? Icons.cloud_upload_outlined
                        : recorder.preparing
                        ? Icons.hourglass_top
                        : recorder.recording
                        ? Icons.stop
                        : Icons.mic,
                    size: 30,
                  ),
                ),
              ),
            ],
          ),
          if (recorder.recording || recorder.preparing) ...[
            const SizedBox(height: 15),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: recorder.preparing ? null : recorder.inputLevel,
                minHeight: 8,
                color: AppColors.accent,
                backgroundColor: const Color(0xFFFFE7E2),
              ),
            ),
            if (recorder.liveTranscript.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  recorder.liveTranscript,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            TextButton.icon(
              onPressed: onCancel,
              style: TextButton.styleFrom(foregroundColor: AppColors.accent),
              icon: const Icon(Icons.close),
              label: const Text('ביטול הקלטה'),
            ),
          ],
          if (recorder.reviewing) ...[
            const SizedBox(height: 15),
            TextFormField(
              key: const ValueKey('voice-commands-transcript-review'),
              initialValue: recorder.reviewTranscript,
              minLines: 2,
              maxLines: 5,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                labelText: 'התמלול שאישרת',
                border: OutlineInputBorder(),
              ),
              onChanged: recorder.updateReviewTranscript,
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: recorder.reviewTranscript.length >= 2
                      ? onSubmit
                      : null,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('שלח'),
                ),
                OutlinedButton.icon(
                  onPressed: onRecord,
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('הקלט מחדש'),
                ),
                TextButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.close),
                  label: const Text('ביטול'),
                ),
              ],
            ),
          ],
          if (recorder.error != null) ...[
            const SizedBox(height: 10),
            Text(
              recorder.error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _VoiceCommandCard extends StatelessWidget {
  const _VoiceCommandCard({required this.command});

  final _VoiceCommand command;

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
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Color(0xFFDDEEE9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.graphic_eq, color: AppColors.primary),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  command.transcript,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _VoiceCommandStatus(status: command.status),
                    if (command.createdAt != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.schedule_outlined,
                            size: 16,
                            color: AppColors.muted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            formatDateTime(command.createdAt),
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceCommandStatus extends StatelessWidget {
  const _VoiceCommandStatus({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toUpperCase();
    final failed = normalized == 'FAILED';
    final pending = normalized == 'PENDING' || normalized == 'PROCESSING';
    final color = failed
        ? Theme.of(context).colorScheme.error
        : pending
        ? AppColors.quote
        : const Color(0xFF137A52);
    final label = failed
        ? 'נכשלה'
        : pending
        ? 'בטיפול'
        : 'הושלמה';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _VoiceCommand {
  const _VoiceCommand({
    required this.transcript,
    required this.status,
    this.createdAt,
  });

  final String transcript;
  final String status;
  final DateTime? createdAt;
  String get id => '$transcript:${createdAt?.microsecondsSinceEpoch ?? 0}';

  factory _VoiceCommand.fromJson(Map<String, Object?> json) {
    return _VoiceCommand(
      transcript: stringValue(
        json['transcript'] ?? json['text'] ?? json['recognizedText'],
        fallback: 'פקודה קולית',
      ),
      status: stringValue(json['status'], fallback: 'נשלחה'),
      createdAt: dateValue(json['createdAt']),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                color: Color(0xFFDDEEE9),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: AppColors.primary),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
