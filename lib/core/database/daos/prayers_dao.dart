/// ============================================================
/// PRAYERS DAO — row-level queries for `prayers` + `prayer_logs`
/// ============================================================
///
/// Logs are keyed by their natural id (`prayerId|day`, see tables.dart), so
/// a write is find-by-id then insert / update — never INSERT OR REPLACE
/// (which would change the rowid the FTS / tombstone triggers key on).
/// ============================================================
library;

import 'package:drift/drift.dart';
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/database/daos/dao_support.dart';
import 'package:focusflow/core/database/tables.dart';

part 'prayers_dao.g.dart';

@DriftAccessor(tables: [Prayers, PrayerLogs, ItemTags, Tags])
class PrayersDao extends DatabaseAccessor<AppDatabase> with _$PrayersDaoMixin {
  PrayersDao(super.attachedDatabase);

  /// Prayers matching [where] (SQL over alias `p`, bound [variables]).
  Selectable<PrayerRow> queryPrayers({
    required String where,
    List<Variable> variables = const [],
    String orderBy = 'p.is_pinned DESC, p.sort_order ASC, p.created_at ASC',
  }) => customSelect(
    'SELECT p.* FROM prayers p WHERE $where ORDER BY $orderBy',
    variables: variables,
    readsFrom: {prayers, itemTags},
  ).map((r) => prayers.map(r.data));

  Future<PrayerRow?> rowById(String id) =>
      (select(prayers)..where((p) => p.id.equals(id))).getSingleOrNull();

  Future<void> insertPrayer(PrayersCompanion row) => into(prayers).insert(row);

  /// Stamped update (updated_at, device_id, sync_version + 1).
  Future<int> updatePrayer(
    String id,
    PrayersCompanion changes,
    WriteStamp stamp,
  ) => (update(
    prayers,
  )..where((p) => p.id.equals(id))).write(stampedUpdate(changes, stamp));

  Future<double?> maxSortOrder() {
    final max = prayers.sortOrder.max();
    return (selectOnly(
      prayers,
    )..addColumns([max])).map((r) => r.read(max)).getSingle();
  }

  // ─────────────────────────────── Logs ───────────────────────────────

  /// Logs of [prayerIds] (all when null) with `date` in [fromKey, toKey]
  /// inclusive, oldest first.
  Future<List<PrayerLogRow>> logs({
    Iterable<String>? prayerIds,
    String? fromKey,
    String? toKey,
  }) => _logsQuery(prayerIds, fromKey, toKey).get();

  /// [logs] as a stream (re-emits when any log changes).
  Stream<List<PrayerLogRow>> watchLogs({
    Iterable<String>? prayerIds,
    String? fromKey,
    String? toKey,
  }) => _logsQuery(prayerIds, fromKey, toKey).watch();

  SimpleSelectStatement<$PrayerLogsTable, PrayerLogRow> _logsQuery(
    Iterable<String>? prayerIds,
    String? fromKey,
    String? toKey,
  ) {
    final q = select(prayerLogs)..orderBy([(l) => OrderingTerm.asc(l.date)]);
    q.where((l) {
      Expression<bool> e = const Constant(true);
      if (prayerIds != null) e = e & l.prayerId.isIn(prayerIds);
      if (fromKey != null) e = e & l.date.isBiggerOrEqualValue(fromKey);
      if (toKey != null) e = e & l.date.isSmallerOrEqualValue(toKey);
      return e;
    });
    return q;
  }

  Future<PrayerLogRow?> logById(String id) =>
      (select(prayerLogs)..where((l) => l.id.equals(id))).getSingleOrNull();

  Future<void> insertLog(PrayerLogsCompanion row) =>
      into(prayerLogs).insert(row);

  Future<int> updateLog(String id, PrayerLogsCompanion changes) =>
      (update(prayerLogs)..where((l) => l.id.equals(id))).write(changes);

  Future<int> deleteLog(String id) =>
      (delete(prayerLogs)..where((l) => l.id.equals(id))).go();

  Future<int> deleteLogsOf(Iterable<String> prayerIds) =>
      (delete(prayerLogs)..where((l) => l.prayerId.isIn(prayerIds))).go();
}
