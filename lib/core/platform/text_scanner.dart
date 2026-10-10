/// ============================================================
/// TEXT SCANNER — on-device OCR for Quick Scan (screen 04 › Scan)
/// ============================================================
///
/// A tiny platform channel instead of a big OCR plugin: Apple Vision on iOS
/// (ios/Runner/AppDelegate.swift › TextScannerPlugin) and ML Kit's
/// Play-services model on Android (MainActivity.kt). Both run offline and
/// add almost nothing to the app size.
/// ============================================================
library;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TextScanner {
  const TextScanner([this._channel = const MethodChannel(channelName)]);

  static const String channelName = 'focusflow/text_scanner';

  final MethodChannel _channel;

  /// Recognised text in reading order (lines joined by `\n`); empty when the
  /// image has no text. Throws [PlatformException] on failure.
  Future<String> recognizeText(String imagePath) async {
    final text = await _channel.invokeMethod<String>('recognizeText', {
      'path': imagePath,
    });
    return text?.trim() ?? '';
  }
}

final textScannerProvider = Provider<TextScanner>((ref) => const TextScanner());
