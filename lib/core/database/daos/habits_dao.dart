/// ============================================================
/// HABITS DAO — row-level queries for `habits` + `habit_logs`
/// ============================================================
///
/// Logs are keyed by (habit_id, date `yyyy-MM-dd`) — unique — so a day
/// never has two rows. [logFor] + insert/update gives an upsert without
/// INSERT OR REPLACE (which would change the rowid).
/// ============================================================
library;

import 'package:drift/drift.dart';
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/database/daos/dao_support.dart';
import 'package:focusflow/core/database/tables.dart';

part 'habits_dao.g.dart';

@DriftAccessor(tables: [Habits, HabitLogs, ItemTags, Tags])
class HabitsDao extends DatabaseAccessor<AppDatabase> with _$HabitsDaoMixin {
  HabitsDao(super.attachedDatabase);

  /// Habits matching [where] (SQL over alias `h`, bound [variables]).
  Selectable<HabitRow> queryHabits({
    required String where,
    List<Variable> variables = const [],
    String orderBy = 'h.is_pinned DESC, h.sort_order ASC, h.created_at ASC',
  }) => customSelect(
    'SELECT h.* FROM habits h WHERE $where ORDER BY $orderBy',
    variables: variables,
    readsFrom: {habits, itemTags},
  ).map((r) => habits.map(r.data));

  Future<HabitRow?> rowById(String id) =>
      (select(habits)..where((h) => h.id.equals(id))).getSingleOrNull();

  Stream<HabitRow?> watchRow(String id) =>
      (select(habits)..where((h) => h.id.equals(id))).watchSingleOrNull();

  Future<void> insertHabit(HabitsCompanion row) => into(habits).insert(row);

  /// Stamped update (updated_at, device_id, sync_version + 1).
  Future<int> updateHabit(
    String id,
    HabitsCompanion changes,
    WriteStamp stamp,
  ) => (update(
    habits,
  )..where((h) => h.id.equals(id))).write(stampedUpdate(changes, stamp));

  Future<double?> maxSortOrder() {
    final max = habits.sortOrder.max();
    return (selectOnly(
      habits,
    )..addColumns([max])).map((r) => r.read(max)).getSingle();
  }

  // ─────────────────────────────── Logs ───────────────────────────────

  /// Logs of [habitIds] (all habits when null) with `date` in
  /// [fromKey, toKey] inclusive (yyyy-MM-dd strings compare correctly).
  SimpleSelectStatement<$HabitLogsTable, HabitLogRow> logsQuery({
    Iterable<String>? habitIds,
    String? fromKey,
    String? toKey,
  }) {
    final q = select(habitLogs)..orderBy([(l) => OrderingTerm.asc(l.date)]);
    q.where((l) {
      Expression<bool> e = const Constant(true);
      if (habitIds != null) e = e & l.habitId.isIn(habitIds);
      if (fromKey != null) e = e & l.date.isBiggerOrEqualValue(fromKey);
      if (toKey != null) e = e & l.date.isSmallerOrEqualValue(toKey);
      return e;
    });
    return q;
  }

  Future<HabitLogRow?> logFor(String habitId, String dayKey) =>
      (select(habitLogs)
            ..where((l) => l.habitId.equals(habitId) & l.date.equals(dayKey)))
          .getSingleOrNull();

  Future<void> insertLog(HabitLogsCompanion row) => into(habitLogs).insert(row);

  Future<int> updateLog(String id, HabitLogsCompanion changes) =>
      (update(habitLogs)..where((l) => l.id.equals(id))).write(changes);

  Future<int> deleteLog(String id) =>
      (delete(habitLogs)..where((l) => l.id.equals(id))).go();

  Future<int> deleteLogsOf(Iterable<String> habitIds) =>
      (delete(habitLogs)..where((l) => l.habitId.isIn(habitIds))).go();
}
