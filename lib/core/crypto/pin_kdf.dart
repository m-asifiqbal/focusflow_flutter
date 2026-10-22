/// ============================================================
/// PIN KDF — Argon2id key-encryption key from the 6-digit master PIN
/// ============================================================
///
/// The master PIN never encrypts anything directly. Argon2id (RFC 9106)
/// stretches PIN + a random 16-byte salt into a 256-bit KEK, which only
/// wraps the random data key (see vault_key_manager.dart).
///
/// ## Parameters (chosen by measurement)
/// `DartArgon2id` (pure Dart — package:cryptography has no native backend
/// in this app) measured on an Apple-silicon Mac, JIT, one lane:
///
/// | memory | passes | time   |
/// |--------|--------|--------|
/// | 19 MiB | 2      | ~57 ms |
/// | 64 MiB | 2      | ~213 ms|
/// | 64 MiB | 3      | ~317 ms|
/// | 96 MiB | 3      | ~474 ms|
/// | 128 MiB| 3      | ~648 ms|
///
/// (Re-checked in a throwaway benchmark: 64 MiB · 3 ≈ 350 ms, 96 MiB · 3
/// ≈ 480 ms incl. warm-up; the benchmark was deleted afterwards.)
///
/// **64 MiB · 3 passes · 1 lane** is the ceiling. Those numbers come from a
/// desktop under JIT; pure-Dart Argon2 under AOT on a low-end Android phone
/// can be several times slower, so the app does not trust the table blindly:
/// [KdfCalibration] times one cheap probe (32 MiB · 1 pass) on the device at
/// vault set-up / PIN change and picks the strongest of 64·3, 64·2, 48·2 that
/// fits ~0.75 s, never below the floor [KdfParams.minimum] (32 MiB · 2).
/// [KdfParams] are stored next to the wrapped key, so the choice persists and
/// a bundle below the floor is re-wrapped after a successful unlock.
/// TODO(device numbers): record release-mode probe times from a real
/// low/mid-range Android phone here (not measurable from this dev setup).
///
/// ## Honest limits
/// A 6-digit PIN has only 10^6 ≈ 2^20 possibilities. Argon2id makes each
/// guess cost ~0.3–1 s and 64 MiB, which defeats casual offline guessing,
/// but an attacker who extracts the wrapped key from the Keychain /
/// Keystore *and* has serious hardware could still enumerate every PIN.
/// The real protection is that the wrapped key never leaves the device's
/// secure storage (or the user's own encrypted backup) and that in-app
/// guessing is rate-limited (exponential back-off, optional wipe).
///
/// The derivation runs on a background isolate ([Argon2Runner]: single
/// threaded, validated cost, time limit, every failure an [Argon2Failure])
/// so the UI keeps animating the PIN dots while it works and a slow or
/// memory-starved phone fails cleanly instead of hanging or crashing.
/// ============================================================
library;

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:focusflow/core/crypto/argon2_runner.dart';

/// Argon2id cost parameters, persisted with the wrapped key.
@immutable
class KdfParams {
  const KdfParams({
    required this.memoryKiB,
    required this.iterations,
    this.parallelism = 1,
  });

  /// Production default — see the measurement table in this file's header.
  static const KdfParams recommended = KdfParams(
    memoryKiB: 64 * 1024,
    iterations: 3,
  );

  /// The floor calibration never goes below (slow devices).
  static const KdfParams minimum = KdfParams(
    memoryKiB: 32 * 1024,
    iterations: 2,
  );

  /// Deliberately cheap parameters for unit / widget tests ONLY.
  @visibleForTesting
  static const KdfParams testing = KdfParams(memoryKiB: 64, iterations: 1);

  static const String algorithm = 'argon2id';

  final int memoryKiB;
  final int iterations;
  final int parallelism;

  /// True when this costs less than [other] in memory or passes (so a key
  /// wrapped with it should be re-wrapped with [other]).
  bool isWeakerThan(KdfParams other) =>
      memoryKiB < other.memoryKiB ||
      iterations < other.iterations ||
      (memoryKiB == other.memoryKiB &&
          iterations == other.iterations &&
          parallelism < other.parallelism);

  Map<String, Object> toJson() => {
    'alg': algorithm,
    'm': memoryKiB,
    't': iterations,
    'p': parallelism,
  };

