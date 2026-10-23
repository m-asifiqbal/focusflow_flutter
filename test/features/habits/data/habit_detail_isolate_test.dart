/// A habit with a very long history computes its stats on a background
/// isolate (HabitsRepositoryImpl.isolateThreshold) — that path must work.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/habits/data/repository/habits_repository_impl.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/test_container.dart';

void main() {
  test('stats of a history past the isolate threshold', () async {
    final today = DateTime(2026, 10, 23);
    final h = await TestHarness.create(now: DateTime(2026, 10, 23, 9));
    addTearDown(h.dispose);
    final repo = h.read(habitsRepositoryProvider);
    final days = HabitsRepositoryImpl.isolateThreshold + 10;
    final start = DateUtilsX.addDays(today, -days);
    final id = await repo.save(Habit.draft(startDate: start, name: 'Read'));
    await h.db.batch((b) {
      for (var i = 0; i < days; i++) {
        final d = DateUtilsX.addDays(start, i);
        b.insert(
          h.db.habitLogs,
          HabitLogsCompanion.insert(
            id: 'l$i',
            habitId: id,
            date: DateUtilsX.dayKey(d),
            createdAt: d,
            updatedAt: d,
          ).copyWith(count: const Value(1)),
        );
      }
    });
    final detail = await repo
        .watchHabitDetail(id, today: today)
        .first
        .timeout(const Duration(seconds: 30));
    expect(detail!.logs.length, days);
  });
}
