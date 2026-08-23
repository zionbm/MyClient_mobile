import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../api/api_client.dart';
import '../../utils/date_formatting.dart';
import '../../utils/json_read.dart';
import '../auth/session_controller.dart';

class VoiceCommandsScreen extends StatefulWidget {
  const VoiceCommandsScreen({super.key, required this.controller});

  final SessionController controller;

  @override
  State<VoiceCommandsScreen> createState() => _VoiceCommandsScreenState();
}

class _VoiceCommandsScreenState extends State<VoiceCommandsScreen> {
  final AudioRecorder _recorder = AudioRecorder();
  Future<List<_VoiceCommand>>? _future;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  bool _recording = false;
  bool _uploading = false;
  double _inputLevel = 0;
  double _peakInputDb = -160;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amplitudeSubscription?.cancel();
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
                      _recording ? Icons.mic : Icons.mic_none,
                      size: 44,
                      color: _recording
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _recording
                          ? 'מקליט פקודה קולית'
                          : 'אפשר לדבר במקום להקליד',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    if (_recording) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _inputLevel,
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _inputLevelMessage(),
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                    ],
                    FilledButton.icon(
                      onPressed: _uploading
                          ? null
                          : _recording
                          ? _stopAndUpload
                          : _startRecording,
                      icon: Icon(_recording ? Icons.stop : Icons.mic),
                      label: Text(
                        _uploading
                            ? 'מעלה...'
                            : _recording
                            ? 'עצור ושלח'
                            : 'התחל הקלטה',
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
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

  Future<void> _startRecording() async {
    setState(() => _error = null);
    try {
      if (!await _recorder.hasPermission()) {
        setState(() => _error = 'צריך לאשר גישה למיקרופון');
        return;
      }
      final tempDir = await getTemporaryDirectory();
      final path =
          '${tempDir.path}/myclient_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          numChannels: 1,
          androidConfig: AndroidRecordConfig(
            useLegacy: true,
            audioSource: AndroidAudioSource.voiceRecognition,
            manageBluetooth: false,
          ),
        ),
        path: path,
      );
      await _amplitudeSubscription?.cancel();
      _amplitudeSubscription = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 250))
          .listen(_updateInputLevel);
      if (mounted) {
        setState(() {
          _recording = true;
          _inputLevel = 0;
          _peakInputDb = -160;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'לא הצלחנו להתחיל הקלטה');
    }
  }

  Future<void> _stopAndUpload() async {
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final path = await _recorder.stop();
      await _amplitudeSubscription?.cancel();
      _amplitudeSubscription = null;
      if (mounted) setState(() => _recording = false);
      if (path == null) {
        setState(() => _error = 'לא נשמר קובץ הקלטה');
        return;
      }
      if (_peakInputDb < -50) {
        setState(() {
          _uploading = false;
          _error =
              'לא זוהה קלט מהמיקרופון. בדוק שהאמולטור מקבל את המיקרופון של המחשב.';
        });
        return;
      }
      final file = File(path);
      final bytes = await file.readAsBytes();
      final session = widget.controller.session!;
      final result = await widget.controller.apiClient.uploadVoiceCommandAudio(
        businessId: session.businessId!,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        bytes: bytes,
        idempotencyKey:
            'voice_${DateTime.now().microsecondsSinceEpoch}_${bytes.length}',
      );
      widget.controller.markDataChanged();
      _load();
      if (!mounted) return;
      final execution = mapValue(result['execution']);
      final status = stringValue(execution['status']);
      final message = status == 'PARTIAL_PENDING'
          ? 'הפקודה נקלטה וממתינה לאישור במסך פעולות AI'
          : 'הפקודה הקולית נשלחה';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(() => _error = 'לא הצלחנו לשלוח את ההקלטה');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _updateInputLevel(Amplitude amplitude) {
    final db = amplitude.current.isFinite ? amplitude.current : -160.0;
    final normalized = ((db + 60) / 60).clamp(0.0, 1.0).toDouble();
    if (!mounted) return;
    setState(() {
      _inputLevel = normalized;
      if (amplitude.max > _peakInputDb) _peakInputDb = amplitude.max;
    });
  }

  String _inputLevelMessage() {
    if (_inputLevel < 0.08) return 'לא מזוהה קלט מהמיקרופון';
    if (_inputLevel > 0.95) return 'הקלט חזק מדי או רווי';
    return 'המיקרופון קולט';
  }

  String _messageFor(Object? error) {
    if (error is ApiException) return error.message;
    return 'בדוק שהשרת המקומי זמין.';
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
