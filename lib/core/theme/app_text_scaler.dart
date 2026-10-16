/// ============================================================
/// APP TEXT SCALER — Settings › Appearance text size on top of the OS
/// ============================================================
///
/// What: a [TextScaler] that applies the in-app text-size multiplier
/// (0.85–1.3) *on top of* the system's own scaler.
/// Why: rebuilding a `TextScaler.linear(system.scale(1) * factor)` throws
/// away Android 14's non-linear scaling (large text grows less than small
/// text) and needs an arbitrary clamp. Composing keeps the platform curve
/// intact: `scale(size) = system.scale(size) * factor`.
///
/// Enlarging is limited so the *app* multiplier alone never pushes text
/// past [maxAppScale]× the font size — but a system scale that is already
/// larger than that is never reduced (no cap below the OS's own choice).
/// ============================================================
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/painting.dart';

@immutable
class AppTextScaler extends TextScaler {
  const AppTextScaler({required this.system, required this.factor});

  /// Wraps [system] with [factor], or returns [system] itself when the
  /// factor is 1 (no extra layer, identical behaviour).
  static TextScaler compose(TextScaler system, double factor) =>
      factor == 1 ? system : AppTextScaler(system: system, factor: factor);

  /// Upper bound the app multiplier may enlarge to on its own.
  static const double maxAppScale = 2.0;

  /// The device's scaler (possibly non-linear).
  final TextScaler system;

  /// Settings › Appearance multiplier.
  final double factor;

  @override
  double scale(double fontSize) {
    final base = system.scale(fontSize);
    final scaled = base * factor;
    if (factor <= 1) return scaled;
    // Never below what the OS asked for; never above 2× from the app alone.
    return math.min(scaled, math.max(base, fontSize * maxAppScale));
  }

  /// Linear approximation, only for legacy readers (use [scale]).
  @override
  double get textScaleFactor => scale(14) / 14;

  @override
  bool operator ==(Object other) =>
      other is AppTextScaler &&
      other.system == system &&
      other.factor == factor;

  @override
  int get hashCode => Object.hash(system, factor);

  @override
  String toString() => 'AppTextScaler($system × $factor)';
}
