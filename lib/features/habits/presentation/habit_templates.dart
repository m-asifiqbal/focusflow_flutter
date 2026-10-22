/// ============================================================
/// HABIT TEMPLATES & CATEGORIES — the editor's quick-start presets
/// ============================================================
///
/// "QUICK START" on the habit editor (screen 15): tapping a template fills
/// every field of the draft (name, icon, colour, category, goal, schedule,
/// part of day and reminder times). Categories are the fixed list offered
/// by the Category row, each with a tag colour for the preview card.
/// Presentation-only data: colours are design-system trios (HabitPalette).
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/domain/entities/habit_frequency.dart';
import 'package:focusflow/features/habits/presentation/habit_style.dart';

/// One quick-start preset.
@immutable
class HabitTemplate {
  const HabitTemplate({
    required this.label,
    required this.name,
    required this.iconKey,
    required this.colors,
    required this.category,
    this.kind = HabitKind.build,
    this.targetCount = 1,
    this.unit = 'times',
    this.frequency = const HabitFrequency.everyDay(),
    this.partOfDay = PartOfDay.anytime,
    this.reminderTimes = const [],
  });

  /// Tile caption ("Meditate").
  final String label;

  /// Habit name it fills in ("Meditate", "Read 20 pages").
  final String name;
  final String iconKey;
  final ModuleColors colors;
  final String category;
  final HabitKind kind;
  final int targetCount;
  final String unit;
  final HabitFrequency frequency;
  final PartOfDay partOfDay;

  /// `HH:mm`.
  final List<String> reminderTimes;

  /// [draft] with every template field applied (id, dates, tags kept).
  Habit applyTo(Habit draft) => draft.copyWith(
    name: name,
    iconKey: iconKey,
    colorHex: HabitPalette.hexOf(colors),
    category: category,
    kind: kind,
    targetCount: targetCount,
    unit: unit,
    frequency: frequency,
    partOfDay: partOfDay,
    reminderEnabled: reminderTimes.isNotEmpty,
    reminderTimes: reminderTimes,
  );
}

abstract final class HabitTemplates {
  /// Mockup order first (Meditate, Read, Exercise, Sleep), then extras.
  static List<HabitTemplate> get all => [
    HabitTemplate(
      label: tr('Meditate'),
      name: tr('Meditate'),
      iconKey: 'spa',
      colors: HabitPalette.amber,
      category: 'Mind',
      targetCount: 10,
      unit: 'min',
      partOfDay: PartOfDay.morning,
      reminderTimes: const ['07:00'],
    ),
    HabitTemplate(
      label: tr('Read'),
      name: tr('Read 20 pages'),
      iconKey: 'book-open',
      colors: HabitPalette.emerald,
      category: 'Learning',
      partOfDay: PartOfDay.evening,
      reminderTimes: const ['21:00'],
    ),
    HabitTemplate(
      label: tr('Exercise'),
      name: tr('Exercise'),
      iconKey: 'person-running',
      colors: HabitPalette.red,
      category: 'Fitness',
      targetCount: 30,
      unit: 'min',
      frequency: const HabitFrequency.timesPerWeek(3),
      partOfDay: PartOfDay.afternoon,
      reminderTimes: const ['18:00'],
    ),
    HabitTemplate(
      label: tr('Sleep'),
      name: tr('Sleep 8 hours'),
      iconKey: 'moon',
      colors: HabitPalette.indigo,
      category: 'Health',
      targetCount: 8,
      unit: 'hours',
      partOfDay: PartOfDay.evening,
      reminderTimes: const ['22:30'],
    ),
    HabitTemplate(
      label: tr('Drink water'),
      name: tr('Drink Water'),
      iconKey: 'droplet',
      colors: HabitPalette.blue,
      category: 'Health',
      targetCount: 8,
      unit: 'glasses',
      frequency: HabitFrequency.weekdays,
      partOfDay: PartOfDay.morning,
      reminderTimes: const ['09:00', '13:00', '17:00'],
    ),
    HabitTemplate(
      label: tr('Walk'),
      name: tr('Walk'),
      iconKey: 'person-walking',
      colors: HabitPalette.sky,
      category: 'Fitness',
      targetCount: 30,
      unit: 'min',
    ),
    HabitTemplate(
      label: tr('Journal'),
      name: tr('Journal'),
      iconKey: 'pen',
      colors: HabitPalette.violet,
      category: 'Mind',
      partOfDay: PartOfDay.evening,
      reminderTimes: const ['21:30'],
    ),
    HabitTemplate(
      label: tr('No sugar'),
      name: tr('No sugar'),
      iconKey: 'ban',
      colors: HabitPalette.rose,
      category: 'Health',
      kind: HabitKind.quit,
      unit: 'slips',
    ),
  ];
}

abstract final class HabitCategories {
  /// The Category row's options.
  static const List<String> all = [
    'Health',
    'Fitness',
    'Mind',
    'Learning',
    'Productivity',
    'Finance',
    'Social',
    'Other',
  ];

  /// Tag colours of the preview card's category tag.
  static ModuleColors colorsOf(String category) =>
      switch (category.toLowerCase()) {
        'health' => TagPalette.health,
        'fitness' => HabitPalette.red,
        'mind' => HabitPalette.amber,
        'learning' => HabitPalette.blue,
        'productivity' => HabitPalette.indigo,
        'finance' => TagPalette.finance,
        'social' => HabitPalette.pink,
        _ => TagPalette.forName(category),
      };
}
