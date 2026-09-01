import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'voice_command_recorder.dart';

class VoiceRecordingStatusCard extends StatelessWidget {
  const VoiceRecordingStatusCard({
    super.key,
    required this.recorder,
    required this.onStopForReview,
    required this.onSubmit,
    required this.onRecordAgain,
    required this.onCancel,
  });

  final VoiceCommandRecorder recorder;
  final VoidCallback onStopForReview;
  final VoidCallback onSubmit;
  final VoidCallback onRecordAgain;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final error = recorder.error;
    if (!recorder.recording &&
        !recorder.preparing &&
        !recorder.uploading &&
        !recorder.reviewing &&
        error == null) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            color: scheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        error != null
                            ? Icons.error_outline
                            : recorder.reviewing
                            ? Icons.edit_note_outlined
                            : Icons.mic,
                        color: error != null ? scheme.error : scheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          error ?? recorder.inputLevelMessage(),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  if (recorder.recording) ...[
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: recorder.inputLevel,
                      minHeight: 6,
                    ),
                    if (recorder.liveTranscript.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        recorder.liveTranscript,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: onStopForReview,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.accent,
                          ),
                          icon: const Icon(Icons.stop_rounded),
                          label: const Text('עצור לבדיקה'),
                        ),
                        TextButton.icon(
                          onPressed: onCancel,
                          icon: const Icon(Icons.close),
                          label: const Text('ביטול'),
                        ),
                      ],
                    ),
                  ] else if (recorder.reviewing) ...[
                    const SizedBox(height: 10),
                    TextFormField(
                      key: const ValueKey('voice-transcript-review'),
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
                    const SizedBox(height: 10),
                    Wrap(
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
                          onPressed: onRecordAgain,
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
                  ] else if (recorder.preparing) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: onCancel,
                      icon: const Icon(Icons.close),
                      label: const Text('ביטול'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
