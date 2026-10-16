/// ============================================================
/// VAULT REPOSITORY (Drift implementation) — ciphertext only
/// ============================================================
///
/// Maps `vault_items` rows to [VaultItemRecord]s. Blobs pass through
/// untouched; nothing here can decrypt them. The title filter is a LIKE on
/// the plaintext title column (vault lists are small; global search uses
/// `vault_fts`, also title-only).
/// ============================================================
library;

import 'package:drift/drift.dart';
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/database/daos/dao_support.dart';
import 'package:focusflow/core/database/daos/organisation_dao.dart';
import 'package:focusflow/core/database/daos/vault_dao.dart';
import 'package:focusflow/core/items/data/item_mappers.dart';
import 'package:focusflow/core/items/data/repository_base.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/items/tag.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_record.dart';
import 'package:focusflow/features/vault/domain/repository/vault_repository.dart';

class VaultRepositoryImpl extends RepositoryBase implements VaultRepository {
  VaultRepositoryImpl({
    required super.db,
    required super.clock,
    required super.deviceId,
    required super.newId,
  }) : _dao = VaultDao(db),
       _org = OrganisationDao(db),
       _tags = TagWriter(OrganisationDao(db), newId);

  /// Generator history size.
  static const int generatorHistoryLimit = 10;

  final VaultDao _dao;
  final OrganisationDao _org;
  final TagWriter _tags;

  Set<ResultSetImplementation<dynamic, dynamic>> get _tables => {
    db.vaultItems,
    db.folders,
    db.itemTags,
    db.tags,
  };

  static VaultItemRecord _map(VaultListRow r, List<Tag> tags) {
    final v = r.row;
    return VaultItemRecord(
      id: v.id,
      type: VaultItemType.fromValue(v.itemType),
      title: v.title,
      iconKey: v.iconKey,
      colorHex: v.colorHex,
      folderId: v.folderId,
      folderName: r.folderName,
      tags: tags,
      encryptedPayload: v.encryptedPayload,
      passwordStrength: v.passwordStrength,
      passwordUpdatedAt: v.passwordUpdatedAt,
      passwordFingerprint: v.passwordFingerprint,
      breachCount: v.breachCount,
      breachCheckedAt: v.breachCheckedAt,
      hasTotp: v.hasTotp,
      expiryDays: v.expiryDays,
      isFavorite: v.isFavorite,
      isPinned: v.isPinned,
      sortOrder: v.sortOrder,
      createdAt: v.createdAt,
      updatedAt: v.updatedAt,
      archivedAt: v.archivedAt,
      deletedAt: v.deletedAt,
    );
  }

  static VaultItemsCompanion _content(VaultItemRecord r) => VaultItemsCompanion(
    itemType: Value(r.type.index),
    title: Value(r.title.trim()),
    iconKey: Value(r.iconKey),
    colorHex: Value(r.colorHex),
    folderId: Value(r.folderId),
    encryptedPayload: Value(r.encryptedPayload),
    passwordStrength: Value(r.passwordStrength),
    passwordUpdatedAt: Value(r.passwordUpdatedAt),
    passwordFingerprint: Value(r.passwordFingerprint),
    breachCount: Value(r.breachCount),
    breachCheckedAt: Value(r.breachCheckedAt),
    hasTotp: Value(r.hasTotp),
    expiryDays: Value(r.expiryDays),
    isFavorite: Value(r.isFavorite),
    isPinned: Value(r.isPinned),
  );

  Future<List<VaultItemRecord>> _load(
    String where,
    List<Variable> vars, {
    String orderBy = 'v.title COLLATE NOCASE ASC',
  }) async {
    final rows = await _dao
        .queryItems(where: where, variables: vars, orderBy: orderBy)
        .get();
    if (rows.isEmpty) return const [];
    final tags = await _org.tagsByItem(
      ItemType.vault,
      itemIds: rows.map((r) => r.row.id),
    );
    return [for (final r in rows) _map(r, ItemMappers.tags(tags[r.row.id]))];
  }

  @override
  Stream<List<VaultItemRecord>> watchItems(VaultQuery query) =>
      db.watchComputed(_tables, () {
        final where = <String>[activeSql('v')];
        final vars = <Variable>[];
        if (query.type != null) {
          where.add('v.item_type = ?');
          vars.add(Variable.withInt(query.type!.index));
        }
        if (query.folderId != null) {
          where.add('v.folder_id = ?');
          vars.add(Variable.withString(query.folderId!));
        }
        if (query.favouritesOnly) where.add('v.is_favorite = 1');
        final text = query.text.trim();
        if (text.isNotEmpty) {
          where.add(r"v.title LIKE ? ESCAPE '\'");
          vars.add(Variable.withString(likeContains(text)));
        }
        return _load(
          where.join(' AND '),
          vars,
          orderBy: query.sort == VaultSort.recent
              ? 'v.updated_at DESC'
              : 'v.title COLLATE NOCASE ASC',
        );
      });

  @override
  Stream<VaultItemRecord?> watchItem(String id) =>
      db.watchComputed(_tables, () => getItem(id));

