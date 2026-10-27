/// Screen 16 — Habit detail: mockup state (Drink Water 6/8, weekdays,
/// ~17 weeks of history) renders in light + dark; Log adds a glass, Skip
/// marks today skipped, a heatmap/history tap opens the day sheet, a new
/// habit shows the empty-stats copy, no overflow at 360 pt / 1.3.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/domain/entities/habit_frequency.dart';
import 'package:focusflow/features/habits/domain/entities/habit_log.dart';
import 'package:focusflow/features/habits/domain/repository/habits_repository.dart';
import 'package:focusflow/features/habits/presentation/habit_style.dart';
import 'package:focusflow/features/habits/presentation/providers/habit_detail_providers.dart';
import 'package:focusflow/features/habits/presentation/widgets/detail/habit_heatmap.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/screen_harness.dart';
import '../../../helpers/test_container.dart';
import '../habits_seed.dart';

/// The mockup PNG is 1170×4137 (390×1379 pt).
const _mockupTall = Size(390, 1379);

/// Drink Water like mockup 16 (today = Fri 12 Jun 2026): weekdays, 8
/// glasses, today 6/8, yesterday complete. The stat tiles match the mockup:
/// a 12-day current streak (Tue 26 May → Thu 11 Jun, Wed 10 Jun skipped
/// with a note), a 31-day best streak (1 Apr → 13 May), 214 check-ins
/// (weekend logs fill up the total; they never touch streaks or rates).
/// Completion reads 85 %, the closest a weekday habit can get to the
/// mockup's 86 % with a skip inside the last 30 days (17 of 20 measured
/// days). The mockup's "Sun, Jun 11" row can't exist — 11 Jun 2026 is a
/// Thursday ("Yesterday") — so the skipped row reads "Wed, Jun 10".
Future<String> _seedWater(HabitsRepository repo, {bool history = true}) async {
  final today = DateUtilsX.dateOnly(mockupNow);
  DateTime on(int m, int d, [int y = 2026]) => DateTime(y, m, d);
  final start = on(10, 1, 2025);
  final id = await repo.save(
    Habit.draft(
      startDate: start,
      name: 'Drink Water',
      iconKey: 'droplet',
      colorHex: HabitPalette.hexOf(HabitPalette.blue),
      targetCount: 8,
      unit: 'glasses',
      frequency: HabitFrequency.weekdays,
    ),
  );
  if (!history) return id;

  // Weekday counts; null = no log. Monthly bars as in the mockup: Jan ~50 %,
  // Feb ~75 %, Mar ~57 %, Apr 100 % (best streak), May 86 %, Jun 100 %.
  int? weekday(DateTime d) {
    bool between(DateTime a, DateTime b) => !d.isBefore(a) && !d.isAfter(b);
    if (d == today) return 6;
    if (between(on(5, 26), on(6, 11))) return 8; // current streak
    if (d == on(5, 25)) return 3; // breaks it
    if (between(on(5, 15), on(5, 22))) return d == on(5, 19) ? 4 : 8;
    if (d == on(5, 14)) return 5; // ends the best streak
    if (between(on(4, 1), on(5, 13))) return 8; // best streak (31 days)
    if (d == on(3, 31)) return 3; // …which starts after a partial day
    final i = DateUtilsX.daysBetween(start, d);
    if (d.isBefore(on(2, 1))) return const [8, 3, 8, 5, 0, 8][i % 6];
    if (d.isBefore(on(3, 1))) return const [8, 8, 4, 8, 8, 2, 8, 8][i % 8];
    return const [8, 8, 4, 8, 2, 8, 6][i % 7];
  }

  var total = 0;
  final weekends = <DateTime>[];
  for (var d = start; !d.isAfter(today); d = DateUtilsX.addDays(d, 1)) {
    if (d.weekday > DateTime.friday) {
      weekends.add(d);
      continue;
    }
    final skip = d == on(6, 10);
    final count = skip ? 0 : weekday(d);
    if (!skip && (count == null || count == 0)) continue;
    await repo.setLog(
      id,
      d,
      count: count ?? 0,
      skipped: skip,
      note: skip ? 'travel day' : null,
    );
    if (!skip) total++;
  }
  // Newest weekends first until the total reads 214 check-ins.
  for (final (i, d) in weekends.reversed.indexed) {
    if (total >= 214) break;
    await repo.setLog(id, d, count: const [3, 8, 5, 2, 6][i % 5]);
    total++;
  }
  assert(total == 214, 'seed needs more history ($total)');
  return id;
}

