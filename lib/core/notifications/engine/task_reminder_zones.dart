/// ============================================================
/// TASK REMINDER ZONES — task reminders follow the planning zone
/// ============================================================
///
/// What: before a reconcile pass, moves each open task's "Remind me"
/// reminder to its floating due day/time in the *planning zone* (the
/// device zone, or Settings › Time zone when set — the one rule used for
/// reminders, tasks and digests; see NotificationZones.resolve).
///
/// Why: the tasks repository writes reminder instants in the device's
/// local zone. After travel (device zone changed, possibly while the app
/// was closed) or with a zone override, the stored instant would fire at
/// the old wall time. The last planning zone is remembered in preferences
/// so a change between launches is caught too. Reminders the user moved
/// by hand are never touched (RemindersRepository.resyncTaskReminders).
/// ============================================================
library;

import 'package:focusflow/core/notifications/engine/planner_snapshot.dart';
import 'package:focusflow/core/notifications/planning/zone_calendar.dart';
import 'package:focusflow/core/utils/app_logger.dart';
import 'package:focusflow/features/reminders/domain/repository/reminders_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

abstract final class TaskReminderZones {
  /// Preference: IANA name of the zone the last pass planned in.
  static const String lastZoneKey = 'notifications.last_zone';

  /// Aligns task reminders with [location]; [previous] = zones planned in
  /// earlier this session. Returns how many reminders moved.
  static Future<int> align(
    RemindersRepository reminders,
    SharedPreferences prefs,
    tz.Location location, {
    Iterable<tz.Location> previous = const [],
  }) async {
    final names = <String>{
      ?prefs.getString(lastZoneKey),
      for (final p in previous) p.name,
    }..remove(location.name);
    final from = <WallClock>[
      for (final name in names)
        if (_location(name) case final l?) ZoneCalendar(l).at,
    ];
    var moved = 0;
    try {
      moved = await reminders.resyncTaskReminders(
        ZoneCalendar(location).at,
        from: from,
      );
    } catch (e) {
      AppLogger.w('Task reminder zone sync failed: $e');
      return 0;
    }
    if (prefs.getString(lastZoneKey) != location.name) {
      await prefs.setString(lastZoneKey, location.name);
    }
    return moved;
  }

  static tz.Location? _location(String name) {
    NotificationZones.ensureLoaded();
    try {
      return tz.getLocation(name);
    } on tz.LocationNotFoundException {
      return null;
    }
  }
}
