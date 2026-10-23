/// ============================================================
/// PLANNER SNAPSHOT — repositories + settings → one PlannerInput
/// ============================================================
///
/// What: reads the current value of each repository stream the planner
/// needs (schedulable reminders, active tasks, today's habits) and wraps
/// them with the settings, the clock and the wall-clock zone.
///
/// Why: the engine treats repository streams only as *triggers*; every
/// reconcile reads a fresh, consistent snapshot here. The background
/// action isolate uses the same loader, so both plan identically.
///
/// The planning window comes from [PlannerLimits] (platform dependent).
///
/// Also resolves the planning time zone: `AppSettings.timeZone` when set
/// and known, else the device zone, else UTC.
/// ============================================================
library;

import 'package:focusflow/core/notifications/planning/planner_input.dart';
import 'package:focusflow/core/notifications/planning/zone_calendar.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/utils/clock.dart';
import 'package:focusflow/features/habits/domain/repository/habits_repository.dart';
import 'package:focusflow/features/medicines/domain/repository/medicines_repository.dart';
import 'package:focusflow/features/reminders/domain/repository/reminders_repository.dart';
import 'package:focusflow/features/tasks/domain/repository/tasks_repository.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class PlannerSnapshotLoader {
  const PlannerSnapshotLoader({
    required this.reminders,
    required this.tasks,
    required this.habits,
    required this.medicines,
    required this.clock,
    this.limits = PlannerLimits.conservative,
  });

  final RemindersRepository reminders;
  final TasksRepository tasks;
  final HabitsRepository habits;
  final MedicinesRepository medicines;
  final Clock clock;

  /// How far ahead / how much the platform's OS can be asked to hold.
  final PlannerLimits limits;

  Future<PlannerInput> load(AppSettings settings, tz.Location location) async {
    final now = clock.now();
    final calendar = ZoneCalendar(location);
    final today = calendar.dayOf(now);
    final (rs, ts, hs, ms) = await (
      reminders.watchSchedulable().first,
      tasks.watchTasks(const TasksQuery()).first,
      // Computed now, not read from a shared live stream: the pass must
      // include every write made before it (editors flush right after saving).
      habits.todayHabitsNow(today, weekStartsOn: settings.weekStartsOn),
      medicines.schedulable(
        ZoneCalendar.addDays(today, -1),
        ZoneCalendar.addDays(today, limits.horizonDays + 1),
      ),
    ).wait;
    return PlannerInput(
      now: now,
      calendar: calendar,
      settings: settings,
      reminders: rs,
      tasks: ts,
      habits: hs,
      medicines: ms,
      horizonDays: limits.horizonDays,
      vitalHorizonDays: limits.vitalHorizonDays,
      maxScheduled: limits.maxScheduled,
    );
  }
}

/// IANA zone handling for the engine.
abstract final class NotificationZones {
  static bool _loaded = false;

  /// Loads the tz database once (cheap to call again).
  static void ensureLoaded() {
    if (_loaded) return;
    tzdata.initializeTimeZones();
    _loaded = true;
  }

  /// [override] (Settings › Time zone) when valid, else [device], else UTC.
  static tz.Location resolve({String? override, String? device}) {
    ensureLoaded();
    for (final name in [override, device]) {
      if (name == null || name.isEmpty) continue;
      try {
        return tz.getLocation(name);
      } on tz.LocationNotFoundException {
        continue;
      }
    }
    return tz.UTC;
  }
}
