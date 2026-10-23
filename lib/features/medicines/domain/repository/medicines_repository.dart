/// ============================================================
/// MEDICINES REPOSITORY (contract)
/// ============================================================
///
/// Loads medicines + dose logs and writes doses. Day-level rules (what is
/// due, adherence, streaks) are pure domain code in `domain/services/`.
/// Days are local calendar days; pass any DateTime within the day.
///
/// Stock: taking a dose subtracts its amount from [Medicine.stockLeft]
/// (when tracked, never below 0); un-taking it (skip, undo) gives it back —
/// every dose write adjusts the stock by the difference between the old
/// and the new state, so repeated taps can never drift the count.
/// ============================================================
library;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine_dose.dart';
import 'package:focusflow/features/medicines/domain/services/medicine_insights.dart';
import 'package:focusflow/features/medicines/domain/services/medicine_stats.dart';

enum MedicinesScope {
  /// Active medicines (paused and finished courses included).
  active,

  /// Archived (not deleted) medicines.
  archived,
}

/// Everything the medicine list (and the Reminders "Medicine" chip) shows
/// for one day.
@immutable
class MedicineDay {
  const MedicineDay({
    required this.day,
    required this.slots,
    required this.medicines,
  });

  final DateTime day;

  /// The day's doses, soonest first (see MedicineSchedule.dayPlan).
  final List<DoseSlot> slots;

  /// Every active medicine (the cabinet), pinned first then manual order.
  final List<Medicine> medicines;

  /// As-needed medicines (logged with "Log a dose").
  List<Medicine> get asNeeded => [
    for (final m in medicines)
      if (m.isAsNeeded && !m.isPaused && !m.hasEndedBy(day)) m,
  ];

  /// Medicines at or below their refill threshold.
  List<Medicine> get lowStock => [
    for (final m in medicines)
      if (m.isLow && !m.isPaused && !m.hasEndedBy(day)) m,
  ];

  /// Scheduled (not as-needed) doses of the day.
  List<DoseSlot> get scheduled => [
    for (final s in slots)
      if (!s.isAsNeeded) s,
  ];

  bool get isEmpty => medicines.isEmpty;

  static const _slotsEq = ListEquality<DoseSlot>();
  static const _medsEq = ListEquality<Medicine>();

  @override
  bool operator ==(Object other) =>
      other is MedicineDay &&
      other.day == day &&
      _slotsEq.equals(other.slots, slots) &&
      _medsEq.equals(other.medicines, medicines);

  @override
  int get hashCode =>
      Object.hash(day, _slotsEq.hash(slots), _medsEq.hash(medicines));
}

/// Everything the medicine detail screen shows.
@immutable
class MedicineDetail {
  const MedicineDetail({
    required this.medicine,
    required this.stats,
    required this.now,
  });

  final Medicine medicine;
  final MedicineStats stats;

  /// The instant the stats were computed for.
  final DateTime now;

  @override
  bool operator ==(Object other) =>
      other is MedicineDetail &&
      other.medicine == medicine &&
      other.stats == stats &&
      other.now == now;

  @override
  int get hashCode => Object.hash(medicine, stats, now);
}

/// A medicine with its dose logs in a range (notification planner).
@immutable
class MedicineWithDoses {
  const MedicineWithDoses({required this.medicine, required this.logs});

  final Medicine medicine;
  final List<DoseLog> logs;

  static const _eq = ListEquality<DoseLog>();

  @override
  bool operator ==(Object other) =>
      other is MedicineWithDoses &&
      other.medicine == medicine &&
      _eq.equals(other.logs, logs);

  @override
  int get hashCode => Object.hash(medicine, _eq.hash(logs));
}

abstract interface class MedicinesRepository {
  /// Medicines of [scope], pinned first then manual order.
  Stream<List<Medicine>> watchMedicines(MedicinesScope scope);

  /// One medicine in any lifecycle state (null when gone).
  Stream<Medicine?> watchMedicine(String id);
  Future<Medicine?> getMedicine(String id);

  /// The doses of [day] and the cabinet (see [MedicineDay]).
  Stream<MedicineDay> watchDay(DateTime day);

  /// Medicine + stats at [now] (re-computed when doses change).
  Stream<MedicineDetail?> watchDetail(String id, DateTime now);

  /// Insights › Medicine for [period] ending on [now]'s day (recomputed
  /// when doses change; the yearly pass runs on a background isolate).
  Stream<MedicineInsights> watchInsights(MedicinePeriod period, DateTime now);

  /// Dose logs with day in [from, to] (inclusive) — calendar dots.
  Stream<List<DoseLog>> watchLogsInRange(DateTime from, DateTime to);

  /// Active, not paused medicines with reminders on, with their logs from
  /// [from] to [to] (inclusive days) — read fresh, for the planner.
  Future<List<MedicineWithDoses>> schedulable(DateTime from, DateTime to);

  /// The stored log of a scheduled dose (null = not logged).
  Future<DoseLog?> doseLog(String medicineId, DateTime day, int minutes);

  /// Marks the dose taken (now, with [quantity] or the scheduled amount).
  Future<void> markTaken(
    String medicineId,
    DateTime day,
    int minutes, {
    double? quantity,
  });

  /// Marks the dose skipped.
  Future<void> markSkipped(String medicineId, DateTime day, int minutes);

  /// Snoozes the dose until [until] (it stays pending).
  Future<void> snooze(
    String medicineId,
    DateTime day,
    int minutes,
    DateTime until,
  );

  /// Puts the dose back to exactly [previous] (null = not logged) — undo.
  Future<void> restoreDose(
    String medicineId,
    DateTime day,
    int minutes,
    DoseLog? previous,
  );

  /// Logs an as-needed dose taken at [at]. Returns the new log's id.
  Future<String> logAsNeeded(String medicineId, DateTime at, double quantity);

  /// Deletes an as-needed dose (undo of [logAsNeeded]); gives the stock back.
  Future<void> deleteAsNeeded(String doseId);

  /// Writes imported dose logs as they are (no stock change: an import
  /// brings the stock it had). Existing doses with the same id are kept.
  Future<void> importDoses(List<DoseLog> logs);

  /// Adds [amount] units to the stock (starts tracking when untracked).
  Future<void> refill(String id, double amount);

  /// Creates ([Medicine.isNew]) or updates a medicine. Returns the id.
  /// Update writes only the editor's fields: paused / pinned / favourite
  /// and tags keep their stored values, and the stock only when
  /// [writeStock] (the user edited it — doses taken meanwhile must not be
  /// undone by a stale draft).
  Future<String> save(Medicine medicine, {bool writeStock = false});

  Future<void> setPaused(String id, bool paused);
}
