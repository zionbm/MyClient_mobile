import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../core/paging/paging_controller.dart';
import '../../core/paging/paged_list_view.dart';
import '../../models/page.dart' as pagination;
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
      appBar: AppBar(title: const Text('פקודות קוליות')),
      body: PagedListView<_VoiceCommand>(
        future: _future,
        onRefresh: _refresh,
        canLoadMore: _paging.canLoadMore,
        onLoadMore: _loadMore,
        loadMoreLabel: 'טען עוד פקודות',
        header: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(
                  _recorder.recording
                      ? Icons.mic
                      : _recorder.preparing
                      ? Icons.hourglass_top
                      : Icons.mic_none,
                  size: 44,
                  color: _recorder.recording || _recorder.preparing
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  _recorder.recording
                      ? 'מקליט פקודה קולית'
                      : _recorder.preparing
                      ? 'מכין הקלטה...'
                      : 'אפשר לדבר במקום להקליד',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (_recorder.recording || _recorder.preparing) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _recorder.preparing ? null : _recorder.inputLevel,
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _recorder.inputLevelMessage(),
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  if (_recorder.liveTranscript.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      _recorder.liveTranscript,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: 76,
                  height: 76,
                  child: FloatingActionButton.large(
                    heroTag: 'voice-commands-record',
                    tooltip: _recorder.recording
                        ? 'עצור ושלח'
                        : _recorder.preparing
                        ? 'מכין הקלטה'
                        : 'פקודה קולית',
                    onPressed: _recorder.uploading || _recorder.preparing
                        ? null
                        : _recorder.recording
                        ? _stopAndUpload
                        : () => _recorder.start(widget.controller),
                    child: Icon(
                      _recorder.uploading
                          ? Icons.cloud_upload_outlined
                          : _recorder.preparing
                          ? Icons.hourglass_top
                          : _recorder.recording
                          ? Icons.stop
                          : Icons.mic,
                      size: 34,
                    ),
                  ),
                ),
                if (_recorder.recording || _recorder.preparing) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _recorder.cancel,
                    icon: const Icon(Icons.close),
                    label: const Text('ביטול הקלטה'),
                  ),
                ],
                if (_recorder.error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _recorder.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
        empty: const _InfoCard(
          icon: Icons.history_toggle_off_outlined,
          title: 'עדיין אין פקודות קוליות',
          body: 'פקודות שתשלח מהאפליקציה יופיעו כאן.',
        ),
        errorBuilder: (context, error) => _InfoCard(
          icon: Icons.cloud_off_outlined,
          title: 'לא הצלחנו לטעון היסטוריה',
          body: _messageFor(error),
        ),
        itemBuilder: (context, command) => Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.graphic_eq)),
            title: Text(command.transcript),
            subtitle: Text(
              [
                command.status,
                if (command.createdAt != null)
                  formatDateTime(command.createdAt),
              ].join(' · '),
            ),
          ),
        ),
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

  Future<void> _stopAndUpload() async {
    final result = await _recorder.stopAndUpload(widget.controller);
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
  }

  String _messageFor(Object? error) {
    if (error is ApiException) return error.message;
    return 'בדוק שהשרת המקומי זמין.';
  }

  void _handleRecorderChanged() {
    if (mounted) setState(() {});
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
