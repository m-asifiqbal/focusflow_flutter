/// ============================================================
/// VOICE DICTATION — speech-to-text for the note editor's mic button
/// ============================================================
///
/// Thin wrapper over speech_to_text so the editor can be tested with a fake
/// (no microphone in widget tests). Recognition runs on the device's own
/// speech service; the transcript is only handed back to the caller.
/// ============================================================
library;

import 'package:speech_to_text/speech_to_text.dart';

abstract interface class VoiceDictation {
  /// Asks for microphone / speech permission (first time) and starts
  /// listening. [onText] receives the transcript so far; [onDone] fires
  /// once with the final text. Returns false when speech is unavailable or
  /// permission was denied.
  Future<bool> start({
    required void Function(String text) onText,
    required void Function(String text) onDone,
  });

  Future<void> stop();
}

class DeviceVoiceDictation implements VoiceDictation {
  DeviceVoiceDictation([SpeechToText? speech])
    : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  bool _ready = false;

  @override
  Future<bool> start({
    required void Function(String text) onText,
    required void Function(String text) onDone,
  }) async {
    if (!_ready) {
      _ready = await _speech.initialize();
      if (!_ready) return false;
    }
    var finished = false;
    await _speech.listen(
      onResult: (result) {
        if (finished) return;
        onText(result.recognizedWords);
        if (result.finalResult) {
          finished = true;
          onDone(result.recognizedWords);
        }
      },
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
      ),
    );
    return true;
  }

  @override
  Future<void> stop() => _speech.stop();
}
