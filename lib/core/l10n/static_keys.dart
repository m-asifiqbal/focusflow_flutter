/// ============================================================
/// STATIC KEYS — translatable text that lives in const data
/// ============================================================
///
/// Why: `tr('…')` cannot run in a constant (enum arguments, `static const`
/// lists, default parameter values). Such a label keeps its plain English
/// literal there, is listed here so `tool/l10n/extract.dart` puts it in the
/// catalogue and the packs, and is translated where it is shown:
/// `Text(tr(entry.label))`. Keep each text exactly as written at its
/// declaration. Never list text that is already inside a `tr('…')` call.
/// ============================================================
library;

const List<String> kStaticL10nKeys = <String>[
  // habits
  // Habit categories and icon search groups (stored in English, shown through
  // HabitWords.shown / matched with tr(group)).
  'Health',
  'Fitness',
  'Mind',
  'Learning',
  'Productivity',
  'Finance',
  'Social',
  'Other',
  'Creative',
  'Food',
  'Money',
  'Quit',
  // habits: units of a goal, shown after a number ("8 glasses", "30 min",
  // "3 times", "Log 1 glass") — stored in English, shown through
  // HabitWords.shown.
  'times',
  'time',
  'hours',
  'hour',
  'glasses',
  'glass',
];
