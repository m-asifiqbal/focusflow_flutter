/// Maintenance.runIfDue: the 30-day trash purge runs at most once per
/// ~day (throttled through prefs); abandoned blank notes are swept once
/// per process (app launch) without ever touching real notes.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/startup/maintenance.dart';
import 'package:focusflow/features/notifications_center/domain/entities/inbox_entry.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../helpers/test_container.dart';

final DateTime _now = DateTime(2026, 6, 12, 9, 41);

void main() {
  late TestHarness h;

  setUp(() async => h = await TestHarness.create(now: _now));
  tearDown(() => h.dispose());

  Maintenance fresh() => Maintenance(
    h.read(itemsRepositoryProvider),
    h.read(sharedPreferencesProvider),
    h.clock,
    inbox: h.read(inboxRepositoryProvider),
  );

  test('purges expired trash, throttled to once per ~day', () async {
    final notes = h.read(notesRepositoryProvider);
    final items = h.read(itemsRepositoryProvider);
    final old = await notes.createEmpty(title: 'Old');
    await items.moveToTrash([ItemRef(ItemType.note, old)]);
    final maintenance = fresh();

    await maintenance.runIfDue(); // records the run; nothing expired yet
    expect(await notes.getNote(old), isNotNull);

    h.clock.advance(const Duration(days: 31));
    final young = await notes.createEmpty(title: 'Young');
    await items.moveToTrash([ItemRef(ItemType.note, young)]);
    await maintenance.runIfDue();
    expect(await notes.getNote(old), isNull);
    expect(await notes.getNote(young), isNotNull);

    // Within 20 h: throttled, even though `young` would now be expired.
    h.clock.advance(const Duration(days: 30, hours: -12));
    await h
        .read(sharedPreferencesProvider)
        .setString(
          'maintenance_last_run',
          h.clock.now().subtract(const Duration(hours: 1)).toIso8601String(),
        );
    await maintenance.runIfDue();
    expect(await notes.getNote(young), isNotNull);

    h.clock.advance(const Duration(hours: 21));
    await maintenance.runIfDue();
    expect(await notes.getNote(young), isNull);
  });

  test('sweeps blank notes on the first run of a process only', () async {
    final notes = h.read(notesRepositoryProvider);
    final blank = await notes.createEmpty();
    final real = await notes.createEmpty(title: 'Groceries');
    h.clock.advance(const Duration(hours: 2));

    final launch = fresh();
    await launch.runIfDue();
    expect(await notes.getNote(blank), isNull);
    expect(await notes.getNote(real), isNotNull);

    // A blank note created later in the same process (an editor may be
    // open on it) is left alone by later runs.
    final open = await notes.createEmpty();
    h.clock.advance(const Duration(days: 2));
    await launch.runIfDue();
    expect(await notes.getNote(open), isNotNull);

    // Next launch sweeps it.
    await fresh().runIfDue();
    expect(await notes.getNote(open), isNull);
  });

  test('drops notifications older than the retention, keeps recent', () async {
    final inbox = h.read(inboxRepositoryProvider);
    await inbox.add(
      kind: InboxKind.reminder,
      title: 'Old',
      at: _now.subtract(Maintenance.inboxRetention + const Duration(days: 1)),
    );
    await inbox.add(
      kind: InboxKind.reminder,
      title: 'Recent',
      at: _now.subtract(const Duration(days: 10)),
    );

    await fresh().runIfDue();

    final left = await inbox.watch().first;
    expect(left.map((e) => e.title), ['Recent']);
  });
}
