/// ============================================================
/// SEARCH DAO — FTS5 queries behind Global search (screen 06)
/// ============================================================
///
/// One index-backed query per module over its external-content FTS5 table
/// (`notes_fts`, `tasks_fts` …, joined to the content table by rowid).
/// Ranking inputs (bm25, updated_at, is_pinned) are returned raw; the
/// repository blends them into the final score.
///
/// Privacy rules enforced here:
///   • locked notes match on the title only and never return a snippet;
///   • vault items are indexed by title only (vault_fts) — no secrets;
///   • trashed items are always excluded.
/// ============================================================
library;

import 'package:drift/drift.dart';
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/database/daos/dao_support.dart';
import 'package:focusflow/core/database/tables.dart';
import 'package:focusflow/core/items/item_type.dart';

part 'search_dao.g.dart';

/// Per-module SQL shape of a search query.
class _SearchSpec {
  const _SearchSpec({
    required this.fts,
    required this.table,
    required this.titleExpr,
    required this.metaExpr,
    required this.weights,
    this.snippetColumn,
    this.lockedExpr = '0',
    this.extraCols = '',
  });

  final String fts;
  final String table;
  final String titleExpr;
  final String metaExpr;
  final String weights;
  final int? snippetColumn;
  final String lockedExpr;
  final String extraCols;
}

@DriftAccessor(
  tables: [
    Notes,
    Tasks,
    Reminders,
    Habits,
    VaultItems,
    Folders,
    ItemTags,
    Tags,
  ],
)
class SearchDao extends DatabaseAccessor<AppDatabase> with _$SearchDaoMixin {
  SearchDao(super.attachedDatabase);

  static const Map<ItemType, _SearchSpec> _specs = {
    ItemType.note: _SearchSpec(
      fts: 'notes_fts',
      table: 'notes',
      titleExpr: 'x.title',
      metaExpr: "''",
      weights: '10.0, 1.0',
      snippetColumn: 1,
      lockedExpr: 'x.is_locked',
    ),
    ItemType.task: _SearchSpec(
      fts: 'tasks_fts',
      table: 'tasks',
      titleExpr: 'x.title',
      metaExpr: "''",
      weights: '10.0, 1.0',
      snippetColumn: 1,
      extraCols:
          ', x.priority AS priority, x.due_date AS due_date, '
          'x.due_time_minutes AS due_minutes, x.completed_at AS completed_at',
    ),
    ItemType.reminder: _SearchSpec(
      fts: 'reminders_fts',
      table: 'reminders',
      titleExpr: 'x.title',
      metaExpr: "''",
      weights: '10.0, 1.0',
      snippetColumn: 1,
      extraCols: ', COALESCE(x.snoozed_until, x.trigger_at) AS trigger_at',
    ),
    ItemType.habit: _SearchSpec(
      fts: 'habits_fts',
      table: 'habits',
      titleExpr: 'x.name',
      metaExpr: 'x.category',
      weights: '10.0, 2.0',
    ),
    ItemType.vault: _SearchSpec(
      fts: 'vault_fts',
      table: 'vault_items',
      titleExpr: 'x.title',
      metaExpr:
          "CASE x.item_type WHEN 1 THEN 'Card' WHEN 2 THEN 'Wi-Fi' "
          "WHEN 3 THEN 'Secure note' ELSE 'Login' END",
      weights: '1.0',
      lockedExpr: '1',
    ),
  };

  /// Filters shared by result and count queries (alias `x`).
  ({String sql, List<Variable> vars}) _filters(
    ItemType type, {
    required String match,
    String? titleOnlyMatch,
    required bool includeArchived,
    List<String> tagIds = const [],
    List<String> tagPrefixes = const [],
    DateTime? from,
    DateTime? to,
    int? minPriority,
  }) {
    final spec = _specs[type]!;
    final where = <String>[
      '${spec.fts} MATCH ?',
      'x.deleted_at IS NULL',
      if (!includeArchived) 'x.archived_at IS NULL',
    ];
    final vars = <Variable>[Variable.withString(match)];
    if (type == ItemType.note && titleOnlyMatch != null) {
      where.add(
        '(x.is_locked = 0 OR x.rowid IN (SELECT rowid FROM notes_fts '
        'WHERE notes_fts MATCH ?))',
      );
      vars.add(Variable.withString(titleOnlyMatch));
    }
    if (type == ItemType.reminder) {
      where.add(
        '(x.linked_item_id IS NULL OR x.linked_item_type IS NULL OR '
        "x.linked_item_type = 'reminder' OR "
        '${linkedItemActiveSql('x.linked_item_type', 'x.linked_item_id')})',
      );
    }
    for (final id in tagIds) {
      where.add(
        'EXISTS (SELECT 1 FROM item_tags it WHERE it.item_type = ? '
        'AND it.item_id = x.id AND it.tag_id = ?)',
      );
      vars
        ..add(Variable.withString(type.key))
        ..add(Variable.withString(id));
    }
    for (final prefix in tagPrefixes) {
      where.add(tagPrefixExists('x.id', type.key));
      vars.add(Variable.withString(likePrefix(prefix)));
    }
    if (from != null) {
      where.add('x.updated_at >= ?');
      vars.add(Variable<DateTime>(from));
    }
    if (to != null) {
      where.add('x.updated_at < ?');
      vars.add(Variable<DateTime>(to));
    }
    if (minPriority != null && type == ItemType.task) {
      where.add('x.priority >= ?');
      vars.add(Variable.withInt(minPriority));
    }
    return (sql: where.join(' AND '), vars: vars);
  }

