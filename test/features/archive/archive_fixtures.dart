/// Fixtures of the Archive / Recently Deleted tests: the rows of
/// design/23 and design/24 (provider overrides for the pixel captures) and
/// a small real seed for the live-data tests.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/item_summary.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/features/archive/presentation/providers/archive_providers.dart';
import 'package:focusflow/features/habits/domain/services/streak_calculator.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:focusflow/features/vault/presentation/vault_gate.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../helpers/test_container.dart';

/// 9:41 on Friday Jun 12, like the mockups' status bar.
final DateTime kArchiveNow = DateTime(2026, 6, 12, 9, 41);

ItemSummary _item(
  ItemType type,
  String id,
  String title, {
  DateTime? archivedAt,
  DateTime? deletedAt,
  bool completed = false,
}) => ItemSummary(
  ref: ItemRef(type, id),
  title: title,
  isCompleted: completed,
  createdAt: DateTime(2026),
  updatedAt: archivedAt ?? deletedAt ?? DateTime(2026),
  archivedAt: archivedAt,
  deletedAt: deletedAt,
);

/// The rows of design/23 (newest archive first).
final List<ItemSummary> kMockupArchived = [
  _item(
    ItemType.note,
    'n1',
    'Old project brief — Fresh LPG relaunch',
    archivedAt: DateTime(2026, 6, 2, 10),
  ),
  _item(
    ItemType.task,
    't1',
    'Migrate to new CI pipeline',
    archivedAt: DateTime(2026, 5, 28, 10),
    completed: true,
  ),
  _item(
    ItemType.habit,
    'h1',
    'Learn Spanish (paused)',
    archivedAt: DateTime(2026, 5, 20, 10),
  ),
  _item(
    ItemType.reminder,
    'r1',
    'Passport renewal',
    archivedAt: DateTime(2026, 5, 10, 10),
  ),
  _item(
    ItemType.vault,
    'v1',
    'Old Twitter account',
    archivedAt: DateTime(2026, 4, 22, 10),
  ),
  _item(
    ItemType.note,
    'n2',
    'Conference notes 2022',
    archivedAt: DateTime(2026, 3, 3, 10),
  ),
  _item(
    ItemType.task,
    't2',
    'Q1 OKR review',
    archivedAt: DateTime(2026, 2, 18, 10),
  ),
];

/// The rows of design/24 (newest deletion first).
final List<ItemSummary> kMockupTrash = [
  _item(
    ItemType.note,
    'n3',
    'Random thoughts',
    deletedAt: DateTime(2026, 6, 12, 8),
  ),
  _item(
    ItemType.task,
    't3',
    'Buy printer ink',
    deletedAt: DateTime(2026, 6, 11, 18),
  ),
  _item(
    ItemType.reminder,
    'r2',
    'Dentist appointment',
    deletedAt: DateTime(2026, 6, 3, 12),
  ),
  _item(
    ItemType.vault,
    'v2',
    'Old Wi-Fi password',
    deletedAt: DateTime(2026, 5, 30, 12),
  ),
  _item(
    ItemType.habit,
    'h2',
    'Cold showers',
    deletedAt: DateTime(2026, 5, 18, 12),
  ),
];

/// Test-controlled vault lock state.
final testVaultStatus = StateProvider<VaultStatus>((_) => VaultStatus.unlocked);

/// Vault state (always) + optionally the mockup rows.
List<Override> archiveOverrides({bool mockup = false}) => [
  vaultStatusProvider.overrideWith((ref) => ref.watch(testVaultStatus)),
  if (mockup) ...[
    archivedItemsProvider.overrideWith((ref) => Stream.value(kMockupArchived)),
    trashProvider.overrideWith((ref) => Stream.value(kMockupTrash)),
    archivedHabitStreakProvider.overrideWith(
      (ref, args) => Stream.value(const HabitStreak(current: 34, best: 34)),
    ),
  ],
];

/// Ids of [seedArchive]'s items.
typedef ArchiveSeed = ({String note, String task, String trashed});

/// An archived note ("Conference notes"), an archived task ("Q1 OKR
/// review") and a deleted note ("Random thoughts").
Future<ArchiveSeed> seedArchive(TestHarness h) async {
  final notes = h.read(notesRepositoryProvider);
  final items = h.read(itemsRepositoryProvider);
  final note = await notes.createEmpty(title: 'Conference notes');
  final task = await h
      .read(tasksRepositoryProvider)
      .save(
        TaskItem(
          id: '',
          title: 'Q1 OKR review',
          createdAt: kArchiveNow,
          updatedAt: kArchiveNow,
        ),
      );
  final trashed = await notes.createEmpty(title: 'Random thoughts');
  await items.archive([
    ItemRef(ItemType.note, note),
    ItemRef(ItemType.task, task),
  ]);
  await items.moveToTrash([ItemRef(ItemType.note, trashed)]);
  return (note: note, task: task, trashed: trashed);
}
