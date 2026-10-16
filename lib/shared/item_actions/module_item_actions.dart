/// ============================================================
/// MODULE ITEM ACTIONS — the per-module rows of the item actions sheet
/// ============================================================
///
/// The shared sheet (item_actions_sheet.dart) builds the generic rows (pin,
/// favourite, duplicate, colour, tags/folder, reminder) and asks each module
/// for its own rows through ONE function per module, owned by that feature:
///
///   notes     features/notes/presentation/note_item_actions.dart
///   tasks     features/tasks/presentation/task_item_actions.dart
///   reminders features/reminders/presentation/reminder_item_actions.dart
///   habits    features/habits/presentation/habit_item_actions.dart
///   vault     features/vault/presentation/vault_item_actions.dart
///
/// Screen 09: Task → Complete, Change due date, Priority; Reminder →
/// Snooze, Disable; Habit → Log today, Pause; Vault → Copy username /
/// password; Note → Share/export, Lock with Vault PIN.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/widgets/ff_action_sheet.dart';

/// Rows a module adds around the generic ones.
@immutable
class ModuleItemActions {
  const ModuleItemActions({
    this.leading = const [],
    this.trailing = const [],
    this.readSafe = const [],
  });

  static const ModuleItemActions none = ModuleItemActions();

  /// Shown above the generic rows (e.g. Task › Complete).
  final List<FFActionItem> leading;

  /// Shown below the generic rows (e.g. Note › Lock with Vault PIN).
  final List<FFActionItem> trailing;

  /// The only module rows shown for an archived / trashed item: rows that
  /// don't edit it (e.g. Note › Share / export).
  final List<FFActionItem> readSafe;
}
