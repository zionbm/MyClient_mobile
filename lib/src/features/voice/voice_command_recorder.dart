import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import '../../api/api_client.dart';
import '../../utils/json_read.dart';
import '../auth/session_controller.dart';
import 'voice_command_result.dart';

class VoiceCommandUploadResult {
  const VoiceCommandUploadResult({required this.result});

  final VoiceCommandResult result;
}

enum VoiceRecordingPhase { idle, preparing, recording, finishing, cancelled }

class VoiceCommandRecorder extends ChangeNotifier {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _audioSubscription;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  StreamSubscription<dynamic>? _socketSubscription;
  WebSocket? _socket;
  Completer<void>? _firstCompletion;

  VoiceRecordingPhase _phase = VoiceRecordingPhase.idle;
  double _inputLevel = 0;
  double _peakInputDb = -160;
  String _liveTranscript = '';
  String? _error;
  bool _cancelRequested = false;
  bool _socketReady = false;
  final Map<String, StringBuffer> _deltaByItem = {};
  final Map<String, String> _completedByItem = {};

  bool get preparing => _phase == VoiceRecordingPhase.preparing;
  bool get recording => _phase == VoiceRecordingPhase.recording;
  bool get uploading => _phase == VoiceRecordingPhase.finishing;
  bool get finishing => _phase == VoiceRecordingPhase.finishing;
  double get inputLevel => _inputLevel;
  String? get error => _error;
  String get liveTranscript => _liveTranscript.trim();

