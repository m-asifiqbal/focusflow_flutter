/// ============================================================
/// PRAYER SCHEDULE — which days a prayer is due and its window that day
/// ============================================================
///
/// What: [PrayerSchedule.isDueOn] (weekdays, optional date range, paused),
/// [PrayerSchedule.windowOn] (start / end instants from the rules and the
/// day's sun times) and [PrayerSchedule.dayPlan] — the day's [PrayerSlot]s,
/// soonest first, each with its log and a [PrayerSlotState] at any instant
/// — and [PrayerSchedule.jamaatOn], the congregation's time that day.
/// Why: one place for the window rules the tab, the notification planner,
/// Home and the statistics all share. An end at or before the start means
/// the next day (Isha → midnight, a night vigil 23:00 – 01:00).
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer_log.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_jamaat_estimate.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_times.dart';

/// A prayer's window on one day.
@immutable
class PrayerWindow {
  const PrayerWindow(this.start, this.end);

  final DateTime start;

  /// Null = no end (a moment).
  final DateTime? end;

  /// The end, or the end of the start's day for an open-ended prayer.
  DateTime get until =>
      end ??
      DateTime(start.year, start.month, start.day).add(const Duration(days: 1));

  Duration? get length => end?.difference(start);

  bool contains(DateTime t) => !t.isBefore(start) && t.isBefore(until);

  @override
  bool operator ==(Object other) =>
      other is PrayerWindow && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// Where a prayer of the day stands at a given instant.
enum PrayerSlotState {
  /// Its window has not begun.
  upcoming,

  /// Inside its window, not marked.
  open,

  /// Inside the last [PrayerSchedule.endingSoon] of its window, not marked.
  endingSoon,

  /// Marked on time / late / made up.
  done,

  /// Window over without a mark, or marked missed.
  missed,

  /// Marked excused.
  excused,
}

/// One prayer on one day.
@immutable
class PrayerSlot {
  const PrayerSlot({
    required this.prayer,
    required this.day,
    required this.window,
    this.log,
  });

  final Prayer prayer;

  /// The day it belongs to (date only).
  final DateTime day;
  final PrayerWindow window;
  final PrayerLog? log;

  String get id => PrayerLog.idFor(prayer.id, DateUtilsX.dayKey(day));

  /// When the congregation prays that day (null = no jamaat set).
  DateTime? get jamaat => PrayerSchedule.jamaatOn(
    prayer,
    day,
    window.start,
    window.until,
    DateUtilsX.atMinutes,
  );

  PrayerStatus? get status {
    final s = log?.status;
    return s == null || s == PrayerStatus.pending ? null : s;
  }

  PrayerSlotState stateAt(DateTime now) {
    final s = status;
    if (s != null) {
      if (s.done) return PrayerSlotState.done;
      return s == PrayerStatus.excused
          ? PrayerSlotState.excused
          : PrayerSlotState.missed;
    }
    if (now.isBefore(window.start)) return PrayerSlotState.upcoming;
    if (!now.isBefore(window.until)) return PrayerSlotState.missed;
    final end = window.end;
    if (end != null && end.difference(now) <= PrayerSchedule.endingSoon) {
      return PrayerSlotState.endingSoon;
    }
    return PrayerSlotState.open;
  }

  /// The status a "Mark prayed" tap at [now] records: on time inside the
  /// window (or before it, praying early is the user's call), late after
  /// its end.
  PrayerStatus markAt(DateTime now) =>
      now.isBefore(window.until) ? PrayerStatus.onTime : PrayerStatus.late;

  @override
  bool operator ==(Object other) =>
      other is PrayerSlot &&
      other.prayer == prayer &&
      other.day == day &&
      other.window == window &&
      other.log == log;

