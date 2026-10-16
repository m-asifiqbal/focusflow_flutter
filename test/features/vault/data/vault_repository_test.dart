/// VaultRepository — breach results are cached without touching
/// `updated_at` (the "Recent" order must not change), but still carry the
/// sync bookkeeping; allItemIds covers every lifecycle state.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/database/daos/vault_dao.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_record.dart';
import 'package:focusflow/features/vault/domain/repository/vault_repository.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/test_container.dart';

void main() {
  late TestHarness h;
  late VaultRepository vault;
  final t0 = DateTime(2026, 6, 13, 9);

  VaultItemRecord draft(String title) => VaultItemRecord(
    id: '',
    type: VaultItemType.login,
    title: title,
    encryptedPayload: Uint8List.fromList([1, 2, 3]),
    createdAt: t0,
    updatedAt: t0,
  );

  setUp(() async {
    h = await TestHarness.create(now: t0);
    vault = h.read(vaultRepositoryProvider);
  });

  tearDown(() => h.dispose());

  test('updateBreachResult keeps updated_at and the Recent order', () async {
    final older = await vault.save(draft('Older'));
    h.clock.advance(const Duration(hours: 1));
    final newer = await vault.save(draft('Newer'));
    const recent = VaultQuery(sort: VaultSort.recent);
    expect((await vault.watchItems(recent).first).map((r) => r.id), [
      newer,
      older,
    ]);
    final before = (await vault.getItem(older))!;
    final versionBefore = (await VaultDao(h.db).rowById(older))!.syncVersion;

    h.clock.advance(const Duration(hours: 1));
    await vault.updateBreachResult(older, 42, h.clock.now());

    final after = (await vault.getItem(older))!;
    expect(after.breachCount, 42);
    expect(after.breachCheckedAt, isNotNull);
    expect(after.updatedAt, before.updatedAt);
    expect(
      (await VaultDao(h.db).rowById(older))!.syncVersion,
      versionBefore + 1,
    );
    expect((await vault.watchItems(recent).first).map((r) => r.id), [
      newer,
      older,
    ]);
  });

  test('allItemIds includes archived and trashed items', () async {
    final a = await vault.save(draft('A'));
    final b = await vault.save(draft('B'));
    final c = await vault.save(draft('C'));
    final items = h.read(itemsRepositoryProvider);
    await items.archive([ItemRef(ItemType.vault, b)]);
    await items.moveToTrash([ItemRef(ItemType.vault, c)]);
    expect((await vault.allItemIds()).toSet(), {a, b, c});
    expect((await vault.getAll()).map((r) => r.id), [a]);
  });
}
