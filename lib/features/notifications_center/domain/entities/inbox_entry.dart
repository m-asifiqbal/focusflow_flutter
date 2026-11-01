/// ============================================================
/// INBOX ENTRY — one row of the Notification centre (screen 27)
/// ============================================================
///
/// Every fired local notification (and in-app events: backup done, weak
/// password found …) is written to the inbox so the user can see and act
/// on it later. [actions] are keys from [InboxActions] rendered as inline
/// buttons.
/// ============================================================
library;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:focusflow/core/items/item_type.dart';

/// Stored as [name] in `inbox_entries.kind`.
enum InboxKind {
  reminder,
  task,
  habit,
  medicine,
  prayer,
  security,
  sync,
  system;

  static InboxKind fromName(String? name) =>
      values.firstWhereOrNull((k) => k.name == name) ?? InboxKind.system;
}

/// Inline action keys (`inbox_entries.actions_json`).
abstract final class InboxActions {
  static const done = 'done';
  static const snooze = 'snooze';
  static const reschedule = 'reschedule';
  static const view = 'view';
  static const open = 'open';
  static const fix = 'fix';
  static const log = 'log';
}

@immutable
class InboxEntry {
  const InboxEntry({
    required this.id,
    required this.kind,
    required this.title,
    this.body = '',
    this.ref,
    this.route,
    this.actions = const [],
    required this.createdAt,
    this.readAt,
    this.dismissedAt,
  });

  final String id;
  final InboxKind kind;
  final String title;
  final String body;

  /// Item to open on tap (null for app-level events).
  final ItemRef? ref;

  /// Where Open goes when there is no [ref] (the notification's own route:
  /// morning briefing → Home, weekly report → Insights).
  final String? route;

  /// [InboxActions] keys, in display order.
  final List<String> actions;
  final DateTime createdAt;
  final DateTime? readAt;
  final DateTime? dismissedAt;

  bool get isRead => readAt != null;
  bool get isDismissed => dismissedAt != null;

  static const _eq = ListEquality<String>();

  @override
  bool operator ==(Object other) =>
      other is InboxEntry &&
      other.id == id &&
      other.kind == kind &&
      other.title == title &&
      other.body == body &&
      other.ref == ref &&
      other.route == route &&
      _eq.equals(other.actions, actions) &&
      other.createdAt == createdAt &&
      other.readAt == readAt &&
      other.dismissedAt == dismissedAt;

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    title,
    body,
    ref,
    route,
    _eq.hash(actions),
    createdAt,
    readAt,
    dismissedAt,
  );

  @override
  String toString() => 'InboxEntry(${kind.name}: $title)';
}
