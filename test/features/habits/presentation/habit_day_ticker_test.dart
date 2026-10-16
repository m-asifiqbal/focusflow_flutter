/// HabitDayTicker: a habit screen left open past midnight moves "today" on
/// by itself (FakeClock + fake timers), and the timer dies with the widget.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/habits/presentation/providers/habits_providers.dart';
import 'package:focusflow/features/habits/presentation/widgets/habit_day_ticker.dart';

import '../../../helpers/test_container.dart';

void main() {
  testWidgets('habit day rolls over at midnight while the screen is open', (
    tester,
  ) async {
    final h = (await tester.runAsync(
      () => TestHarness.create(now: DateTime(2026, 6, 12, 23, 59)),
    ))!;
    addTearDown(() => tester.runAsync(h.dispose));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: h.container,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: HabitDayTicker(
            child: Consumer(
              builder: (_, ref, _) =>
                  Text(DateUtilsX.dayKey(ref.watch(habitTodayProvider))),
            ),
          ),
        ),
      ),
    );
    expect(find.text('2026-06-12'), findsOneWidget);

    // The wall clock passes midnight; the timer is due 1 s after it.
    h.clock.set(DateTime(2026, 6, 13, 0, 0, 30));
    await tester.pump(const Duration(seconds: 30));
    expect(find.text('2026-06-12'), findsOneWidget);
    await tester.pump(const Duration(seconds: 31));
    await tester.pump();
    expect(find.text('2026-06-13'), findsOneWidget);

    // Unmounting cancels the timer (no pending timers at the end).
    await tester.pumpWidget(const SizedBox());
  });
}