  @override
  int get hashCode => Object.hash(prayer, day, window, log);
}

abstract final class PrayerSchedule {
  /// The jamaat of [p] on [day] whose window runs [start] – [until]: the
  /// estimate for a daily prayer, the window start + N minutes, or a clock
  /// time from [at] (a wall clock) —
  /// on the next day when the window crosses midnight and the time falls
  /// after it (Isha until 1 AM, jamaat at 00:15).
  static DateTime? jamaatOn(
    Prayer p,
    DateTime day,
    DateTime start,
    DateTime until,
    DateTime Function(DateTime day, int minutes) at,
  ) {
    final j = p.jamaat;
    if (j == null) return null;
    if (j.estimated) {
      final role = PrayerJamaatEstimate.roleOf(p);
      // Not one of the five daily prayers (renamed?): at the start.
      return role == null ? start : PrayerJamaatEstimate.at(role, start, until);
    }
    if (j.afterStart) return start.add(Duration(minutes: j.minutes));
    final t = at(day, j.minutes);
    if (t.isBefore(start)) {
      final next = at(DateUtilsX.addDays(day, 1), j.minutes);
      if (next.isBefore(until)) return next;
    }
    return t;
  }

  /// "Ends in 18 min": the last stretch of a window is flagged.
  static const Duration endingSoon = Duration(minutes: 20);

  /// Whether [p] is due on [day] (weekday, date range, pause).
  static bool isDueOn(Prayer p, DateTime day, {bool ignorePause = false}) {
    if (p.isPaused && !ignorePause) return false;
    final d = DateUtilsX.dateOnly(day);
    final from = p.startDate;
    if (from != null && d.isBefore(DateUtilsX.dateOnly(from))) return false;
    final to = p.endDate;
    if (to != null && d.isAfter(DateUtilsX.dateOnly(to))) return false;
    return p.weekdaysMask & (1 << (d.weekday - 1)) != 0;
  }

  /// The window of [p] on [day] with that day's [sun] times (null = no
  /// location: auto rules use their fallback times). An end at or before
  /// the start moves to the next day.
  static PrayerWindow windowOn(
    Prayer p,
    DateTime day,
    SolarDay? sun, {
    SolarDay? nextSun,
    SolarDay? prevSun,
  }) {
    final d = DateUtilsX.dateOnly(day);
    final start = startsLastNight(p) && prevSun != null
        ? p.start.on(d, prevSun)
        : p.start.on(d, sun);
    final rule = p.end;
    if (rule == null) return PrayerWindow(start, null);
    var end = rule.on(d, sun);
    if (!end.isAfter(start)) {
      // A fixed end, or a sun event that is "tomorrow" (dawn as the end of
      // a night prayer): the same rule on the next day.
      final next = DateUtilsX.addDays(d, 1);
      end = rule.isAuto && nextSun != null
          ? rule.on(next, nextSun)
          : end.add(const Duration(days: 1));
    }
    return PrayerWindow(start, end);
  }

  /// A prayer that starts at the last third of the night (Tahajjud): the
  /// sun day's `lastThird` is the night *after* that day, so the day's
  /// prayer uses the previous day's — the night ending this morning.
  static bool startsLastNight(Prayer p) =>
      p.start.event == SolarEvent.lastThird;

  /// The day's prayers due on [day], soonest first, each with its log from
  /// [logsById] (keys: [PrayerLog.idFor]). [sunFor] gives a day's sun times
  /// (null without a location).
  static List<PrayerSlot> dayPlan(
    Iterable<Prayer> prayers,
    DateTime day,
    SolarDay? Function(DateTime day) sunFor,
    Map<String, PrayerLog> logsById,
  ) {
    final d = DateUtilsX.dateOnly(day);
    final sun = sunFor(d);
    SolarDay? next;
    var nextDone = false;
    SolarDay? nextSun() {
      if (!nextDone) {
        next = sunFor(DateUtilsX.addDays(d, 1));
        nextDone = true;
      }
      return next;
    }

    final key = DateUtilsX.dayKey(d);
    final out = <PrayerSlot>[];
    for (final p in prayers) {
      if (!p.isActive || !isDueOn(p, d)) continue;
      out.add(
        PrayerSlot(
          prayer: p,
          day: d,
          window: windowOn(
            p,
            d,
            sun,
            nextSun: p.end?.isAuto ?? false ? nextSun() : null,
            prevSun: startsLastNight(p)
                ? sunFor(DateUtilsX.addDays(d, -1))
                : null,
          ),
          log: logsById[PrayerLog.idFor(p.id, key)],
        ),
      );
    }
    out.sort((a, b) {
      final c = a.window.start.compareTo(b.window.start);
      return c != 0 ? c : a.prayer.sortOrder.compareTo(b.prayer.sortOrder);
    });
    return out;
  }

