/// LibraryFormat — the copy of the Library hub cards and mixed rows.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/items/item_summary.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/items/library_counts.dart';
import 'package:focusflow/features/library/presentation/library_format.dart';
import 'package:focusflow/features/vault/presentation/state/vault_session_state.dart';

import '../library_fixtures.dart';

void main() {
  final now = kLibraryNow;

  LibraryCardLines card(
    ItemType t, [
    LibraryCounts? c,
    VaultStatus vault = VaultStatus.locked,
  ]) => LibraryFormat.card(t, c ?? kMockupCounts, now: now, vault: vault);

  test('mockup numbers', () {
    expect(LibraryFormat.headerSubtitle(113), '113 items across 5 spaces');
    expect(LibraryFormat.headerSubtitle(1, spaces: 1), '1 item across 1 space');
    final notes = card(ItemType.note);
    expect(
      (notes.count, notes.highlight, notes.meta),
      (48, '3 pinned', 'Edited 2h ago'),
    );
    final tasks = card(ItemType.task);
    expect((tasks.highlight, tasks.meta), ('7 due today', '2 overdue'));
    final reminders = card(ItemType.reminder);
    expect((reminders.highlight, reminders.meta), ('3 today', 'Next 10:00 AM'));
    final habits = card(ItemType.habit);
    expect(
      (habits.highlight, habits.meta),
      ('2/4 done today', 'Best streak 45d'),
    );
    final vault = card(ItemType.vault);
    expect(
      (vault.count, vault.highlight, vault.meta),
      (24, '2 weak', 'Locked'),
    );
    expect(card(ItemType.vault, null, VaultStatus.unlocked).meta, 'Unlocked');
  });

  test('zero states say "Create your first"', () {
    for (final t in ItemType.values) {
      final l = card(t, LibraryCounts.empty);
      expect(l.count, 0);
      expect(l.highlight, LibraryFormat.createFirst, reason: t.name);
    }
    expect(
      card(ItemType.vault, LibraryCounts.empty, VaultStatus.notSetUp).meta,
      'Not set up',
    );
  });

  test('fallback lines', () {
    const c = LibraryCounts(
      tasksTotal: 3,
      tasksOpen: 0,
      tasksDone: 3,
      vaultTotal: 4,
      vaultBreached: 1,
      habitsTotal: 2,
    );
    expect(card(ItemType.task, c).highlight, 'All done');
    expect(card(ItemType.task, c).meta, '3 done');
    expect(card(ItemType.vault, c).highlight, '1 breached');
    expect(card(ItemType.habit, c).highlight, 'Rest day');
    expect(
      LibraryFormat.nextTime(DateTime(2026, 6, 13, 9), now),
      'tomorrow 9:00 AM',
    );
    expect(LibraryFormat.nextTime(DateTime(2026, 6, 20, 9), now), 'Jun 20');
    expect(
      LibraryFormat.nextTime(DateTime(2026, 6, 12, 14, 5), now, use24h: true),
      '14:05',
    );
  });

  test('row meta never needs secrets', () {
    ItemSummary s(
      ItemType t, {
      String meta = '',
      DateTime? at,
      bool done = false,
      String? folder,
    }) => ItemSummary(
      ref: ItemRef(t, 'x'),
      title: 'x',
      meta: meta,
      scheduledAt: at,
      isCompleted: done,
      folderName: folder,
      createdAt: now,
      updatedAt: now.subtract(const Duration(hours: 2)),
    );
    expect(
      LibraryFormat.rowMeta(s(ItemType.note, folder: 'Ideas'), now),
      'Note · Edited 2h ago · Ideas',
    );
    expect(
      LibraryFormat.rowMeta(
        s(ItemType.task, at: DateTime(2026, 6, 12, 17)),
        now,
      ),
      'Task · Due Today 5:00 PM',
    );
    expect(
      LibraryFormat.rowMeta(s(ItemType.task, done: true), now),
      'Task · completed',
    );
    expect(
      LibraryFormat.rowMeta(s(ItemType.vault, meta: 'Login'), now),
      'Password · Login',
    );
    expect(LibraryFormat.items(1), '1 item');
  });

  test('edited times read in sentence case', () {
    final now = DateTime(2026, 6, 12, 9, 41);
    expect(LibraryFormat.edited(now, now), 'Edited just now');
    expect(
      LibraryFormat.edited(DateTime(2026, 6, 11, 20), now),
      'Edited yesterday',
    );
    expect(
      LibraryFormat.edited(now.subtract(const Duration(hours: 2)), now),
      'Edited 2h ago',
    );
    expect(LibraryFormat.edited(DateTime(2026, 5, 3), now), 'Edited May 3');
  });
}
