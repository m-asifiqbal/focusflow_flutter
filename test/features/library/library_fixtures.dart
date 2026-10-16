/// Fixtures of the Library tests: the design/05 numbers + tags (provider
/// overrides for the pixel captures) and a small real seed for the
/// live-data tests.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/items/library_counts.dart';
import 'package:focusflow/core/items/tag.dart';
import 'package:focusflow/features/library/presentation/providers/library_providers.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:focusflow/features/vault/presentation/vault_gate.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../helpers/test_container.dart';

/// 9:41 on a Friday, like the mockups' status bar.
final DateTime kLibraryNow = DateTime(2026, 6, 12, 9, 41);

/// The counts shown on design/05_library.png (113 items).
final LibraryCounts kMockupCounts = LibraryCounts(
  notesTotal: 48,
  notesPinned: 3,
  notesLastEditedAt: kLibraryNow.subtract(const Duration(hours: 2)),
  tasksTotal: 23,
  tasksOpen: 15,
  tasksDueToday: 7,
  tasksOverdue: 2,
  tasksDone: 8,
  remindersTotal: 12,
  remindersToday: 3,
  remindersNextAt: DateTime(2026, 6, 12, 10),
  habitsTotal: 6,
  habitsDoneToday: 2,
  habitsScheduledToday: 4,
  habitsBestStreak: 45,
  vaultTotal: 24,
  vaultWeak: 2,
  pinned: 9,
  favourites: 14,
  tags: 7,
  folders: 4,
  archived: 37,
  trash: 5,
);

/// The tag cloud of design/05.
const List<Tag> kMockupTags = [
  Tag(id: 't1', name: 'work', usageCount: 12),
  Tag(id: 't2', name: 'design', usageCount: 9),
  Tag(id: 't3', name: 'personal', usageCount: 8),
  Tag(id: 't4', name: 'finance', usageCount: 6),
  Tag(id: 't5', name: 'health', usageCount: 5),
  Tag(id: 't6', name: 'travel', usageCount: 4),
  Tag(id: 't7', name: 'ideas', usageCount: 3),
];

/// Test-controlled vault lock state.
final testVaultStatus = StateProvider<VaultStatus>((_) => VaultStatus.locked);

/// Vault state (always) + optionally the mockup numbers and tags.
List<Override> libraryOverrides({bool mockup = false}) => [
  vaultStatusProvider.overrideWith((ref) => ref.watch(testVaultStatus)),
  if (mockup) ...[
    libraryCountsProvider.overrideWith((ref) => Stream.value(kMockupCounts)),
    libraryTagsProvider.overrideWith((ref) => Stream.value(kMockupTags)),
  ],
];

/// Ids of [seedLibrary]'s items.
typedef LibrarySeed = ({
  String pinnedNote,
  String plainNote,
  String task,
  String workTag,
  String folder,
});

/// Two notes (one pinned + favourite, tagged #work, in folder "Ideas") and
/// one task due today tagged #work.
Future<LibrarySeed> seedLibrary(TestHarness h) async {
  final notes = h.read(notesRepositoryProvider);
  final tasks = h.read(tasksRepositoryProvider);
  final items = h.read(itemsRepositoryProvider);
  final folder = await h
      .read(foldersRepositoryProvider)
      .create(ItemType.note, 'Ideas');
  final pinned = await notes.createEmpty(
    title: 'Product launch plan',
    tagNames: ['work'],
    folderId: folder,
  );
  final plain = await notes.createEmpty(title: 'Grocery list');
  final ref = ItemRef(ItemType.note, pinned);
  await items.setPinned([ref], true);
  await items.setFavorite([ref], true);
  final task = await tasks.save(
    TaskItem(
      id: '',
      title: 'Send the invoice',
      dueDate: DateTime(2026, 6, 12),
      dueTimeMinutes: 17 * 60,
      createdAt: kLibraryNow,
      updatedAt: kLibraryNow,
    ),
  );
  await items.addTags([ItemRef(ItemType.task, task)], ['work']);
  final work = (await h.read(tagsRepositoryProvider).watchTags().first)
      .firstWhere((t) => t.name == 'work');
  return (
    pinnedNote: pinned,
    plainNote: plain,
    task: task,
    workTag: work.id,
    folder: folder,
  );
}
