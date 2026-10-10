/// ============================================================
/// MODULE STYLE — one colour + one Font Awesome icon per module
/// ============================================================
///
/// | Module     | Solid   | Soft    | Ink     | FA icon        |
/// |------------|---------|---------|---------|----------------|
/// | Notes      | #10B981 | #D1FAE5 | #047857 | note-sticky    |
/// | Tasks      | #3B82F6 | #DBEAFE | #1D4ED8 | check-double   |
/// | Reminders  | #F97316 | #FFEDD5 | #C2410C | bell           |
/// | Habits     | #6366F1 | #E0E7FF | #4338CA | repeat         |
/// | Vault      | #F59E0B | #FEF3C7 | #B45309 | shield-halved  |
/// | Quick Scan | #F43F5E | #FFE4E6 | #BE123C | camera         |
/// ============================================================
library;

import 'package:flutter/widgets.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

enum AppModule {
  notes,
  tasks,
  reminders,
  habits,
  vault,
  scan;

  static AppModule fromItemType(ItemType type) => switch (type) {
    ItemType.note => AppModule.notes,
    ItemType.task => AppModule.tasks,
    ItemType.reminder => AppModule.reminders,
    ItemType.habit => AppModule.habits,
    ItemType.vault => AppModule.vault,
  };
}

@immutable
class ModuleStyle {
  const ModuleStyle._(this.colors, this.icon);

  final ModuleColors colors;
  final IconData icon;

  Color get solid => colors.solid;
  Color get soft => colors.soft;
  Color get ink => colors.ink;

  static const notes = ModuleStyle._(
    ModuleColors(
      solid: AppPalette.emerald500,
      soft: AppPalette.emerald100,
      ink: AppPalette.emerald700,
    ),
    FontAwesomeIcons.solidNoteSticky,
  );
  static const tasks = ModuleStyle._(
    ModuleColors(
      solid: AppPalette.blue500,
      soft: AppPalette.blue100,
      ink: AppPalette.blue700,
    ),
    FontAwesomeIcons.checkDouble,
  );
  static const reminders = ModuleStyle._(
    ModuleColors(
      solid: AppPalette.orange500,
      soft: AppPalette.orange100,
      ink: AppPalette.orange700,
    ),
    FontAwesomeIcons.solidBell,
  );
  static const habits = ModuleStyle._(
    ModuleColors(
      solid: AppPalette.indigo500,
      soft: AppPalette.indigo100,
      ink: AppPalette.indigo700,
    ),
    FontAwesomeIcons.repeat,
  );
  static const vault = ModuleStyle._(
    ModuleColors(
      solid: AppPalette.amber500,
      soft: AppPalette.amber100,
      ink: AppPalette.amber700,
    ),
    FontAwesomeIcons.shieldHalved,
  );
  static const scan = ModuleStyle._(
    ModuleColors(
      solid: AppPalette.rose500,
      soft: AppPalette.rose100,
      ink: AppPalette.rose700,
    ),
    FontAwesomeIcons.camera,
  );

  static ModuleStyle of(AppModule module) => switch (module) {
    AppModule.notes => notes,
    AppModule.tasks => tasks,
    AppModule.reminders => reminders,
    AppModule.habits => habits,
    AppModule.vault => vault,
    AppModule.scan => scan,
  };

  static ModuleStyle forType(ItemType type) =>
      of(AppModule.fromItemType(type));
}

extension ItemTypeStyle on ItemType {
  ModuleStyle get style => ModuleStyle.forType(this);
}
