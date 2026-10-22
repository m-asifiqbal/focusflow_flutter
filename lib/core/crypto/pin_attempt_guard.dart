/// ============================================================
/// PIN ATTEMPT GUARD — failed-PIN counter with exponential back-off
/// ============================================================
///
/// Screen 17: the first [freeAttempts] wrong PINs cost nothing; from then
/// on every failure locks the pad for 30 s · 2^(n − 5), capped at one hour
/// (30 s, 1 min, 2 min, 4 min …). The counter and lock-out are persisted
/// in secure storage, so killing the app does not reset them. The
/// optional wipe after [wipeThreshold] failures is decided by the vault
/// session (setting).
///
/// Attempts are counted BEFORE the PIN is checked ([recordAttempt]) and
/// reset on success, so killing the app during the slow Argon2id check
/// cannot make a guess free.
///
/// Clock changes: a lock-out only ends when BOTH hold —
///  1. the wall clock passed the stored deadline, and
///  2. the lock-out duration has elapsed on a MONOTONIC clock while the
///     app was running (accumulated across launches in `waitedMs`).
/// Moving the device clock forward therefore never shortens it; moving it
/// backwards is detected (deadline further away than the lock-out itself)
/// and re-based on the monotonic time still owed. Trade-off: time while
/// the app is not running does not count towards a lock-out (max 1 h).
/// ============================================================
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/crypto/vault_secret_storage.dart';

@immutable
class PinAttemptState {
  const PinAttemptState({this.failed = 0, this.lockedUntil});

  static const PinAttemptState initial = PinAttemptState();

  final int failed;
  final DateTime? lockedUntil;

  bool isLockedOut(DateTime now) =>
      lockedUntil != null && now.isBefore(lockedUntil!);

  Duration remaining(DateTime now) => lockedUntil == null
      ? Duration.zero
      : lockedUntil!.difference(now).isNegative
      ? Duration.zero
      : lockedUntil!.difference(now);

  @override
  bool operator ==(Object other) =>
      other is PinAttemptState &&
      other.failed == failed &&
      other.lockedUntil == lockedUntil;

  @override
  int get hashCode => Object.hash(failed, lockedUntil);
}

class PinAttemptGuard {
  PinAttemptGuard(this._store, {Duration Function()? monotonic})
    : _mono = monotonic ?? _processElapsed;

  static const String storageKey = 'vault.attempts';
  static const int freeAttempts = 5;
  static const int wipeThreshold = 10;
  static const Duration baseDelay = Duration(seconds: 30);
  static const Duration maxDelay = Duration(hours: 1);

  static final Stopwatch _stopwatch = Stopwatch()..start();
  static Duration _processElapsed() => _stopwatch.elapsed;

  final VaultSecretStorage _store;
  final Duration Function() _mono;

  /// Monotonic reading at the last accrual in THIS process (time before the
  /// app started is never counted).
  Duration? _mark;

  /// Lock-out after the [failed]-th wrong PIN (null = none yet).
  static Duration? backoffFor(int failed) {
    if (failed < freeAttempts) return null;
    final exp = math.min(failed - freeAttempts, 10);
    final d = baseDelay * math.pow(2, exp).toInt();
    return d > maxDelay ? maxDelay : d;
  }

