/// ============================================================
/// HABIT DAY TICKER — moves habit screens on to the next habit day
/// ============================================================
///
/// What: while mounted, invalidates habitTodayProvider when the next habit
/// day starts (local midnight + Settings › Habit reset time) and whenever
/// the app resumes.
/// Why: habitTodayProvider reads the clock once. Without this, a list or
/// detail screen left open past the reset time keeps showing yesterday and
/// check-ins are written to the wrong day. The timer lives in a widget so
/// it is cancelled with the screen (no leaked timers in tests, none while
/// nothing shows habits); timers don't run while the app is suspended,
/// hence the resume hook. Home can wrap its habit section in it too.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/features/habits/domain/services/habit_day.dart';
import 'package:focusflow/features/habits/presentation/providers/habits_providers.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

/// Keeps habitTodayProvider current while [child] is mounted.
class HabitDayTicker extends ConsumerStatefulWidget {
  const HabitDayTicker({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<HabitDayTicker> createState() => _HabitDayTickerState();
}

class _HabitDayTickerState extends ConsumerState<HabitDayTicker> {
  /// Fires just after the boundary, so the recompute lands on the new day.
  static const Duration _slack = Duration(seconds: 1);

  late final AppLifecycleListener _lifecycle;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _invalidate);
    // Every recompute (new day, reset time changed) re-arms the timer.
    ref.listenManual(habitTodayProvider, (_, _) => _schedule());
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    final now = ref.read(clockProvider).now();
    final reset = ref.read(settingsProvider).habitResetMinutes;
    final wait =
        HabitDay.nextStart(now, resetMinutes: reset).difference(now) + _slack;
    _timer = Timer(wait.isNegative ? _slack : wait, _invalidate);
  }

  void _invalidate() {
    if (mounted) ref.invalidate(habitTodayProvider);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
