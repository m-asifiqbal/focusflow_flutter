/// ============================================================
/// DAO SUPPORT — shared write stamping, SQL helpers, reactive queries
/// ============================================================
///
/// Every DAO uses these helpers so the sync rules hold everywhere:
///   • [WriteStamp] + [stampedUpdate]: every UPDATE of an item row sets
///     `updated_at = now`, `device_id = <this device>` and
///     `sync_version = sync_version + 1` (last-write-wins merge, core/sync).
///   • [ItemTablesX.itemTable]: ItemType → Drift table, for generic
///     lifecycle code (archive / trash / pin …) that works on any module.
///   • [ReactiveQueries.watchComputed]: a stream that recomputes an async
///     value whenever one of the given tables changes — used for screens
///     that combine several queries (lists + tags, library counts …).
///
/// Raw SQL in DAOs only ever interpolates *code constants* (table / column
/// names); user values always travel as bound [Variable]s.
/// ============================================================
library;

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/items/item_type.dart';

/// Who wrote and when — passed from repositories (which own the Clock and
/// device id) down to the DAOs.
class WriteStamp {
  const WriteStamp(this.now, this.deviceId);

  final DateTime now;
  final String deviceId;
}

/// Wraps an UPDATE companion with the sync bookkeeping columns of
/// [ItemColumns] tables (`updated_at`, `device_id`, `sync_version + 1`).
Insertable<T> stampedUpdate<T>(Insertable<T> changes, WriteStamp stamp) =>
    RawValuesInsertable<T>({
      ...changes.toColumns(false),
      'updated_at': Variable<DateTime>(stamp.now),
      'device_id': Variable<String>(stamp.deviceId),
      'sync_version': const CustomExpression<int>('sync_version + 1'),
    });

/// `?, ?, ?` for [count] bound variables.
String sqlPlaceholders(int count) => List.filled(count, '?').join(', ');

/// Escapes `\`, `%` and `_` for a `LIKE … ESCAPE '\'` pattern.
String likeEscape(String s) =>
    s.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');

/// `LIKE` pattern matching [s] anywhere (use with `ESCAPE '\'`).
String likeContains(String s) => '%${likeEscape(s)}%';

/// `alias.archived_at IS NULL AND alias.deleted_at IS NULL` — the Active
/// lifecycle condition.
String activeSql([String? alias]) {
  final p = alias == null ? '' : '$alias.';
  return '${p}archived_at IS NULL AND ${p}deleted_at IS NULL';
}

/// SQL CTE body listing every active, *visible* item as `(item_type, id)`;
/// use as `WITH active_items(item_type, id) AS ($activeItemsSql)`.
/// Reminders whose linked task / note is archived, trashed or gone are left
/// out (they are hidden everywhere — see [reminderLinkVisibleSql]).
final String activeItemsSql = AppDatabase.itemTables.entries
    .map(
      (e) =>
          "SELECT '${e.key}', x.id FROM ${e.value} x WHERE ${activeSql('x')}"
          "${e.key == 'reminder' ? ' AND ${reminderLinkVisibleSql('x')}' : ''}",
    )
    .join(' UNION ALL ');

/// SQL condition that is true when the item `(typeExpr, idExpr)` exists and
/// is active (used to hide reminders whose linked task / note is archived,
/// trashed or gone).
String linkedItemActiveSql(String typeExpr, String idExpr) {
  final parts = AppDatabase.itemTables.entries.map(
    (e) =>
        "($typeExpr = '${e.key}' AND EXISTS (SELECT 1 FROM ${e.value} li "
        'WHERE li.id = $idExpr AND ${activeSql('li')}))',
  );
  return '(${parts.join(' OR ')})';
}

/// SQL condition, over a reminders row (or a projection with the same
/// `linked_item_type` / `linked_item_id` columns) aliased [alias], that is
/// true when the reminder has no link or its linked item is active. Hidden
/// reminders never appear in lists, counts or collections ("archived items
/// never fire").
String reminderLinkVisibleSql(String alias) =>
    '($alias.linked_item_id IS NULL OR $alias.linked_item_type IS NULL OR '
    "$alias.linked_item_type = 'reminder' OR "
    '${linkedItemActiveSql('$alias.linked_item_type', '$alias.linked_item_id')})';

/// Fractional position between two neighbours (manual drag-to-reorder):
/// only the moved row is rewritten.
double sortBetween(double? before, double? after) {
  if (before == null && after == null) return 0;
  if (before == null) return after! - 1;
  if (after == null) return before + 1;
  return (before + after) / 2;
}

