import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'voice_command_recorder.dart';

class VoiceRecordingStatusCard extends StatelessWidget {
  const VoiceRecordingStatusCard({
    super.key,
    required this.recorder,
    required this.onStopAndSubmit,
    required this.onCancel,
  });

  final VoiceCommandRecorder recorder;
  final VoidCallback onStopAndSubmit;
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
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.border),
            ),
            borderRadius: BorderRadius.circular(20),
            color: scheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: error != null
                              ? AppColors.errorContainer
                              : recorder.recording
                              ? AppColors.errorContainer
                              : AppColors.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          error != null
                              ? Icons.error_outline
                              : recorder.reviewing
                              ? Icons.edit_note_outlined
                              : Icons.mic,
                          color: error != null || recorder.recording
                              ? AppColors.error
                              : AppColors.primary,
                        ),
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
                    const SizedBox(height: 8),
                    const Text(
                      'האודיו אינו נשמר',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: onStopAndSubmit,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.accent,
                          ),
                          icon: const Icon(Icons.stop_rounded),
                          label: const Text('סיים ושלח'),
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
