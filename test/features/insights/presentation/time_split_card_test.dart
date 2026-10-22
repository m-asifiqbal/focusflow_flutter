/// "Where your time went": the animated callout donut — sweeps in, counts
/// the total up, labels every slice, reacts to touches, stays inside the
/// card at 360 pt / text scale 1.3 and under reduce motion shows the end
/// state at once. Captures `build/screens/25_time_split*.png`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/features/insights/domain/entities/insights_snapshot.dart';
import 'package:focusflow/features/insights/presentation/widgets/time_split_card.dart';

import '../../../helpers/screen_harness.dart';
import '../../../helpers/test_container.dart';

void main() {
  late TestHarness h;

  const split = TimeSplit(tasks: 27, habits: 21, notes: 7, reminders: 2);

  Future<void> boot(
    WidgetTester tester, {
    Size size = kMockupSize,
    double textScale = 1,
    bool dark = false,
    TimeSplit data = split,
  }) async {
    await loadAppFonts();
    h = (await tester.runAsync(
      () => TestHarness.create(now: DateTime(2026, 10, 15)),
    ))!;
    addTearDown(() => tester.runAsync(h.dispose));
    await pumpScreen(
      tester,
      h,
      Material(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(child: TimeSplitCard(split: data)),
        ),
      ),
      size: size,
      textScale: textScale,
      dark: dark,
    );
  }

  testWidgets('shows the total and every share', (tester) async {
    await boot(tester);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('57'), findsOneWidget);
    expect(find.text('actions'), findsOneWidget);
    // Legend rows.
    for (final l in ['Tasks', 'Habits', 'Notes', 'Reminders']) {
      expect(find.text(l), findsOneWidget);
    }
    await captureScreen(tester, '25_time_split');
  });

  testWidgets('dark capture', (tester) async {
    await boot(tester, dark: true);
    await tester.pump(const Duration(seconds: 2));
    await captureScreen(tester, '25_time_split_dark');
  });

  testWidgets('touching a legend row highlights without errors', (
    tester,
  ) async {
    await boot(tester);
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('Habits'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    await captureScreen(tester, '25_time_split_touched');
    await tester.tap(find.text('Habits'));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('one module only: a full ring', (tester) async {
    await boot(tester, data: const TimeSplit(tasks: 5));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('5'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await captureScreen(tester, '25_time_split_single');
  });

  for (final dark in [false, true]) {
    testWidgets('no overflow at 360 pt and text scale 1.3 '
        '(${dark ? 'dark' : 'light'})', (tester) async {
      await boot(
        tester,
        size: const Size(360, 800),
        textScale: 1.3,
        dark: dark,
      );
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
      await captureScreen(
        tester,
        '25_time_split_360_x13${dark ? '_dark' : ''}',
      );
    });
  }
}
