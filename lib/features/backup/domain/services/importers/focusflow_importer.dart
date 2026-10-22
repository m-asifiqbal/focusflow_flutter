/// ============================================================
/// FOCUSFLOW IMPORTER — FocusFlow JSON / CSV exports, generic CSV
/// ============================================================
///
/// What: reads back what ExportWriters writes (JSON with
/// `format: focusflow-export`, per-module CSVs with a `type` column) and,
/// leniently, any CSV with a title/name column ("generic CSV": rows with a
/// due date become tasks, the rest notes).
/// Why: exports must round-trip, and a plain spreadsheet of to-dos is the
/// most common thing people try to import.
/// ============================================================
library;

import 'dart:convert';

import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/features/backup/domain/entities/import_bundle.dart';
import 'package:focusflow/features/backup/domain/services/csv_codec.dart';
import 'package:focusflow/features/backup/domain/services/export_records.dart';
import 'package:focusflow/features/backup/domain/services/importers/import_parsing.dart';

abstract final class FocusFlowImporter {
  static const _priorities = ['none', 'low', 'medium', 'high'];

  static bool isExportJson(Object? json) =>
      json is Map && json['format'] == kFocusFlowExportFormat;

  /// A FocusFlow JSON export.
  static ImportBundle fromJson(String text) {
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      throw ImportFormatException(tr('This JSON file is damaged.'));
    }
    if (!isExportJson(json)) {
      throw ImportFormatException(
        tr('This JSON file is not a FocusFlow export.'),
      );
    }
    final m = json as Map;
    // Defensive: a hand-edited file may hold anything where a list of
    // objects belongs — non-objects are skipped, never a crash.
    List<Map> list(String k) => [
      if (m[k] case final List l) ...l.whereType<Map>(),
    ];
    return ImportBundle(
      source: ImportSource.focusflowJson,
      notes: list('notes').map(_note).toList(),
      tasks: list('tasks').map(_task).toList(),
      reminders: [
        for (final r in list('reminders'))
          if (ImportParsing.dateTime(r['at']) case final at?)
            ImportedReminder(
              title: '${r['title'] ?? ''}',
              note: '${r['note'] ?? ''}',
              at: at,
              createdAt: ImportParsing.dateTime(r['created']),
            ),
      ],
      habits: list('habits').map(_habit).toList(),
    );
  }

  static ImportedNote _note(Map r) => ImportedNote(
    title: '${r['title'] ?? ''}',
    text: '${r['text'] ?? ''}',
    tags: ImportParsing.tags(r['tags']),
    createdAt: ImportParsing.dateTime(r['created']),
    archived: '${r['archived'] ?? ''}'.isNotEmpty,
    pinned: r['pinned'] == true || ImportParsing.boolean(r['pinned']),
  );

  static ImportedTask _task(Map r) {
    final subs = r['subtasks'];
    return ImportedTask(
      title: '${r['title'] ?? ''}',
      notes: '${r['notes'] ?? ''}',
      due: ImportParsing.day(r['due']),
      dueTimeMinutes: ImportParsing.minutes(r['dueTime']),
      priority: _priorities.indexOf('${r['priority']}').clamp(0, 3),
      completedAt: ImportParsing.dateTime(r['completed']),
      subtasks: subs is List
          ? [
              for (final s in subs.whereType<Map>())
                (title: '${s['title'] ?? ''}', done: s['done'] == true),
            ]
          : _subtaskLines('${subs ?? ''}'),
      tags: ImportParsing.tags(r['tags']),
      createdAt: ImportParsing.dateTime(r['created']),
      archived: '${r['archived'] ?? ''}'.isNotEmpty,
    );
  }

  static List<({String title, bool done})> _subtaskLines(String s) => [
    for (final line in const LineSplitter().convert(s))
      if (line.trim().isNotEmpty)
        (
          title: line.replaceFirst(RegExp(r'^\s*\[[ xX]\]\s*'), '').trim(),
          done: RegExp(r'^\s*\[[xX]\]').hasMatch(line),
        ),
  ];

  static ImportedHabit _habit(Map r) {
    final logs = <String, int>{};
    final raw = r['logs'];
    if (raw is List) {
      for (final m in raw.whereType<Map>()) {
        final c = m['count'];
        final n = c is num ? c.toInt() : int.tryParse('${c ?? ''}') ?? 0;
        if (m['skipped'] != true && n > 0) logs['${m['date']}'] = n;
      }
    } else {
      // CSV "doneDays": "2026-06-01 2026-06-02=3".
      for (final part in '${r['doneDays'] ?? ''}'.split(' ')) {
        if (part.isEmpty) continue;
        final kv = part.split('=');
        logs[kv.first] = kv.length > 1 ? int.tryParse(kv[1]) ?? 1 : 1;
      }
    }
    int n(String k, int d) => int.tryParse('${r[k] ?? ''}') ?? d;
    return ImportedHabit(
      name: '${r['name'] ?? ''}',
      targetCount: n('target', 1),
      unit: '${r['unit'] ?? 'times'}',
      frequencyType: n('frequencyType', 0),
      weekdaysMask: n('weekdaysMask', 127),
      timesPerWeek: n('timesPerWeek', 3),
      everyNDays: n('everyNDays', 2),
      quit: r['kind'] == 'quit',
      startDate: ImportParsing.day(r['startDate']),
      logs: logs,
      createdAt: ImportParsing.dateTime(r['created']),
    );
  }

  /// A FocusFlow CSV (has a `type` column) or a generic CSV.
  static ImportBundle fromCsv(String text) {
    final rows = CsvCodec.decodeMaps(text);
    if (rows.isEmpty) {
      throw ImportFormatException(tr('This CSV file is empty.'));
    }
    final header = rows.first.keys.toSet();
    if (!header.contains('title') && !header.contains('name')) {
      throw ImportFormatException(
        tr('No "title" or "name" column found in this CSV.'),
      );
    }
    final ours = header.contains('type');
    final notes = <ImportedNote>[], tasks = <ImportedTask>[];
    final reminders = <ImportedReminder>[], habits = <ImportedHabit>[];
    final problems = <ImportProblem>[];
    // CSV keys are lower-cased; map back to the JSON field names.
    Map<String, String> js(Map<String, String> r) => {
      ...r,
      'dueTime': r['duetime'] ?? '',
      'frequencyType': r['frequencytype'] ?? '',
      'weekdaysMask': r['weekdaysmask'] ?? '',
      'timesPerWeek': r['timesperweek'] ?? '',
      'everyNDays': r['everyndays'] ?? '',
      'startDate': r['startdate'] ?? '',
      'doneDays': r['donedays'] ?? '',
    };
    for (var i = 0; i < rows.length; i++) {
      final r = js(rows[i]);
      final title = (r['title'] ?? r['name'] ?? '').trim();
      if (title.isEmpty && (r['text'] ?? r['notes'] ?? '').trim().isEmpty) {
        problems.add(ImportProblem(tr('Row {n}: no title', {'n': i + 2})));
        continue;
      }
      final type = ours ? r['type'] : null;
      switch (type) {
        case 'note':
          notes.add(_note(r));
        case 'task':
          tasks.add(_task(r));
        case 'habit':
          habits.add(_habit(r));
        case 'reminder':
          final at = ImportParsing.dateTime(r['at']);
          if (at == null) {
            problems.add(
              ImportProblem(tr('Row {n}: reminder has no time', {'n': i + 2})),
            );
          } else {
            reminders.add(
              ImportedReminder(title: title, note: r['note'] ?? '', at: at),
            );
          }
        default:
          final due = r['due'] ?? r['due date'] ?? r['date'] ?? '';
          if (due.trim().isNotEmpty || header.contains('priority')) {
            tasks.add(_task({...r, 'title': title, 'due': due}));
          } else {
            notes.add(
              ImportedNote(
                title: title,
                text: r['text'] ?? r['content'] ?? r['notes'] ?? '',
                tags: ImportParsing.tags(r['tags']),
              ),
            );
          }
      }
    }
    return ImportBundle(
      source: ours ? ImportSource.focusflowCsv : ImportSource.genericCsv,
      notes: notes,
      tasks: tasks,
      reminders: reminders,
      habits: habits,
      problems: problems,
    );
  }
}
