import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../api/api_client.dart';
import '../../utils/json_read.dart';
import '../auth/session_controller.dart';

class VoiceCommandUploadResult {
  const VoiceCommandUploadResult({required this.partialPending});

  final bool partialPending;
}

class VoiceCommandRecorder extends ChangeNotifier {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Amplitude>? _amplitudeSubscription;

  bool _recording = false;
  bool _uploading = false;
  double _inputLevel = 0;
  double _peakInputDb = -160;
  String? _error;

  bool get recording => _recording;
  bool get uploading => _uploading;
  double get inputLevel => _inputLevel;
  String? get error => _error;

  Future<void> start() async {
    _error = null;
    notifyListeners();
    try {
      if (!await _recorder.hasPermission()) {
        _error = 'צריך לאשר גישה למיקרופון';
        notifyListeners();
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
      _recording = true;
      _inputLevel = 0;
      _peakInputDb = -160;
      notifyListeners();
    } catch (_) {
      _error = 'לא הצלחנו להתחיל הקלטה';
      notifyListeners();
    }
  }

  Future<VoiceCommandUploadResult?> stopAndUpload(
    SessionController controller,
  ) async {
    _uploading = true;
    _error = null;
    notifyListeners();
    try {
      final path = await _recorder.stop();
      await _amplitudeSubscription?.cancel();
      _amplitudeSubscription = null;
      _recording = false;
      notifyListeners();
      if (path == null) {
        _error = 'לא נשמר קובץ הקלטה';
        return null;
      }
      if (_peakInputDb < -50) {
        _error =
            'לא זוהה קלט מהמיקרופון. בדוק שהאמולטור מקבל את המיקרופון של המחשב.';
        return null;
      }
      final file = File(path);
      final bytes = await file.readAsBytes();
      final session = controller.session!;
      final result = await controller.apiClient.uploadVoiceCommandAudio(
        businessId: session.businessId!,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        bytes: bytes,
        idempotencyKey:
            'voice_${DateTime.now().microsecondsSinceEpoch}_${bytes.length}',
      );
      controller.markDataChanged();
      final execution = mapValue(result['execution']);
      final status = stringValue(execution['status']);
      return VoiceCommandUploadResult(
        partialPending: status == 'PARTIAL_PENDING',
      );
    } on ApiException catch (error) {
      _error = error.message;
      return null;
    } catch (_) {
      _error = 'לא הצלחנו לשלוח את ההקלטה';
      return null;
    } finally {
      _uploading = false;
      notifyListeners();
    }
  }

  String inputLevelMessage() {
    if (_inputLevel < 0.08) return 'לא מזוהה קלט מהמיקרופון';
    if (_inputLevel > 0.95) return 'הקלט חזק מדי או רווי';
    return 'המיקרופון קולט';
  }

  void _updateInputLevel(Amplitude amplitude) {
    final db = amplitude.current.isFinite ? amplitude.current : -160.0;
    final normalized = ((db + 60) / 60).clamp(0.0, 1.0).toDouble();
    _inputLevel = normalized;
    if (amplitude.max > _peakInputDb) _peakInputDb = amplitude.max;
    notifyListeners();
  }

  @override
  void dispose() {
    _amplitudeSubscription?.cancel();
    _recorder.dispose();
    super.dispose();
  }
}
