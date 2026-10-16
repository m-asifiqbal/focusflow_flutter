/// NotesRepository.watchCreatedInRange — creation instants of active notes
/// in [from, to), oldest first.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/test_container.dart';

void main() {
  late TestHarness h;
  final now = DateTime(2026, 10, 15, 9);

  setUp(() async => h = await TestHarness.create(now: now));
  tearDown(() => h.dispose());

  Future<String> createAt(DateTime at) {
    h.clock.set(at);
    return h.read(notesRepositoryProvider).createEmpty(title: 'Note $at');
  }

  test('active notes created in [from, to), oldest first', () async {
    final from = DateTime(2026, 10, 9);
    final to = DateTime(2026, 10, 16);
    await createAt(DateTime(2026, 10, 8, 23, 59));
    await createAt(DateTime(2026, 10, 14, 7));
    await createAt(from);
    await createAt(to);
    final trashed = await createAt(DateTime(2026, 10, 12));
    await h.read(itemsRepositoryProvider).moveToTrash([
      ItemRef(ItemType.note, trashed),
    ]);

    final created = await h
        .read(notesRepositoryProvider)
        .watchCreatedInRange(from, to)
        .first;
    expect(created, [from, DateTime(2026, 10, 14, 7)]);
  });
}
