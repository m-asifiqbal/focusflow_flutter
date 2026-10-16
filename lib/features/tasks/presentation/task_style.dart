/// ============================================================
/// TASK STYLE — colours and icons of the tasks screens (10, 11)
/// ============================================================
///
/// What: priority colours (4 pt row bar, editor dots), the colour trio of
/// a list / tag pill ("WORK", "FINANCE"), the small icon of a task-list
/// chip ("Work" briefcase, "Personal" user) and the stat-tile tints.
/// Why: rows, chips, the editor and the board must agree; everything maps
/// onto existing theme trios (ModuleStyle / TagPalette / PriorityColors),
/// so dark mode and the accent colour work without new colours.
/// ============================================================
library;

import 'package:flutter/widgets.dart';
import 'package:focusflow/core/items/folder.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';

abstract final class TaskStyle {
  /// The Tasks module trio (check circles, progress bars, repeat icon).
  static final ModuleColors module = ModuleStyle.tasks.colors;

  /// Row bar / dot colour; null for no priority.
  static Color? priorityColor(TaskPriority p) => switch (p) {
    TaskPriority.high => PriorityColors.high,
    TaskPriority.medium => PriorityColors.medium,
    TaskPriority.low => PriorityColors.low,
    TaskPriority.none => null,
  };

  /// Pill colours for a list or tag called [name] with an optional stored
  /// `RRGGBB` [hex] (named palette entries first, e.g. Work → blue).
  static ModuleColors labelColors(String name, {String? hex}) {
    final color = parseHex(hex);
    if (color == null) return TagPalette.forName(name);
    final hsl = HSLColor.fromColor(color);
    return ModuleColors(
      solid: color,
      soft: hsl.withLightness(0.93).toColor(),
      ink: hsl.withLightness(0.32).toColor(),
    );
  }

  /// Chip icon of a task list: by its stored icon key, else by name.
  static IconData listIcon(Folder list) =>
      _icons[list.iconKey] ?? _icons[list.name.toLowerCase().trim()] ?? _list;

  static const IconData _list = FontAwesomeIcons.solidFolder;

  static const Map<String?, IconData> _icons = {
    'work': FontAwesomeIcons.briefcase,
    'briefcase': FontAwesomeIcons.briefcase,
    'personal': FontAwesomeIcons.solidUser,
    'user': FontAwesomeIcons.solidUser,
    'home': FontAwesomeIcons.house,
    'house': FontAwesomeIcons.house,
    'shopping': FontAwesomeIcons.cartShopping,
    'groceries': FontAwesomeIcons.cartShopping,
    'health': FontAwesomeIcons.solidHeart,
    'fitness': FontAwesomeIcons.dumbbell,
    'finance': FontAwesomeIcons.wallet,
    'money': FontAwesomeIcons.wallet,
    'study': FontAwesomeIcons.graduationCap,
    'school': FontAwesomeIcons.graduationCap,
    'travel': FontAwesomeIcons.plane,
    'design': FontAwesomeIcons.palette,
    'ideas': FontAwesomeIcons.solidLightbulb,
  };

  /// Stat-tile tints (Today blue · Overdue red · Upcoming primary · Done slate).
  static final ModuleColors todayTile = module;
  static const ModuleColors overdueTile = TagPalette.high;
  static const ModuleColors doneTile = ModuleColors(
    solid: AppPalette.slate500,
    soft: AppPalette.slate200,
    ink: AppPalette.slate600,
  );
}