  /// `EXISTS(tag on item whose name starts with ?)` — bind [likePrefix].
  static String tagPrefixExists(String idExpr, String typeKey) =>
      'EXISTS (SELECT 1 FROM item_tags it JOIN tags tg ON tg.id = it.tag_id '
      "WHERE it.item_type = '$typeKey' AND it.item_id = $idExpr "
      "AND tg.name LIKE ? ESCAPE '\\')";

  /// LIKE pattern for "starts with [prefix]" with %, _ and \ escaped.
  static String likePrefix(String prefix) => '${likeEscape(prefix)}%';

  /// Ranked rows of one module. Columns: id, title, meta, score (bm25,
  /// lower = better), snippet, is_pinned, is_locked, updated_at,
  /// archived_at, folder_name (+ module extras: priority, due_date,
  /// due_minutes, completed_at for tasks; trigger_at for reminders).
  Future<List<QueryRow>> search(
    ItemType type, {
    required String match,
    String? titleOnlyMatch,
    bool includeArchived = false,
    List<String> tagIds = const [],
    List<String> tagPrefixes = const [],
    DateTime? from,
    DateTime? to,
    int? minPriority,
    int limit = 50,
  }) {
    final spec = _specs[type]!;
    final f = _filters(
      type,
      match: match,
      titleOnlyMatch: titleOnlyMatch,
      includeArchived: includeArchived,
      tagIds: tagIds,
      tagPrefixes: tagPrefixes,
      from: from,
      to: to,
      minPriority: minPriority,
    );
    final snippet = spec.snippetColumn == null
        ? "''"
        : "CASE WHEN ${spec.lockedExpr} = 1 THEN '' ELSE "
              "snippet(${spec.fts}, ${spec.snippetColumn}, '', '', '…', 12) END";
    return customSelect(
      'SELECT x.id AS id, ${spec.titleExpr} AS title, ${spec.metaExpr} AS meta, '
      'bm25(${spec.fts}, ${spec.weights}) AS score, $snippet AS snippet, '
      'x.is_pinned AS is_pinned, ${spec.lockedExpr} AS is_locked, '
      'x.updated_at AS updated_at, x.archived_at AS archived_at, '
      'f.name AS folder_name${spec.extraCols} '
      'FROM ${spec.fts} JOIN ${spec.table} x ON x.rowid = ${spec.fts}.rowid '
      'LEFT JOIN folders f ON f.id = x.folder_id AND f.deleted_at IS NULL '
      'WHERE ${f.sql} ORDER BY score LIMIT ?',
      variables: [...f.vars, Variable.withInt(limit)],
      readsFrom: {attachedDatabase.itemTable(type), folders, itemTags, tags},
    ).get();
  }

  /// Number of matches of one module (same filters as [search]).
  Future<int> count(
    ItemType type, {
    required String match,
    String? titleOnlyMatch,
    bool includeArchived = false,
    List<String> tagIds = const [],
    List<String> tagPrefixes = const [],
    DateTime? from,
    DateTime? to,
    int? minPriority,
  }) async {
    final spec = _specs[type]!;
    final f = _filters(
      type,
      match: match,
      titleOnlyMatch: titleOnlyMatch,
      includeArchived: includeArchived,
      tagIds: tagIds,
      tagPrefixes: tagPrefixes,
      from: from,
      to: to,
      minPriority: minPriority,
    );
    final row = await customSelect(
      'SELECT COUNT(*) AS c FROM ${spec.fts} '
      'JOIN ${spec.table} x ON x.rowid = ${spec.fts}.rowid WHERE ${f.sql}',
      variables: f.vars,
      readsFrom: {attachedDatabase.itemTable(type), itemTags, tags},
    ).getSingle();
    return row.read<int>('c');
  }
}
