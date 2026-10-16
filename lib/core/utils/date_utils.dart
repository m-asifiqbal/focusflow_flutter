/// ============================================================
/// DATE UTILS — day keys, week math, friendly labels
/// ============================================================
library;

import 'package:intl/intl.dart';

abstract final class DateUtilsX {
  /// `yyyy-MM-dd` key for a local day (habit logs, calendar maps).
  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static DateTime parseDayKey(String key) {
    final parts = key.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Encodes the calendar day of [day] for a "floating" date column (task
  /// due dates): UTC midnight of that y/m/d. Unlike local midnight it does
  /// not move to another day when the device changes time zone. Use it for
  /// values written to `tasks.due_date` *and* for SQL bounds compared to it.
  static DateTime toStoredDay(DateTime day) =>
      DateTime.utc(day.year, day.month, day.day);

  /// Decodes a [toStoredDay] value (Drift returns it as a local DateTime)
  /// back to the local calendar day at midnight.
  static DateTime fromStoredDay(DateTime stored) {
    final u = stored.toUtc();
    return DateTime(u.year, u.month, u.day);
  }

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Adds whole calendar days (DST-safe: works on y/m/d, not hours).
  static DateTime addDays(DateTime d, int days) =>
      DateTime(d.year, d.month, d.day + days, d.hour, d.minute, d.second);

  /// First day of the week containing [d]; [weekStart] uses
  /// DateTime.monday (1) … DateTime.sunday (7).
  static DateTime startOfWeek(DateTime d, int weekStart) {
    final day = dateOnly(d);
    final diff = (day.weekday - weekStart + 7) % 7;
    return addDays(day, -diff);
  }

  /// The 7 days of the week containing [d].
  static List<DateTime> weekDays(DateTime d, int weekStart) {
    final start = startOfWeek(d, weekStart);
    return [for (var i = 0; i < 7; i++) addDays(start, i)];
  }

  /// Minutes after midnight → DateTime on [day].
  static DateTime atMinutes(DateTime day, int minutes) =>
      DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60);

  /// "9:00 AM" / "09:00" depending on [use24h].
  static String time(DateTime t, {bool use24h = false}) =>
      use24h ? DateFormat('HH:mm').format(t) : DateFormat('hh:mm a').format(t);

  /// Minutes after midnight formatted as a time.
  static String minutesToTime(int minutes, {bool use24h = false}) =>
      time(atMinutes(DateTime(2000), minutes), use24h: use24h);

  /// Whole calendar days from [from] to [to] (time of day ignored).
  /// Computed on UTC dates: local midnights are 23 or 25 h apart across a
  /// DST change, which would make `Duration.inDays` off by one.
  static int daysBetween(DateTime from, DateTime to) => DateTime.utc(
    to.year,
    to.month,
    to.day,
  ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

  /// "Today" / "Tomorrow" / "Yesterday" / "Tue, Jun 13".
  static String relativeDay(DateTime d, DateTime now) {
    final diff = daysBetween(now, d);
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    if (d.year == now.year) return DateFormat('EEE, MMM d').format(d);
    return DateFormat('MMM d, y').format(d);
  }

  /// "2h ago", "5 min ago", "Yesterday", "Jun 8".
  static String ago(DateTime t, DateTime now) {
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24 && isSameDay(t, now)) return '${diff.inHours}h ago';
    if (isSameDay(t, addDays(now, -1))) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (t.year == now.year) return DateFormat('MMM d').format(t);
    return DateFormat('MMM d, y').format(t);
  }

  /// "in 25 min", "in 2 h", "5 min ago".
  static String until(DateTime t, DateTime now) {
    final diff = t.difference(now);
    if (diff.isNegative) return ago(t, now);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return 'in ${diff.inMinutes} min';
    if (diff.inHours < 24) {
      final m = diff.inMinutes % 60;
      return m == 0 ? 'in ${diff.inHours} h' : 'in ${diff.inHours} h $m min';
    }
    return 'in ${diff.inDays} d';
  }
}
