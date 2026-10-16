/// The module list screens (Notes · Tasks · Reminders · Habits) have a back
/// arrow at the top left of their fixed toolbar, and the Notes ⋯ pop-up can
/// add a new note.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/router/app_router.dart';
import 'package:focusflow/core/router/app_routes.dart';

import '../features/notes/notes_fixtures.dart';
import '../features/reminders/isolated_notifications.dart';
import '../helpers/screen_harness.dart';
import '../helpers/test_container.dart';

final _now = DateTime(2026, 10, 13, 9, 41);

void main() {
  late Directory docs;

  setUp(() => docs = Directory.systemTemp.createTempSync('ff_list_screens'));
  tearDown(() {
    if (docs.existsSync()) docs.deleteSync(recursive: true);
  });

  Future<TestHarness> boot(WidgetTester tester) async {
    final h = (await tester.runAsync(
      () => TestHarness.create(
        now: _now,
        overrides: [...isolatedNotifications(), ...notesOverrides(docs)],
      ),
    ))!;
    addTearDown(() => tester.runAsync(h.dispose));
    return h;
  }

  // `state` follows imperative pushes too (currentConfiguration doesn't).
  String location(TestHarness h) => h.read(routerProvider).state.uri.path;

  for (final (name, route) in [
    ('Notes', AppRoutes.notes),
    ('Tasks', AppRoutes.tasks),
    ('Reminders', AppRoutes.reminders),
    ('Habits', AppRoutes.habits),
  ]) {
    testWidgets('$name has a back arrow that returns to Library', (
      tester,
    ) async {
      final h = await boot(tester);
      await pumpApp(tester, h, AppRoutes.library);
      h.read(routerProvider).push(route);
      await settle(tester);
      expect(location(h), route);
      final back = find.bySemanticsLabel('Back');
      expect(back, findsOneWidget);
      // Top left of the screen, in front of the title.
      expect(tester.getCenter(back).dx, lessThan(80));
      expect(
        tester.getCenter(back).dx,
        lessThan(tester.getCenter(find.text(name)).dx),
      );
      await tester.tap(back);
      await settle(tester);
      expect(location(h), AppRoutes.library);
    });
  }

  testWidgets('Notes ⋯ pop-up: "Add new note" opens a new note', (
    tester,
  ) async {
    final h = await boot(tester);
    await pumpApp(tester, h, AppRoutes.notes);
    await tester.tap(find.bySemanticsLabel('More options'));
    await settle(tester);
    expect(find.text('Add new note'), findsOneWidget);
    // It leads the menu.
    expect(
      tester.getTopLeft(find.text('Add new note')).dy,
      lessThan(tester.getTopLeft(find.text('Select notes')).dy),
    );
    await tester.tap(find.text('Add new note'));
    await settle(tester);
    expect(location(h), AppRoutes.newNote);
  });
}
