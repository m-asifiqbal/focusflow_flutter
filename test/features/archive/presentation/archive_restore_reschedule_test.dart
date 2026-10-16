/// Prompt 23: restoring an archived reminder whose time has passed asks to
/// reschedule it (restore_reschedule.dart via restoreFromArchive); a future
/// reminder comes back silently.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/features/archive/presentation/widgets/archive_rows.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/screen_harness.dart';
import '../../../helpers/test_container.dart';
import '../archive_fixtures.dart';

void main() {
  setUpAll(loadAppFonts);

  Future<(TestHarness, String)> harness(
    WidgetTester tester,
    DateTime at,
  ) async {
    const inset = FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
    tester.view
      ..padding = inset
      ..viewPadding = inset;
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    final h = (await tester.runAsync(
      () => TestHarness.create(now: kArchiveNow, overrides: archiveOverrides()),
    ))!;
    addTearDown(() => tester.runAsync(h.dispose));
    final id = (await tester.runAsync(() async {
      final repo = h.read(remindersRepositoryProvider);
      final id = await repo.save(
        Reminder.draft(triggerAt: at, title: 'Passport renewal'),
      );
      await h.read(itemsRepositoryProvider).archive([
        (await repo.getReminder(id))!.ref,
      ]);
      return id;
    }))!;
    return (h, id);
  }

  Future<void> tapRestore(WidgetTester tester) async {
    await tester.tap(
      find.byWidgetPredicate(
        (w) =>
            w is RestoreButton && w.semanticLabel == 'Restore Passport renewal',
      ),
    );
    await settle(tester);
  }

  testWidgets('a past reminder asks to reschedule; Keep as is keeps it', (
    tester,
  ) async {
    final past = kArchiveNow.subtract(const Duration(days: 2));
    final (h, id) = await harness(tester, past);
    await pumpApp(tester, h, AppRoutes.archive);
    await tapRestore(tester);

    expect(find.text('Reschedule "Passport renewal"?'), findsOneWidget);
    expect(find.text('Pick a new time'), findsOneWidget);
    expect(find.text('Edit reminder'), findsOneWidget);
    await tester.tap(find.text('Keep as is'));
    await settle(tester);
    expect(find.text('Reschedule "Passport renewal"?'), findsNothing);

    final r = await tester.runAsync(
      () => h.read(remindersRepositoryProvider).getReminder(id),
    );
    expect(r!.isActive, isTrue);
    expect(r.triggerAt, past);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a past reminder: Pick a new time opens the date sheet', (
    tester,
  ) async {
    final (h, _) = await harness(
      tester,
      kArchiveNow.subtract(const Duration(hours: 3)),
    );
    await pumpApp(tester, h, AppRoutes.archive);
    await tapRestore(tester);
    await tester.tap(find.text('Pick a new time'));
    await settle(tester);
    expect(find.text('Reschedule'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a future reminder is restored without asking', (tester) async {
    final (h, id) = await harness(
      tester,
      kArchiveNow.add(const Duration(days: 3)),
    );
    await pumpApp(tester, h, AppRoutes.archive);
    await tapRestore(tester);
    expect(find.textContaining('Reschedule'), findsNothing);
    expect(find.text('"Passport renewal" restored'), findsOneWidget);
    final r = await tester.runAsync(
      () => h.read(remindersRepositoryProvider).getReminder(id),
    );
    expect(r!.isActive, isTrue);
  });
}
