import 'package:flutter/material.dart';

import '../../api/api_client.dart';
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

  @override
  void initState() {
    super.initState();
    _recorder.addListener(_handleRecorderChanged);
    _load();
  }

  @override
  void dispose() {
    _recorder.removeListener(_handleRecorderChanged);
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('פקודות קוליות')),
      body: RefreshIndicator(
        onRefresh: () async => _load(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(
                      _recorder.recording ? Icons.mic : Icons.mic_none,
                      size: 44,
                      color: _recorder.recording
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _recorder.recording
                          ? 'מקליט פקודה קולית'
                          : 'אפשר לדבר במקום להקליד',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    if (_recorder.recording) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _recorder.inputLevel,
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _recorder.inputLevelMessage(),
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                    ],
                    FilledButton.icon(
                      onPressed: _recorder.uploading
                          ? null
                          : _recorder.recording
                          ? _stopAndUpload
                          : _recorder.start,
                      icon: Icon(_recorder.recording ? Icons.stop : Icons.mic),
                      label: Text(
                        _recorder.uploading
                            ? 'מעלה...'
                            : _recorder.recording
                            ? 'עצור ושלח'
                            : 'התחל הקלטה',
                      ),
                    ),
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
            const SizedBox(height: 16),
            FutureBuilder<List<_VoiceCommand>>(
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
                    title: 'לא הצלחנו לטעון היסטוריה',
                    body: _messageFor(snapshot.error),
                  );
                }
                final commands = snapshot.data ?? const <_VoiceCommand>[];
                if (commands.isEmpty) {
                  return const _InfoCard(
                    icon: Icons.history_toggle_off_outlined,
                    title: 'עדיין אין פקודות קוליות',
                    body: 'פקודות שתשלח מהאפליקציה יופיעו כאן.',
                  );
                }
                return Column(
                  children: commands
                      .map(
                        (command) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Card(
                            child: ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.graphic_eq),
                              ),
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
          .listVoiceCommands(
            businessId: session.businessId!,
            firebaseUid: session.firebaseUid,
            mockPhoneNumber: session.mockPhoneNumber,
          )
          .then(
            (json) => mapListValue(
              json['voiceCommands'],
            ).map(_VoiceCommand.fromJson).toList(),
          );
    });
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
          onRecordAgain: _recorder.start,
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