  Future<void> start(SessionController controller) async {
    if (_phase != VoiceRecordingPhase.idle &&
        _phase != VoiceRecordingPhase.cancelled) {
      return;
    }
    _resetForNewRecording();
    _phase = VoiceRecordingPhase.preparing;
    notifyListeners();
    try {
      if (!await _recorder.hasPermission()) {
        _error = 'צריך לאשר גישה למיקרופון';
        _phase = VoiceRecordingPhase.idle;
        notifyListeners();
        return;
      }
      final session = controller.session!;
      final realtimeSession = await controller.apiClient
          .createVoiceRealtimeSession(
            businessId: session.businessId!,
            firebaseUid: session.firebaseUid,
            mockPhoneNumber: session.mockPhoneNumber,
          );
      if (_cancelRequested) {
        _phase = VoiceRecordingPhase.cancelled;
        notifyListeners();
        return;
      }
      final token = stringValue(realtimeSession['value']);
      if (token.isEmpty) {
        throw const FormatException('Missing realtime client secret');
      }
      _socket = await WebSocket.connect(
        'wss://api.openai.com/v1/realtime?intent=transcription',
        headers: {'Authorization': 'Bearer $token'},
      );
      _socketReady = true;
      _socketSubscription = _socket!.listen(
        _handleServerEvent,
        onError: (_) {
          _error = 'החיבור לתמלול החי נכשל';
          notifyListeners();
        },
        onDone: () {
          _socketReady = false;
          notifyListeners();
        },
      );
      if (_cancelRequested) {
        await cancel();
        return;
      }
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 24000,
          numChannels: 1,
          streamBufferSize: 4096,
          noiseSuppress: false,
          androidConfig: AndroidRecordConfig(
            audioSource: AndroidAudioSource.mic,
            manageBluetooth: false,
          ),
        ),
      );
      _audioSubscription = stream.listen(_sendAudioChunk);
      await _amplitudeSubscription?.cancel();
      _amplitudeSubscription = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 250))
          .listen(_updateInputLevel);
      _phase = VoiceRecordingPhase.recording;
      notifyListeners();
    } on ApiException catch (error) {
      await _cleanupRealtimeResources();
      _error = error.message;
      _phase = VoiceRecordingPhase.idle;
      notifyListeners();
    } catch (_) {
      await _cleanupRealtimeResources();
      _error = 'לא הצלחנו להתחיל הקלטה';
      _phase = VoiceRecordingPhase.idle;
      notifyListeners();
    }
  }

  Future<VoiceCommandUploadResult?> stopAndUpload(
    SessionController controller,
  ) async {
    if (!recording) return null;
    _phase = VoiceRecordingPhase.finishing;
    _error = null;
    notifyListeners();
    try {
      await _audioSubscription?.cancel();
      _audioSubscription = null;
      await _recorder.stop();
      await _amplitudeSubscription?.cancel();
      _amplitudeSubscription = null;
      if (_peakInputDb < -50) {
        _error =
            'לא זוהה קלט מהמיקרופון. בדוק שהאמולטור מקבל את המיקרופון של המחשב.';
        return null;
      }
      if (_socketReady) {
        _socket?.add(jsonEncode({'type': 'input_audio_buffer.commit'}));
        await _firstCompletion?.future.timeout(
          const Duration(seconds: 4),
          onTimeout: () {},
        );
      }
      final transcript = liveTranscript;
      await _cleanupRealtimeResources();
      if (transcript.length < 2) {
        _error = 'לא זוהה דיבור ברור בהקלטה';
        return null;
      }
      final session = controller.session!;
      final result = await controller.apiClient.submitVoiceCommandTranscript(
        businessId: session.businessId!,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        transcript: transcript,
        idempotencyKey:
            'voice_text_${DateTime.now().microsecondsSinceEpoch}_${transcript.length}',
      );
      controller.markDataChanged();
      final voiceResult = mapValue(result['voiceResult']);
      return VoiceCommandUploadResult(
        result: voiceResult.isEmpty
            ? VoiceCommandResult.fallback()
            : VoiceCommandResult.fromJson(voiceResult),
      );
    } on ApiException catch (error) {
      if (error.statusCode != 401) {
        return VoiceCommandUploadResult(
          result: VoiceCommandResult.fallback(message: error.message),
        );
      }
      _error = error.message;
      return null;
    } catch (_) {
      _error = 'לא הצלחנו לשלוח את התמלול';
      return null;
    } finally {
      await _cleanupRealtimeResources();
      _phase = VoiceRecordingPhase.idle;
      notifyListeners();
    }
  }

  Future<void> cancel() async {
    _cancelRequested = true;
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    if (recording) {
      await _recorder.stop().catchError((_) => null);
    }
    await _cleanupRealtimeResources();
    _phase = VoiceRecordingPhase.cancelled;
    _error = null;
    notifyListeners();
  }

  String inputLevelMessage() {
    if (preparing) return 'מכין הקלטה...';
    if (finishing) return 'מסיים ומפענח...';
    if (_inputLevel < 0.08) return 'לא מזוהה קלט מהמיקרופון';
    if (_inputLevel > 0.95) return 'הקלט חזק מדי או רווי';
    return 'המיקרופון קולט';
  }

  void acknowledgeCancellation() {
    if (_phase == VoiceRecordingPhase.cancelled) {
      _phase = VoiceRecordingPhase.idle;
      notifyListeners();
    }
  }

  void _sendAudioChunk(Uint8List chunk) {
    if (!_socketReady || chunk.isEmpty) return;
    _socket?.add(
      jsonEncode({
        'type': 'input_audio_buffer.append',
        'audio': base64Encode(chunk),
      }),
    );
  }

  void _handleServerEvent(dynamic message) {
    if (message is! String) return;
    final event = jsonDecode(message);
    if (event is! Map<String, dynamic>) return;
    final type = event['type'];
    if (type == 'conversation.item.input_audio_transcription.delta') {
      final itemId = event['item_id']?.toString() ?? 'live';
      final delta = event['delta']?.toString() ?? '';
      if (delta.isEmpty) return;
      _deltaByItem.putIfAbsent(itemId, StringBuffer.new).write(delta);
      _rebuildTranscript();
      notifyListeners();
      return;
    }
    if (type == 'conversation.item.input_audio_transcription.completed') {
      final itemId = event['item_id']?.toString() ?? 'live';
      final transcript = event['transcript']?.toString().trim() ?? '';
      if (transcript.isNotEmpty) {
        _completedByItem[itemId] = transcript;
        _deltaByItem.remove(itemId);
        _rebuildTranscript();
      }
      if (_firstCompletion?.isCompleted == false) {
        _firstCompletion?.complete();
      }
      notifyListeners();
      return;
    }
    if (type == 'conversation.item.input_audio_transcription.segment') {
      final text = event['text']?.toString().trim() ?? '';
      if (text.isNotEmpty && !_liveTranscript.contains(text)) {
        _liveTranscript = [_liveTranscript, text]
            .where((part) {
              return part.trim().isNotEmpty;
            })
            .join(' ');
        notifyListeners();
      }
      return;
    }
    if (type == 'error') {
      final error = event['error'];
      if (error is Map && error['message'] != null) {
        _error = error['message'].toString();
        notifyListeners();
      }
    }
  }

  void _rebuildTranscript() {
    final completed = _completedByItem.values;
    final deltas = _deltaByItem.values.map((buffer) => buffer.toString());
    _liveTranscript = [
      ...completed,
      ...deltas,
    ].map((part) => part.trim()).where((part) => part.isNotEmpty).join(' ');
  }

  void _updateInputLevel(Amplitude amplitude) {
    final db = amplitude.current.isFinite ? amplitude.current : -160.0;
    final normalized = ((db + 60) / 60).clamp(0.0, 1.0).toDouble();
    _inputLevel = normalized;
    if (amplitude.max > _peakInputDb) _peakInputDb = amplitude.max;
    notifyListeners();
  }

  void _resetForNewRecording() {
    _cancelRequested = false;
    _socketReady = false;
    _inputLevel = 0;
    _peakInputDb = -160;
    _liveTranscript = '';
    _error = null;
    _deltaByItem.clear();
    _completedByItem.clear();
    _firstCompletion = Completer<void>();
  }

  Future<void> _cleanupRealtimeResources() async {
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    await _socketSubscription?.cancel();
    _socketSubscription = null;
    await _socket?.close();
    _socket = null;
    _socketReady = false;
  }

  @override
  void dispose() {
    _cleanupRealtimeResources();
    _recorder.dispose();
    super.dispose();
  }
}
