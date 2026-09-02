import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import '../../api/api_client.dart';
import '../../core/state/data_invalidator.dart';
import '../../core/network/idempotency_key.dart';
import '../../core/observability/app_error_reporter.dart';
import '../../models/session.dart';
import '../../services/assistant_speech_player.dart';
import '../../utils/json_read.dart';
import '../auth/session_controller.dart';
import 'voice_command_result.dart';

class VoiceCommandUploadResult {
  const VoiceCommandUploadResult({required this.result, this.actionBatchId});

  final VoiceCommandResult result;
  final String? actionBatchId;
}

enum VoiceRecordingPhase {
  idle,
  preparing,
  recording,
  finalizingTranscript,
  reviewing,
  submitting,
  result,
  cancelled,
}

bool isVoiceRecordingTransitionAllowed(
  VoiceRecordingPhase current,
  VoiceRecordingPhase next,
) {
  if (next == VoiceRecordingPhase.cancelled) return true;
  return switch (current) {
    VoiceRecordingPhase.idle =>
      next == VoiceRecordingPhase.preparing ||
          next == VoiceRecordingPhase.submitting,
    VoiceRecordingPhase.preparing =>
      next == VoiceRecordingPhase.recording || next == VoiceRecordingPhase.idle,
    VoiceRecordingPhase.recording =>
      next == VoiceRecordingPhase.finalizingTranscript,
    VoiceRecordingPhase.finalizingTranscript =>
      next == VoiceRecordingPhase.reviewing ||
          next == VoiceRecordingPhase.submitting ||
          next == VoiceRecordingPhase.idle,
    VoiceRecordingPhase.reviewing =>
      next == VoiceRecordingPhase.preparing ||
          next == VoiceRecordingPhase.submitting,
    VoiceRecordingPhase.submitting =>
      next == VoiceRecordingPhase.reviewing ||
          next == VoiceRecordingPhase.result,
    VoiceRecordingPhase.result =>
      next == VoiceRecordingPhase.idle || next == VoiceRecordingPhase.preparing,
    VoiceRecordingPhase.cancelled =>
      next == VoiceRecordingPhase.idle || next == VoiceRecordingPhase.preparing,
  };
}

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
  String _reviewTranscript = '';
  String? _submissionIdempotencyKey;
  final String _assistantClientSessionId = IdempotencyKey.create(
    'assistant_session',
  );
  String? _error;
  bool _cancelRequested = false;
  bool _socketReady = false;
  bool _disposed = false;
  int _operationGeneration = 0;
  final Map<String, StringBuffer> _deltaByItem = {};
  final Map<String, String> _completedByItem = {};

  bool get preparing => _phase == VoiceRecordingPhase.preparing;
  bool get recording => _phase == VoiceRecordingPhase.recording;
  bool get finalizing => _phase == VoiceRecordingPhase.finalizingTranscript;
  bool get reviewing => _phase == VoiceRecordingPhase.reviewing;
  bool get submitting => _phase == VoiceRecordingPhase.submitting;
  bool get uploading => finalizing || submitting;
  bool get finishing => finalizing;
  VoiceRecordingPhase get phase => _phase;
  double get inputLevel => _inputLevel;
  String? get error => _error;
  String get liveTranscript => _liveTranscript.trim();
  String get reviewTranscript => _reviewTranscript.trim();

  Future<void> start(SessionController controller) async {
    if (_phase != VoiceRecordingPhase.idle &&
        _phase != VoiceRecordingPhase.cancelled &&
        _phase != VoiceRecordingPhase.reviewing &&
        _phase != VoiceRecordingPhase.result) {
      return;
    }
    final generation = ++_operationGeneration;
    await AssistantSpeechPlayer.stop();
    _resetForNewRecording();
    _setPhase(VoiceRecordingPhase.preparing);
    _notify();
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!_isCurrent(generation)) return;
      if (!hasPermission) {
        _error = 'צריך לאשר גישה למיקרופון';
        _setPhase(VoiceRecordingPhase.idle);
        _notify();
        return;
      }
      final session = controller.session!;
      final realtimeSession = await controller.apiClient.voice
          .createRealtimeSession(
            businessId: session.businessId!,
            firebaseUid: session.firebaseUid,
            mockPhoneNumber: session.mockPhoneNumber,
          );
      if (!_isCurrent(generation)) return;
      final token = stringValue(realtimeSession['value']);
      if (token.isEmpty) {
        throw const FormatException('Missing realtime client secret');
      }
      final socket = await WebSocket.connect(
        'wss://api.openai.com/v1/realtime?intent=transcription',
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 12));
      if (!_isCurrent(generation)) {
        await socket.close();
        return;
      }
      _socket = socket;
      _socketReady = true;
      _socketSubscription = _socket!.listen(
        _handleServerEvent,
        onError: (error, stack) {
          AppErrorReporter.report(error, stack, source: 'voice_socket');
          _error = 'החיבור לתמלול החי נכשל';
          _notify();
        },
        onDone: () {
          _socketReady = false;
          _notify();
        },
      );
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
      if (!_isCurrent(generation)) {
        await _recorder.stop().catchError((_) => null);
        return;
      }
      _audioSubscription = stream.listen(_sendAudioChunk);
      await _amplitudeSubscription?.cancel();
      if (!_isCurrent(generation)) {
        await _recorder.stop().catchError((_) => null);
        return;
      }
      _amplitudeSubscription = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 250))
          .listen(_updateInputLevel);
      _setPhase(VoiceRecordingPhase.recording);
      _notify();
    } on ApiException catch (error) {
      if (!_isCurrent(generation)) return;
      await _cleanupRealtimeResources();
      _error = error.message;
      _setPhase(VoiceRecordingPhase.idle);
      _notify();
    } catch (error, stack) {
      if (!_isCurrent(generation)) return;
      await _cleanupRealtimeResources();
      AppErrorReporter.report(error, stack, source: 'voice_start');
      _error = 'לא הצלחנו להתחיל הקלטה';
      _setPhase(VoiceRecordingPhase.idle);
      _notify();
    }
  }

  Future<bool> stopForReview() async {
    if (!recording) return false;
    _setPhase(VoiceRecordingPhase.finalizingTranscript);
    _error = null;
    _notify();
    try {
      await _audioSubscription?.cancel();
      _audioSubscription = null;
      await _recorder.stop();
      await _amplitudeSubscription?.cancel();
      _amplitudeSubscription = null;
      if (_peakInputDb < -50) {
        _error =
            'לא זוהה קלט מהמיקרופון. בדוק שהאמולטור מקבל את המיקרופון של המחשב.';
        _setPhase(VoiceRecordingPhase.idle);
        return false;
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
        _setPhase(VoiceRecordingPhase.idle);
        return false;
      }
      _reviewTranscript = transcript;
      _submissionIdempotencyKey = null;
      _setPhase(VoiceRecordingPhase.reviewing);
      return true;
    } catch (error, stack) {
      AppErrorReporter.report(error, stack, source: 'voice_finalize');
      _error = 'לא הצלחנו לסיים את התמלול';
      _setPhase(VoiceRecordingPhase.idle);
      return false;
    } finally {
      await _cleanupRealtimeResources();
      _notify();
    }
  }

  Future<VoiceCommandUploadResult?> stopAndSubmit(
    SessionController controller,
  ) async {
    if (!recording) return null;
    final transcript = await _finalizeForDirectSubmission();
    if (transcript == null) return null;
    _submissionIdempotencyKey ??= _submissionKey('voice_text', transcript);
    return _submitTranscript(
      controller,
      transcript: transcript,
      idempotencyKey: _submissionIdempotencyKey!,
      restorePhaseOnAuthenticationError: VoiceRecordingPhase.idle,
    );
  }

  Future<String?> _finalizeForDirectSubmission() async {
    _setPhase(VoiceRecordingPhase.finalizingTranscript);
    _error = null;
    _notify();
    try {
      await _audioSubscription?.cancel();
      _audioSubscription = null;
      await _recorder.stop();
      await _amplitudeSubscription?.cancel();
      _amplitudeSubscription = null;
      if (_peakInputDb < -50) {
        _error =
            'לא זוהה קלט מהמיקרופון. בדוק שהאמולטור מקבל את המיקרופון של המחשב.';
        _setPhase(VoiceRecordingPhase.idle);
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
      if (transcript.length < 2) {
        _error = 'לא זוהה דיבור ברור בהקלטה';
        _setPhase(VoiceRecordingPhase.idle);
        return null;
      }
      _reviewTranscript = transcript;
      _submissionIdempotencyKey = null;
      return transcript;
    } catch (error, stack) {
      AppErrorReporter.report(error, stack, source: 'voice_finalize');
      _error = 'לא הצלחנו לסיים את התמלול';
      _setPhase(VoiceRecordingPhase.idle);
      return null;
    } finally {
      await _cleanupRealtimeResources();
      _notify();
    }
  }

  void updateReviewTranscript(String value) {
    if (!reviewing) return;
    final normalized = value.trim();
    if (normalized == _reviewTranscript.trim()) return;
    _reviewTranscript = value;
    _submissionIdempotencyKey = null;
    _error = null;
    _notify();
  }

  Future<VoiceCommandUploadResult?> submitReviewedTranscript(
    SessionController controller,
  ) async {
    if (!reviewing) return null;
    final transcript = reviewTranscript;
    if (transcript.length < 2) {
      _error = 'צריך להשאיר תמלול לפני השליחה';
      _notify();
      return null;
    }
    _submissionIdempotencyKey ??= _submissionKey('voice_text', transcript);
    return _submitTranscript(
      controller,
      transcript: transcript,
      idempotencyKey: _submissionIdempotencyKey!,
      restorePhaseOnAuthenticationError: VoiceRecordingPhase.reviewing,
    );
  }

  Future<VoiceCommandUploadResult?> submitTextCommand(
    SessionController controller,
    String value,
  ) async {
    final transcript = value.trim();
    if (transcript.length < 2 ||
        preparing ||
        recording ||
        finalizing ||
        submitting) {
      return null;
    }
    return _submitTranscript(
      controller,
      transcript: transcript,
      idempotencyKey: _submissionKey('assistant_text', transcript),
      restorePhaseOnAuthenticationError: VoiceRecordingPhase.idle,
    );
  }

  Future<VoiceCommandUploadResult?> _submitTranscript(
    SessionController controller, {
    required String transcript,
    required String idempotencyKey,
    required VoiceRecordingPhase restorePhaseOnAuthenticationError,
  }) async {
    _setPhase(VoiceRecordingPhase.submitting);
    _error = null;
    _notify();
    try {
      final session = controller.session!;
      final result = await controller.apiClient.v2Assistant.submitTranscript(
        businessId: session.businessId!,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        clientSessionId: _assistantClientSessionId,
        transcript: transcript,
        idempotencyKey: idempotencyKey,
      );
      controller.markDataChanged({DataScope.crm, DataScope.ai});
      await _playV2SpeechIfEnabled(controller, session, result);
      final voiceResult = mapValue(result['voiceResult']);
      final uploadResult = VoiceCommandUploadResult(
        result: voiceResult.isEmpty
            ? VoiceCommandResult.fallback()
            : VoiceCommandResult.fromJson(voiceResult),
        actionBatchId: nullableString(mapValue(result['actionBatch'])['id']),
      );
      _setPhase(VoiceRecordingPhase.result);
      return uploadResult;
    } on ApiException catch (error) {
      if (error.statusCode != 401) {
        _setPhase(VoiceRecordingPhase.result);
        return VoiceCommandUploadResult(
          result: VoiceCommandResult.fallback(message: error.message),
        );
      }
      _error = error.message;
      _setPhase(restorePhaseOnAuthenticationError);
      return null;
    } catch (error, stack) {
      AppErrorReporter.report(error, stack, source: 'voice_submit');
      _error = 'לא הצלחנו לשלוח את התמלול';
      _setPhase(restorePhaseOnAuthenticationError);
      return null;
    } finally {
      _notify();
    }
  }

  String _submissionKey(String prefix, String transcript) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${transcript.length}';

  Future<void> _playV2SpeechIfEnabled(
    SessionController controller,
    AppSession session,
    Map<String, Object?> result,
  ) async {
    try {
      final preferences = await controller.apiClient.v2ActionBatches
          .preferences(
            firebaseUid: session.firebaseUid,
            mockPhoneNumber: session.mockPhoneNumber,
          );
      if (mapValue(preferences['preferences'])['assistantResponseMode'] !=
          'TEXT_AND_VOICE') {
        return;
      }
      final actionBatchId = nullableString(
        mapValue(result['actionBatch'])['id'],
      );
      if (actionBatchId == null) return;
      final speech = await controller.apiClient.v2ActionBatches.speech(
        businessId: session.businessId!,
        actionBatchId: actionBatchId,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
      );
      final audio = nullableString(speech['audioBase64']);
      if (audio != null) await AssistantSpeechPlayer.playBase64(audio);
    } catch (error, stack) {
      AppErrorReporter.report(error, stack, source: 'assistant_tts');
    }
  }

  Future<void> cancel() async {
    _operationGeneration += 1;
    _cancelRequested = true;
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    if (recording || preparing || finalizing) {
      await _recorder.stop().catchError((_) => null);
    }
    await _cleanupRealtimeResources();
    _setPhase(VoiceRecordingPhase.cancelled);
    _error = null;
    _notify();
  }

  String inputLevelMessage() {
    if (preparing) return 'מכין הקלטה...';
    if (finalizing) return 'מסיים את התמלול...';
    if (submitting) return 'שולח לעוזרת...';
    if (_inputLevel < 0.08) return 'לא מזוהה קלט מהמיקרופון';
    if (_inputLevel > 0.95) return 'הקלט חזק מדי או רווי';
    return 'המיקרופון קולט';
  }

  void acknowledgeCancellation() {
    if (_phase == VoiceRecordingPhase.cancelled) {
      _setPhase(VoiceRecordingPhase.idle);
      _notify();
    }
  }

  void acknowledgeResult() {
    if (_phase == VoiceRecordingPhase.result) {
      _setPhase(VoiceRecordingPhase.idle);
      _reviewTranscript = '';
      _submissionIdempotencyKey = null;
      _notify();
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
    final Object? event;
    try {
      event = jsonDecode(message);
    } on FormatException catch (error, stack) {
      AppErrorReporter.report(error, stack, source: 'voice_socket_parse');
      return;
    }
    if (event is! Map<String, dynamic>) return;
    final type = event['type'];
    if (type == 'conversation.item.input_audio_transcription.delta') {
      final itemId = event['item_id']?.toString() ?? 'live';
      final delta = event['delta']?.toString() ?? '';
      if (delta.isEmpty) return;
      _deltaByItem.putIfAbsent(itemId, StringBuffer.new).write(delta);
      _rebuildTranscript();
      _notify();
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
      _notify();
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
        _notify();
      }
      return;
    }
    if (type == 'error') {
      final error = event['error'];
      if (error is Map && error['message'] != null) {
        _error = error['message'].toString();
        _notify();
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
    _notify();
  }

  void _resetForNewRecording() {
    _cancelRequested = false;
    _socketReady = false;
    _inputLevel = 0;
    _peakInputDb = -160;
    _liveTranscript = '';
    _reviewTranscript = '';
    _submissionIdempotencyKey = null;
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

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _setPhase(VoiceRecordingPhase next) {
    assert(
      isVoiceRecordingTransitionAllowed(_phase, next),
      'Invalid voice recording transition: $_phase -> $next',
    );
    _phase = next;
  }

  bool _isCurrent(int generation) {
    return !_disposed &&
        !_cancelRequested &&
        generation == _operationGeneration;
  }

  @override
  void dispose() {
    _disposed = true;
    _operationGeneration += 1;
    unawaited(_cleanupRealtimeResources());
    _recorder.dispose();
    super.dispose();
  }
}
