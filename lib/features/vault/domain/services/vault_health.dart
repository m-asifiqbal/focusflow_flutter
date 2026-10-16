/// ============================================================
/// VAULT HEALTH — the detail screen's "Security health" score (19)
/// ============================================================
///
/// A 0–100 rating of one saved password from data the vault already has:
/// cached HIBP result (never checked = neutral), reuse (same HMAC
/// fingerprint on another item), estimated strength (bits) and 2FA.
/// Weights: breaches 30 · unique 25 · strength 30 · 2FA 15. Pure Dart; the
/// password itself is only measured, never kept.
/// ============================================================
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/crypto/password_strength.dart';

/// One line of the health checklist.
@immutable
class VaultHealthCheck {
  const VaultHealthCheck(this.label, {required this.ok, this.unknown = false});

  final String label;
  final bool ok;

  /// Neither good nor bad (breaches never checked).
  final bool unknown;

  @override
  bool operator ==(Object other) =>
      other is VaultHealthCheck &&
      other.label == label &&
      other.ok == ok &&
      other.unknown == unknown;

  @override
  int get hashCode => Object.hash(label, ok, unknown);
}

@immutable
class VaultHealth {
  const VaultHealth({
    required this.score,
    required this.rating,
    required this.checks,
  });

  /// Rates [password] (non-empty) of an item.
  /// [breachCount] null = never checked; [reused] = same fingerprint on
  /// another active item.
  factory VaultHealth.of({
    required String password,
    required int? breachCount,
    required bool reused,
    required bool hasTotp,
  }) {
    final strength = PasswordStrengthEstimator.estimate(password);
    final breached = (breachCount ?? 0) > 0;
    final long = strength.length >= 16;
    var score = 0.0;
    score += breachCount == null ? 24 : (breached ? 0 : 30);
    score += reused ? 0 : 25;
    score += 30 * math.min(1, strength.bits / _fullStrengthBits);
    if (!long) score = math.min(score, 30 + 25 + 30 * 0.8 + 15);
    score += hasTotp ? 15 : 0;
    if (strength.isCommon || breached) score = math.min(score, 40);
    final pct = score.round().clamp(0, 100);
    return VaultHealth(
      score: pct,
      rating: ratingFor(pct),
      checks: [
        VaultHealthCheck(
          breachCount == null
              ? 'Not checked for breaches'
              : breached
              ? _breachText(breachCount)
              : 'No breaches',
          ok: !breached,
          unknown: breachCount == null,
        ),
        VaultHealthCheck(reused ? 'Reused' : 'Unique', ok: !reused),
        VaultHealthCheck(
          long ? '16+ characters' : '${strength.length} characters',
          ok: long,
        ),
        VaultHealthCheck(hasTotp ? '2FA enabled' : 'No 2FA', ok: hasTotp),
      ],
    );
  }

  /// Bits at which the strength part is full (≈ 16 random mixed chars).
  static const double _fullStrengthBits = 108;

  /// 0–100.
  final int score;

  /// "Excellent" · "Good" · "Fair" · "Poor".
  final String rating;

  /// Breaches · reuse · length · 2FA, in the mockup's order.
  final List<VaultHealthCheck> checks;

  static String ratingFor(int score) => score >= 90
      ? 'Excellent'
      : score >= 75
      ? 'Good'
      : score >= 50
      ? 'Fair'
      : 'Poor';

  static String _breachText(int n) =>
      n == 1 ? 'Seen in 1 breach' : 'Seen in $n breaches';

  @override
  bool operator ==(Object other) =>
      other is VaultHealth &&
      other.score == score &&
      other.rating == rating &&
      listEquals(other.checks, checks);

  @override
  int get hashCode => Object.hash(score, rating, Object.hashAll(checks));
}
