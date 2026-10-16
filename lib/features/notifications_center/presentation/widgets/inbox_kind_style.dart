/// ============================================================
/// INBOX KIND STYLE — icon tile + filter chip label per inbox kind
/// ============================================================
///
/// What: the module tile of a notification row (bell for reminders, double
/// check for tasks, repeat for habits, shield for security, cloud for
/// sync) and the filter chip labels of screen 27.
/// Why: one mapping so rows and chips never disagree; colours come from
/// [ModuleStyle] / palette tokens, never literals.
/// ============================================================
library;

import 'package:flutter/widgets.dart';
import 'package:focusflow/core/constants/app_info.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/features/notifications_center/domain/entities/inbox_entry.dart';

/// Visual identity of an [InboxKind].
extension InboxKindStyle on InboxKind {
  /// Tile colours (soft fill + solid glyph).
  ModuleColors get colors => switch (this) {
    InboxKind.reminder => ModuleStyle.reminders.colors,
    InboxKind.task => ModuleStyle.tasks.colors,
    InboxKind.habit => ModuleStyle.habits.colors,
    InboxKind.security => ModuleStyle.vault.colors,
    InboxKind.sync => TagPalette.travel,
    InboxKind.system => ModuleStyle.notes.colors,
  };

  /// Tile glyph.
  IconData get icon => switch (this) {
    InboxKind.reminder => FontAwesomeIcons.solidBell,
    InboxKind.task => FontAwesomeIcons.checkDouble,
    InboxKind.habit => FontAwesomeIcons.repeat,
    InboxKind.security => FontAwesomeIcons.shieldHalved,
    InboxKind.sync => FontAwesomeIcons.cloudArrowUp,
    InboxKind.system => FontAwesomeIcons.solidBell,
  };

  /// Spoken name of the tile ("Reminder notification").
  String get label => switch (this) {
    InboxKind.reminder => 'Reminder',
    InboxKind.task => 'Task',
    InboxKind.habit => 'Habit',
    InboxKind.security => 'Security',
    InboxKind.sync => 'Sync',
    InboxKind.system => AppInfo.name,
  };
}

/// The filter chips in order (null = All).
const List<(InboxKind?, String)> inboxFilters = [
  (null, 'All'),
  (InboxKind.reminder, 'Reminders'),
  (InboxKind.task, 'Tasks'),
  (InboxKind.habit, 'Habits'),
  (InboxKind.security, 'Security'),
  (InboxKind.sync, 'Sync'),
];
