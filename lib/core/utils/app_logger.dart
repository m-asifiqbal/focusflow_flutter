/// ============================================================
/// APP LOGGER (same API as Fresh LPG's AppLogger ≈ Timber)
/// ============================================================
///
/// ```dart
/// AppLogger.d('Debug'); AppLogger.w('Warning');
/// AppLogger.e('Failed', error: e, stackTrace: st);
/// ```
/// NEVER log vault plaintext, PINs, keys, tokens or note contents.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

abstract final class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 8,
      lineLength: 110,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
    level: kReleaseMode ? Level.error : Level.debug,
  );

  static void d(String message) => _logger.d(message);

  static void i(String message) => _logger.i(message);

  static void w(String message) => _logger.w(message);

  static void e(String message, {Object? error, StackTrace? stackTrace}) =>
      _logger.e(message, error: error, stackTrace: stackTrace);
}
