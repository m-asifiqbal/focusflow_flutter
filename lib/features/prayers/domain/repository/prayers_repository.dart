/// ============================================================
/// PRAYERS REPOSITORY (contract)
/// ============================================================
///
/// Loads prayers and their day logs, and writes logs. Windows, the day plan
/// and statistics are pure domain code (`domain/services/`) because they
/// also depend on the saved location (settings), not only on the database.
/// Days are local calendar days; pass any DateTime within the day.
/// Archive / delete / restore go through the shared ItemsRepository.
/// ============================================================
library;

import 'package:focusflow/features/prayers/domain/entities/prayer.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer_log.dart';

enum PrayersScope {
  /// Active prayers (paused ones included).
  active,

  /// Archived (not deleted) prayers.
  archived,
}

abstract interface class PrayersRepository {
  /// Prayers of [scope], pinned first then manual order.
  Stream<List<Prayer>> watchPrayers(PrayersScope scope);

  /// One prayer in any lifecycle state (null when gone).
  Stream<Prayer?> watchPrayer(String id);
  Future<Prayer?> getPrayer(String id);

  /// Every log with day in [from, to] (inclusive); re-emits on log writes.
  Stream<List<PrayerLog>> watchLogs(DateTime from, DateTime to);

  /// [watchLogs] read once (the notification planner).
  Future<List<PrayerLog>> logsBetween(DateTime from, DateTime to);

  /// Active, not paused prayers — read fresh, for the planner.
  Future<List<Prayer>> schedulable();

  /// The log of [prayerId] on [day] (null = not marked).
  Future<PrayerLog?> log(String prayerId, DateTime day);

  /// Records [status] for the day (creating the log), stamped [at] (now
  /// when null). [place] / [congregation] keep their stored values when
  /// null. Clears a snooze.
  Future<void> mark(
    String prayerId,
    DateTime day,
    PrayerStatus status, {
    DateTime? at,
    String? place,
    bool? congregation,
  });

  /// Adds [delta] to the day's tally (never below 0) and returns the new
  /// count. Reaching [target] marks it on time; dropping below a target it
  /// had reached un-marks it.
  Future<int> addCount(String prayerId, DateTime day, int delta, {int? target});

  /// Snoozes the day's reminder until [until] (the log stays pending).
  Future<void> snooze(String prayerId, DateTime day, DateTime until);

  /// Puts the day back to exactly [previous] (null = not marked) — undo.
  Future<void> restoreLog(String prayerId, DateTime day, PrayerLog? previous);

  /// Creates ([Prayer.isNew]) or updates a prayer. Returns the id. An
  /// update writes the editor's fields only (pinned / favourite / paused
  /// and tags keep their stored values).
  Future<String> save(Prayer prayer);

  /// Creates every draft of [prayers] (the setup picker), in order.
  Future<List<String>> addAll(List<Prayer> prayers);

  Future<void> setPaused(String id, bool paused);
}
