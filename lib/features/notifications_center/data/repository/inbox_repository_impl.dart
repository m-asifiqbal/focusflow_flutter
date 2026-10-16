/// ============================================================
/// INBOX REPOSITORY (Drift implementation)
/// ============================================================
library;

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/database/daos/inbox_dao.dart';
import 'package:focusflow/core/items/data/repository_base.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/features/notifications_center/domain/entities/inbox_entry.dart';
import 'package:focusflow/features/notifications_center/domain/repository/inbox_repository.dart';

class InboxRepositoryImpl extends RepositoryBase implements InboxRepository {
  InboxRepositoryImpl({
    required super.db,
    required super.clock,
    required super.deviceId,
    required super.newId,
  }) : _dao = InboxDao(db);

  final InboxDao _dao;

  static List<String> _actions(String json) {
    try {
      final list = jsonDecode(json);
      return list is List
          ? List.unmodifiable(list.whereType<String>())
          : const [];
    } on FormatException {
      return const [];
    }
  }

  static InboxEntry _map(InboxRow r) {
    final type = ItemType.fromKey(r.itemType);
    return InboxEntry(
      id: r.id,
      kind: InboxKind.fromName(r.kind),
      title: r.title,
      body: r.body,
      ref: type == null || r.itemId == null ? null : ItemRef(type, r.itemId!),
      actions: _actions(r.actionsJson),
      createdAt: r.createdAt,
      readAt: r.readAt,
      dismissedAt: r.dismissedAt,
    );
  }

  @override
  Future<String> add({
    required InboxKind kind,
    required String title,
    String body = '',
    ItemRef? ref,
    List<String> actions = const [],
    DateTime? at,
  }) async {
    if (at != null) {
      // A delivery at a given time is recorded once (idempotent).
      final same = await _dao.findSame(
        kind: kind.name,
        title: title,
        itemType: ref?.type.key,
        itemId: ref?.id,
        createdAt: at,
      );
      if (same != null) return same.id;
    }
    final id = newId();
    await _dao.insertEntry(
      InboxEntriesCompanion.insert(
        id: id,
        kind: kind.name,
        title: title,
        body: Value(body),
        itemId: Value(ref?.id),
        itemType: Value(ref?.type.key),
        actionsJson: Value(jsonEncode(actions)),
        createdAt: at ?? now(),
      ),
    );
    return id;
  }

  @override
  Stream<List<InboxEntry>> watch({InboxKind? kind}) => _dao
      .watchEntries(kind: kind?.name)
      .map((rows) => List<InboxEntry>.unmodifiable(rows.map(_map)));

  @override
  Stream<int> watchUnreadCount() => _dao.watchUnreadCount().distinct();

  @override
  Future<void> markRead(String id) =>
      _dao.updateEntry(id, InboxEntriesCompanion(readAt: Value(now())));

  @override
  Future<void> markAllRead({InboxKind? kind}) =>
      _dao.markAllRead(now(), kind: kind?.name);

  @override
  Future<void> dismiss(String id) =>
      _dao.updateEntry(id, InboxEntriesCompanion(dismissedAt: Value(now())));

  @override
  Future<void> undismiss(String id) => _dao.updateEntry(
    id,
    const InboxEntriesCompanion(dismissedAt: Value(null)),
  );

  @override
  Future<int> clearOlderThan(Duration age) =>
      _dao.deleteOlderThan(now().subtract(age));
}