  /// The next prayer to begin after [now]: the first of [today] (soonest
  /// first) whose window starts later, else the first of [tomorrow] (null
  /// = nothing ahead). Fasts and counting practices are never "next".
  static PrayerSlot? next(
    List<PrayerSlot> today,
    DateTime now, {
    List<PrayerSlot> Function()? tomorrow,
  }) {
    bool prayer(PrayerSlot s) => !s.prayer.kind.isFast && !s.prayer.kind.counts;
    for (final s in today) {
      if (prayer(s) && s.window.start.isAfter(now)) return s;
    }
    for (final s in tomorrow?.call() ?? const <PrayerSlot>[]) {
      if (prayer(s)) return s;
    }
    return null;
  }

  /// The prayer whose window is open at [now] and that is not marked yet
  /// (the one ending soonest when several are; null = none). Fasts and
  /// counting practices never count.
  static PrayerSlot? current(List<PrayerSlot> slots, DateTime now) {
    PrayerSlot? out;
    for (final s in slots) {
      if (s.prayer.kind.isFast || s.prayer.kind.counts) continue;
      if (s.status != null) continue;
      final st = s.stateAt(now);
      if (st != PrayerSlotState.open && st != PrayerSlotState.endingSoon) {
        continue;
      }
      if (out == null || s.window.until.isBefore(out.window.until)) out = s;
    }
    return out;
  }

  /// The next instant after [now] at which something on the Prayer page
  /// changes by itself: a window opens, enters its last [endingSoon]
  /// stretch or ends, a jamaat time comes into view (3 hours ahead) or
  /// passes, or the day rolls over. The page wakes at exactly this instant
  /// instead of waiting for the next minute tick (null = nothing ahead,
  /// which only happens for an empty list).
  static DateTime? nextChange(Iterable<PrayerSlot> slots, DateTime now) {
    DateTime? best;
    void consider(DateTime? t) {
      if (t == null || !t.isAfter(now)) return;
      if (best == null || t.isBefore(best!)) best = t;
    }

    for (final s in slots) {
      final end = s.window.end;
      consider(s.window.start);
      consider(end);
      if (end != null) consider(end.subtract(endingSoon));
      final j = s.jamaat;
      consider(j);
      if (j != null) consider(j.subtract(const Duration(hours: 3)));
    }
    consider(DateUtilsX.addDays(DateUtilsX.dateOnly(now), 1));
    return best;
  }

  /// Whether every prayer of the day (not fasts or counters) is done or
  /// excused — false for a day with none.
  static bool allDone(List<PrayerSlot> slots) {
    var any = false;
    for (final s in slots) {
      if (s.prayer.kind.isFast || s.prayer.kind.counts) continue;
      any = true;
      final st = s.status;
      if (st == null || !(st.done || st == PrayerStatus.excused)) return false;
    }
    return any;
  }

  /// The slot to put in the "next prayer" hero at [now]: the open one
  /// (ending soonest), else the next upcoming one; null when the day has
  /// nothing left. Fasts and counting practices never take the hero.
  static PrayerSlot? focus(List<PrayerSlot> slots, DateTime now) {
    PrayerSlot? open;
    PrayerSlot? upcoming;
    for (final s in slots) {
      if (s.prayer.kind.isFast || s.prayer.kind.counts) continue;
      switch (s.stateAt(now)) {
        case PrayerSlotState.open || PrayerSlotState.endingSoon:
          if (open == null || s.window.until.isBefore(open.window.until)) {
            open = s;
          }
        case PrayerSlotState.upcoming:
          upcoming ??= s;
        case _:
          break;
      }
    }
    return open ?? upcoming;
  }
}
