/// Home › Up Next: the card stays on screen while the minute tick
/// re-queries "next" (no skeleton flash), Retry re-runs the failed query;
/// the "Get started" checklist ticks steps off as items exist; "View all"
/// opens Tasks.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/router/app_router.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/home/presentation/providers/home_providers.dart';
import 'package:focusflow/features/home/presentation/widgets/home_section_states.dart';
import 'package:focusflow/features/home/presentation/widgets/home_up_next.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder_occurrence.dart';
import 'package:focusflow/features/tasks/presentation/providers/minute_clock.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/screen_harness.dart';
import '../../../helpers/test_container.dart';
import '../../reminders/isolated_notifications.dart';
import '../home_seed.dart';

void main() {
  late TestHarness h;

  Future<void> boot(
    WidgetTester tester, {
    List<Override> extra = const [],
  }) async {
    await loadAppFonts();
    h = (await tester.runAsync(
      () => TestHarness.create(
        now: homeNow,
        overrides: [...isolatedNotifications(), ...extra],
      ),
    ))!;
    addTearDown(() => tester.runAsync(h.dispose));
  }

  Finder inUpNext(Finder f) =>
      find.descendant(of: find.byType(HomeUpNextSection), matching: f);

  testWidgets('a minute tick keeps the card (no skeleton flash)', (
    tester,
  ) async {
    await boot(tester);
    await tester.runAsync(() => seedHomeMockup(h));
    await pumpApp(tester, h, AppRoutes.home, size: const Size(390, 1538));
    expect(find.text('in 25 min · 10:00 AM'), findsOneWidget);

    h.clock.set(homeNow.add(const Duration(minutes: 1)));
    h.read(minuteClockProvider.notifier).tick();
    // One frame: the re-query is still running (AsyncLoading + value).
    await tester.pump();
    expect(inUpNext(find.byType(FFSkeletonRow)), findsNothing);
    expect(inUpNext(find.text('Call the bank about card')), findsOneWidget);

    await settle(tester);
    expect(find.text('in 24 min · 10:00 AM'), findsOneWidget);
    expect(inUpNext(find.byType(FFSkeletonRow)), findsNothing);
  });

  testWidgets("Retry re-runs today's Up Next query", (tester) async {
    var calls = 0;
    await boot(
      tester,
      extra: [
        homeNextReminderProvider.overrideWith((ref) {
          calls++;
          return calls == 1
              ? Stream<ReminderOccurrence?>.error(StateError('db closed'))
              : Stream<ReminderOccurrence?>.value(null);
        }),
      ],
    );
    await pumpScreen(
      tester,
      h,
      const Scaffold(body: SingleChildScrollView(child: HomeUpNextSection())),
    );
    await settle(tester);
    expect(find.byType(HomeErrorCard), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await settle(tester);
    expect(calls, 2);
    expect(find.byType(HomeErrorCard), findsNothing);
    expect(find.text('Nothing coming up'), findsOneWidget);
  });

  // Data is written before Home is pumped: writing from runAsync while
  // Home's fake-zone queries hold the DB can deadlock the test.
  testWidgets('Get started: first run shows three open steps', (tester) async {
    await boot(tester);
    await pumpApp(tester, h, AppRoutes.home, size: const Size(390, 1538));
    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('3 quick steps'), findsOneWidget);
    expect(find.byType(HomeGetStartedCard), findsOneWidget);
  });

  testWidgets('Get started ticks off a step once its item exists', (
    tester,
  ) async {
    await boot(tester);
    await tester.runAsync(
      () => h.read(notesRepositoryProvider).createEmpty(title: 'First'),
    );
    await pumpApp(tester, h, AppRoutes.home, size: const Size(390, 1538));
    expect(find.text('1 of 3 done'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'^Write your first note, done')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp(r'^Add your first task\n')),
      findsOneWidget,
    );
  });

  testWidgets('Get started leaves once every step is done', (tester) async {
    await boot(tester);
    // Note, task (Thu) and reminders/habits exist; nothing is due today.
    await tester.runAsync(() async {
      await seedHomeMockup(h);
      final today = await h
          .read(tasksRepositoryProvider)
          .watchTasksForDay(homeToday)
          .first;
      await h.read(itemsRepositoryProvider).archive([
        for (final t in today) t.ref,
      ]);
    });
    await pumpApp(tester, h, AppRoutes.home, size: const Size(390, 1538));
    expect(find.byType(HomeGetStartedCard), findsNothing);
    expect(find.text('No tasks today'), findsOneWidget);
  });

  testWidgets('"View all N tasks" opens Tasks', (tester) async {
    await boot(tester);
    await tester.runAsync(() => seedHomeMockup(h));
    await pumpApp(tester, h, AppRoutes.home, size: const Size(390, 1538));
    await tester.tap(find.text('View all 7 tasks'));
    await settle(tester);
    expect(h.read(routerProvider).state.uri.toString(), AppRoutes.tasks);
  });
}
