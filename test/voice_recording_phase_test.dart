import 'package:flutter_test/flutter_test.dart';
import 'package:dev_mobile/src/features/voice/voice_command_recorder.dart';

void main() {
  test('PTT review happy path follows the V2 state machine', () {
    const path = [
      VoiceRecordingPhase.idle,
      VoiceRecordingPhase.preparing,
      VoiceRecordingPhase.recording,
      VoiceRecordingPhase.finalizingTranscript,
      VoiceRecordingPhase.reviewing,
      VoiceRecordingPhase.submitting,
      VoiceRecordingPhase.result,
      VoiceRecordingPhase.idle,
    ];

    for (var index = 0; index < path.length - 1; index += 1) {
      expect(
        isVoiceRecordingTransitionAllowed(path[index], path[index + 1]),
        isTrue,
      );
    }
  });

  test('review can re-record or return after a failed submission', () {
    expect(
      isVoiceRecordingTransitionAllowed(
        VoiceRecordingPhase.reviewing,
        VoiceRecordingPhase.preparing,
      ),
      isTrue,
    );
    expect(
      isVoiceRecordingTransitionAllowed(
        VoiceRecordingPhase.submitting,
        VoiceRecordingPhase.reviewing,
      ),
      isTrue,
    );
  });

  test('typed assistant message can submit directly from idle', () {
    expect(
      isVoiceRecordingTransitionAllowed(
        VoiceRecordingPhase.idle,
        VoiceRecordingPhase.submitting,
      ),
      isTrue,
    );
  });

  test('recording cannot skip transcript review and submit directly', () {
    expect(
      isVoiceRecordingTransitionAllowed(
        VoiceRecordingPhase.recording,
        VoiceRecordingPhase.submitting,
      ),
      isFalse,
    );
  });
}
