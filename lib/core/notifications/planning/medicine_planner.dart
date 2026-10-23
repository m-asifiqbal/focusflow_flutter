/// ============================================================
/// MEDICINE PLANNER — dose alerts, snoozes and "did you take it?"
/// ============================================================
///
/// For every day of the window, every dose of a schedulable medicine
/// (active, not paused, reminders on — `MedicinesRepository.schedulable`)
/// that is not taken or skipped becomes part of a notification at its wall
/// time. Doses due at the same minute share ONE notification ("Time for 3
/// medicines") whose Taken / Snooze / Skip apply to all of them — the
/// payload lists their medicine ids.
///
/// Keys (`med:<yyyy-MM-dd>:<minute>[:…]`):
///   • `med:<day>:<min>`    the doses at their time;
///   • `med:<day>:<min>:s`  the same slot's snoozed doses, at the earliest
///                          snooze end (a different key, so the original
///                          alarm — which the alarm service may have
///                          re-armed itself — is cancelled, not doubled);
///   • `med:<day>:<min>:f`  the follow-up `followUpMinutes` after the dose
///                          time while it is still not logged (never for a
///                          snoozed dose: the snooze is its follow-up).
/// Alarm-style medicines ring as alarms (the follow-up never does). Doses
/// ignore quiet hours (NotificationCategory.bypassesQuietHours).
/// ============================================================
library;

import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/notifications/planning/notification_plan.dart';
import 'package:focusflow/core/notifications/planning/planner_input.dart';
import 'package:focusflow/core/notifications/planning/zone_calendar.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine_dose.dart';
import 'package:focusflow/features/medicines/domain/services/medicine_schedule.dart';
import 'package:focusflow/features/medicines/domain/services/medicine_words.dart';

abstract final class MedicinePlanner {
  static const String prefix = 'med:';

  /// A follow-up ("did you take it?") key — not vital, no inbox entry.
  static bool isFollowUpKey(String key) =>
      key.startsWith(prefix) && key.endsWith(':f');

  /// `(dayKey, minute)` of a medicine plan key, or null.
  static (String, int)? parseKey(String key) {
    final parts = key.split(':');
    if (parts.length < 3 || parts.first != 'med') return null;
    final minutes = int.tryParse(parts[2]);
    if (minutes == null || parts[1].length != 10) return null;
    return (parts[1], minutes);
  }

  static List<PlannedNotification> plan(PlannerInput input, DateTime until) {
    if (!input.settings.notifyMedicines || input.medicines.isEmpty) {
      return const [];
    }
    final cal = input.calendar;
    final now = input.now;
    final logs = [
      for (final w in input.medicines) {for (final l in w.logs) l.id: l},
    ];
    final result = <PlannedNotification>[];
    for (var day = input.today; ; day = ZoneCalendar.addDays(day, 1)) {
      if (!cal.at(day, 0).isBefore(until)) break;
      final dayKey = ZoneCalendar.dayKey(day);
      final groups = <String, _Group>{};
      for (var i = 0; i < input.medicines.length; i++) {
        final m = input.medicines[i].medicine;
        if (!MedicineSchedule.isScheduledOn(m, day)) continue;
        final seen = <int>{};
        for (final d in m.doses) {
          if (!seen.add(d.minutes)) continue;
          final log = logs[i][DoseLog.idFor(m.id, dayKey, d.minutes)];
          if (log != null && (log.isTaken || log.isSkipped)) continue;
          final slotAt = cal.at(day, d.minutes);
          final snooze = log?.snoozedUntil;
          final snoozed = snooze != null && snooze.isAfter(now);
          final fireAt = snoozed ? snooze : slotAt;
          final base = '$prefix$dayKey:${d.minutes}';
          if (fireAt.isAfter(now) && fireAt.isBefore(until)) {
            groups
                .putIfAbsent(
                  snoozed ? '$base:s' : base,
                  () => _Group(dayKey, d.minutes, slotAt),
                )
                .add(m, d.quantity, fireAt);
          }
          if (snoozed || m.followUpMinutes <= 0) continue;
          final followAt = slotAt.add(Duration(minutes: m.followUpMinutes));
          if (followAt.isAfter(now) && followAt.isBefore(until)) {
            groups
                .putIfAbsent(
                  '$base:f',
                  () => _Group(dayKey, d.minutes, slotAt, followUp: true),
                )
                .add(m, d.quantity, followAt);
          }
        }
      }
      for (final e in groups.entries) {
        result.add(_describe(input, e.key, e.value));
      }
    }
    return result;
  }

