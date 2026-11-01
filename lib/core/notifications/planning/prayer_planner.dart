/// ============================================================
/// PRAYER PLANNER — prayer windows: at the start, before the end
/// ============================================================
///
/// For every day of the window, every due prayer (active, not paused —
/// `PrayersRepository.schedulable`) gets up to two notifications:
///   • `pry:<day>:<id>:s` — [Prayer.remindBefore] minutes before its window
///     starts (a fast: the Suhoor reminder); rings as an alarm for a high
///     priority prayer, quiet for a low one;
///   • `pry:<day>:<id>:e` — [Prayer.remindBeforeEnd] minutes before the
///     window ends, only while the prayer is not marked (a fast: the Iftar
///     reminder, unless the fast was marked broken / not fasted / excused);
///   • `pry:<day>:<id>:z` — a snoozed start reminder, at the snooze end
///     (its own key, so the original alarm is cancelled, not doubled).
/// Sun-based windows come from the saved location (PrayerSun); without one
/// every rule uses its fallback clock time. Prayer reminders ignore quiet
/// hours: Fajr is at dawn by definition.
/// ============================================================
library;

import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/notifications/planning/notification_plan.dart';
import 'package:focusflow/core/notifications/planning/planner_input.dart';
import 'package:focusflow/core/notifications/planning/zone_calendar.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer_log.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_schedule.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_sun.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_times.dart';

abstract final class PrayerPlanner {
  static const String prefix = 'pry:';

  /// `(dayKey, prayerId, kind)` of a prayer plan key (kind `s` / `e` /
  /// `z`), or null.
  static (String, String, String)? parseKey(String key) {
    final parts = key.split(':');
    if (parts.length != 4 || parts.first != 'pry') return null;
    if (parts[1].length != 10 || parts[2].isEmpty) return null;
    return (parts[1], parts[2], parts[3]);
  }

  /// A "before it ends" key — not vital, no inbox entry.
  static bool isEndKey(String key) =>
      key.startsWith(prefix) && key.endsWith(':e');

  /// Days of prayer reminders handed to the OS: prayers repeat several
  /// times a day, so on iOS (64 pending requests at most) they must not
  /// crowd out a reminder set for next week. Every app open and the
  /// background job roll the window forward.
  static int horizonDays(PlannerInput input) =>
      input.maxScheduled <= PlannerInput.defaultMaxScheduled ? 3 : 10;

  static List<PlannedNotification> plan(PlannerInput input, DateTime end) {
    final prefs = input.settings.prayer;
    if (!prefs.notify || input.prayers.isEmpty) return const [];
    final cal = input.calendar;
    final cap = cal.at(
      ZoneCalendar.addDays(input.today, horizonDays(input)),
      0,
    );
    final until = cap.isBefore(end) ? cap : end;
    final now = input.now;
    final sunFor = PrayerSun.dayFn(prefs);
    final logs = {for (final l in input.prayerLogs) l.id: l};
    final out = <PlannedNotification>[];
    // Yesterday too: a window that began yesterday may end tonight.
    for (
      var day = ZoneCalendar.addDays(input.today, -1);
      cal.at(day, 0).isBefore(until);
      day = ZoneCalendar.addDays(day, 1)
    ) {
      final dayKey = ZoneCalendar.dayKey(day);
      for (final p in input.prayers) {
        if (!PrayerSchedule.isDueOn(p, day)) continue;
        final (start, end) = window(input, p, day, sunFor);
        final log = logs[PrayerLog.idFor(p.id, dayKey)];
        final status = log?.status;
        final marked = status != null && status != PrayerStatus.pending;
        void add(PlannedNotification? n) {
          if (n != null && n.fireAt.isAfter(now) && n.fireAt.isBefore(until)) {
            out.add(n);
          }
        }

        final snooze = log?.snoozedUntil;
        if (!marked && snooze != null && snooze.isAfter(now)) {
          add(_start(input, p, dayKey, start, end, snooze, snoozed: true));
        } else if (!marked && p.remindBefore != null) {
          final at = start.subtract(Duration(minutes: p.remindBefore!));
          add(_start(input, p, dayKey, start, end, at));
        }
        final before = p.remindBeforeEnd;
        if (before != null && end != null) {
          final wanted = p.kind.isFast ? !_brokenFast(status) : !marked;
          if (wanted) {
            add(
              _end(
                input,
                p,
                dayKey,
                end,
                end.subtract(Duration(minutes: before)),
              ),
            );
          }
        }
      }
    }
    return out;
  }

  /// Whether the prayer behind [key] still wants its notification (a
  /// request whose time passed but that the OS has not shown yet).
  static bool stillWanted(PlannerInput input, String key) {
    if (!input.settings.prayer.notify) return false;
    final parsed = parseKey(key);
    if (parsed == null) return true;
    final (dayKey, id, kind) = parsed;
    final p = input.prayers.where((p) => p.id == id).firstOrNull;
    if (p == null) return false;
    final status = input.prayerLogs
        .where((l) => l.id == PrayerLog.idFor(id, dayKey))
        .firstOrNull
        ?.status;
    final marked = status != null && status != PrayerStatus.pending;
    if (kind == 'e' && p.kind.isFast) return !_brokenFast(status);
    return !marked;
  }

