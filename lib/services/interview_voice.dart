import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Voice for the AI interview room, using the phone's own services (no paid API, nothing uploaded by this class):
///  - answers: Android's speech recogniser fills the answer box; the candidate can edit before sending;
///  - questions: the phone's text-to-speech reads the interviewer's replies aloud when switched on.
/// The microphone permission is requested only when the candidate first taps the mic.
class InterviewVoice extends ChangeNotifier {
  InterviewVoice({SpeechToText? stt, FlutterTts? tts})
      : _stt = stt ?? SpeechToText(),
        _tts = tts ?? FlutterTts();

  final SpeechToText _stt;
  final FlutterTts _tts;

  bool _sttReady = false;
  bool listening = false;
  bool speaking = false;
  bool speakReplies = false;
  bool ttsAvailable = false;

  /// Why voice answers cannot be used right now (permission, no recogniser, ...), shown to the candidate.
  String? unavailableReason;
  String? lastError;
  String _lastSpoken = '';
  bool _disposed = false;

  static const _errors = {
    'error_permission': 'Microphone access was denied. Allow it in Android settings, or type your answer.',
    'error_insufficient_permissions': 'Microphone access was denied. Allow it in Android settings, or type your answer.',
    'error_no_match': "I didn't catch that. Try again a little closer to the phone, or type your answer.",
    'error_speech_timeout': "I didn't hear anything. Try again, or type your answer.",
    'error_network': 'Speech recognition needs a network connection on this phone. Type your answer instead.',
    'error_network_timeout': 'Speech recognition needs a network connection on this phone. Type your answer instead.',
    'error_audio_error': 'The microphone could not be used. Type your answer instead.',
    'error_busy': 'The speech recogniser is busy. Try again in a moment.',
  };

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Text-to-speech setup; safe to call at room start (it does not need a permission).
  Future<void> initSpeaker() async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.5);
      await _tts.awaitSpeakCompletion(false);
      _tts.setStartHandler(() {
        speaking = true;
        _notify();
      });
      _tts.setCompletionHandler(() {
        speaking = false;
        _notify();
      });
      _tts.setCancelHandler(() {
        speaking = false;
        _notify();
      });
      _tts.setErrorHandler((_) {
        speaking = false;
        _notify();
      });
      ttsAvailable = true;
    } catch (_) {
      ttsAvailable = false;
    }
    _notify();
  }

  Future<bool> _ensureRecogniser() async {
    if (_sttReady) return true;
    try {
      _sttReady = await _stt.initialize(onError: _onError, onStatus: _onStatus);
      unavailableReason = _sttReady ? null : 'Speech recognition is not available on this phone. Type your answer instead.';
    } catch (_) {
      _sttReady = false;
      unavailableReason = 'Speech recognition is not available on this phone. Type your answer instead.';
    }
    _notify();
    return _sttReady;
  }

  void _onError(SpeechRecognitionError e) {
    listening = false;
    lastError = _errors[e.errorMsg] ?? 'Voice input stopped. Type your answer, or try the mic again.';
    if (e.errorMsg.contains('permission')) unavailableReason = _errors['error_permission'];
    _notify();
  }

  void _onStatus(String status) {
    if (status == 'done' || status == 'notListening') {
      listening = false;
      _notify();
    }
  }

  /// Starts listening; [onText] receives the recognised words (partial results included).
  Future<void> startListening(void Function(String text) onText) async {
    lastError = null;
    if (speaking) await stopSpeaking(); // talking cuts the interviewer off
    if (!await _ensureRecogniser()) return;
    try {
      await _stt.listen(
        onResult: (r) => onText(r.recognizedWords),
        listenOptions: SpeechListenOptions(
          localeId: 'en_US',
          listenFor: const Duration(seconds: 90),
          pauseFor: const Duration(seconds: 6),
          partialResults: true,
          cancelOnError: true,
        ),
      );
      listening = true;
    } catch (_) {
      listening = false;
      lastError = 'Voice input could not start. Type your answer instead.';
    }
    _notify();
  }

  Future<void> stopListening() async {
    try {
      await _stt.stop();
    } catch (_) {/* already stopped */}
    listening = false;
    _notify();
  }

  void setSpeakReplies(bool on) {
    speakReplies = on;
    if (!on) stopSpeaking();
    _notify();
  }

  /// Reads [text] aloud when the candidate switched replies on. Only one utterance plays at a time.
  Future<void> speak(String text) async {
    if (!speakReplies || !ttsAvailable || text.trim().isEmpty) return;
    _lastSpoken = text;
    try {
      await _tts.stop();
      await _tts.speak(text.length > 1200 ? text.substring(0, 1200) : text);
    } catch (_) {
      speaking = false;
      _notify();
    }
  }

  Future<void> replay() => speak(_lastSpoken);

  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (_) {/* nothing playing */}
    speaking = false;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    try {
      _stt.cancel();
      _tts.stop();
    } catch (_) {/* best effort */}
    super.dispose();
  }
}
