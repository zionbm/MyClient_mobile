import 'dart:convert';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

class AssistantSpeechPlayer {
  AssistantSpeechPlayer._();

  static final AudioPlayer _player = AudioPlayer();

  static Future<void> playBase64(String value) =>
      _player.play(BytesSource(Uint8List.fromList(base64Decode(value))));

  static Future<void> stop() => _player.stop();
}
