/// ============================================================
/// PRAYERS REPOSITORY (Drift implementation)
/// ============================================================
///
/// Prayers are ordinary items (lifecycle columns, tags, pin / favourite /
/// colour); their day logs live in `prayer_logs`, keyed `prayerId|day`.
/// A log write is find-by-id then insert / update; "back to not marked"
/// deletes the row (its tombstone carries the undo to other devices).
/// ============================================================
library;

import 'package:drift/drift.dart';
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/database/daos/dao_support.dart';
import 'package:focusflow/core/database/daos/organisation_dao.dart';
import 'package:focusflow/core/database/daos/prayers_dao.dart';
import 'package:focusflow/core/items/data/item_mappers.dart';
import 'package:focusflow/core/items/data/repository_base.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/prayers/data/repository/prayer_row_mapper.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer_log.dart';
import 'package:focusflow/features/prayers/domain/repository/prayers_repository.dart';

class PrayersRepositoryImpl extends RepositoryBase
    implements PrayersRepository {
  PrayersRepositoryImpl({
    required super.db,
    required super.clock,
    required super.deviceId,
    required super.newId,
  }) : _dao = PrayersDao(db),
       _org = OrganisationDao(db),
       _tags = TagWriter(OrganisationDao(db), newId);

  final PrayersDao _dao;
  final OrganisationDao _org;
  final TagWriter _tags;

  // ───────────────────────────── Reading ──────────────────────────────

  Future<List<Prayer>> _load(
    String where, [
    List<Variable> vars = const [],
  ]) async {
    final rows = await _dao.queryPrayers(where: where, variables: vars).get();
    if (rows.isEmpty) return const [];
    final tags = await _org.tagsByItem(
      ItemType.prayer,
      itemIds: rows.map((r) => r.id),
    );
    return [
      for (final r in rows)
        PrayerRowMapper.prayer(r, ItemMappers.tags(tags[r.id])),
    ];
  }

  static String _scopeSql(PrayersScope scope) => switch (scope) {
    PrayersScope.active => activeSql('p'),
    PrayersScope.archived =>
      'p.archived_at IS NOT NULL AND p.deleted_at IS NULL',
  };

  @override
  Stream<List<Prayer>> watchPrayers(PrayersScope scope) => db.watchComputed(
    {db.prayers, db.itemTags, db.tags},
    // The tab, Home, Calendar and the planner all read the active list.
    shareKey: ('prayers', scope),
    () async => List<Prayer>.unmodifiable(await _load(_scopeSql(scope))),
  );

  @override
  Stream<Prayer?> watchPrayer(String id) =>
      db.watchComputed({db.prayers, db.itemTags, db.tags}, () => getPrayer(id));

  @override
  Future<Prayer?> getPrayer(String id) async {
    final list = await _load('p.id = ?', [Variable.withString(id)]);
    return list.isEmpty ? null : list.first;
  }

  @override
  Stream<List<PrayerLog>> watchLogs(DateTime from, DateTime to) {
    final fromKey = DateUtilsX.dayKey(from);
    final toKey = DateUtilsX.dayKey(to);
    return db.watchComputed(
      {db.prayerLogs},
      shareKey: ('prayer-logs', fromKey, toKey),
      () async => List<PrayerLog>.unmodifiable(
        (await _dao.logs(
          fromKey: fromKey,
          toKey: toKey,
        )).map(PrayerRowMapper.log),
      ),
    );
  }

  @override
  Future<List<PrayerLog>> logsBetween(DateTime from, DateTime to) async =>
      List.unmodifiable(
        (await _dao.logs(
          fromKey: DateUtilsX.dayKey(from),
          toKey: DateUtilsX.dayKey(to),
        )).map(PrayerRowMapper.log),
      );

  @override
  Future<List<Prayer>> schedulable() =>
      _load('${activeSql('p')} AND p.is_paused = 0');

  @override
  Future<PrayerLog?> log(String prayerId, DateTime day) async {
    final row = await _dao.logById(
      PrayerLog.idFor(prayerId, DateUtilsX.dayKey(day)),
    );
    return row == null ? null : PrayerRowMapper.log(row);
  }

  // ───────────────────────────── Logs ─────────────────────────────────

  /// Read-modify-write of one day's log in a transaction. [change] gets the
  /// stored log (null = none) and returns the new one (null = delete).
  Future<T> _edit<T>(
    String prayerId,
    DateTime day,
    (PrayerLog?, T) Function(PrayerLog? old) change,
  ) => db.transaction(() async {
    final date = DateUtilsX.dateOnly(day);
    final id = PrayerLog.idFor(prayerId, DateUtilsX.dayKey(date));
    final row = await _dao.logById(id);
    final old = row == null ? null : PrayerRowMapper.log(row);
    final (next, result) = change(old);
    final now = this.now();
    if (next == null) {
      if (row != null) await _dao.deleteLog(id);
      return result;
    }
    final values = PrayerLogsCompanion(
      status: Value(next.status.index),
      loggedAt: Value(next.loggedAt),
      place: Value(next.place),
      congregation: Value(next.congregation),
      count: Value(next.count),
      snoozedUntil: Value(next.snoozedUntil),
      updatedAt: Value(now),
    );
    if (row == null) {
      await _dao.insertLog(
        values.copyWith(
          id: Value(id),
          prayerId: Value(prayerId),
          date: Value(DateUtilsX.dayKey(date)),
          createdAt: Value(now),
        ),
      );
    } else {
      await _dao.updateLog(id, values);
    }
    return result;
  });

  @override
  Future<void> mark(
    String prayerId,
    DateTime day,
    PrayerStatus status, {
    DateTime? at,
    String? place,
    bool? congregation,
  }) => _edit(prayerId, day, (old) {
    final when = RepositoryBase.truncateToSeconds(at ?? clock.now());
    final base =
        old ??
        PrayerLog(
          prayerId: prayerId,
          day: DateUtilsX.dateOnly(day),
          status: status,
        );
    return (
      base.copyWith(
        status: status,
        loggedAt: when,
        place: place,
        congregation: congregation,
        clearSnooze: true,
      ),
      null,
    );
  });

  @override
  Future<int> addCount(
    String prayerId,
    DateTime day,
    int delta, {
    int? target,
  }) => _edit(prayerId, day, (old) {
    final count = ((old?.count ?? 0) + delta).clamp(0, 1 << 30);
    var status = old?.status ?? PrayerStatus.pending;
    DateTime? loggedAt = old?.loggedAt;
    if (target != null && target > 0) {
      if (count >= target && !status.done) {
        status = PrayerStatus.onTime;
        loggedAt = RepositoryBase.truncateToSeconds(clock.now());
      } else if (count < target && status == PrayerStatus.onTime) {
        status = PrayerStatus.pending;
      }
    }
    if (count == 0 && old != null && status == PrayerStatus.pending) {
      return (null, 0);
    }
    final base =
        old ??
        PrayerLog(
          prayerId: prayerId,
          day: DateUtilsX.dateOnly(day),
          status: status,
        );
    return (
      base.copyWith(status: status, count: count, loggedAt: loggedAt),
      count,
    );
  });

  @override
  Future<void> snooze(String prayerId, DateTime day, DateTime until) =>
      _edit(prayerId, day, (old) {
        if (old != null && old.status != PrayerStatus.pending) {
          return (old, null);
        }
        final base =
            old ??
            PrayerLog(
              prayerId: prayerId,
              day: DateUtilsX.dateOnly(day),
              status: PrayerStatus.pending,
            );
        return (
          base.copyWith(snoozedUntil: RepositoryBase.truncateToSeconds(until)),
          null,
        );
      });

  @override
  Future<void> restoreLog(String prayerId, DateTime day, PrayerLog? previous) =>
      _edit(prayerId, day, (_) => (previous, null));

  // ──────────────────────────── Prayers ───────────────────────────────

  @override
  Future<String> save(Prayer prayer) =>
      db.transaction(() async => _save(prayer));

  Future<String> _save(Prayer prayer) async {
    final s = stamp();
    var id = prayer.id;
    final existing = id.isEmpty ? null : await _dao.rowById(id);
    if (existing == null) {
      if (id.isEmpty) id = newId();
      await _dao.insertPrayer(
        PrayerRowMapper.content(prayer).copyWith(
          id: Value(id),
          isPaused: Value(prayer.isPaused),
          isPinned: Value(prayer.isPinned),
          isFavorite: Value(prayer.isFavorite),
          createdAt: Value(s.now),
          updatedAt: Value(s.now),
          sortOrder: Value(((await _dao.maxSortOrder()) ?? 0) + 1),
          syncVersion: const Value(1),
          deviceId: Value(deviceId),
        ),
      );
      if (prayer.tags.isNotEmpty) {
        await _tags.replaceTags(
          ItemType.prayer,
          id,
          prayer.tags.map((t) => t.name),
          s,
        );
      }
    } else {
      await _dao.updatePrayer(id, PrayerRowMapper.content(prayer), s);
    }
    return id;
  }

  @override
  Future<List<String>> addAll(List<Prayer> prayers) =>
      db.transaction(() async => [for (final p in prayers) await _save(p)]);

  @override
  Future<void> setPaused(String id, bool paused) =>
      _dao.updatePrayer(id, PrayersCompanion(isPaused: Value(paused)), stamp());
}
