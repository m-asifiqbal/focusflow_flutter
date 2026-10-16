/// ============================================================
/// QUIET HOURS — delay non-alarm notifications out of a nightly window
/// ============================================================
///
/// What: a `[start, end)` window of wall-clock minutes (e.g. 22:00 → 07:00,
/// wrapping midnight). A notification that would fire inside the window is
/// moved to the window's end (screen 31: "Quiet hours delay non-alarm
/// notifications"). Alarm-style reminders are never delayed.
///
/// Why a value object: the planner, the settings screen subtitle and the
/// unit tests all need the same "is this minute quiet?" rule, including the
/// midnight wrap and DST nights (the end time is rebuilt as a wall time on
/// the right calendar day, never by adding a Duration).
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/notifications/planning/zone_calendar.dart';

@immutable
class QuietHours {
  const QuietHours({required this.startMinutes, required this.endMinutes});

  /// Minutes after midnight the window opens (inclusive).
  final int startMinutes;

  /// Minutes after midnight the window closes (exclusive).
  final int endMinutes;

  /// Equal start and end means "no window".
  bool get isEmpty => startMinutes == endMinutes;

  /// Whether the window crosses midnight (22:00 → 07:00).
  bool get wraps => startMinutes > endMinutes;

  /// Is wall-clock [minute] (0…1439) inside the window?
  bool containsMinute(int minute) {
    if (isEmpty) return false;
    if (!wraps) return minute >= startMinutes && minute < endMinutes;
    return minute >= startMinutes || minute < endMinutes;
  }

  /// [fireAt] unchanged when outside the window, otherwise the instant the
  /// window closes (same calendar day, or the next one for the late part of
  /// a window that wraps midnight).
  DateTime delay(DateTime fireAt, ZoneCalendar calendar) {
    final minute = calendar.minuteOfDay(fireAt);
    if (!containsMinute(minute)) return fireAt;
    final day = calendar.dayOf(fireAt);
    final endDay = wraps && minute >= startMinutes
        ? ZoneCalendar.addDays(day, 1)
        : day;
    final end = calendar.at(endDay, endMinutes);
    // A DST gap can make the rebuilt end land before [fireAt]; never move
    // a notification earlier.
    return end.isAfter(fireAt) ? end : fireAt;
  }

  @override
  bool operator ==(Object other) =>
      other is QuietHours &&
      other.startMinutes == startMinutes &&
      other.endMinutes == endMinutes;

  @override
  int get hashCode => Object.hash(startMinutes, endMinutes);
}
