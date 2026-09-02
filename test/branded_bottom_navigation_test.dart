import 'package:dev_mobile/src/features/shell/widgets/branded_bottom_navigation.dart';
import 'package:dev_mobile/src/features/voice/voice_command_recorder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('labels the assistant and exposes tap and hold actions', (
    tester,
  ) async {
    int? selectedDestination;
    var voicePressed = false;
    var longPressStarted = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: BrandedBottomNavigation(
            selectedIndex: 0,
            voicePhase: VoiceRecordingPhase.idle,
            onDestinationSelected: (value) => selectedDestination = value,
            onVoicePressed: () => voicePressed = true,
            onVoiceLongPressStart: () => longPressStarted = true,
            onVoiceLongPressEnd: () {},
          ),
        ),
      ),
    );

    expect(find.text('עוזרת'), findsOneWidget);

    await tester.tap(find.text('יומן'));
    expect(selectedDestination, 1);

    await tester.tap(find.byIcon(Icons.mic_none_rounded));
    expect(voicePressed, isTrue);

    await tester.longPress(find.byIcon(Icons.mic_none_rounded));
    expect(longPressStarted, isTrue);
  });
}
