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
import 'package:focusflow/core/l10n/tr.dart';
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
    InboxKind.reminder => tr('Reminder'),
    InboxKind.task => tr('Task'),
    InboxKind.habit => tr('Habit'),
    InboxKind.security => tr('Security'),
    InboxKind.sync => tr('Sync'),
    InboxKind.system => AppInfo.name,
  };
}

/// The filter chips in order (null = All); a getter so the labels follow the
/// active language.
List<(InboxKind?, String)> get inboxFilters => [
  (null, tr('All')),
  (InboxKind.reminder, tr('Reminders')),
  (InboxKind.task, tr('Tasks')),
  (InboxKind.habit, tr('Habits')),
  (InboxKind.security, tr('Security')),
  (InboxKind.sync, tr('Sync')),
];
