/// ============================================================
/// BACKUP SCHEDULE — pure timing rules for automatic backups
/// ============================================================
///
/// The OS decides when a background job actually runs (WorkManager /
/// BGTaskScheduler), so the job re-checks whether a Drive backup is due
/// instead of trusting its trigger. Rule: a backup is due once the chosen
/// time of day ("Back up at 9:00 PM") has passed since the last sync —
/// daily, or weekly with at least ~a week between backups.
/// ============================================================
library;

import 'package:focusflow/core/settings/app_settings.dart';

abstract final class BackupSchedule {
  /// Slack so a job that runs a little early still counts as "weekly".
  static const Duration weeklyMinimum = Duration(days: 6, hours: 20);

  /// The most recent occurrence of [minutesOfDay] (local) at or before
  /// [now].
  static DateTime lastSlot(DateTime now, int minutesOfDay) {
    final today = DateTime(
      now.year,
      now.month,
      now.day,
      minutesOfDay ~/ 60,
      minutesOfDay % 60,
    );
    return today.isAfter(now)
        ? DateTime(
            today.year,
            today.month,
            today.day - 1,
            today.hour,
            today.minute,
          )
        : today;
  }

  /// Time from [now] to the next occurrence of [minutesOfDay] (local).
  static Duration delayUntilNext(DateTime now, int minutesOfDay) {
    final last = lastSlot(now, minutesOfDay);
    final next = DateTime(
      last.year,
      last.month,
      last.day + 1,
      last.hour,
      last.minute,
    );
    final d = next.difference(now);
    return d == const Duration(days: 1) ? Duration.zero : d;
  }

  /// Whether the automatic Drive backup should run now.
  static bool isDriveDue({
    required DateTime now,
    required DateTime? lastSync,
    required BackupFrequency frequency,
    required int minutesOfDay,
  }) {
    if (lastSync == null) return true;
    if (!lastSync.isBefore(lastSlot(now, minutesOfDay))) return false;
    return frequency == BackupFrequency.daily ||
        now.difference(lastSync) >= weeklyMinimum;
  }
}