  /// A fast marked broken early, not fasted or excused gets no Iftar call.
  static bool _brokenFast(PrayerStatus? s) =>
      s == PrayerStatus.late ||
      s == PrayerStatus.missed ||
      s == PrayerStatus.excused;

  /// The window of [p] on [day] in the planner's zone: sun events from the
  /// location, fixed times on [PlannerInput.calendar]'s wall clock. An end
  /// at or before the start is the next day.
  static (DateTime, DateTime?) window(
    PlannerInput input,
    Prayer p,
    DateTime day,
    SolarDay? Function(DateTime) sunFor,
  ) {
    final cal = input.calendar;
    DateTime at(PrayerTimeRule r, DateTime d) {
      final e = r.event;
      final sun = e == null ? null : sunFor(d);
      if (e != null && sun != null) {
        return sun.at(e).add(Duration(minutes: r.offset));
      }
      return cal.at(d, r.minutes);
    }

    // Tahajjud: the night ending this morning (see PrayerSchedule).
    final lastNight = PrayerSchedule.startsLastNight(p)
        ? sunFor(ZoneCalendar.addDays(day, -1))
        : null;
    final start = lastNight != null
        ? lastNight.lastThird.add(Duration(minutes: p.start.offset))
        : at(p.start, day);
    final rule = p.end;
    if (rule == null) return (start, null);
    var end = at(rule, day);
    if (!end.isAfter(start)) end = at(rule, ZoneCalendar.addDays(day, 1));
    return (start, end);
  }

  static PlannedNotification _start(
    PlannerInput input,
    Prayer p,
    String dayKey,
    DateTime start,
    DateTime? end,
    DateTime fireAt, {
    bool snoozed = false,
  }) {
    final key = '$prefix$dayKey:${p.id}:${snoozed ? 'z' : 's'}';
    final name = p.displayName;
    final time = input.formatTime(start);
    final range = end == null ? time : '$time – ${input.formatTime(end)}';
    final lead = p.remindBefore ?? 0;
    final String title;
    if (input.settings.prayer.discreet) {
      title = tr('Reminder · {time}', {'time': time});
    } else if (p.kind.isFast) {
      title = tr('Suhoor ends at {time}', {'time': time});
    } else if (!snoozed && lead > 0) {
      title = tr('{name} in {m} min', {'name': name, 'm': lead});
    } else {
      title = tr('Time for {name}', {'name': name});
    }
    final body = input.settings.prayer.discreet
        ? '$name · $range'
        : [range, if (p.place.trim().isNotEmpty) p.place.trim()].join(' · ');
    return _notification(
      input,
      p,
      key,
      dayKey,
      fireAt,
      title,
      body,
      alarm: p.alarm,
      inbox: true,
    );
  }

  static PlannedNotification _end(
    PlannerInput input,
    Prayer p,
    String dayKey,
    DateTime end,
    DateTime fireAt,
  ) {
    final key = '$prefix$dayKey:${p.id}:e';
    final name = p.displayName;
    final time = input.formatTime(end);
    final before = p.remindBeforeEnd ?? 0;
    final String title;
    if (input.settings.prayer.discreet) {
      title = tr('Reminder · {time}', {'time': time});
    } else if (p.kind.isFast) {
      title = before <= 0
          ? tr('Iftar time')
          : tr('Iftar in {m} min', {'m': before});
    } else {
      title = before <= 0
          ? tr('{name} is ending', {'name': name})
          : tr('{name} ends in {m} min', {'name': name, 'm': before});
    }
    final body = p.kind.isFast
        ? tr('{name} · ends {time}', {'name': name, 'time': time})
        : tr('{name} · until {time}', {'name': name, 'time': time});
    // The Iftar call of a high-priority fast rings; an "ends soon" nudge
    // never does.
    return _notification(
      input,
      p,
      key,
      dayKey,
      fireAt,
      title,
      body,
      alarm: p.kind.isFast && p.alarm,
      inbox: p.kind.isFast,
    );
  }

  static PlannedNotification _notification(
    PlannerInput input,
    Prayer p,
    String key,
    String dayKey,
    DateTime fireAt,
    String title,
    String body, {
    required bool alarm,
    required bool inbox,
  }) {
    final category = alarm
        ? NotificationCategory.alarm
        : NotificationCategory.prayer;
    return PlannedNotification(
      id: notificationIdForKey(key),
      key: key,
      fireAt: fireAt,
      category: category,
      title: title,
      body: body,
      payload: NotificationPayload(
        key: key,
        category: category,
        target: p.ref,
        open: p.ref,
        route: AppRoutes.prayers,
        snoozeMinutes: p.snoozeMinutes,
        day: dayKey,
      ),
      buttons: const [
        NotificationButton.done,
        NotificationButton.snooze,
        NotificationButton.open,
      ],
      inboxRef: p.ref,
      inbox: inbox,
      sound: p.priority == PrayerPriority.low
          ? PlannedNotification.silentSound
          : p.sound,
    );
  }
}
