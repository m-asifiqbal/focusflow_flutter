/// ============================================================
/// REMINDER STYLE — icon tile + accent colour of a reminder row
/// ============================================================
///
/// What: picks the soft icon tile and the 4 pt left-border colour of a
/// reminder card (screen 12): linked reminders → blue link, location
/// reminders → violet pin, a few well-known topics get their own icon
/// (pills, house, moon …), everything else the orange Reminders bell. A
/// card colour chosen in the actions sheet (`colorHex`, note palette)
/// overrides the colour.
/// Why: reminders have no icon field; deriving it here keeps the list,
/// the editor and the calendar consistent and costs no schema change.
/// ============================================================
library;

import 'package:flutter/widgets.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder.dart';

/// Icon + colour trio of one reminder.
@immutable
class ReminderStyle {
  const ReminderStyle(this.icon, this.colors);

  final IconData icon;
  final ModuleColors colors;

  static final _default = ReminderStyle(
    FontAwesomeIcons.solidBell,
    ModuleStyle.reminders.colors,
  );

  /// Topic keywords (lower-case title substrings) → icon + colour.
  static final List<(List<String>, ReminderStyle)> _topics = [
    (
      ['vitamin', 'pill', 'medic', 'meds', 'tablet'],
      const ReminderStyle(FontAwesomeIcons.pills, TagPalette.health),
    ),
    (
      ['rent', 'mortgage', 'bill'],
      const ReminderStyle(FontAwesomeIcons.house, TagPalette.high),
    ),
    (
      ['wind down', 'sleep', 'bed', 'screens'],
      ReminderStyle(FontAwesomeIcons.solidMoon, ModuleStyle.habits.colors),
    ),
    (
      ['water', 'drink', 'hydrat'],
      const ReminderStyle(FontAwesomeIcons.glassWater, TagPalette.travel),
    ),
    (
      ['gym', 'workout', 'exercise', 'stretch'],
      const ReminderStyle(FontAwesomeIcons.dumbbell, TagPalette.health),
    ),
    (
      ['birthday', 'anniversary'],
      const ReminderStyle(FontAwesomeIcons.cakeCandles, TagPalette.personal),
    ),
  ];

  /// Note-palette hex (stored `colorHex`) → colour trio.
  static ModuleColors? _fromHex(String? hex) =>
      switch (hex?.replaceAll('#', '').toUpperCase()) {
        'D1FAE5' => TagPalette.ideas,
        'FEF3C7' => TagPalette.finance,
        'DBEAFE' => TagPalette.work,
        'FCE7F3' => TagPalette.personal,
        'EDE9FE' => TagPalette.design,
        'FFEDD5' => TagPalette.peach,
        'ECFCCB' => TagPalette.lime,
        'CFFAFE' => TagPalette.travel,
        'FEE2E2' => TagPalette.high,
        _ => null,
      };

  /// The style of [r].
  static ReminderStyle of(Reminder r) {
    final base = _base(r);
    final custom = _fromHex(r.colorHex);
    return custom == null ? base : ReminderStyle(base.icon, custom);
  }

  static ReminderStyle _base(Reminder r) {
    final link = r.linkedRef;
    if (link != null) {
      return ReminderStyle(
        FontAwesomeIcons.link,
        link.type == ItemType.note
            ? ModuleStyle.notes.colors
            : ModuleStyle.tasks.colors,
      );
    }
    if (r.hasLocation) {
      return const ReminderStyle(
        FontAwesomeIcons.locationDot,
        TagPalette.design,
      );
    }
    final title = r.title.toLowerCase();
    for (final (words, style) in _topics) {
      if (words.any(title.contains)) return style;
    }
    return _default;
  }
}
