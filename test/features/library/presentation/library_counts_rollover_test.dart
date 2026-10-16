/// libraryCountsProvider: day-relative numbers ("due today") follow the
/// day clock, so they roll over at midnight instead of going stale.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/library/presentation/providers/library_providers.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:focusflow/features/tasks/presentation/providers/minute_clock.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/test_container.dart';

void main() {
  test('"due today" recomputes after midnight', () async {
    final h = await TestHarness.create(now: DateTime(2026, 6, 12, 23, 50));
    addTearDown(h.dispose);
    await h
        .read(tasksRepositoryProvider)
        .save(
          TaskItem(
            id: '',
            title: 'Tomorrow thing',
            dueDate: DateUtilsX.toStoredDay(DateTime(2026, 6, 13)),
            createdAt: h.clock.now(),
            updatedAt: h.clock.now(),
          ),
        );
    final sub = h.container.listen(libraryCountsProvider, (_, _) {});
    addTearDown(sub.close);

    var counts = await h.read(libraryCountsProvider.future);
    expect(counts.tasksDueToday, 0);

    // Past midnight; the screen's MinuteTicker ticks the day clock.
    h.clock.advance(const Duration(minutes: 20));
    h.read(minuteClockProvider.notifier).tick();
    counts = await h.read(libraryCountsProvider.future);
    expect(counts.tasksDueToday, 1);

    // A minute change within the day doesn't restart the stream.
    final before = h.read(libraryCountsProvider);
    h.clock.advance(const Duration(minutes: 1));
    h.read(minuteClockProvider.notifier).tick();
    expect(identical(h.read(libraryCountsProvider), before), isTrue);
  });
}
