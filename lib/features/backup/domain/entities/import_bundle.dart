/// ============================================================
/// IMPORT BUNDLE — what an importer parsed out of a file
/// ============================================================
///
/// What: app-neutral notes / tasks / reminders / habits / logins plus the
/// detected source and any per-row problems, shown in the preview
/// ("48 notes · 3 skipped") before anything is written.
/// Why: parsers stay pure (bytes in, bundle out) and the writer applies
/// dedupe + the vault session in one place. Logins are plaintext in
/// memory only and handed straight to the vault bridge.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/sync/vault_bridge.dart';

/// Where a file came from (detected from its name and content).
enum ImportSource {
  ffbackup,
  focusflowJson,
  focusflowCsv,
  googleKeep,
  todoist,
  bitwarden,
  onePassword,
  loopHabit,
  evernote,
  genericCsv;

  /// Display name; only the first is a phrase — the rest are file formats
  /// and product names, which stay as written in every language.
  String get label => switch (this) {
    ffbackup => tr('FocusFlow backup'),
    focusflowJson => 'FocusFlow JSON',
    focusflowCsv => 'FocusFlow CSV',
    googleKeep => 'Google Keep',
    todoist => 'Todoist',
    bitwarden => 'Bitwarden CSV',
    onePassword => '1Password',
    loopHabit => 'Loop Habit',
    evernote => 'Evernote (.enex)',
    genericCsv => 'CSV',
  };
}

@immutable
class ImportedNote {
  const ImportedNote({
    required this.title,
    this.text = '',
    this.tags = const [],
    this.createdAt,
    this.archived = false,
    this.pinned = false,
  });

  final String title;
  final String text;
  final List<String> tags;
  final DateTime? createdAt;
  final bool archived;
  final bool pinned;
}

@immutable
class ImportedTask {
  const ImportedTask({
    required this.title,
    this.notes = '',
    this.due,
    this.dueTimeMinutes,
    this.priority = 0,
    this.completedAt,
    this.subtasks = const [],
    this.tags = const [],
    this.createdAt,
    this.archived = false,
  });

  final String title;
  final String notes;

  /// Calendar day (local midnight).
  final DateTime? due;
  final int? dueTimeMinutes;

  /// 0 none · 1 low · 2 medium · 3 high.
  final int priority;
  final DateTime? completedAt;
  final List<({String title, bool done})> subtasks;
  final List<String> tags;
  final DateTime? createdAt;
  final bool archived;
}

@immutable
class ImportedReminder {
  const ImportedReminder({
    required this.title,
    required this.at,
    this.note = '',
    this.createdAt,
  });

  final String title;
  final DateTime at;
  final String note;
  final DateTime? createdAt;
}

@immutable
class ImportedHabit {
  const ImportedHabit({
    required this.name,
    this.targetCount = 1,
    this.unit = 'times',
    this.frequencyType = 0,
    this.weekdaysMask = 127,
    this.timesPerWeek = 3,
    this.everyNDays = 2,
    this.quit = false,
    this.startDate,
    this.logs = const {},
    this.createdAt,
  });

  final String name;
  final int targetCount;
  final String unit;
  final int frequencyType;
  final int weekdaysMask;
  final int timesPerWeek;
  final int everyNDays;
  final bool quit;
  final DateTime? startDate;

  /// `yyyy-MM-dd` → count done that day.
  final Map<String, int> logs;
  final DateTime? createdAt;
}

/// A row the parser could not use ("Row 12: no title").
@immutable
class ImportProblem {
  const ImportProblem(this.message);

  final String message;
}

@immutable
class ImportBundle {
  const ImportBundle({
    required this.source,
    this.notes = const [],
    this.tasks = const [],
    this.reminders = const [],
    this.habits = const [],
    this.logins = const [],
    this.problems = const [],
  });

  final ImportSource source;
  final List<ImportedNote> notes;
  final List<ImportedTask> tasks;
  final List<ImportedReminder> reminders;
  final List<ImportedHabit> habits;
  final List<ImportedLogin> logins;
  final List<ImportProblem> problems;

  int get itemCount =>
      notes.length +
      tasks.length +
      reminders.length +
      habits.length +
      logins.length;

  bool get isEmpty => itemCount == 0;
}

/// What the writer did ("Imported 46 · 2 duplicates skipped · 1 failed").
@immutable
class ImportResult {
  const ImportResult({
    this.imported = 0,
    this.duplicates = 0,
    this.failed = 0,
    this.failures = const [],
  });

  final int imported;
  final int duplicates;
  final int failed;

  /// Human messages for the partial-failure report (no secrets).
  final List<String> failures;
}

/// The file is not something FocusFlow can import (shown verbatim).
class ImportFormatException implements Exception {
  const ImportFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}
