/// ============================================================
/// CAPTURE INPUTS — contracts for the mic and the Quick Scan camera
/// ============================================================
///
/// What: [SpeechCapture] (dictation into the capture field) and
/// [ScanImageSource] (camera / photo library for Quick Scan OCR).
/// Why: the sheet depends on these small interfaces, not on the plugins,
/// so widget tests can fake them; implementations live in data/datasource/.
/// ============================================================
library;

/// Live dictation. One session at a time.
abstract interface class SpeechCapture {
  /// Starts listening. [onWords] receives the recognised text so far
  /// (partial results); [onDone] fires once when the session ends (silence,
  /// error or [stop]). Returns false when speech recognition is unavailable
  /// or permission was denied.
  Future<bool> start({
    required void Function(String words) onWords,
    required void Function() onDone,
  });

  /// Ends the session, delivering the final words. Called while [start] is
  /// still pending, it aborts that start (which then returns false).
  Future<void> stop();

  /// Ends the session without a final result. Also aborts a [start] that
  /// is still pending: it returns false and never begins listening.
  Future<void> cancel();
}

/// Where a Quick Scan photo comes from.
enum ScanSource { camera, gallery }

abstract interface class ScanImageSource {
  /// Lets the user take / pick a photo; returns its temporary file path,
  /// or null when cancelled.
  Future<String?> pick(ScanSource source);

  /// Deletes the temporary copy once the text is extracted.
  Future<void> discard(String path);
}
