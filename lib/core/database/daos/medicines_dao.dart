/// ============================================================
/// MEDICINES DAO — row-level queries for `medicines` + `medicine_doses`
/// ============================================================
///
/// Doses are keyed by their natural id (`medicineId|day|slot`, see
/// tables.dart), so a write is find-by-id then insert / update — never
/// INSERT OR REPLACE (which would change the rowid).
/// ============================================================
library;

import 'package:drift/drift.dart';
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/database/daos/dao_support.dart';
import 'package:focusflow/core/database/tables.dart';

part 'medicines_dao.g.dart';

@DriftAccessor(tables: [Medicines, MedicineDoses, ItemTags, Tags])
class MedicinesDao extends DatabaseAccessor<AppDatabase>
    with _$MedicinesDaoMixin {
  MedicinesDao(super.attachedDatabase);

  /// Medicines matching [where] (SQL over alias `m`, bound [variables]).
  Selectable<MedicineRow> queryMedicines({
    required String where,
    List<Variable> variables = const [],
    String orderBy = 'm.is_pinned DESC, m.sort_order ASC, m.created_at ASC',
  }) => customSelect(
    'SELECT m.* FROM medicines m WHERE $where ORDER BY $orderBy',
    variables: variables,
    readsFrom: {medicines, itemTags},
  ).map((r) => medicines.map(r.data));

  Future<MedicineRow?> rowById(String id) =>
      (select(medicines)..where((m) => m.id.equals(id))).getSingleOrNull();

  Future<void> insertMedicine(MedicinesCompanion row) =>
      into(medicines).insert(row);

  /// Stamped update (updated_at, device_id, sync_version + 1).
  Future<int> updateMedicine(
    String id,
    MedicinesCompanion changes,
    WriteStamp stamp,
  ) => (update(
    medicines,
  )..where((m) => m.id.equals(id))).write(stampedUpdate(changes, stamp));

  Future<double?> maxSortOrder() {
    final max = medicines.sortOrder.max();
    return (selectOnly(
      medicines,
    )..addColumns([max])).map((r) => r.read(max)).getSingle();
  }

  // ─────────────────────────────── Doses ──────────────────────────────

  /// Doses of [medicineIds] (all when null) with `date` in
  /// [fromKey, toKey] inclusive, oldest first.
  Future<List<MedicineDoseRow>> doses({
    Iterable<String>? medicineIds,
    String? fromKey,
    String? toKey,
  }) {
    final q = select(medicineDoses)
      ..orderBy([
        (d) => OrderingTerm.asc(d.date),
        (d) => OrderingTerm.asc(d.slotMinutes),
      ]);
    q.where((d) {
      Expression<bool> e = const Constant(true);
      if (medicineIds != null) e = e & d.medicineId.isIn(medicineIds);
      if (fromKey != null) e = e & d.date.isBiggerOrEqualValue(fromKey);
      if (toKey != null) e = e & d.date.isSmallerOrEqualValue(toKey);
      return e;
    });
    return q.get();
  }

  Future<MedicineDoseRow?> doseById(String id) =>
      (select(medicineDoses)..where((d) => d.id.equals(id))).getSingleOrNull();

  Future<void> insertDose(MedicineDosesCompanion row) =>
      into(medicineDoses).insert(row);

  Future<int> updateDose(String id, MedicineDosesCompanion changes) =>
      (update(medicineDoses)..where((d) => d.id.equals(id))).write(changes);

  Future<int> deleteDose(String id) =>
      (delete(medicineDoses)..where((d) => d.id.equals(id))).go();

  Future<int> deleteDosesOf(Iterable<String> medicineIds) => (delete(
    medicineDoses,
  )..where((d) => d.medicineId.isIn(medicineIds))).go();
}
