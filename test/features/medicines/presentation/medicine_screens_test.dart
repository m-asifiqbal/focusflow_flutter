/// Medicine screens in the real app: the list (hero, due dose with SNOOZE /
/// SKIP / TAKEN, refill banner, as needed, cabinet), taking a dose from it,
/// the Reminders "Medicine" chip, the detail, and adding a medicine in the
/// editor — light and dark, and without overflow at 360 pt / text 1.3.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine.dart';
import 'package:focusflow/features/medicines/domain/repository/medicines_repository.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/screen_harness.dart';
import '../../../helpers/test_container.dart';

final _now = DateTime(2026, 10, 23, 8, 30);
final _today = DateTime(2026, 10, 23);

/// Metformin 08:00 + 20:00 (6 left: low), Vitamin D3 09:00 (taken early
/// would be odd: not logged), Ibuprofen as needed.
Future<String> _seed(MedicinesRepository repo) async {
  final metformin = await repo.save(
    Medicine.draft(startDate: _today, name: 'Metformin').copyWith(
      strength: '500 mg',
      foodTiming: FoodTiming.afterFood,
      doses: const [DoseTime(8 * 60), DoseTime(20 * 60)],
      stockLeft: 6,
      refillAt: 6,
    ),
  );
  await repo.save(
    Medicine.draft(
      startDate: _today,
      name: 'Vitamin D3',
    ).copyWith(form: MedicineForm.capsule, doses: const [DoseTime(9 * 60)]),
  );
  await repo.save(
    Medicine.draft(
      startDate: _today,
      name: 'Ibuprofen',
    ).copyWith(schedule: MedicineScheduleType.asNeeded, doses: const []),
  );
  return metformin;
}

void main() {
  setUpAll(loadAppFonts);

  late TestHarness h;
  late MedicinesRepository repo;

  setUp(() async {
    h = await TestHarness.create(now: _now);
    repo = h.read(medicinesRepositoryProvider);
  });

  tearDown(() => h.dispose());

  testWidgets('list: doses, refill, as needed; TAKEN logs the dose', (
    tester,
  ) async {
    final id = await tester.runAsync(() => _seed(repo));
    await pumpApp(tester, h, AppRoutes.medicines);
    expect(find.text('Medicines'), findsWidgets);
    expect(find.text('Today\'s doses'.toUpperCase()), findsOneWidget);
    expect(find.text('0 of 3 taken'), findsOneWidget);
    expect(find.text('Metformin is running low'), findsOneWidget);
    await captureScreen(tester, 'medicine_list');
    // Below the fold: as needed and the cabinet.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await settle(tester);
    expect(find.text('Ibuprofen'), findsWidgets);
    await captureScreen(tester, 'medicine_list_bottom');
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 900));
    await settle(tester);

    await tester.tap(find.text('TAKEN').first);
    await settle(tester);
    final log = await tester.runAsync(() => repo.doseLog(id!, _today, 480));
    expect(log?.isTaken, isTrue);
    expect(find.text('1 of 3 taken'), findsOneWidget);
    expect(find.text('Metformin taken'), findsOneWidget); // undo snackbar
    await captureScreen(tester, 'medicine_list_taken');
  });

  testWidgets('empty list invites to add the first medicine', (tester) async {
    await pumpApp(tester, h, AppRoutes.medicines);
    expect(find.text('Add your first medicine'), findsOneWidget);
  });

  testWidgets('Reminders: the Medicine chip shows the day\'s doses', (
    tester,
  ) async {
    await tester.runAsync(() => _seed(repo));
    await pumpApp(tester, h, AppRoutes.reminders);
    await tester.tap(find.text('Medicine'));
    await settle(tester);
    expect(find.text('Metformin'), findsWidgets);
    expect(find.text('Your medicines'.toUpperCase()), findsNothing);
  });

  testWidgets('detail: hero, stats, take the next dose', (tester) async {
    final id = await tester.runAsync(() => _seed(repo));
    await pumpApp(tester, h, AppRoutes.medicine(id!));
    expect(find.text('Metformin'), findsWidgets);
    expect(find.text('0/2'), findsOneWidget);
    // Times read "8:00 AM" with a narrow no-break space (intl).
    final morning = find.textContaining(RegExp(r'Take 0?8:00\sAM dose'));
    await captureScreen(tester, 'medicine_detail');
    expect(morning, findsOneWidget);
    await tester.tap(morning);
    await settle(tester);
    expect(find.text('1/2'), findsOneWidget);
    expect(
      find.textContaining(RegExp(r'Take 0?8:00\sPM dose')),
      findsOneWidget,
    );
  });

  testWidgets('detail: dose calendar switches Week · Month · Year', (
    tester,
  ) async {
    final id = await tester.runAsync(() => _seed(repo));
    await pumpApp(tester, h, AppRoutes.medicine(id!));
    final list = find.byType(ListView);
    await tester.drag(list, const Offset(0, -600));
    await settle(tester);

    // Week is the default and costs nothing extra.
    expect(find.text('This week'), findsOneWidget);
    expect(find.text('Week'), findsOneWidget);

    // Month: a calendar of October 2026 with today's date on a disc.
    await tester.tap(find.text('Month'));
    await settle(tester);
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('23'), findsWidgets);
    expect(find.bySemanticsLabel('Previous month'), findsOneWidget);
    // Today is the first day of the course: nothing earlier to go back to.
    final previous = tester.widget<FFRoundIconButton>(
      find.byWidgetPredicate(
        (w) => w is FFRoundIconButton && w.semanticLabel == 'Previous month',
      ),
    );
    expect(previous.onPressed, isNull);
    expect(tester.takeException(), isNull);

    // Year: twelve mini months; tapping one opens it in the Month view.
    await tester.tap(find.text('Year'));
    await settle(tester);
    expect(find.text('2026'), findsOneWidget);
    expect(find.text('Partly taken'), findsOneWidget);
    expect(find.text('Oct'), findsOneWidget);
    await tester.tap(find.text('Oct'));
    await settle(tester);
    expect(find.text('October 2026'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Back to the week.
    await tester.tap(find.text('Week'));
    await settle(tester);
    expect(find.text('This week'), findsOneWidget);
  });

  testWidgets('editor: add a medicine and land on its page', (tester) async {
    await pumpApp(tester, h, AppRoutes.newMedicinePath);
    expect(find.text('New medicine'), findsOneWidget);
    await captureScreen(tester, 'medicine_editor');
    await tester.enterText(find.byType(TextField).first, 'Amoxicillin');
    await tester.tap(find.text('Liquid'));
    await settle(tester);
    await tester.tap(find.text('Add').last);
    await settle(tester);
    final meds = await tester.runAsync(
      () => repo.watchMedicines(MedicinesScope.active).first,
    );
    expect(meds!.single.name, 'Amoxicillin');
    expect(meds.single.form, MedicineForm.liquid);
    expect(find.text('Amoxicillin'), findsWidgets);
  });

  for (final dark in [false, true]) {
    testWidgets('no overflow at 360 pt / 1.3 (dark: $dark)', (tester) async {
      final id = await tester.runAsync(() => _seed(repo));
      for (final route in [
        AppRoutes.medicines,
        AppRoutes.medicine(id!),
        AppRoutes.medicineEdit(id),
      ]) {
        await pumpApp(
          tester,
          h,
          route,
          size: const Size(360, 800),
          textScale: 1.3,
          dark: dark,
        );
        expect(tester.takeException(), isNull, reason: route);
      }
      await captureScreen(
        tester,
        'medicine_editor_360_${dark ? 'dark' : 'light'}',
      );
    });
  }
}
