/// ============================================================
/// NOTE LOCK PROVIDERS — PIN service + wrong-PIN back-off
/// ============================================================
///
/// * [notePinServiceProvider]  — makes / checks a note's PIN verifier
///   (override in tests with cheap Argon2 parameters).
/// * [notePinAttemptsProvider] — per-note count of wrong PINs in a row and
///   the lock-out they earned ([NotePinBackoff]). Memory only: it resets
///   when the app restarts, which is the trade-off for keeping it simple;
///   the database is encrypted and each guess costs an Argon2 run.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/features/notes/domain/services/note_pin.dart';

final notePinServiceProvider = Provider<NotePinService>(
  (ref) => const NotePinService(),
);

@immutable
class NotePinAttempt {
  const NotePinAttempt({this.failures = 0, this.lockedUntil});

  final int failures;
  final DateTime? lockedUntil;

  Duration remaining(DateTime now) {
    final until = lockedUntil;
    if (until == null || !now.isBefore(until)) return Duration.zero;
    return until.difference(now);
  }
}

class NotePinAttempts extends Notifier<Map<String, NotePinAttempt>> {
  @override
  Map<String, NotePinAttempt> build() => const {};

  /// Time left of [key]'s lock-out at [now] (zero when free to try).
  Duration remaining(String key, DateTime now) =>
      state[key]?.remaining(now) ?? Duration.zero;

  /// A wrong PIN for [key]: counts it and starts the next lock-out.
  void failed(String key, DateTime now) {
    final failures = (state[key]?.failures ?? 0) + 1;
    final delay = NotePinBackoff.delayFor(failures);
    state = {
      ...state,
      key: NotePinAttempt(
        failures: failures,
        lockedUntil: delay == null ? null : now.add(delay),
      ),
    };
  }

  void succeeded(String key) {
    if (!state.containsKey(key)) return;
    state = {...state}..remove(key);
  }
}

final notePinAttemptsProvider =
    NotifierProvider<NotePinAttempts, Map<String, NotePinAttempt>>(
      NotePinAttempts.new,
    );