  /// The current state at [now] (wall clock; defaults to DateTime.now).
  /// [PinAttemptState.lockedUntil] is the EFFECTIVE deadline (see the
  /// header), not necessarily the stored one.
  Future<PinAttemptState> load([DateTime? now]) async {
    final at = now ?? DateTime.now();
    final rec = await _read(at);
    if (rec == null) return PinAttemptState.initial;
    if (rec.lockMs <= 0) return PinAttemptState(failed: rec.failed);

    // Accrue monotonic time spent running since the last look.
    final mono = _mono();
    var waited = rec.waitedMs;
    final mark = _mark;
    if (mark != null && mono >= mark) waited += (mono - mark).inMilliseconds;
    _mark = mono;
    if (waited > rec.lockMs) waited = rec.lockMs;

    var until = rec.until;
    final owed = rec.lockMs - waited;
    // Clock went backwards: the deadline is further away than the whole
    // lock-out. Re-base it on the time still owed.
    if (until.difference(at).inMilliseconds > rec.lockMs) {
      until = at.add(Duration(milliseconds: owed));
    }
    if (waited != rec.waitedMs || until != rec.until) {
      await _write(rec.failed, until, rec.lockMs, waited);
    }
    final wallLeft = until.difference(at).inMilliseconds;
    final left = math.max(owed, wallLeft);
    return PinAttemptState(
      failed: rec.failed,
      lockedUntil: left > 0 ? at.add(Duration(milliseconds: left)) : null,
    );
  }

  /// Counts one attempt at [now] BEFORE the PIN is checked and returns the
  /// state as if it failed. Call [reset] when the PIN was right.
  Future<PinAttemptState> recordAttempt(DateTime now) async {
    final rec = await _read(now);
    final failed = (rec?.failed ?? 0) + 1;
    final delay = backoffFor(failed);
    _mark = _mono();
    await _write(
      failed,
      now.add(delay ?? Duration.zero),
      delay?.inMilliseconds ?? 0,
      0,
    );
    return PinAttemptState(
      failed: failed,
      lockedUntil: delay == null ? null : now.add(delay),
    );
  }

  /// Gives back the attempt [recordAttempt] counted when the check itself
  /// could not run (storage / KDF failure, out of memory): that was not a
  /// wrong PIN and must not move the user towards a lock-out or a wipe.
  /// [before] is the state read before counting (not locked out then).
  Future<void> refund(PinAttemptState before, DateTime now) async {
    _mark = null;
    if (before.failed <= 0) {
      await _store.delete(storageKey);
    } else {
      await _write(before.failed, now, 0, 0);
    }
  }

  /// Alias kept for callers that count after the check.
  Future<PinAttemptState> recordFailure(DateTime now) => recordAttempt(now);

  Future<void> reset() async {
    _mark = null;
    await _store.delete(storageKey);
  }

  Future<_Record?> _read(DateTime now) async {
    final raw = await _store.read(storageKey);
    if (raw == null) return null;
    try {
      final json = (jsonDecode(raw) as Map).cast<String, Object?>();
      final failed = (json['failed'] as num?)?.toInt() ?? 0;
      final until = DateTime.tryParse(json['until'] as String? ?? '');
      var lockMs = (json['lockMs'] as num?)?.toInt();
      // Records written before the monotonic fields existed: whatever was
      // left of that lock-out (capped at its length) still has to elapse.
      lockMs ??= until == null
          ? 0
          : math.min(
              math.max(until.difference(now).inMilliseconds, 0),
              backoffFor(failed)?.inMilliseconds ?? 0,
            );
      return _Record(
        failed: failed,
        until: until ?? DateTime.fromMillisecondsSinceEpoch(0),
        lockMs: lockMs,
        waitedMs: (json['waitedMs'] as num?)?.toInt() ?? 0,
      );
    } on Object {
      // Unparseable: keep counting from the maximum free budget rather
      // than granting fresh attempts.
      return _Record(
        failed: freeAttempts,
        until: DateTime.fromMillisecondsSinceEpoch(0),
        lockMs: 0,
        waitedMs: 0,
      );
    }
  }

  Future<void> _write(int failed, DateTime until, int lockMs, int waited) =>
      _store.write(
        storageKey,
        jsonEncode({
          'failed': failed,
          'until': until.toIso8601String(),
          'lockMs': lockMs,
          'waitedMs': waited,
        }),
      );
}

class _Record {
  const _Record({
    required this.failed,
    required this.until,
    required this.lockMs,
    required this.waitedMs,
  });

  final int failed;
  final DateTime until;
  final int lockMs;
  final int waitedMs;
}
