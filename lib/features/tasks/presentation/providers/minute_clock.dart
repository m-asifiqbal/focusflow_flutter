/// ============================================================
/// MINUTE CLOCK — "now" for time-relative lists (tasks, reminders)
/// ============================================================
///
/// What: [minuteClockProvider] holds the current instant truncated to the
/// minute (read from the injectable [clockProvider]); [MinuteTicker] is a
/// widget that refreshes it every 30 s while a list screen is visible.
/// Why: "Overdue", "Today", "next in 25 min" and the reminders timeline are
/// relative to now, so they must recompute when the minute (or the day)
/// changes — but only while someone is looking. The timer lives in a
/// widget so it is cancelled with the screen (no leaked timers in tests),
/// and the value comes from the clock provider so tests can freeze it.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/shared/providers/core_providers.dart';

/// The current instant, truncated to the minute.
class MinuteClock extends Notifier<DateTime> {
  @override
  DateTime build() => _read();

  DateTime _read() {
    final t = ref.read(clockProvider).now();
    return DateTime(t.year, t.month, t.day, t.hour, t.minute);
  }

  /// Re-reads the clock; listeners rebuild only when the minute changed.
  void tick() {
    final next = _read();
    if (next != state) state = next;
  }
}

final minuteClockProvider = NotifierProvider<MinuteClock, DateTime>(
  MinuteClock.new,
);

/// Today's local calendar day (midnight), derived from [minuteClockProvider].
final todayProvider = Provider<DateTime>(
  (ref) => DateUtilsX.dateOnly(ref.watch(minuteClockProvider)),
);

/// Today's day for an action that is about to write (pick a date, set a
/// time / repeat anchor): re-reads the clock first, so a stale minute
/// (app resumed after midnight) never creates items in the past.
DateTime readFreshToday(WidgetRef ref) {
  ref.read(minuteClockProvider.notifier).tick();
  return ref.read(todayProvider);
}

/// Keeps [minuteClockProvider] fresh while [child] is mounted.
class MinuteTicker extends ConsumerStatefulWidget {
  const MinuteTicker({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<MinuteTicker> createState() => _MinuteTickerState();
}

class _MinuteTickerState extends ConsumerState<MinuteTicker>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _tick());
    // A screen opened after a while must not show a stale "now".
    WidgetsBinding.instance.addPostFrameCallback((_) => _tick());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _tick();
  }

  void _tick() {
    if (mounted) ref.read(minuteClockProvider.notifier).tick();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
