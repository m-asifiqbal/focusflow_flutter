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
import 'package:focusflow/core/l10n/tr.dart';

enum ItemType {
  note('note'),
  task('task'),
  reminder('reminder'),
  habit('habit'),
  vault('vault');

  const ItemType(this.key);

  /// Stable storage / deep-link key (`item_tags.item_type`, `focusflow://item/{key}/{id}`).
  final String key;

  /// Singular label ("Note") in the active language. A getter, not a field,
  /// so it follows a language switch.
  String get label => switch (this) {
    note => tr('Note'),
    task => tr('Task'),
    reminder => tr('Reminder'),
    habit => tr('Habit'),
    vault => tr('Password'),
  };

  /// Module name ("Notes") in the active language.
  String get plural => switch (this) {
    note => tr('Notes'),
    task => tr('Tasks'),
    reminder => tr('Reminders'),
    habit => tr('Habits'),
    vault => tr('Vault'),
  };

  /// Lower-case singular for the middle of a sentence ("note"). Its own
  /// texts, not `label.toLowerCase()`: case rules differ between languages.
  String get noun => switch (this) {
    note => tr('note'),
    task => tr('task'),
    reminder => tr('reminder'),
    habit => tr('habit'),
    vault => tr('password'),
  };

  /// Lower-case plural for the middle of a sentence ("notes"). The vault
  /// reads "vault", as it always has ("3 vault archived").
  String get nouns => switch (this) {
    note => tr('notes'),
    task => tr('tasks'),
    reminder => tr('reminders'),
    habit => tr('habits'),
    vault => tr('vault'),
  };

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
