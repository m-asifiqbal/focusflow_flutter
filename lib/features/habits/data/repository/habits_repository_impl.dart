/// ============================================================
/// HABITS REPOSITORY (Drift implementation)
/// ============================================================
///
/// Loads habits + logs and delegates every day-level rule to the pure
/// services (HabitDayStatusBuilder, HabitStatsCalculator). Logs are upserted
/// per (habit, day) with find-then-insert/update — never INSERT OR REPLACE.
/// Logs only carry `updatedAt` (no sync version), so log writes don't bump
/// the habit row.
/// ============================================================
library;

import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/database/daos/dao_support.dart';
import 'package:focusflow/core/database/daos/habits_dao.dart';
import 'package:focusflow/core/database/daos/organisation_dao.dart';
import 'package:focusflow/core/items/data/item_mappers.dart';
import 'package:focusflow/core/items/data/repository_base.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/domain/entities/habit_day_status.dart';
import 'package:focusflow/features/habits/domain/entities/habit_log.dart';
import 'package:focusflow/features/habits/data/repository/habit_row_mapper.dart';
import 'package:focusflow/features/habits/domain/repository/habits_repository.dart';
import 'package:focusflow/features/habits/domain/services/habit_day_status_builder.dart';
import 'package:focusflow/features/habits/domain/services/habit_stats_calculator.dart';

class HabitsRepositoryImpl extends RepositoryBase implements HabitsRepository {
  HabitsRepositoryImpl({
    required super.db,
    required super.clock,
    required super.deviceId,
    required super.newId,
  }) : _dao = HabitsDao(db),
       _org = OrganisationDao(db),
       _tags = TagWriter(OrganisationDao(db), newId);

  final HabitsDao _dao;
  final OrganisationDao _org;
  final TagWriter _tags;

  Set<ResultSetImplementation<dynamic, dynamic>> get _tables => {
    db.habits,
    db.habitLogs,
    db.itemTags,
    db.tags,
  };

  // ───────────────────────────── Reading ──────────────────────────────

  Future<List<Habit>> _load(
    String where, [
    List<Variable> vars = const [],
  ]) async {
    final rows = await _dao.queryHabits(where: where, variables: vars).get();
    if (rows.isEmpty) return const [];
    final tags = await _org.tagsByItem(
      ItemType.habit,
      itemIds: rows.map((r) => r.id),
    );
    return [
      for (final r in rows)
        HabitRowMapper.habit(r, ItemMappers.tags(tags[r.id])),
    ];
  }

  Future<Map<String, List<HabitLog>>> _logsByHabit(
    Iterable<String> habitIds, {
    DateTime? from,
    DateTime? to,
  }) async {
    final rows = await _dao
        .logsQuery(
          habitIds: habitIds,
          fromKey: from == null ? null : DateUtilsX.dayKey(from),
          toKey: to == null ? null : DateUtilsX.dayKey(to),
        )
        .get();
    final result = <String, List<HabitLog>>{};
    for (final r in rows) {
      result.putIfAbsent(r.habitId, () => []).add(HabitRowMapper.log(r));
    }
    return result;
  }

  /// WHERE clause (alias `h`) + variables for a list [query].
  static (String, List<Variable>) _where(HabitsQuery query) {
    final where = <String>[
      switch (query.scope) {
        HabitsScope.today => '${activeSql('h')} AND h.is_paused = 0',
        HabitsScope.all => activeSql('h'),
        HabitsScope.morning => '${activeSql('h')} AND h.part_of_day = 1',
        HabitsScope.afternoon => '${activeSql('h')} AND h.part_of_day = 2',
        // Afternoon + evening: the list only has Morning / Evening chips,
        // so "Evening" means the second half of the day.
        HabitsScope.evening => '${activeSql('h')} AND h.part_of_day IN (2, 3)',
        HabitsScope.archived =>
          'h.archived_at IS NOT NULL AND h.deleted_at IS NULL',
      },
    ];
    final vars = <Variable>[];
    final text = query.text.trim();
    if (text.isNotEmpty) {
      where.add(r"(h.name LIKE ? ESCAPE '\' OR h.category LIKE ? ESCAPE '\')");
      vars
        ..add(Variable.withString(likeContains(text)))
        ..add(Variable.withString(likeContains(text)));
    }
    return (where.join(' AND '), vars);
  }

  @override
  Stream<List<Habit>> watchHabits(HabitsQuery query) =>
      db.watchComputed(_tables, () {
        final (where, vars) = _where(query);
        return _load(where, vars);
      });

  @override
  Stream<Habit?> watchHabit(String id) =>
      db.watchComputed({db.habits, db.itemTags, db.tags}, () => getHabit(id));

  @override
  Future<Habit?> getHabit(String id) async {
    final list = await _load('h.id = ?', [Variable.withString(id)]);
    return list.isEmpty ? null : list.first;
  }