  /// Reads stored parameters. A cost this app would never have written
  /// (a damaged or crafted bundle) is a [FormatException], so it surfaces as
  /// an unreadable key instead of an attempt to allocate it.
  factory KdfParams.fromJson(Map<String, Object?> json) {
    if (json['alg'] != algorithm) {
      throw FormatException('Unsupported KDF ${json['alg']}');
    }
    final p = KdfParams(
      memoryKiB: (json['m'] as num).toInt(),
      iterations: (json['t'] as num).toInt(),
      parallelism: (json['p'] as num?)?.toInt() ?? 1,
    );
    if (!Argon2Runner.accept(
      memoryKiB: p.memoryKiB,
      iterations: p.iterations,
      parallelism: p.parallelism,
    )) {
      throw FormatException('Unsupported KDF cost $p');
    }
    return p;
  }

  @override
  bool operator ==(Object other) =>
      other is KdfParams &&
      other.memoryKiB == memoryKiB &&
      other.iterations == iterations &&
      other.parallelism == parallelism;

  @override
  int get hashCode => Object.hash(memoryKiB, iterations, parallelism);

  @override
  String toString() =>
      'Argon2id(m=${memoryKiB}KiB, t=$iterations, p=$parallelism)';
}

/// Derives the 256-bit KEK. Abstract so tests can count calls.
abstract interface class PinKdf {
  Future<SecretKey> deriveKek(String pin, Uint8List salt, KdfParams params);
}

/// Argon2id through [Argon2Runner].
class Argon2PinKdf implements PinKdf {
  const Argon2PinKdf({this.useIsolate = true});

  /// Off only in tests that run inside a fake-async zone (the derivation
  /// then runs inline; the cost is cheap there).
  final bool useIsolate;

  @override
  Future<SecretKey> deriveKek(
    String pin,
    Uint8List salt,
    KdfParams params,
  ) async {
    final bytes = await Argon2Runner.derive(
      password: pin.codeUnits,
      salt: salt,
      memoryKiB: params.memoryKiB,
      iterations: params.iterations,
      parallelism: params.parallelism,
      inline: useIsolate ? null : true,
    );
    return SecretKeyData(bytes);
  }
}

/// Picks Argon2id parameters for this device from one timed probe.
abstract final class KdfCalibration {
  /// The probe: 32 MiB · 1 pass (1/6 of [KdfParams.recommended]).
  static const KdfParams probe = KdfParams(memoryKiB: 32 * 1024, iterations: 1);

  /// Wall-clock budget for one unlock.
  static const Duration target = Duration(milliseconds: 750);

  /// Strongest first; all at or above [KdfParams.minimum].
  static const List<KdfParams> candidates = [
    KdfParams.recommended,
    KdfParams(memoryKiB: 64 * 1024, iterations: 2),
    KdfParams(memoryKiB: 48 * 1024, iterations: 2),
    KdfParams.minimum,
  ];

  /// Times [probe] with [kdf] (random throwaway PIN / salt) and [choose]s.
  static Future<KdfParams> measure(
    PinKdf kdf, {
    KdfParams ceiling = KdfParams.recommended,
  }) async {
    final watch = Stopwatch()..start();
    await kdf.deriveKek('000000', Uint8List(16), probe);
    watch.stop();
    return choose(watch.elapsed, ceiling: ceiling);
  }

  /// Argon2 time scales ~linearly with memory × passes, so each candidate
  /// is estimated from the probe's time; the strongest that fits [target]
  /// (and is not above [ceiling]) wins, else [KdfParams.minimum].
  static KdfParams choose(
    Duration probeTime, {
    KdfParams ceiling = KdfParams.recommended,
  }) {
    final unit =
        probeTime.inMicroseconds / (probe.memoryKiB * probe.iterations);
    var weakest = KdfParams.minimum;
    for (final c in candidates) {
      if (c.memoryKiB > ceiling.memoryKiB ||
          c.iterations > ceiling.iterations) {
        continue;
      }
      weakest = c;
      if (unit * c.memoryKiB * c.iterations <= target.inMicroseconds) return c;
    }
    // Too slow even for the floor: keep the floor (security over speed).
    return ceiling.isWeakerThan(weakest) ? ceiling : weakest;
  }
}