  /// Whether the doses behind plan [key] are still not logged (for a
  /// request whose time passed but that the OS has not shown yet).
  static bool stillWanted(PlannerInput input, String key) {
    if (!input.settings.notifyMedicines) return false;
    final parsed = parseKey(key);
    if (parsed == null) return true;
    final (dayKey, minutes) = parsed;
    final day = DateTime.parse(dayKey);
    for (final w in input.medicines) {
      final m = w.medicine;
      if (!MedicineSchedule.isScheduledOn(m, day)) continue;
      if (!m.doses.any((d) => d.minutes == minutes)) continue;
      final id = DoseLog.idFor(m.id, dayKey, minutes);
      final logged = w.logs.any(
        (l) => l.id == id && (l.isTaken || l.isSkipped),
      );
      if (!logged) return true;
    }
    return false;
  }

  static PlannedNotification _describe(
    PlannerInput input,
    String key,
    _Group g,
  ) {
    final single = g.items.length == 1 ? g.items.first : null;
    final alarm = !g.followUp && g.items.any((e) => e.$1.alarmStyle);
    final category = alarm
        ? NotificationCategory.alarm
        : NotificationCategory.medicine;
    final time = input.formatTime(g.slotAt);
    final String title;
    final String body;
    if (g.followUp) {
      title = tr('Did you take your {time} dose?', {'time': time});
      body = _names(g);
    } else if (single != null) {
      final (m, q) = single;
      title = tr('Time for {name}', {'name': _name(m)});
      body = _line(m, q);
    } else {
      title = tr(
        '{count, plural, one {Time for # medicine} other {Time for # medicines}}',
        {'count': g.items.length},
      );
      body = _names(g);
    }
    final ref = single?.$1.ref;
    final snooze = g.items
        .map((e) => e.$1.snoozeMinutes)
        .where((m) => m > 0)
        .fold<int?>(null, (a, b) => a == null || b < a ? b : a);
    return PlannedNotification(
      id: notificationIdForKey(key),
      key: key,
      fireAt: g.fireAt!,
      category: category,
      title: title,
      body: body,
      payload: NotificationPayload(
        key: key,
        category: category,
        target: g.items.first.$1.ref,
        open: ref,
        route: ref == null ? AppRoutes.medicines : null,
        snoozeMinutes: snooze,
        day: g.dayKey,
        doses: [for (final e in g.items) e.$1.id],
      ),
      buttons: g.followUp
          ? const [NotificationButton.taken, NotificationButton.skip]
          : const [
              NotificationButton.taken,
              NotificationButton.snooze,
              NotificationButton.skip,
            ],
      inboxRef: ref,
      inbox: !g.followUp,
    );
  }

  static String _name(Medicine m) =>
      m.name.trim().isEmpty ? tr('Medicine') : m.name.trim();

  /// "500 mg · 1 tablet · after food · 6 tablets left".
  static String _line(Medicine m, double quantity) {
    final low = m.isLow ? MedicineWords.left(m.stockLeft!, m.form) : null;
    return [MedicineWords.doseLine(m, quantity), ?low].join(' · ');
  }

  /// "Metformin (1 tablet), Vitamin D3 (1 capsule)".
  static String _names(_Group g) => g.items
      .map((e) => '${_name(e.$1)} (${MedicineWords.amount(e.$2, e.$1.form)})')
      .join(', ');
}

/// The doses that share one notification.
class _Group {
  _Group(this.dayKey, this.minutes, this.slotAt, {this.followUp = false});

  final String dayKey;
  final int minutes;
  final DateTime slotAt;
  final bool followUp;
  final List<(Medicine, double)> items = [];

  /// The earliest fire time of its doses.
  DateTime? fireAt;

  void add(Medicine m, double quantity, DateTime at) {
    items.add((m, quantity));
    final f = fireAt;
    if (f == null || at.isBefore(f)) fireAt = at;
  }
}
