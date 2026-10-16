/// Reviewer test for lib/shared/item_actions/item_pickers.dart: the colour
/// sheet writes the note colour (White clears it) and the set-reminder
/// quick sheet creates / removes the linked reminder via
/// RemindersRepository.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/widgets/ff_bottom_sheet.dart';
import 'package:focusflow/shared/item_actions/item_pickers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../features/notes/notes_fixtures.dart';
import '../features/notes/presentation/notes_list_fixtures.dart';
import '../helpers/screen_harness.dart';
import '../helpers/test_container.dart';

void main() {
  late Directory docs;

  setUp(() => docs = Directory.systemTemp.createTempSync('ff_pickers'));
  tearDown(() {
    if (docs.existsSync()) docs.deleteSync(recursive: true);
  });

  Future<(TestHarness, String)> harness(WidgetTester tester) async {
    final h = (await tester.runAsync(
      () => TestHarness.create(now: kListNow, overrides: notesOverrides(docs)),
    ))!;
    addTearDown(() => tester.runAsync(h.dispose));
    final ids = (await tester.runAsync(() => seedNotesList(h, docs)))!;
    h.clock.set(kListNow);
    return (h, ids['Inspiration Trip']!);
  }

  Future<void> host(
    WidgetTester tester,
    TestHarness h,
    Future<void> Function(BuildContext, WidgetRef) open,
  ) => pumpScreen(
    tester,
    h,
    Consumer(
      builder: (context, ref, _) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => open(context, ref),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );

  testWidgets('colour sheet writes the colour; White clears it', (
    tester,
  ) async {
    await loadAppFonts();
    final (h, id) = await harness(tester);
    final items = h.read(itemsRepositoryProvider);
    final ref = noteRef(id);
    await host(tester, h, (c, r) => pickItemColour(c, r, [ref]));

    await tester.tap(find.text('open'));
    await settle(tester);
    expect(find.text('Change colour'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Pink colour'));
    await settle(tester);
    final pink = await tester.runAsync(() => items.get(ref));
    expect(pink!.colorHex, isNotNull);

    await tester.tap(find.text('open'));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('White colour'));
    await settle(tester);
    final white = await tester.runAsync(() => items.get(ref));
    expect(white!.colorHex, isNull);
    expect(find.byType(FFBottomSheet), findsNothing);
  });

  testWidgets('set reminder preset links a reminder; Remove unlinks it', (
    tester,
  ) async {
    await loadAppFonts();
    final (h, id) = await harness(tester);
    final ref = noteRef(id);
    final reminders = h.read(remindersRepositoryProvider);
    final item = (await tester.runAsync(
      () => h.read(itemsRepositoryProvider).get(ref),
    ))!;
    await host(tester, h, (c, r) => setItemReminder(c, r, item));

    await tester.tap(find.text('open'));
    await settle(tester);
    await tester.tap(find.text('Tomorrow morning'));
    await settle(tester);
    final linked = await tester.runAsync(
      () => reminders.getLinkedReminder(ref),
    );
    expect(linked, isNotNull);
    expect(linked!.triggerAt, DateTime(2026, 6, 13, 9));
    expect(find.textContaining('Reminder set for'), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    await tester.tap(find.text('open'));
    await settle(tester);
    expect(find.textContaining('Currently'), findsOneWidget);
    await tester.tap(find.text('Remove reminder'));
    await settle(tester);
    final gone = await tester.runAsync(() => reminders.getLinkedReminder(ref));
    expect(gone, isNull);
  });
}
