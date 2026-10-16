/// Account read models: the stats card counts active items and distinct
/// active days live from the database.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/features/auth/presentation/providers/account_providers.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/test_container.dart';

void main() {
  final now = DateTime(2026, 10, 13, 9, 41);

  Future<AccountStats> next(
    TestHarness h,
    bool Function(AccountStats) ok,
  ) async {
    for (var i = 0; i < 100; i++) {
      final v = h.read(accountStatsProvider).valueOrNull;
      if (v != null && ok(v)) return v;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    fail('stats never matched');
  }

  test('stats follow the database', () async {
    final h = await TestHarness.create(now: now);
    addTearDown(h.dispose);
    final sub = h.container.listen(accountStatsProvider, (_, _) {});
    addTearDown(sub.close);

    final empty = await next(h, (_) => true);
    expect(empty.items, 0);

    await h
        .read(tasksRepositoryProvider)
        .save(
          TaskItem(id: '', title: 'Ship it', createdAt: now, updatedAt: now),
        );
    final one = await next(h, (s) => s.items == 1);
    expect(one.daysActive, 1);
    expect(one.bestStreak, 0);
  });
}