void main() {
  late TestHarness h;

  Future<String> setUp(WidgetTester tester, {bool history = true}) async {
    await loadAppFonts();
    h = (await tester.runAsync(() => TestHarness.create(now: mockupNow)))!;
    addTearDown(() => tester.runAsync(h.dispose));
    return (await tester.runAsync(
      () => _seedWater(h.read(habitsRepositoryProvider), history: history),
    ))!;
  }

  Future<HabitLog?> todayLog(WidgetTester tester, String id) async {
    final today = DateUtilsX.dateOnly(mockupNow);
    final logs = await tester.runAsync(
      () =>
          h.read(habitsRepositoryProvider).watchLogsInRange(today, today).first,
    );
    return logs!.where((l) => l.habitId == id).firstOrNull;
  }

  testWidgets('mockup state (light)', (tester) async {
    final id = await setUp(tester);
    await pumpApp(tester, h, AppRoutes.habit(id), size: _mockupTall);
    expect(find.text('Habit'), findsOneWidget);
    expect(find.text('Drink Water'), findsOneWidget);
    expect(find.text('6/8'), findsOneWidget);
    expect(find.text('Log 1 glass'), findsOneWidget);
    expect(find.text('Skip today'), findsOneWidget);
    for (final t in ['CURRENT STREAK', 'BEST STREAK', 'COMPLETION', 'TOTAL']) {
      expect(find.text(t, findRichText: true), findsOneWidget);
    }
    expect(find.text('Consistency'), findsOneWidget);
    // The consistency range starts on this week.
    expect(find.text('This week'), findsOneWidget);
    expect(find.text('Monthly completion'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    // Stat tiles as in the mockup (completion: see _seedWater).
    for (final v in ['12', '31', '85%', '214']) {
      expect(find.text(v, findRichText: true), findsWidgets, reason: v);
    }
    expect(find.text('Wed, Jun 10'), findsOneWidget);
    expect(find.bySemanticsLabel('Edit habit'), findsOneWidget);
    expect(find.bySemanticsLabel('More options'), findsOneWidget);
    await captureScreen(tester, '16_habit_detail');
  });

  testWidgets('mockup state (dark)', (tester) async {
    final id = await setUp(tester);
    await pumpApp(
      tester,
      h,
      AppRoutes.habit(id),
      size: _mockupTall,
      dark: true,
    );
    await captureScreen(tester, '16_habit_detail_dark');
  });

  testWidgets('Log adds one glass; Skip marks today skipped', (tester) async {
    final id = await setUp(tester);
    await pumpApp(tester, h, AppRoutes.habit(id), size: _mockupTall);
    await tester.tap(find.text('Log 1 glass'));
    await settle(tester);
    expect((await todayLog(tester, id))!.count, 7);
    expect(find.text('7/8'), findsOneWidget);

    await tester.tap(find.text('Skip today'));
    await settle(tester);
    expect((await todayLog(tester, id))!.skipped, isTrue);
    expect(find.text('Unskip'), findsOneWidget);
  });

  testWidgets('More offers pause, export, archive, delete; pause persists', (
    tester,
  ) async {
    final id = await setUp(tester);
    await pumpApp(tester, h, AppRoutes.habit(id), size: _mockupTall);
    await tester.tap(find.bySemanticsLabel('More options'));
    await settle(tester);
    for (final t in ['Pause habit', 'Export CSV', 'Archive', 'Delete']) {
      expect(find.text(t), findsWidgets, reason: t);
    }
    await tester.tap(find.text('Pause habit'));
    await settle(tester);
    final habit = await tester.runAsync(
      () => h.read(habitsRepositoryProvider).getHabit(id),
    );
    expect(habit!.isPaused, isTrue);
  });

  testWidgets('history row opens the day sheet; edit opens the editor', (
    tester,
  ) async {
    final id = await setUp(tester);
    await pumpApp(tester, h, AppRoutes.habit(id), size: _mockupTall);
    await tester.tap(find.text('Yesterday'));
    await settle(tester);
    expect(find.text('Note (optional)'), findsOneWidget);
    await tester.tapAt(const Offset(195, 40));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('Edit habit'));
    await settle(tester);
    expect(find.text('Edit Habit'), findsOneWidget);
  });

  testWidgets('a trashed habit offers Restore / Delete forever only', (
    tester,
  ) async {
    final id = await setUp(tester);
    await tester.runAsync(
      () => h.read(itemsRepositoryProvider).moveToTrash([
        ItemRef(ItemType.habit, id),
      ]),
    );
    await pumpApp(tester, h, AppRoutes.habit(id), size: _mockupTall);
    await tester.tap(find.bySemanticsLabel('More options'));
    await settle(tester);
    expect(find.text('Restore'), findsOneWidget);
    expect(find.text('Delete forever'), findsOneWidget);
    for (final t in ['Pause habit', 'Export CSV', 'Archive']) {
      expect(find.text(t), findsNothing, reason: t);
    }
  });

  testWidgets('day sheet: Skipped disables the stepper; Save offers Undo', (
    tester,
  ) async {
    final id = await setUp(tester);
    await pumpApp(tester, h, AppRoutes.habit(id), size: _mockupTall);
    await tester.tap(find.text('Yesterday'));
    await settle(tester);
    await tester.tap(find.text('Skipped (rest day)'));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('Decrease Count (glasses)'));
    await settle(tester);
    expect(find.text('8'), findsWidgets);
    await tester.tap(find.text('Save'));
    await settle(tester);
    final yesterday = DateUtilsX.addDays(DateUtilsX.dateOnly(mockupNow), -1);
    Future<HabitLog?> log() async => (await tester.runAsync(
      () => h
          .read(habitsRepositoryProvider)
          .watchLogsInRange(yesterday, yesterday)
          .first,
    ))!.where((l) => l.habitId == id).firstOrNull;
    expect((await log())!.skipped, isTrue);
    expect(find.text('Log updated · Jun 11'), findsOneWidget);
    await tester.tap(find.text('UNDO'));
    await settle(tester);
    final back = (await log())!;
    expect((back.count, back.skipped), (8, false));
  });

  /// Opens the range sheet from the link and picks [label].
  Future<void> pickRange(WidgetTester tester, String from, String label) async {
    await tester.tap(find.text(from));
    await settle(tester);
    await tester.tap(find.text(label).last);
    await settle(tester);
  }

  testWidgets('consistency starts on this week; the link has a chevron', (
    tester,
  ) async {
    final id = await setUp(tester);
    await pumpApp(tester, h, AppRoutes.habit(id), size: _mockupTall);
    HabitHeatmap map() =>
        tester.widget<HabitHeatmap>(find.byType(HabitHeatmap));
    expect(map().calendar, isTrue);
    expect(map().weeks, 1);
    expect(find.text('This week'), findsOneWidget);
    // The chevron tells the user the range can be changed.
    expect(find.byIcon(FontAwesomeIcons.chevronDown), findsWidgets);
    expect(
      find.bySemanticsLabel(RegExp('Heatmap range, This week')),
      findsOneWidget,
    );
  });

  testWidgets('the range sheet offers week, month, 4 months and year', (
    tester,
  ) async {
    final id = await setUp(tester);
    await pumpApp(tester, h, AppRoutes.habit(id), size: _mockupTall);
    HabitHeatmap map() =>
        tester.widget<HabitHeatmap>(find.byType(HabitHeatmap));

    await tester.tap(find.text('This week'));
    await settle(tester);
    for (final l in ['This month', 'Last 4 months', 'Last year']) {
      expect(find.text(l), findsOneWidget, reason: l);
    }
    await tester.tap(find.text('This month'));
    await settle(tester);
    await captureScreen(tester, 'habit_detail_month');
    expect(map().calendar, isTrue);
    expect(map().from!.day, 1);
    expect(map().weeks, inInclusiveRange(1, 6));
    // Days before the 1st are not drawn (and can't be tapped).
    expect(
      HabitHeatmap.levelFor(
        day: map().from!.subtract(const Duration(days: 1)),
        end: DateTime(2026, 6, 30),
        byDay: const {},
        rest: const {},
        from: map().from,
      ),
      lessThan(-2),
    );

    await pickRange(tester, 'This month', 'Last 4 months');
    expect(map().calendar, isFalse);
    expect(map().weeks, 17);

    await pickRange(tester, 'Last 4 months', 'Last year');
    expect(map().weeks, 53);
    expect(find.text('Last year'), findsOneWidget);

    await pickRange(tester, 'Last year', 'This week');
    expect(map().calendar, isTrue);
    expect(map().weeks, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('monthly completion: every bar has a label, a tap picks one', (
    tester,
  ) async {
    final id = await setUp(tester);
    await pumpApp(tester, h, AppRoutes.habit(id), size: _mockupTall);
    expect(find.text('Tap a bar'), findsOneWidget);
    final chart = find.byType(BarChart);
    expect(chart, findsOneWidget);
    final data = tester.widget<BarChart>(chart).data;
    // The percentage on top of every bar: always shown, and touch enabled.
    expect(data.barTouchData.enabled, isTrue);
    expect(
      data.barGroups.every((g) => g.showingTooltipIndicators.isNotEmpty),
      isTrue,
    );
    expect(data.barGroups.length, greaterThan(1));
    // The current month is the picked one at first (solid colour).
    Color? rodColor(int i) =>
        tester.widget<BarChart>(chart).data.barGroups[i].barRods.single.color;
    final last = data.barGroups.length - 1;
    expect(rodColor(last), isNot(rodColor(0)));

    // Tap the first bar: it becomes the solid one.
    final box = tester.getRect(chart);
    await tester.tapAt(Offset(box.left + 40, box.center.dy + 20));
    await tester.pump(const Duration(milliseconds: 600));
    expect(rodColor(0), isNot(rodColor(last)));
    expect(tester.takeException(), isNull);
  });

  test('HabitHeatmapRange steps shortest to longest and wraps', () {
    expect(HabitHeatmapRange.week.next, HabitHeatmapRange.month);
    expect(HabitHeatmapRange.month.next, HabitHeatmapRange.months4);
    expect(HabitHeatmapRange.months4.next, HabitHeatmapRange.year);
    expect(HabitHeatmapRange.year.next, HabitHeatmapRange.week);
  });

  test('HabitHeatmapRange.weeksFor counts the rows of the month', () {
    // 1 Oct 2026 is a Thursday; Monday weeks: 28 Sep, 5, 12, 19, 26 Oct.
    expect(
      HabitHeatmapRange.month.weeksFor(DateTime(2026, 10, 27), DateTime.monday),
      5,
    );
    expect(
      HabitHeatmapRange.month.weeksFor(DateTime(2026, 10, 2), DateTime.monday),
      1,
    );
    // Sunday weeks start a day earlier: 27 Sep, 4, 11, 18, 25 Oct.
    expect(
      HabitHeatmapRange.month.weeksFor(DateTime(2026, 10, 26), DateTime.sunday),
      5,
    );
    expect(HabitHeatmapRange.week.weeksFor(DateTime(2026, 10, 27), 1), 1);
    expect(HabitHeatmapRange.year.weeksFor(DateTime(2026, 10, 27), 1), 53);
    expect(
      HabitHeatmapRange.month.firstDay(DateTime(2026, 10, 27)),
      DateTime(2026, 10),
    );
    expect(HabitHeatmapRange.year.firstDay(DateTime(2026, 10, 27)), isNull);
  });

  testWidgets('new habit shows the empty stats copy', (tester) async {
    final id = await setUp(tester, history: false);
    await pumpApp(tester, h, AppRoutes.habit(id));
    expect(find.text('0/8'), findsOneWidget);
    expect(
      find.text('Your stats appear after the first check-in.'),
      findsOneWidget,
    );
    await captureScreen(tester, '16_habit_detail_empty');
  });

  testWidgets('missing habit shows not found', (tester) async {
    await setUp(tester, history: false);
    await pumpApp(tester, h, AppRoutes.habit('nope'));
    expect(find.text('Habit not found'), findsOneWidget);
  });

  testWidgets('no overflow at 360 pt and text scale 1.3', (tester) async {
    final id = await setUp(tester);
    await pumpApp(
      tester,
      h,
      AppRoutes.habit(id),
      size: const Size(360, 800),
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('History'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
    await captureScreen(tester, '16_habit_detail_360_scale130');
  });
}