extension ItemTablesX on AppDatabase {
  /// The Drift table holding items of [type].
  TableInfo<Table, Object?> itemTable(ItemType type) => switch (type) {
    ItemType.note => notes,
    ItemType.task => tasks,
    ItemType.reminder => reminders,
    ItemType.habit => habits,
    ItemType.medicine => medicines,
    ItemType.vault => vaultItems,
  };

  /// SQL name of the table holding items of [type].
  String itemTableName(ItemType type) => AppDatabase.itemTables[type.key]!;

  /// All six item tables.
  Set<TableInfo<Table, Object?>> get allItemTables => {
    notes,
    tasks,
    reminders,
    habits,
    medicines,
    vaultItems,
  };
}

/// Live shared queries per database ([ReactiveQueries.watchComputed]'s
/// `shareKey`).
final Expando<Map<Object, Object>> _sharedQueries =
    Expando<Map<Object, Object>>('shared queries');

/// One running computation serving many listeners: the latest value is
/// replayed to a late listener, writes re-run it once for all, and it stops
/// (and forgets the value) when the last listener leaves.
class _SharedQuery<T> {
  _SharedQuery({required this.start, required this.release});

  final Stream<T> Function() start;
  final void Function() release;
  final List<MultiStreamController<T>> _listeners = [];
  StreamSubscription<T>? _upstream;
  bool _hasValue = false;
  T? _value;

  Stream<T> get stream => Stream<T>.multi((controller) {
    _listeners.add(controller);
    if (_hasValue) controller.add(_value as T);
    _upstream ??= start().listen(
      (value) {
        _hasValue = true;
        _value = value;
        for (final l in [..._listeners]) {
          l.add(value);
        }
      },
      onError: (Object error, StackTrace stack) {
        for (final l in [..._listeners]) {
          l.addError(error, stack);
        }
      },
    );
    controller.onCancel = () {
      _listeners.remove(controller);
      if (_listeners.isNotEmpty) return null;
      final upstream = _upstream;
      _upstream = null;
      _hasValue = false;
      _value = null;
      release();
      return upstream?.cancel();
    };
  }, isBroadcast: true);
}

extension ReactiveQueries on GeneratedDatabase {
  /// A stream that runs [compute] once on listen and again whenever any of
  /// [tables] is written (after the transaction commits). Bursts of writes
  /// are coalesced, and values deep-equal to the previous emission are
  /// skipped so Riverpod listeners don't rebuild needlessly.
  ///
  /// [shareKey] makes the stream *shared*: every caller that passes an equal
  /// key (a record naming the query and all its parameters) listens to one
  /// computation instead of running its own. Use it for expensive queries
  /// several screens show at once (Home, the library counts and the
  /// notification planner all read today's habits): each write then costs
  /// one recomputation, not one per subscriber.
  Stream<T> watchComputed<T>(
    Iterable<ResultSetImplementation<dynamic, dynamic>> tables,
    Future<T> Function() compute, {
    Object? shareKey,
  }) {
    if (shareKey != null) {
      final registry = _sharedQueries[this] ??= <Object, Object>{};
      final live = registry[shareKey];
      if (live != null) return (live as _SharedQuery<T>).stream;
      final watched = tables.toList();
      final shared = _SharedQuery<T>(
        start: () => watchComputed(watched, compute),
        release: () => registry.remove(shareKey),
      );
      registry[shareKey] = shared;
      return shared.stream;
    }
    const eq = DeepCollectionEquality();
    final query = TableUpdateQuery.onAllTables(tables);
    StreamSubscription<Set<TableUpdate>>? sub;
    var cancelled = false;
    var running = false;
    var dirty = false;
    var hasLast = false;
    T? last;
    late final StreamController<T> controller;

    Future<void> run() async {
      if (running) {
        dirty = true;
        return;
      }
      running = true;
      try {
        do {
          dirty = false;
          try {
            final value = await compute();
            if (cancelled) return;
            if (hasLast && eq.equals(last, value)) continue;
            last = value;
            hasLast = true;
            controller.add(value);
          } catch (e, s) {
            if (!cancelled) controller.addError(e, s);
          }
        } while (dirty && !cancelled);
      } finally {
        running = false;
      }
    }

    controller = StreamController<T>(
      onListen: () {
        sub = tableUpdates(query).listen((_) => run());
        run();
      },
      onPause: () => sub?.pause(),
      onResume: () => sub?.resume(),
      onCancel: () {
        cancelled = true;
        return sub?.cancel();
      },
    );
    return controller.stream;
  }
}