  @override
  Stream<HabitWithLogs?> watchHabitWithLogs(
    String id, {
    DateTime? from,
    DateTime? to,
  }) => db.watchComputed(_tables, () async {
    final habit = await getHabit(id);
    if (habit == null) return null;
    final logs = await _logsByHabit([id], from: from, to: to);
    return HabitWithLogs(
      habit: habit,
      logs: List.unmodifiable(logs[id] ?? const []),
    );
  });

  /// Histories longer than this compute their stats on a background
  /// isolate (years of daily logs) so the detail screen never janks.
  static const int isolateThreshold = 1500;

  @override
  Stream<HabitDetail?> watchHabitDetail(
    String id, {
    DateTime? today,
    int weekStartsOn = DateTime.monday,
  }) => db.watchComputed(_tables, () async {
    final habit = await getHabit(id);
    if (habit == null) return null;
    final day = DateUtilsX.dateOnly(today ?? clock.now());
    final logs = List<HabitLog>.unmodifiable(
      (await _logsByHabit([id]))[id] ?? const <HabitLog>[],
    );
    final calculator = HabitStatsCalculator(weekStartsOn: weekStartsOn);
    final stats = logs.length > isolateThreshold
        ? await _statsOnIsolate(calculator, habit, logs, day)
        : calculator.compute(habit, logs, day);
    return HabitDetail(habit: habit, logs: logs, stats: stats, today: day);
  });

  /// Static on purpose: a closure made inside an instance method can
  /// capture `this` (and with it the database connection), which can't be
  /// sent to an isolate — the long-history detail used to fail with
  /// "object is unsendable".
  static Future<HabitStats> _statsOnIsolate(
    HabitStatsCalculator calculator,
    Habit habit,
    List<HabitLog> logs,
    DateTime day,
  ) => Isolate.run(() => calculator.compute(habit, logs, day));

  @override
  Stream<List<HabitDayStatus>> watchTodayHabits(
    DateTime day, {
    int weekStartsOn = DateTime.monday,
  }) => watchDayStatuses(
    const HabitsQuery(scope: HabitsScope.today),
    day,
    weekStartsOn: weekStartsOn,
  );

  @override
  Stream<List<HabitDayStatus>> watchDayStatuses(
    HabitsQuery query,
    DateTime day, {
    int weekStartsOn = DateTime.monday,
  }) => db.watchComputed(
    _tables,
    // Home, the library counts and the calendar read the same cards: one
    // computation (and one re-run per write) serves them all.
    shareKey: (
      'habit-day-statuses',
      query.scope,
      query.text.trim(),
      DateUtilsX.dayKey(day),
      weekStartsOn,
    ),
    () => _dayStatuses(query, day, weekStartsOn),
  );

  @override
  Future<List<HabitDayStatus>> todayHabitsNow(
    DateTime day, {
    int weekStartsOn = DateTime.monday,
  }) => _dayStatuses(
    const HabitsQuery(scope: HabitsScope.today),
    day,
    weekStartsOn,
  );

  Future<List<HabitDayStatus>> _dayStatuses(
    HabitsQuery query,
    DateTime day,
    int weekStartsOn,
  ) async {
    final (where, vars) = _where(query);
    final habits = await _load(where, vars);
    if (habits.isEmpty) return const <HabitDayStatus>[];
    final ref = DateUtilsX.dateOnly(day);
    final logs = await _logsByHabit(
      habits.map((h) => h.id),
      to: DateUtilsX.addDays(ref, 7),
    );
    return [
      for (final h in habits)
        HabitDayStatusBuilder.build(
          h,
          logs[h.id] ?? const [],
          ref,
          weekStartsOn: weekStartsOn,
        ),
    ];
  }

  @override
  Stream<List<HabitLog>> watchLogsInRange(DateTime from, DateTime to) =>
      db.watchComputed({db.habitLogs}, () async {
        final rows = await _dao
            .logsQuery(
              fromKey: DateUtilsX.dayKey(from),
              toKey: DateUtilsX.dayKey(to),
            )
            .get();
        return List<HabitLog>.unmodifiable(rows.map(HabitRowMapper.log));
      });

  // ───────────────────────────── Logs ─────────────────────────────────

  /// Upserts the (habit, day) log through [change] (old row or null).
  Future<void> _writeLog(
    String habitId,
    DateTime day,
    HabitLogsCompanion Function(HabitLogRow? old) change,
  ) => db.transaction(() async {
    final key = DateUtilsX.dayKey(day);
    final now = this.now();
    final old = await _dao.logFor(habitId, key);
    final c = change(old).copyWith(updatedAt: Value(now));
    if (old == null) {
      await _dao.insertLog(
        c.copyWith(
          id: Value(newId()),
          habitId: Value(habitId),
          date: Value(key),
          createdAt: Value(now),
        ),
      );
    } else {
      await _dao.updateLog(old.id, c);
    }
  });

