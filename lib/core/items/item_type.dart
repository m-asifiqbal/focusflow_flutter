/// ============================================================
/// ITEM TYPE — the shared kernel every module plugs into
/// ============================================================
///
/// The five "spaces" share one lifecycle (Active → Archive → Recently
/// Deleted → purged) and one set of list behaviours (pin, favourite, colour,
/// folder, tags, swipe, long-press sheet, multi-select). [ItemType] + [ItemRef]
/// let shared screens (Library, Archive, Trash, Search, Calendar, the item
/// actions sheet) address any item without knowing its module.
/// ============================================================
library;

import 'package:flutter/foundation.dart';

enum ItemType {
  note('note', 'Note', 'Notes'),
  task('task', 'Task', 'Tasks'),
  reminder('reminder', 'Reminder', 'Reminders'),
  habit('habit', 'Habit', 'Habits'),
  vault('vault', 'Password', 'Vault');

  const ItemType(this.key, this.label, this.plural);

  /// Stable storage / deep-link key (`item_tags.item_type`, `focusflow://item/{key}/{id}`).
  final String key;

  /// Singular label ("Note").
  final String label;

  /// Module name ("Notes").
  final String plural;

  static ItemType? fromKey(String? key) {
    for (final t in values) {
      if (t.key == key) return t;
    }
    return null;
  }
}

/// A typed pointer to one item in any module.
@immutable
class ItemRef {
  const ItemRef(this.type, this.id);

  final ItemType type;
  final String id;

  @override
  bool operator ==(Object other) =>
      other is ItemRef && other.type == type && other.id == id;

  @override
  int get hashCode => Object.hash(type, id);

  @override
  String toString() => 'ItemRef(${type.key}/$id)';
}
