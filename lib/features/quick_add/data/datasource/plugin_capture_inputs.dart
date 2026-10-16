/// ============================================================
/// PLUGIN CAPTURE INPUTS — speech_to_text + image_picker adapters
/// ============================================================
///
/// What: the production [SpeechCapture] (speech_to_text, dictation mode)
/// and [ScanImageSource] (image_picker, downscaled to keep OCR fast).
/// Why: isolates the plugins behind the domain contracts so the sheet stays
/// testable. Nothing recognised is logged (it may be private).
/// ============================================================
library;

import 'dart:io';

import 'package:focusflow/features/quick_add/domain/services/capture_inputs.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechToTextCapture implements SpeechCapture {
  SpeechToTextCapture([SpeechToText? speech])
    : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  bool _ready = false;
  void Function()? _onDone;

  /// Bumped by every start and cancel (and by a stop during start-up). A
  /// [start] overtaken while awaiting the plugin (the sheet closed during
  /// the permission prompt) sees a newer session and must not listen.
  int _session = 0;

  /// A [start] is still awaiting the plugin.
  bool _starting = false;

  void _finish() {
    final done = _onDone;
    _onDone = null;
    done?.call();
  }

  @override
  Future<bool> start({
    required void Function(String words) onWords,
    required void Function() onDone,
  }) async {
    final session = ++_session;
    _starting = true;
    try {
      _ready =
          _ready ||
          await _speech.initialize(
            onStatus: (status) {
              if (status == SpeechToText.doneStatus ||
                  status == SpeechToText.notListeningStatus) {
                _finish();
              }
            },
            onError: (_) => _finish(),
          );
      if (!_ready || session != _session) return false;
      _onDone = onDone;
      await _speech.listen(
        onResult: (r) {
          if (session == _session) onWords(r.recognizedWords);
        },
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          partialResults: true,
          cancelOnError: true,
        ),
      );
      if (session != _session) {
        // Cancelled while listen() was starting: stop the late session.
        _onDone = null;
        await _speech.cancel();
        return false;
      }
      return true;
    } on Exception {
      if (session == _session) _onDone = null;
      return false;
    } finally {
      if (session == _session) _starting = false;
    }
  }

  @override
  Future<void> stop() {
    // Stopping before listening began aborts the pending start; a running
    // session keeps its id so the final words still arrive.
    if (_starting) {
      _session++;
      _starting = false;
    }
    return _speech.stop();
  }

  @override
  Future<void> cancel() async {
    _session++;
    _starting = false;
    _onDone = null;
    await _speech.cancel();
  }
}

class ImagePickerScanSource implements ScanImageSource {
  ImagePickerScanSource([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Long edge cap: plenty for text, much faster to recognise.
  static const double _maxEdge = 2400;

  @override
  Future<String?> pick(ScanSource source) async {
    final file = await _picker.pickImage(
      source: source == ScanSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: _maxEdge,
      maxHeight: _maxEdge,
      imageQuality: 90,
      requestFullMetadata: false,
    );
    return file?.path;
  }

  @override
  Future<void> discard(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      // Already gone (the picker's temp dir may be cleared by the OS).
    }
  }
}