  @override
  Future<int> increment(String habitId, DateTime day, {int by = 1}) async {
    var result = 0;
    await _writeLog(habitId, day, (old) {
      final next = (old?.count ?? 0) + by;
      result = next < 0 ? 0 : next;
      return HabitLogsCompanion(
        count: Value(result),
        skipped: const Value(false),
      );
    });
    return result;
  }

  @override
  Future<void> setLog(
    String habitId,
    DateTime day, {
    required int count,
    bool skipped = false,
    String? note,
  }) => _writeLog(
    habitId,
    day,
    (_) => HabitLogsCompanion(
      count: Value(count < 0 ? 0 : count),
      skipped: Value(skipped),
      note: Value(note == null || note.trim().isEmpty ? null : note.trim()),
    ),
  );

  @override
  Future<void> skip(String habitId, DateTime day) => _writeLog(
    habitId,
    day,
    (_) => const HabitLogsCompanion(count: Value(0), skipped: Value(true)),
  );

  @override
  Future<void> toggleDone(String habitId, DateTime day) async {
    final habit = await getHabit(habitId);
    if (habit == null) return;
    await _writeLog(habitId, day, (old) {
      final log = old == null ? null : HabitRowMapper.log(old);
      final done = habit.isDoneWith(log);
      final int count;
      if (habit.isQuit) {
        count = done ? 1 : 0; // clean → slip, slip → clean
      } else {
        count = done ? 0 : habit.targetCount;
      }
      return HabitLogsCompanion(
        count: Value(count),
        skipped: const Value(false),
      );
    });
  }

  @override
  Future<void> clearLog(String habitId, DateTime day) async {
    final old = await _dao.logFor(habitId, DateUtilsX.dayKey(day));
    if (old != null) await _dao.deleteLog(old.id);
  }

  // ───────────────────────────── Habits ───────────────────────────────

  @override
  Future<String> save(Habit habit) => db.transaction(() async {
    final s = stamp();
    var id = habit.id;
    final existing = id.isEmpty ? null : await _dao.rowById(id);
    if (existing == null) {
      if (id.isEmpty) id = newId();
      await _dao.insertHabit(
        HabitRowMapper.content(habit).copyWith(
          id: Value(id),
          createdAt: Value(s.now),
          updatedAt: Value(s.now),
          sortOrder: Value(((await _dao.maxSortOrder()) ?? 0) + 1),
          syncVersion: const Value(1),
          deviceId: Value(deviceId),
        ),
      );
      await _tags.replaceTags(
        ItemType.habit,
        id,
        habit.tags.map((t) => t.name),
        s,
      );
    } else {
      // Only the editor's fields: flags and tags have their own writers,
      // so a stale draft can't revert them.
      await _dao.updateHabit(id, HabitRowMapper.editorContent(habit), s);
    }
    return id;
  });

  @override
  Future<void> reorder(String id, {String? afterId, String? beforeId}) async {
    final after = afterId == null ? null : await _dao.rowById(afterId);
    final before = beforeId == null ? null : await _dao.rowById(beforeId);
    await _dao.updateHabit(
      id,
      HabitsCompanion(
        sortOrder: Value(sortBetween(after?.sortOrder, before?.sortOrder)),
      ),
      stamp(),
    );
  }

  @override
  Future<void> resetHistory(String id) => db.transaction(() async {
    await _dao.deleteLogsOf([id]);
    await _dao.updateHabit(id, const HabitsCompanion(), stamp());
  });

  @override
  Future<void> restoreLogs(List<HabitLog> logs) async {
    if (logs.isEmpty) return;
    await db.transaction(() async {
      final now = this.now();
      for (final l in logs) {
        final key = l.dayKey;
        final content = HabitLogsCompanion(
          count: Value(l.count < 0 ? 0 : l.count),
          skipped: Value(l.skipped),
          note: Value(l.note),
          updatedAt: Value(now),
        );
        final old = await _dao.logFor(l.habitId, key);
        if (old == null) {
          await _dao.insertLog(
            content.copyWith(
              id: Value(l.id.isEmpty ? newId() : l.id),
              habitId: Value(l.habitId),
              date: Value(key),
              createdAt: Value(l.createdAt),
            ),
          );
        } else {
          await _dao.updateLog(old.id, content);
        }
      }
      for (final habitId in {for (final l in logs) l.habitId}) {
        await _dao.updateHabit(habitId, const HabitsCompanion(), stamp());
      }
    });
  }

  @override
  Future<void> setPaused(String id, bool paused) =>
      _dao.updateHabit(id, HabitsCompanion(isPaused: Value(paused)), stamp());
}
