/// ============================================================
/// HABIT DAY — which calendar day "today" is for habits
/// ============================================================
///
/// Settings › Habits › "Habit reset time" lets night owls keep logging
/// yesterday's habits after midnight: until [resetMinutes] after midnight
/// the habit day is still the previous calendar day. Comparing minutes of
/// the day (instead of subtracting a Duration) keeps it DST-safe.
/// ============================================================
library;

import 'package:focusflow/core/utils/date_utils.dart';

abstract final class HabitDay {
  /// The habit day (local midnight) at [now] for a reset [resetMinutes]
  /// after midnight (0 = midnight; clamped to 0…1439).
  static DateTime of(DateTime now, {int resetMinutes = 0}) {
    final reset = resetMinutes.clamp(0, 24 * 60 - 1);
    final minuteOfDay = now.hour * 60 + now.minute;
    final day = DateUtilsX.dateOnly(now);
    return minuteOfDay < reset ? DateUtilsX.addDays(day, -1) : day;
  }

  /// The moment the next habit day starts after [now]: the local reset
  /// time on the calendar day after [now]'s habit day.
  static DateTime nextStart(DateTime now, {int resetMinutes = 0}) {
    final reset = resetMinutes.clamp(0, 24 * 60 - 1);
    final next = DateUtilsX.addDays(of(now, resetMinutes: reset), 1);
    return DateTime(next.year, next.month, next.day, reset ~/ 60, reset % 60);
  }
}
