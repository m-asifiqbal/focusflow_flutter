/// ============================================================
/// TASK / HABIT IMPORTERS — Todoist CSV, Loop Habit Tracker
/// ============================================================
///
/// What:
/// * Todoist project CSV (TYPE, CONTENT, DESCRIPTION, PRIORITY, INDENT,
///   DATE…): `task` rows → tasks, deeper INDENT → subtasks of the task
///   above, `note` rows → appended to the task's notes, `@labels` → tags,
///   priority 1 (urgent) … 4 (none). Natural-language dates Todoist can't
///   be parsed offline are kept in the notes ("Due: every mon").
/// * Loop Habit Tracker export (zip with Habits.csv + Checkmarks.csv, or a
///   bare Habits.csv): habits with their frequency and every manually
///   checked day (value 2; numeric habits store value × 1000).
/// Why: the most common task and habit apps on Android/iOS.
/// ============================================================
library;

import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/backup/domain/entities/import_bundle.dart';
import 'package:focusflow/features/backup/domain/services/csv_codec.dart';
import 'package:focusflow/features/backup/domain/services/importers/import_parsing.dart';

abstract final class TodoistImporter {
  static bool isTodoistCsv(Set<String> header) =>
      header.contains('type') &&
      header.contains('content') &&
      header.contains('priority');

  static final _label = RegExp(r'(^|\s)@([\w-]+)');

  static ImportBundle parse(String text) {
    final rows = CsvCodec.decodeMaps(text);
    if (rows.isEmpty || !isTodoistCsv(rows.first.keys.toSet())) {
      throw ImportFormatException(tr('This is not a Todoist CSV export.'));
    }
    final tasks = <_TaskDraft>[];
    for (final r in rows) {
      final type = (r['type'] ?? '').trim().toLowerCase();
      final content = (r['content'] ?? '').trim();
      if (type == 'note' && tasks.isNotEmpty && content.isNotEmpty) {
        tasks.last.notes.add(content);
        continue;
      }
      if (type != 'task' || content.isEmpty) continue;
      final indent = int.tryParse(r['indent'] ?? '') ?? 1;
      final tags = [for (final m in _label.allMatches(content)) m.group(2)!];
      final title = content.replaceAll(_label, ' ').trim();
      if (indent > 1 && tasks.isNotEmpty) {
        tasks.last.subtasks.add(title);
        continue;
      }
      final date = (r['date'] ?? '').trim();
      final due = ImportParsing.day(date);
      final p = int.tryParse(r['priority'] ?? '') ?? 4;
      tasks.add(
        _TaskDraft(
            title: title,
            tags: tags,
            priority: switch (p) {
              1 => 3,
              2 => 2,
              3 => 1,
              _ => 0,
            },
            due: due,
            time: due == null ? null : _timeOf(date),
          )
          ..notes.addAll([
            if ((r['description'] ?? '').trim().isNotEmpty)
              r['description']!.trim(),
            if (due == null && date.isNotEmpty) 'Due: $date',
          ]),
      );
    }
    if (tasks.isEmpty) {
      throw ImportFormatException(tr('No tasks found in this Todoist CSV.'));
    }
    return ImportBundle(
      source: ImportSource.todoist,
      tasks: [
        for (final t in tasks)
          ImportedTask(
            title: t.title,
            notes: t.notes.join('\n\n'),
            due: t.due,
            dueTimeMinutes: t.time,
            priority: t.priority,
            tags: t.tags,
            subtasks: [for (final s in t.subtasks) (title: s, done: false)],
          ),
      ],
    );
  }

  static int? _timeOf(String date) {
    final t = DateTime.tryParse(date);
    if (t == null || (t.hour == 0 && t.minute == 0)) return null;
    final l = t.toLocal();
    return l.hour * 60 + l.minute;
  }
}

class _TaskDraft {
  _TaskDraft({
    required this.title,
    required this.tags,
    required this.priority,
    this.due,
    this.time,
  });

  final String title;
  final List<String> tags;
  final int priority;
  final DateTime? due;
  final int? time;
  final List<String> notes = [];
  final List<String> subtasks = [];
}

abstract final class LoopImporter {
  static bool isHabitsCsv(Set<String> header) =>
      header.contains('position') &&
      header.contains('name') &&
      (header.contains('frequencynumerator') ||
          header.contains('numrepetitions') ||
          header.contains('question'));

  /// [habitsCsv] = Habits.csv; [checkmarksCsv] = the root Checkmarks.csv.
  static ImportBundle parse(String habitsCsv, {String? checkmarksCsv}) {
    final rows = CsvCodec.decodeMaps(habitsCsv);
    if (rows.isEmpty || !isHabitsCsv(rows.first.keys.toSet())) {
      throw ImportFormatException(tr('This is not a Loop Habit export.'));
    }
    final logs = _checkmarks(checkmarksCsv);
    final habits = <ImportedHabit>[];
    for (final r in rows) {
      final name = (r['name'] ?? '').trim();
      if (name.isEmpty || ImportParsing.boolean(r['archived'])) continue;
      final num =
          int.tryParse(r['frequencynumerator'] ?? '') ??
          int.tryParse(r['numrepetitions'] ?? '') ??
          1;
      final den =
          int.tryParse(r['frequencydenominator'] ?? '') ??
          int.tryParse(r['interval'] ?? '') ??
          1;
      final numeric = (r['type'] ?? '').trim() == '1';
      final target = numeric
          ? (double.tryParse(r['target value'] ?? '') ?? 1).round()
          : 1;
      final days = logs[name] ?? const <String, int>{};
      habits.add(
        ImportedHabit(
          name: name,
          targetCount: target.clamp(1, 9999),
          unit: numeric
              ? ((r['unit'] ?? '').trim().isEmpty ? 'times' : r['unit']!.trim())
              : 'times',
          frequencyType: switch ((num, den)) {
            (1, 1) => 0,
            (_, 7) => 2,
            (1, _) => 3,
            _ => 0,
          },
          timesPerWeek: den == 7 ? num.clamp(1, 7) : 3,
          everyNDays: num == 1 && den > 1 ? den : 2,
          startDate: days.isEmpty
              ? null
              : ImportParsing.day((days.keys.toList()..sort()).first),
          logs: {
            for (final e in days.entries)
              e.key: numeric ? (e.value / 1000).round() : 1,
          }..removeWhere((_, v) => v <= 0),
        ),
      );
    }
    if (habits.isEmpty) {
      throw ImportFormatException(tr('No habits found in this export.'));
    }
    return ImportBundle(source: ImportSource.loopHabit, habits: habits);
  }

  /// Habit name → day → raw value of the days that count as done.
  static Map<String, Map<String, int>> _checkmarks(String? csv) {
    if (csv == null) return const {};
    final rows = CsvCodec.decode(csv);
    if (rows.length < 2) return const {};
    final names = rows.first;
    final out = <String, Map<String, int>>{};
    for (final r in rows.skip(1)) {
      final day = ImportParsing.day(r.first);
      if (day == null) continue;
      for (var c = 1; c < r.length && c < names.length; c++) {
        final v = int.tryParse(r[c].trim()) ?? -1;
        // 2 = checked manually (boolean); numeric habits: amount × 1000.
        if (v == 2 || v > 3) {
          (out[names[c].trim()] ??= {})[DateUtilsX.dayKey(day)] = v;
        }
      }
    }
    return out;
  }
}
