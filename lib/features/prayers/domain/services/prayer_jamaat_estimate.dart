/// ============================================================
/// PRAYER JAMAAT ESTIMATE — a typical congregation time, offline
/// ============================================================
///
/// What: for the five daily prayers, the time a mosque typically holds the
/// jamaat on a given day, from that day's window: the start plus a usual
/// delay, rounded up to a time a mosque would put on its board, and kept
/// clear of the window's end:
///   Fajr     start + 30 min, to 5 min   (≥ 15 min before sunrise)
///   Dhuhr    start + 30 min, to 15 min  (1:15 / 1:30 PM)
///   Asr      start + 15 min, to 5 min
///   Maghrib  start + 5 min,  to 1 min   (prayed almost at once)
///   Isha     start + 15 min, to 5 min
/// [roleOf] tells which of the five a prayer is: by its sun event when it
/// follows the sun, else by its name (in the active language, English or
/// a common spelling).
/// Why: jamaat times belong to each mosque, and FocusFlow never goes online
/// or sends the location anywhere — an estimate that moves with the
/// seasons, labelled as such ("~"), is the honest offline answer. The user
/// can switch to the mosque's real time at any moment.
/// ============================================================
library;

import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_times.dart';

/// The five daily prayers, in order.
enum DailyPrayer {
  fajr(30, 5),
  dhuhr(30, 15),
  asr(15, 5),
  maghrib(5, 1),
  isha(15, 5);

  const DailyPrayer(this.delay, this.roundTo);

  /// Minutes after the window opens.
  final int delay;

  /// The clock step it is rounded up to.
  final int roundTo;
}

abstract final class PrayerJamaatEstimate {
  /// How close to the window's end an estimate may come.
  static const Duration endMargin = Duration(minutes: 15);

  /// Which daily prayer [p] is (null: not one of the five — a fast, a
  /// counter, Tahajjud, another tradition's prayer …).
  static DailyPrayer? roleOf(Prayer p) {
    if (p.kind != PrayerKind.salah) return null;
    final byEvent = switch (p.start.event) {
      SolarEvent.dawn => DailyPrayer.fajr,
      SolarEvent.noon => DailyPrayer.dhuhr,
      SolarEvent.asr => DailyPrayer.asr,
      SolarEvent.sunset => DailyPrayer.maghrib,
      SolarEvent.nightfall => DailyPrayer.isha,
      _ => null,
    };
    if (byEvent != null) return byEvent;
    final name = p.name.trim().toLowerCase();
    if (name.isEmpty) return null;
    for (final (role, words) in [
      (DailyPrayer.fajr, [tr('Fajr'), 'fajr', 'fajar', 'subh', 'fojor']),
      (DailyPrayer.dhuhr, [tr('Dhuhr'), 'dhuhr', 'zuhr', 'zohr', 'duhr']),
      (DailyPrayer.asr, [tr('Asr'), 'asr', 'asor']),
      (DailyPrayer.maghrib, [tr('Maghrib'), 'maghrib', 'magrib']),
      (DailyPrayer.isha, [tr('Isha'), 'isha', 'esha', 'ishaa']),
    ]) {
      if (words.any((w) => name == w.toLowerCase())) return role;
    }
    return null;
  }

  /// The estimated jamaat of a [role] prayer whose window runs [start] –
  /// [until] that day.
  static DateTime at(DailyPrayer role, DateTime start, DateTime until) {
    final step = Duration(minutes: role.roundTo);
    final raw = start.add(Duration(minutes: role.delay));
    // Whole minutes (sun times carry seconds), then up to the step on the
    // wall clock.
    var t = DateTime(raw.year, raw.month, raw.day, raw.hour, raw.minute);
    final into = (t.hour * 60 + t.minute) % role.roundTo;
    if (into != 0) {
      t = DateTime(t.year, t.month, t.day, t.hour, t.minute - into).add(step);
    }
    // Never so late the window is nearly over (short Fajr / Maghrib).
    final latest = until.subtract(endMargin);
    if (t.isAfter(latest)) {
      t = latest.isAfter(start) ? latest : start;
    }
    return t;
  }
}
