/// ============================================================
/// PRAYER CLOCK TICKER — wakes the Prayer page when a waqt begins or ends
/// ============================================================
///
/// What: a one-shot timer set for [at] (the page's next change, from
/// [PrayerSchedule.nextChange]). When it fires it re-reads the clock
/// ([PrayerClock.refresh]); the page rebuilds with the new "now", hands the
/// hero the new slot and arms the timer again for the following change.
/// Also catches up when the app returns from the background.
/// Why: the shared minute clock only moves once a minute (and its timer
/// beats every 30 s), so a countdown could hit zero and sit there — the
/// card still showing the waqt that had just ended — until the page was
/// left and opened again. The timer lives in a widget so it is cancelled
/// with the screen (no leaked timers in tests).
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/features/prayers/presentation/providers/prayers_providers.dart';
import 'package:focusflow/shared/providers/core_providers.dart';

class PrayerClockTicker extends ConsumerStatefulWidget {
  const PrayerClockTicker({required this.at, required this.child, super.key});

  /// The next instant the page changes by itself (null = nothing to wait
  /// for).
  final DateTime? at;
  final Widget child;

  @override
  ConsumerState<PrayerClockTicker> createState() => _PrayerClockTickerState();
}

class _PrayerClockTickerState extends ConsumerState<PrayerClockTicker>
    with WidgetsBindingObserver {
  /// A beat past the boundary, so the clock has certainly crossed it.
  static const Duration _grace = Duration(milliseconds: 250);

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _arm();
  }

  @override
  void didUpdateWidget(PrayerClockTicker old) {
    super.didUpdateWidget(old);
    if (old.at != widget.at) _arm();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _fire();
  }

  void _arm() {
    _timer?.cancel();
    final at = widget.at;
    if (at == null) return;
    final wait = at.difference(ref.read(clockProvider).now());
    _timer = Timer(wait.isNegative ? Duration.zero : wait + _grace, _fire);
  }

  void _fire() {
    if (mounted) ref.read(prayerNowProvider.notifier).refresh();
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
