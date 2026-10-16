/// ============================================================
/// FOCUS TIMER CONTROLLER — runs the pure FocusTimer and records sessions
/// ============================================================
///
/// What: an auto-dispose Notifier (one per [FocusTarget]) over the pure
/// FocusTimer transitions; "now" comes from [clockProvider] so tests use a
/// FakeClock. A finished session (planned length reached, or stopped after
/// ≥ 1 min) is written through FocusSessionsRepository.
/// Why: state lives in the provider, so the timer sheet survives rebuilds
/// (theme, text scale, rotation). The 1-second tick comes from the sheet
/// widget (cancelled with it, no leaked timers); when the sheet closes the
/// provider is disposed and a running session is saved then — closing the
/// sheet is the same as Stop.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/utils/clock.dart';
import 'package:focusflow/features/insights/domain/repository/focus_sessions_repository.dart';
import 'package:focusflow/features/insights/domain/services/focus_timer.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

/// What the session is for (both null = a free focus session).
typedef FocusTarget = ({String? taskId, String? taskTitle});

class FocusTimerController
    extends AutoDisposeFamilyNotifier<FocusTimerState, FocusTarget> {
  late Clock _clock;
  late FocusSessionsRepository _repo;

  /// Mirror of [state], readable in onDispose.
  FocusTimerState _latest = const FocusTimerState();

  void _set(FocusTimerState s) => state = _latest = s;

  @override
  FocusTimerState build(FocusTarget arg) {
    _clock = ref.watch(clockProvider);
    _repo = ref.watch(focusSessionsRepositoryProvider);
    // Closing the sheet ends the session: record what was focused.
    ref.onDispose(() {
      if (_latest.isActive) {
        unawaited(_record(FocusTimer.finish(_latest, _now)));
      }
    });
    return _latest = const FocusTimerState();
  }

  DateTime get _now => _clock.now();

  void setMinutes(int minutes) => _set(FocusTimer.setMinutes(state, minutes));

  void start() => _set(FocusTimer.start(state, _now));

  void pause() => _set(FocusTimer.pause(state, _now));

  void resume() => _set(FocusTimer.resume(state, _now));

  /// Called every second by the sheet (which repaints the countdown from
  /// the clock itself): finishes and records the session once its planned
  /// length is reached.
  Future<void> tick() async {
    if (FocusTimer.isDue(state, _now)) await stop();
  }

  /// Ends the session now; records it when it lasted ≥ 1 min. Returns the
  /// recorded minutes (null = too short, nothing saved).
  Future<int?> stop() async {
    if (!state.isActive) return state.savedMinutes;
    final done = FocusTimer.finish(state, _now);
    _set(done);
    await _record(done);
    return done.savedMinutes;
  }

  /// Back to the length picker.
  void reset() => _set(FocusTimer.reset(state));

  Future<void> _record(FocusTimerState s) async {
    final minutes = s.savedMinutes;
    final start = s.startedAt;
    if (minutes == null || start == null) return;
    await _repo.add(
      taskId: arg.taskId,
      startedAt: start,
      durationMinutes: minutes,
    );
  }
}

final focusTimerProvider = NotifierProvider.autoDispose
    .family<FocusTimerController, FocusTimerState, FocusTarget>(
      FocusTimerController.new,
    );