  @override
  Future<VaultItemRecord?> getItem(String id) async {
    final list = await _load('v.id = ?', [Variable.withString(id)]);
    return list.isEmpty ? null : list.first;
  }

  @override
  Future<List<VaultItemRecord>> getAll() => _load(activeSql('v'), const []);

  @override
  Future<String> save(VaultItemRecord record) => db.transaction(() async {
    final s = stamp();
    var id = record.id;
    final existing = id.isEmpty ? null : await _dao.rowById(id);
    if (existing == null) {
      if (id.isEmpty) id = newId();
      await _dao.insertItem(
        _content(record).copyWith(
          id: Value(id),
          createdAt: Value(s.now),
          updatedAt: Value(s.now),
          sortOrder: Value(((await _dao.maxSortOrder()) ?? 0) + 1),
          syncVersion: const Value(1),
          deviceId: Value(deviceId),
        ),
      );
    } else {
      await _dao.updateItem(id, _content(record), s);
    }
    await _tags.replaceTags(
      ItemType.vault,
      id,
      record.tags.map((t) => t.name),
      s,
    );
    return id;
  });

  @override
  Future<void> addHistory(String itemId, Uint8List encryptedPassword) =>
      _dao.insertHistory(
        VaultHistoryCompanion.insert(
          id: newId(),
          itemId: itemId,
          encryptedPassword: encryptedPassword,
          changedAt: now(),
        ),
      );

  @override
  Stream<List<VaultHistoryEntry>> watchHistory(String itemId) => _dao
      .watchHistory(itemId)
      .map(
        (rows) => [
          for (final h in rows)
            VaultHistoryEntry(
              id: h.id,
              itemId: h.itemId,
              encryptedPassword: h.encryptedPassword,
              changedAt: h.changedAt,
            ),
        ],
      );

  @override
  Stream<VaultCounts> watchCounts() => _dao
      .counts()
      .watchSingle()
      .map(
        (r) => VaultCounts(
          total: r.read<int>('total'),
          byType: {
            VaultItemType.login: r.read<int>('logins'),
            VaultItemType.card: r.read<int>('cards'),
            VaultItemType.wifi: r.read<int>('wifi'),
            VaultItemType.secureNote: r.read<int>('notes'),
          },
          favourites: r.read<int>('favourites'),
          weak: r.read<int>('weak'),
          breached: r.read<int>('breached'),
          withTotp: r.read<int>('totp'),
        ),
      )
      .distinct();

  /// Deliberately NOT a stamped update: a breach check is derived cache,
  /// not an edit, so `updated_at` stays put (the "Recent" sort must not
  /// reorder after a background check). `device_id` + `sync_version` still
  /// move so the cached result travels with the next sync.
  @override
  Future<void> updateBreachResult(String id, int count, DateTime checkedAt) =>
      (db.update(db.vaultItems)..where((v) => v.id.equals(id))).write(
        RawValuesInsertable<VaultItemRow>({
          'breach_count': Variable<int>(count),
          'breach_checked_at': Variable<DateTime>(
            RepositoryBase.truncateToSeconds(checkedAt),
          ),
          'device_id': Variable<String>(deviceId),
          'sync_version': const CustomExpression<int>('sync_version + 1'),
        }),
      );

  @override
  Future<List<String>> allItemIds() async {
    final rows =
        await (db.selectOnly(db.vaultItems)..addColumns([db.vaultItems.id]))
            .map((r) => r.read(db.vaultItems.id)!)
            .get();
    return rows;
  }

  @override
  Future<void> addGeneratorEntry(
    Uint8List encryptedValue, {
    String mode = 'password',
    int entropyBits = 0,
  }) => db.transaction(() async {
    await _dao.insertGenerated(
      GeneratorHistoryCompanion.insert(
        id: newId(),
        encryptedValue: encryptedValue,
        mode: Value(mode),
        entropyBits: Value(entropyBits),
        createdAt: now(),
      ),
    );
    await _dao.pruneGenerated(generatorHistoryLimit);
  });

  @override
  Stream<List<GeneratedSecret>> watchGeneratorHistory() =>
      _dao.generatedQuery().watch().map(
        (rows) => [
          for (final g in rows)
            GeneratedSecret(
              id: g.id,
              encryptedValue: g.encryptedValue,
              mode: g.mode,
              entropyBits: g.entropyBits,
              createdAt: g.createdAt,
            ),
        ],
      );

  @override
  Future<void> clearGeneratorHistory() => _dao.clearGenerated();

  @override
  Future<void> deleteLocallyOnly(
    List<String> ids,
    Future<void> Function() delete,
  ) => db.transaction(() async {
    await delete();
    if (ids.isEmpty) return;
    // The AFTER DELETE triggers (sync_tombstones.dart) just recorded these.
    await db.customUpdate(
      "DELETE FROM tombstones WHERE entity = 'vault' AND entity_id IN "
      '(${sqlPlaceholders(ids.length)})',
      variables: ids.map(Variable.withString).toList(),
      updates: {db.tombstones},
      updateKind: UpdateKind.delete,
    );
  });
}
