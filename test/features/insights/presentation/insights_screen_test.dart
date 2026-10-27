/// Screen 25 — Insights: seeded numbers (light + dark captures), range
/// switching, "Not enough data" states, the focus timer from the Focus
/// hours card, share, and no overflow at 360 pt / text scale 1.3.
///
/// Uses [pumpScreen] (the screen inside the themed app chrome) rather than
/// the whole app: the shell's other tabs open plain Drift query streams in
/// the fake-async zone, which leave a pending timer that blocks closing
/// the database at teardown.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/features/insights/data/share/insights_share_service.dart';
import 'package:focusflow/features/insights/domain/entities/insights_range.dart';
import 'package:focusflow/features/insights/presentation/providers/insights_providers.dart';
import 'package:focusflow/features/insights/presentation/screens/insights_screen.dart';
import 'package:focusflow/features/insights/presentation/widgets/focus_timer_sheet.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/screen_harness.dart';
import '../../../helpers/test_container.dart';
import 'insights_seed.dart';

class _FakeShare implements InsightsShareService {
  final shared = <Uint8List>[];

  @override
  Future<bool> sharePng(Uint8List png, {required String fileStamp}) async {
    shared.add(png);
    return true;
  }
}

void main() {
  late TestHarness h;
  late _FakeShare share;

  Future<void> boot(WidgetTester tester, {bool withData = true}) async {
    await loadAppFonts();
    share = _FakeShare();
    h = (await tester.runAsync(
      () => TestHarness.create(
        now: insightsNow,
        overrides: [insightsShareServiceProvider.overrideWithValue(share)],
      ),
    ))!;
    addTearDown(() => tester.runAsync(h.dispose));
    if (withData) await tester.runAsync(() => seedInsights(h));
  }

  Finder text(String s) => find.text(s, skipOffstage: false);

  /// The sections reveal, count up and sweep in over ~1.2 s.
  Future<void> intro(WidgetTester tester) =>
      tester.pump(const Duration(seconds: 2));

  testWidgets('renders the seeded week (light)', (tester) async {
    await boot(tester);
    await pumpScreen(tester, h, const InsightsScreen());
    await intro(tester);
    await captureScreen(tester, '25_insights');

    expect(find.text('Insights'), findsOneWidget);
    expect(find.text('Your productivity at a glance'), findsOneWidget);
    expect(find.text('TASK COMPLETION'), findsOneWidget);
    Finder kpi(String label) => find.bySemanticsLabel(label);
    // 27 of 32 due vs 7 of 14.
    expect(kpi('Task completion: 84%, up 34%'), findsOneWidget);
    // 210 focus minutes vs 60.
    expect(kpi('Focus hours: 3.5, up 2.5h'), findsOneWidget);
    // Every habit done vs 19 of 21 days.
    expect(kpi('Habit consistency: 100%, up 10%'), findsOneWidget);
    expect(kpi('Notes created: 7, up 5'), findsOneWidget);
    expect(find.text('34%'), findsOneWidget);
    expect(find.text('Daily productivity'), findsOneWidget);
    expect(find.text('Mon'), findsOneWidget);
    expect(text('Task timeline'), findsOneWidget);
    expect(text('Where your time went'), findsOneWidget);
    // 27 tasks + 21 check-ins + 7 notes + 2 reminders.
    expect(text('57'), findsOneWidget);
    expect(text('Habit streaks'), findsOneWidget);
    expect(text('Daily reading'), findsOneWidget);
    expect(text('45 d'), findsOneWidget);
    expect(text('21 d'), findsOneWidget);
    expect(text('12 d'), findsOneWidget);
    expect(text('Weekly tip'), findsOneWidget);
    expect(
      find.textContaining('more tasks before noon', skipOffstage: false),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('dark mode capture', (tester) async {
    await boot(tester);
    await pumpScreen(tester, h, const InsightsScreen(), dark: true);
    await intro(tester);
    expect(find.text('84%'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await captureScreen(tester, '25_insights_dark');
  });

  testWidgets('switching ranges recomputes', (tester) async {
    await boot(tester);
    await pumpScreen(tester, h, const InsightsScreen());
    await intro(tester);
    await tester.tap(find.text('30 Days'));
    await settle(tester);
    await intro(tester);
    expect(h.read(insightsRangeProvider).preset, InsightsPreset.month);
    // Notes: 10 in 30 days, none in the 30 days before.
    expect(find.bySemanticsLabel('Notes created: 10, up 10'), findsOneWidget);

    await tester.tap(find.text('Today'));
    await settle(tester);
    expect(h.read(insightsRangeProvider).preset, InsightsPreset.today);
    expect(
      find.text('Pick a longer range to see a trend.', skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('empty data shows "Not enough data" per chart', (tester) async {
    await boot(tester, withData: false);
    await pumpScreen(tester, h, const InsightsScreen());
    await intro(tester);
    // The productivity chart, the task timeline and the time-split donut.
    expect(text('Not enough data'), findsNWidgets(3));
    expect(text('No tasks are due in this range.'), findsOneWidget);
    expect(text('No habits yet'), findsOneWidget);
    expect(find.text('—'), findsNWidgets(2)); // no task / habit rates
    expect(tester.takeException(), isNull);
    await captureScreen(tester, '25_insights_empty');
  });

  testWidgets('Focus hours opens the timer and stop records it', (
    tester,
  ) async {
    await boot(tester, withData: false);
    await pumpScreen(tester, h, const InsightsScreen());
    await intro(tester);
    await tester.tap(find.bySemanticsLabel(RegExp('^Focus hours')));
    await settle(tester);
    expect(find.byType(FocusTimerSheet), findsOneWidget);
    expect(find.text('25:00'), findsOneWidget);
    await tester.tap(find.text('45 min'));
    await tester.pump();
    expect(find.text('45:00'), findsOneWidget);
    await tester.tap(find.text('Start focus'));
    h.clock.advance(const Duration(minutes: 12));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('33:00'), findsOneWidget);
    await tester.tap(find.text('Stop'));
    await settle(tester);
    expect(find.text('Saved 12 min of focus. Nice work!'), findsOneWidget);
    final sessions = await tester.runAsync(
      () => h
          .read(focusSessionsRepositoryProvider)
          .watchRange(insightsToday, insightsNow.add(const Duration(days: 1)))
          .first,
    );
    expect(sessions!.single.durationMinutes, 12);
    await tester.tap(find.text('Done'));
    await settle(tester);
    expect(find.byType(FocusTimerSheet), findsNothing);
    expect(find.text('0.2'), findsOneWidget); // 12 min in the KPI
  });

  testWidgets('share renders the page to a PNG', (tester) async {
    await boot(tester);
    await pumpScreen(tester, h, const InsightsScreen());
    await intro(tester);
    await tester.runAsync(() async {
      await tester.tap(find.bySemanticsLabel('Share insights'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await settle(tester);
    expect(share.shared, hasLength(1));
    // PNG signature.
    expect(share.shared.single.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
  });

  for (final dark in [false, true]) {
    testWidgets('no overflow at 360 pt and text scale 1.3 '
        '(${dark ? 'dark' : 'light'})', (tester) async {
      await boot(tester);
      await pumpScreen(
        tester,
        h,
        const InsightsScreen(),
        size: const Size(360, 800),
        textScale: 1.3,
        dark: dark,
      );
      expect(tester.takeException(), isNull);
      // Scroll through every section.
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -2000),
      );
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Weekly tip'), findsOneWidget);
      if (!dark) await captureScreen(tester, '25_insights_360_x13');
    });
  }
}
