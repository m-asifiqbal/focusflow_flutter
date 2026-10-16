/// ============================================================
/// VAULT DAO — `vault_items`, `vault_history`, `generator_history`
/// ============================================================
///
/// Ciphertext only: this layer never sees a plaintext secret. The payload,
/// history passwords and generator values are opaque AES-GCM blobs written
/// by the vault crypto service (features/vault).
/// ============================================================
library;

import 'package:drift/drift.dart';
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/database/daos/dao_support.dart';
import 'package:focusflow/core/database/tables.dart';

part 'vault_dao.g.dart';

/// A vault row plus its folder name.
typedef VaultListRow = ({VaultItemRow row, String? folderName});

@DriftAccessor(
  tables: [VaultItems, VaultHistory, GeneratorHistory, Folders, ItemTags, Tags],
)
class VaultDao extends DatabaseAccessor<AppDatabase> with _$VaultDaoMixin {
  VaultDao(super.attachedDatabase);

  static const _select =
      'SELECT v.*, f.name AS folder_name FROM vault_items v '
      'LEFT JOIN folders f ON f.id = v.folder_id AND f.deleted_at IS NULL';

  VaultListRow _map(QueryRow r) => (
    row: vaultItems.map(r.data),
    folderName: r.readNullable<String>('folder_name'),
  );

  /// Items matching [where] (SQL over alias `v`, bound [variables]).
  Selectable<VaultListRow> queryItems({
    required String where,
    List<Variable> variables = const [],
    String orderBy = 'v.title COLLATE NOCASE ASC',
  }) => customSelect(
    '$_select WHERE $where ORDER BY v.is_pinned DESC, $orderBy',
    variables: variables,
    readsFrom: {vaultItems, folders, itemTags},
  ).map(_map);

  Selectable<VaultListRow> itemById(String id) => customSelect(
    '$_select WHERE v.id = ?',
    variables: [Variable.withString(id)],
    readsFrom: {vaultItems, folders},
  ).map(_map);

  Future<VaultItemRow?> rowById(String id) =>
      (select(vaultItems)..where((v) => v.id.equals(id))).getSingleOrNull();

  Future<void> insertItem(VaultItemsCompanion row) =>
      into(vaultItems).insert(row);

  /// Stamped update (updated_at, device_id, sync_version + 1).
  Future<int> updateItem(
    String id,
    VaultItemsCompanion changes,
    WriteStamp stamp,
  ) => (update(
    vaultItems,
  )..where((v) => v.id.equals(id))).write(stampedUpdate(changes, stamp));

  Future<double?> maxSortOrder() {
    final max = vaultItems.sortOrder.max();
    return (selectOnly(
      vaultItems,
    )..addColumns([max])).map((r) => r.read(max)).getSingle();
  }

  /// Active item counts per `item_type` code + favourites / weak /
  /// breached / with-TOTP.
  Selectable<QueryRow> counts() => customSelect(
    'SELECT COUNT(*) AS total, '
    'COALESCE(SUM(CASE WHEN item_type = 0 THEN 1 ELSE 0 END), 0) AS logins, '
    'COALESCE(SUM(CASE WHEN item_type = 1 THEN 1 ELSE 0 END), 0) AS cards, '
    'COALESCE(SUM(CASE WHEN item_type = 2 THEN 1 ELSE 0 END), 0) AS wifi, '
    'COALESCE(SUM(CASE WHEN item_type = 3 THEN 1 ELSE 0 END), 0) AS notes, '
    'COALESCE(SUM(CASE WHEN is_favorite = 1 THEN 1 ELSE 0 END), 0) AS favourites, '
    'COALESCE(SUM(CASE WHEN password_strength IS NOT NULL AND password_strength <= 1 THEN 1 ELSE 0 END), 0) AS weak, '
    'COALESCE(SUM(CASE WHEN breach_count > 0 THEN 1 ELSE 0 END), 0) AS breached, '
    'COALESCE(SUM(CASE WHEN has_totp = 1 THEN 1 ELSE 0 END), 0) AS totp '
    'FROM vault_items WHERE ${activeSql()}',
    readsFrom: {vaultItems},
  );

  // ───────────────────────────── History ──────────────────────────────

  Future<void> insertHistory(VaultHistoryCompanion row) =>
      into(vaultHistory).insert(row);

  /// Previous passwords of [itemId], newest first.
  Stream<List<VaultHistoryRow>> watchHistory(String itemId) =>
      (select(vaultHistory)
            ..where((h) => h.itemId.equals(itemId))
            ..orderBy([(h) => OrderingTerm.desc(h.changedAt)]))
          .watch();

  Future<int> deleteHistoryOf(Iterable<String> itemIds) =>
      (delete(vaultHistory)..where((h) => h.itemId.isIn(itemIds))).go();

  // ──────────────────────── Generator history ─────────────────────────

  Future<void> insertGenerated(GeneratorHistoryCompanion row) =>
      into(generatorHistory).insert(row);

  /// Newest first.
  SimpleSelectStatement<$GeneratorHistoryTable, GeneratorHistoryRow>
  generatedQuery() => select(generatorHistory)
    ..orderBy([
      (g) => OrderingTerm.desc(g.createdAt),
      (g) => OrderingTerm.desc(g.rowId),
    ]);

  /// Keeps only the newest [keep] generator entries.
  Future<int> pruneGenerated(int keep) => customUpdate(
    'DELETE FROM generator_history WHERE rowid NOT IN (SELECT rowid FROM '
    'generator_history ORDER BY created_at DESC, rowid DESC LIMIT ?)',
    variables: [Variable.withInt(keep)],
    updates: {generatorHistory},
    updateKind: UpdateKind.delete,
  );

  Future<int> clearGenerated() => delete(generatorHistory).go();
}
