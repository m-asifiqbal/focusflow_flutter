/// ============================================================
/// MEDICINES REPOSITORY (Drift implementation)
/// ============================================================
///
/// Loads medicines + dose logs and delegates every day-level rule to the
/// pure services (MedicineSchedule, MedicineStatsCalculator). Dose writes
/// run in one transaction with the stock change they cause (see the
/// contract), and stamp the medicine row only when its stock changed.
/// ============================================================
library;

import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:focusflow/core/database/daos/dao_support.dart';
import 'package:focusflow/core/database/daos/medicines_dao.dart';
import 'package:focusflow/core/database/daos/organisation_dao.dart';
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/items/data/item_mappers.dart';
import 'package:focusflow/core/items/data/repository_base.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/medicines/data/repository/medicine_row_mapper.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine_dose.dart';
import 'package:focusflow/features/medicines/domain/repository/medicines_repository.dart';
import 'package:focusflow/features/medicines/domain/services/medicine_insights.dart';
import 'package:focusflow/features/medicines/domain/services/medicine_schedule.dart';
import 'package:focusflow/features/medicines/domain/services/medicine_stats.dart';

class MedicinesRepositoryImpl extends RepositoryBase
    implements MedicinesRepository {
  MedicinesRepositoryImpl({
    required super.db,
    required super.clock,
    required super.deviceId,
    required super.newId,
  }) : _dao = MedicinesDao(db),
       _org = OrganisationDao(db),
       _tags = TagWriter(OrganisationDao(db), newId);

  final MedicinesDao _dao;
  final OrganisationDao _org;
  final TagWriter _tags;

  Set<ResultSetImplementation<dynamic, dynamic>> get _tables => {
    db.medicines,
    db.medicineDoses,
    db.itemTags,
    db.tags,
  };

  // ───────────────────────────── Reading ──────────────────────────────

  Future<List<Medicine>> _load(
    String where, [
    List<Variable> vars = const [],
  ]) async {
    final rows = await _dao.queryMedicines(where: where, variables: vars).get();
    if (rows.isEmpty) return const [];
    final tags = await _org.tagsByItem(
      ItemType.medicine,
      itemIds: rows.map((r) => r.id),
    );
    return [
      for (final r in rows)
        MedicineRowMapper.medicine(r, ItemMappers.tags(tags[r.id])),
    ];
  }

  Future<List<DoseLog>> _logs(
    Iterable<String> ids, {
    DateTime? from,
    DateTime? to,
  }) async {
    final list = ids.toList();
    if (list.isEmpty) return const [];
    final rows = await _dao.doses(
      medicineIds: list,
      fromKey: from == null ? null : DateUtilsX.dayKey(from),
      toKey: to == null ? null : DateUtilsX.dayKey(to),
    );
    return List.unmodifiable(rows.map(MedicineRowMapper.dose));
  }

  static String _scopeSql(MedicinesScope scope) => switch (scope) {
    MedicinesScope.active => activeSql('m'),
    MedicinesScope.archived =>
      'm.archived_at IS NOT NULL AND m.deleted_at IS NULL',
  };

  @override
  Stream<List<Medicine>> watchMedicines(MedicinesScope scope) =>
      db.watchComputed({db.medicines, db.itemTags, db.tags}, () async {
        return List<Medicine>.unmodifiable(await _load(_scopeSql(scope)));
      });

  @override
  Stream<Medicine?> watchMedicine(String id) => db.watchComputed({
    db.medicines,
    db.itemTags,
    db.tags,
  }, () => getMedicine(id));

  @override
  Future<Medicine?> getMedicine(String id) async {
    final list = await _load('m.id = ?', [Variable.withString(id)]);
    return list.isEmpty ? null : list.first;
  }

  @override
  Stream<MedicineDay> watchDay(DateTime day) {
    final date = DateUtilsX.dateOnly(day);
    return db.watchComputed(
      _tables,
      // The medicine list, the Reminders chip and Home read the same day.
      shareKey: ('medicine-day', DateUtilsX.dayKey(date)),
      () async {
        final meds = await _load(_scopeSql(MedicinesScope.active));
        final logs = await _logs(meds.map((m) => m.id), from: date, to: date);
        return MedicineDay(
          day: date,
          slots: List.unmodifiable(MedicineSchedule.dayPlan(meds, date, logs)),
          medicines: meds,
        );
      },
    );
  }

  @override
  Stream<MedicineDetail?> watchDetail(String id, DateTime now) =>
      db.watchComputed(_tables, () async {
        final m = await getMedicine(id);
        if (m == null) return null;
        final today = DateUtilsX.dateOnly(now);
        final logs = await _logs(
          [id],
          from: DateUtilsX.addDays(today, -MedicineStatsCalculator.streakLimit),
          to: today,
        );
        return MedicineDetail(
          medicine: m,
          stats: MedicineStatsCalculator.compute(m, logs, now),
          now: now,
        );
      });

  @override
  Stream<MedicineInsights> watchInsights(
    MedicinePeriod period,
    DateTime now,
  ) => db.watchComputed(_tables, () async {
    final win = MedicineInsightsCalculator.window(period, now);
    final prev = MedicineInsightsCalculator.previousWindow(period, win);
    // History counts archived medicines too (up to their archive day).
    final meds = await _load('m.deleted_at IS NULL');
    final logs = await _logs(
      meds.map((m) => m.id),
      from: prev.$1,
      to: win.$2,
    );
    MedicineInsights run() => MedicineInsightsCalculator.compute(
      medicines: meds,
      logs: logs,
      period: period,
      now: now,
    );
    // A year of daily doses for several medicines: off the UI isolate.
    return period == MedicinePeriod.yearly ? Isolate.run(run) : run();
  });

  @override
  Stream<List<DoseLog>> watchLogsInRange(DateTime from, DateTime to) =>
      db.watchComputed({db.medicineDoses, db.medicines}, () async {
        // Archived / trashed medicines never show (rule 3).
        final active = await _dao
            .queryMedicines(where: activeSql('m'))
            .map((r) => r.id)
            .get();
        if (active.isEmpty) return const <DoseLog>[];
        final rows = await _dao.doses(
          medicineIds: active,
          fromKey: DateUtilsX.dayKey(from),
          toKey: DateUtilsX.dayKey(to),
        );
        return List<DoseLog>.unmodifiable(rows.map(MedicineRowMapper.dose));
      });

  @override
  Future<List<MedicineWithDoses>> schedulable(
    DateTime from,
    DateTime to,
  ) async {
    final meds = await _load(
      '${activeSql('m')} AND m.is_paused = 0 AND m.reminder_enabled = 1 '
      'AND m.schedule_type != ${MedicineScheduleType.asNeeded.index}',
    );
    if (meds.isEmpty) return const [];
    final logs = await _logs(meds.map((m) => m.id), from: from, to: to);
    final byMed = <String, List<DoseLog>>{};
    for (final l in logs) {
      byMed.putIfAbsent(l.medicineId, () => []).add(l);
    }
    return [
      for (final m in meds)
        MedicineWithDoses(
          medicine: m,
          logs: List.unmodifiable(byMed[m.id] ?? const <DoseLog>[]),
        ),
    ];
  }

  @override
  Future<DoseLog?> doseLog(String medicineId, DateTime day, int minutes) async {
    final row = await _dao.doseById(
      DoseLog.idFor(medicineId, DateUtilsX.dayKey(day), minutes),
    );
    return row == null ? null : MedicineRowMapper.dose(row);
  }

  // ───────────────────────────── Doses ────────────────────────────────

  /// Writes the scheduled dose ([medicineId], [day], [minutes]) as
  /// [next] (null = delete the log) and moves the stock by the change.
  Future<void> _setDose(
    String medicineId,
    DateTime day,
    int minutes,
    DoseLog? Function(DoseLog? old, Medicine m, DateTime now) next,
  ) => db.transaction(() async {
    final m = await getMedicine(medicineId);
    if (m == null) return;
    final key = DateUtilsX.dayKey(day);
    final id = DoseLog.idFor(medicineId, key, minutes);
    final oldRow = await _dao.doseById(id);
    final old = oldRow == null ? null : MedicineRowMapper.dose(oldRow);
    final now = this.now();
    final value = next(old, m, now);
    await _write(id, old, value, now);
    await _moveStock(m, old, value);
  });

  Future<void> _write(
    String id,
    DoseLog? old,
    DoseLog? value,
    DateTime now,
  ) async {
    if (value == null) {
      if (old != null) await _dao.deleteDose(id);
      return;
    }
    final content = MedicineDosesCompanion(
      status: Value(value.status.index),
      takenAt: Value(value.takenAt),
      quantity: Value(value.quantity),
      snoozedUntil: Value(value.snoozedUntil),
      updatedAt: Value(now),
    );
    if (old == null) {
      await _dao.insertDose(
        content.copyWith(
          id: Value(id),
          medicineId: Value(value.medicineId),
          date: Value(value.dayKey),
          slotMinutes: Value(value.slotMinutes),
          createdAt: Value(now),
        ),
      );
    } else {
      await _dao.updateDose(id, content);
    }
  }

  /// Applies the stock change of a dose going from [old] to [value].
  Future<void> _moveStock(Medicine m, DoseLog? old, DoseLog? value) async {
    final left = m.stockLeft;
    if (left == null) return;
    final before = old != null && old.isTaken ? old.quantity : 0.0;
    final after = value != null && value.isTaken ? value.quantity : 0.0;
    final delta = before - after;
    if (delta == 0) return;
    final next = left + delta;
    await _dao.updateMedicine(
      m.id,
      MedicinesCompanion(stockLeft: Value(next < 0 ? 0 : next)),
      stamp(),
    );
  }

  DoseLog _fresh(String medicineId, DateTime day, int minutes, DateTime now) =>
      DoseLog(
        id: DoseLog.idFor(medicineId, DateUtilsX.dayKey(day), minutes),
        medicineId: medicineId,
        dayKey: DateUtilsX.dayKey(day),
        slotMinutes: minutes,
        createdAt: now,
        updatedAt: now,
      );

  @override
  Future<void> markTaken(
    String medicineId,
    DateTime day,
    int minutes, {
    double? quantity,
  }) => _setDose(medicineId, day, minutes, (old, m, now) {
    final base = old ?? _fresh(medicineId, day, minutes, now);
    return base.copyWith(
      status: DoseStatus.taken,
      takenAt: now,
      quantity: quantity ?? m.quantityAt(minutes),
      clearSnooze: true,
    );
  });

  @override
  Future<void> markSkipped(String medicineId, DateTime day, int minutes) =>
      _setDose(medicineId, day, minutes, (old, m, now) {
        final base = old ?? _fresh(medicineId, day, minutes, now);
        return base.copyWith(
          status: DoseStatus.skipped,
          takenAt: now,
          quantity: m.quantityAt(minutes),
          clearSnooze: true,
        );
      });

  @override
  Future<void> snooze(
    String medicineId,
    DateTime day,
    int minutes,
    DateTime until,
  ) => _setDose(medicineId, day, minutes, (old, m, now) {
    final base = old ?? _fresh(medicineId, day, minutes, now);
    return base.copyWith(
      status: DoseStatus.pending,
      clearTakenAt: true,
      quantity: m.quantityAt(minutes),
      snoozedUntil: RepositoryBase.truncateToSeconds(until),
    );
  });

  @override
  Future<void> restoreDose(
    String medicineId,
    DateTime day,
    int minutes,
    DoseLog? previous,
  ) => _setDose(medicineId, day, minutes, (_, _, _) => previous);

  @override
  Future<String> logAsNeeded(
    String medicineId,
    DateTime at,
    double quantity,
  ) async {
    final when = RepositoryBase.truncateToSeconds(at);
    final key = DateUtilsX.dayKey(when);
    final id = DoseLog.asNeededId(medicineId, key, when);
    await db.transaction(() async {
      final m = await getMedicine(medicineId);
      if (m == null) return;
      final now = this.now();
      final old = await _dao.doseById(id);
      final value = DoseLog(
        id: id,
        medicineId: medicineId,
        dayKey: key,
        slotMinutes: when.hour * 60 + when.minute,
        status: DoseStatus.taken,
        takenAt: when,
        quantity: quantity,
        createdAt: now,
        updatedAt: now,
      );
      final oldLog = old == null ? null : MedicineRowMapper.dose(old);
      await _write(id, oldLog, value, now);
      await _moveStock(m, oldLog, value);
    });
    return id;
  }

  @override
  Future<void> deleteAsNeeded(String doseId) => db.transaction(() async {
    final row = await _dao.doseById(doseId);
    if (row == null) return;
    final old = MedicineRowMapper.dose(row);
    await _dao.deleteDose(doseId);
    final m = await getMedicine(old.medicineId);
    if (m != null) await _moveStock(m, old, null);
  });

  @override
  Future<void> importDoses(List<DoseLog> logs) async {
    if (logs.isEmpty) return;
    await db.transaction(() async {
      final now = this.now();
      for (final l in logs) {
        if (await _dao.doseById(l.id) != null) continue;
        await _write(l.id, null, l, now);
      }
    });
  }

  @override
  Future<void> refill(String id, double amount) => db.transaction(() async {
    final row = await _dao.rowById(id);
    if (row == null || amount <= 0) return;
    await _dao.updateMedicine(
      id,
      MedicinesCompanion(
        stockLeft: Value((row.stockLeft ?? 0) + amount),
        packSize: Value(amount),
      ),
      stamp(),
    );
  });

  // ──────────────────────────── Medicines ─────────────────────────────

  @override
  Future<String> save(Medicine medicine, {bool writeStock = false}) =>
      db.transaction(() async {
        final s = stamp();
        var id = medicine.id;
        final existing = id.isEmpty ? null : await _dao.rowById(id);
        if (existing == null) {
          if (id.isEmpty) id = newId();
          await _dao.insertMedicine(
            MedicineRowMapper.content(medicine).copyWith(
              id: Value(id),
              stockLeft: Value(medicine.stockLeft),
              packSize: Value(medicine.packSize ?? medicine.stockLeft),
              createdAt: Value(s.now),
              updatedAt: Value(s.now),
              sortOrder: Value(((await _dao.maxSortOrder()) ?? 0) + 1),
              syncVersion: const Value(1),
              deviceId: Value(deviceId),
            ),
          );
          await _tags.replaceTags(
            ItemType.medicine,
            id,
            medicine.tags.map((t) => t.name),
            s,
          );
        } else {
          var changes = MedicineRowMapper.editorContent(medicine);
          if (writeStock) {
            changes = changes.copyWith(stockLeft: Value(medicine.stockLeft));
          }
          await _dao.updateMedicine(id, changes, s);
        }
        return id;
      });

  @override
  Future<void> setPaused(String id, bool paused) => _dao.updateMedicine(
    id,
    MedicinesCompanion(isPaused: Value(paused)),
    stamp(),
  );
}
