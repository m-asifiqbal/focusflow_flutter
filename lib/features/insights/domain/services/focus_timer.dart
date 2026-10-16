/// ============================================================
/// FOCUS TIMER — pure countdown state machine (Insights › Focus hours)
/// ============================================================
///
/// What: an immutable [FocusTimerState] plus pure transitions (start,
/// pause, resume, tick, stop) that take "now" from the caller.
/// Why: elapsed time is derived from instants (accumulated + now −
/// resumedAt), never from counting ticks, so a dropped frame, a slow
/// device or a rebuild can't drift the countdown, and tests drive it with
/// a FakeClock. Persisting the finished session is the controller's job
/// ([FocusTimerState.sessionMinutes] says what to record).
/// ============================================================
library;

import 'package:flutter/foundation.dart';

enum FocusPhase { setup, running, paused, finished }

@immutable
class FocusTimerState {
  const FocusTimerState({
    this.phase = FocusPhase.setup,
    this.plannedMinutes = FocusTimer.defaultMinutes,
    this.accumulated = Duration.zero,
    this.startedAt,
    this.resumedAt,
    this.savedMinutes,
  });

  final FocusPhase phase;

  /// Length of the session the user picked.
  final int plannedMinutes;

  /// Running time banked before the last pause.
  final Duration accumulated;

  /// When the session first started (recorded as the session start).
  final DateTime? startedAt;

  /// When the current running stretch began (null unless running).
  final DateTime? resumedAt;

  /// Minutes recorded when the session ended (null = nothing recorded:
  /// still going, or stopped before [FocusTimer.minRecordMinutes]).
  final int? savedMinutes;

  Duration get planned => Duration(minutes: plannedMinutes);

  bool get isActive =>
      phase == FocusPhase.running || phase == FocusPhase.paused;

  /// Time focused so far, as of [now].
  Duration elapsedAt(DateTime now) {
    final since = resumedAt;
    final running = since == null ? Duration.zero : now.difference(since);
    final total = accumulated + (running.isNegative ? Duration.zero : running);
    return total > planned ? planned : total;
  }

  Duration remainingAt(DateTime now) => planned - elapsedAt(now);

  /// 0…1 of the planned length done.
  double progressAt(DateTime now) => plannedMinutes <= 0
      ? 0
      : elapsedAt(now).inMilliseconds / planned.inMilliseconds;

  /// Whole minutes to record if the session ended at [now] (null below
  /// the minimum).
  int? sessionMinutes(DateTime now) {
    final m = elapsedAt(now).inMinutes;
    return m >= FocusTimer.minRecordMinutes ? m : null;
  }

  FocusTimerState copyWith({
    FocusPhase? phase,
    int? plannedMinutes,
    Duration? accumulated,
    DateTime? startedAt,
    DateTime? resumedAt,
    bool clearResumedAt = false,
    int? savedMinutes,
  }) => FocusTimerState(
    phase: phase ?? this.phase,
    plannedMinutes: plannedMinutes ?? this.plannedMinutes,
    accumulated: accumulated ?? this.accumulated,
    startedAt: startedAt ?? this.startedAt,
    resumedAt: clearResumedAt ? null : (resumedAt ?? this.resumedAt),
    savedMinutes: savedMinutes ?? this.savedMinutes,
  );

  @override
  bool operator ==(Object other) =>
      other is FocusTimerState &&
      other.phase == phase &&
      other.plannedMinutes == plannedMinutes &&
      other.accumulated == accumulated &&
      other.startedAt == startedAt &&
      other.resumedAt == resumedAt &&
      other.savedMinutes == savedMinutes;

  @override
  int get hashCode => Object.hash(
    phase,
    plannedMinutes,
    accumulated,
    startedAt,
    resumedAt,
    savedMinutes,
  );

  @override
  String toString() =>
      'FocusTimerState($phase, $plannedMinutes min, banked $accumulated)';
}

/// Pure transitions. Invalid ones return the state unchanged.
abstract final class FocusTimer {
  static const int defaultMinutes = 25;
  static const List<int> presets = [25, 45, 60];
  static const int minMinutes = 5;
  static const int maxMinutes = 180;
  static const int customStep = 5;

  /// Shorter sessions are not recorded.
  static const int minRecordMinutes = 1;

  static FocusTimerState setMinutes(FocusTimerState s, int minutes) =>
      s.phase == FocusPhase.setup
      ? s.copyWith(plannedMinutes: minutes.clamp(minMinutes, maxMinutes))
      : s;

  static FocusTimerState start(FocusTimerState s, DateTime now) =>
      s.phase == FocusPhase.setup
      ? s.copyWith(
          phase: FocusPhase.running,
          startedAt: now,
          resumedAt: now,
          accumulated: Duration.zero,
        )
      : s;

  static FocusTimerState pause(FocusTimerState s, DateTime now) =>
      s.phase == FocusPhase.running
      ? s.copyWith(
          phase: FocusPhase.paused,
          accumulated: s.elapsedAt(now),
          clearResumedAt: true,
        )
      : s;

  static FocusTimerState resume(FocusTimerState s, DateTime now) =>
      s.phase == FocusPhase.paused
      ? s.copyWith(phase: FocusPhase.running, resumedAt: now)
      : s;

  /// Whether a running session has reached its planned length at [now].
  static bool isDue(FocusTimerState s, DateTime now) =>
      s.phase == FocusPhase.running && s.remainingAt(now) <= Duration.zero;

  /// Ends an active session at [now]: the state is frozen and
  /// `savedMinutes` set when it is long enough to record.
  static FocusTimerState finish(FocusTimerState s, DateTime now) {
    if (!s.isActive) return s;
    final elapsed = s.elapsedAt(now);
    final minutes = s.sessionMinutes(now);
    return FocusTimerState(
      phase: FocusPhase.finished,
      plannedMinutes: s.plannedMinutes,
      accumulated: elapsed,
      startedAt: s.startedAt,
      savedMinutes: minutes,
    );
  }

  /// Back to the picker, keeping the chosen length.
  static FocusTimerState reset(FocusTimerState s) =>
      FocusTimerState(plannedMinutes: s.plannedMinutes);
}
