/// ============================================================
/// NOTE PIN — the individual PIN of a locked note
/// ============================================================
///
/// What: every locked note has its own PIN (4–6 digits, chosen by the user
/// when locking it). [NotePinService.createVerifier] turns a PIN into a
/// self-describing string `v1:<memKiB>:<passes>:<salt>:<hash>` (Argon2id
/// over the PIN with a random 16-byte salt) that is stored on the note;
/// [NotePinService.verify] re-derives and compares in constant time. The PIN
/// itself is never stored, logged or synced.
/// Why: a different salt per note means equal PINs look different and one
/// note's PIN says nothing about another's. The cost is deliberately lower
/// than the Vault's (19 MiB · 2 passes, tens of ms on a phone, on a
/// background isolate) because a note is opened often; the parameters
/// travel with the verifier, so they can be raised later without breaking
/// existing notes. Honest limit: 4–6 digits are guessable offline by
/// someone who extracts the database; the database file is itself encrypted
/// and in-app guessing is rate-limited (see NotePinAttempts).
/// ============================================================
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:focusflow/core/crypto/pin_kdf.dart';

class NotePinService {
  const NotePinService({
    this.kdf = const Argon2PinKdf(),
    this.params = defaultParams,
  });

  /// Cost of new verifiers (stored inside each one).
  static const KdfParams defaultParams = KdfParams(
    memoryKiB: 19 * 1024,
    iterations: 2,
  );

  static const int minLength = 4;
  static const int maxLength = 6;
  static const String _version = 'v1';
  static const int _saltBytes = 16;

  final PinKdf kdf;
  final KdfParams params;

  /// 4–6 ASCII digits.
  static bool isValidPin(String pin) =>
      pin.length >= minLength &&
      pin.length <= maxLength &&
      RegExp(r'^[0-9]+$').hasMatch(pin);

  /// The string to store for [pin] (fresh random salt).
  Future<String> createVerifier(String pin) async {
    if (!isValidPin(pin)) throw ArgumentError('PIN must be 4-6 digits');
    final rng = math.Random.secure();
    final salt = Uint8List.fromList([
      for (var i = 0; i < _saltBytes; i++) rng.nextInt(256),
    ]);
    final hash = await _hash(pin, salt, params);
    return [
      _version,
      params.memoryKiB,
      params.iterations,
      base64.encode(salt),
      base64.encode(hash),
    ].join(':');
  }

  /// Whether [pin] is the PIN [verifier] was made from. A malformed
  /// verifier never matches.
  Future<bool> verify(String pin, String verifier) async {
    final parsed = _parse(verifier);
    if (parsed == null || !isValidPin(pin)) return false;
    final hash = await _hash(pin, parsed.salt, parsed.params);
    return _constantTimeEquals(hash, parsed.hash);
  }

  Future<Uint8List> _hash(String pin, Uint8List salt, KdfParams p) async {
    final key = await kdf.deriveKek(pin, salt, p);
    return Uint8List.fromList(await key.extractBytes());
  }

  static ({KdfParams params, Uint8List salt, Uint8List hash})? _parse(
    String verifier,
  ) {
    final parts = verifier.split(':');
    if (parts.length != 5 || parts[0] != _version) return null;
    final m = int.tryParse(parts[1]);
    final t = int.tryParse(parts[2]);
    if (m == null || t == null || m < 8 || t < 1) return null;
    try {
      return (
        params: KdfParams(memoryKiB: m, iterations: t),
        salt: base64.decode(parts[3]),
        hash: base64.decode(parts[4]),
      );
    } on FormatException {
      return null;
    }
  }

  static bool _constantTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

/// How long in-app guessing is slowed down after wrong PINs of one note:
/// three free tries, then 30 s doubling per failure up to 15 minutes.
abstract final class NotePinBackoff {
  static const int freeAttempts = 3;
  static const Duration base = Duration(seconds: 30);
  static const Duration max = Duration(minutes: 15);

  /// Lock-out after the [failures]-th wrong PIN in a row (null = none).
  static Duration? delayFor(int failures) {
    if (failures < freeAttempts) return null;
    final exp = math.min(failures - freeAttempts, 6);
    final d = base * math.pow(2, exp).toInt();
    return d > max ? max : d;
  }
}
