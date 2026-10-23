/// ============================================================
/// EXPORT RECORDS — readable per-item maps from raw snapshot rows
/// ============================================================
///
/// What: turns a (filtered) [DbSnapshot] into plain JSON-friendly maps per
/// module: ISO dates, tag names, folder names, subtasks and habit logs
/// inlined, enum ints spelled out.
/// Why: JSON and CSV exports are for people and other tools, not for
/// FocusFlow's own restore (that is the .ffbackup), so they must read well
/// and survive a round trip through the FocusFlow JSON/CSV importer.
/// Vault rows are never mapped here (ciphertext only travels in .ffbackup).
/// ============================================================
library;

import 'dart:convert';

import 'package:focusflow/core/sync/snapshot.dart';
import 'package:focusflow/core/utils/date_utils.dart';

/// Export schema id written into JSON exports (and recognised on import).
const String kFocusFlowExportFormat = 'focusflow-export';

const List<String> _priorities = ['none', 'low', 'medium', 'high'];

class ExportRecords {
  ExportRecords(this.s) {
    for (final t in s.rows('tags')) {
      _tagNames['${t['id']}'] = '${t['name'] ?? ''}';
    }
    for (final f in s.rows('folders')) {
      _folderNames['${f['id']}'] = '${f['name'] ?? ''}';
    }
    for (final l in s.rows('item_tags')) {
      final name = _tagNames['${l['tag_id']}'];
      if (name == null) continue;
      (_tagsOf['${l['item_type']}:${l['item_id']}'] ??= []).add(name);
    }
  }

  final DbSnapshot s;
  final _tagNames = <String, String>{};
  final _folderNames = <String, String>{};
  final _tagsOf = <String, List<String>>{};

  /// Unix seconds → local ISO-8601 (null stays null).
  static String? iso(Object? v) => v is int
      ? DateTime.fromMillisecondsSinceEpoch(v * 1000).toIso8601String()
      : null;

  /// A stored floating day (UTC midnight seconds) → `yyyy-MM-dd`.
  static String? day(Object? v) => v is int
      ? DateUtilsX.dayKey(
          DateTime.fromMillisecondsSinceEpoch(v * 1000, isUtc: true),
        )
      : null;

  static bool _b(Object? v) => v == 1 || v == true;

  Map<String, Object?> _common(String type, RawRow r) => {
    'id': r['id'],
    'tags': _tagsOf['$type:${r['id']}'] ?? const <String>[],
    'folder': _folderNames['${r['folder_id']}'],
    'pinned': _b(r['is_pinned']),
    'favorite': _b(r['is_favorite']),
    'color': r['color_hex'],
    'created': iso(r['created_at']),
    'updated': iso(r['updated_at']),
    'archived': iso(r['archived_at']),
  };

  List<Map<String, Object?>> notes() => [
    for (final r in s.rows('notes'))
      {
        'title': r['title'] ?? '',
        'text': r['plain_text'] ?? '',
        ..._common('note', r),
      },
  ];

  List<Map<String, Object?>> tasks() {
    final subs = <String, List<Map<String, Object?>>>{};
    final sorted = [...s.rows('subtasks')]
      ..sort(
        (a, b) => ((a['sort_order'] as num?) ?? 0).compareTo(
          (b['sort_order'] as num?) ?? 0,
        ),
      );
    for (final st in sorted) {
      (subs['${st['task_id']}'] ??= []).add({
        'title': st['title'] ?? '',
        'done': _b(st['done']),
      });
    }
    return [
      for (final r in s.rows('tasks'))
        {
          'title': r['title'] ?? '',
          'notes': r['notes'] ?? '',
          'due': day(r['due_date']),
          'dueTime': _hhmm(r['due_time_minutes']),
          'priority': _priorities[((r['priority'] as int?) ?? 0).clamp(0, 3)],
          'repeat': r['repeat_rule'],
          'completed': iso(r['completed_at']),
          'subtasks': subs['${r['id']}'] ?? const <Map<String, Object?>>[],
          ..._common('task', r),
        },
    ];
  }

  List<Map<String, Object?>> reminders() => [
    for (final r in s.rows('reminders'))
      {
        'title': r['title'] ?? '',
        'note': r['note'] ?? '',
        'at': iso(r['trigger_at']),
        'repeat': r['repeat_rule'],
        'enabled': _b(r['is_enabled']),
        'completed': iso(r['completed_at']),
        ..._common('reminder', r),
      },
  ];

  List<Map<String, Object?>> habits() {
    final logs = <String, List<Map<String, Object?>>>{};
    for (final l in s.rows('habit_logs')) {
      (logs['${l['habit_id']}'] ??= []).add({
        'date': l['date'],
        'count': l['count'] ?? 0,
        'skipped': _b(l['skipped']),
      });
    }
    for (final list in logs.values) {
      list.sort((a, b) => '${a['date']}'.compareTo('${b['date']}'));
    }
    return [
      for (final r in s.rows('habits'))
        {
          'name': r['name'] ?? '',
          'icon': r['icon_key'],
          'category': r['category'],
          'kind': r['habit_type'] == 1 ? 'quit' : 'build',
          'target': r['target_count'] ?? 1,
          'unit': r['unit'] ?? 'times',
          'frequencyType': r['frequency_type'] ?? 0,
          'weekdaysMask': r['weekdays_mask'] ?? 127,
          'timesPerWeek': r['times_per_week'] ?? 3,
          'everyNDays': r['every_n_days'] ?? 2,
          'startDate': r['start_date'],
          'paused': _b(r['is_paused']),
          'logs': logs['${r['id']}'] ?? const <Map<String, Object?>>[],
          ..._common('habit', r),
        },
    ];
  }

  static const List<String> _forms = [
    'tablet', 'capsule', 'liquid', 'drops', 'injection', 'inhaler', 'other', //
  ];
  static const List<String> _food = ['any', 'before', 'with', 'after'];
  static const List<String> _schedules = [
    'everyDay', 'specificDays', 'everyNDays', 'asNeeded', //
  ];

  static String _name(List<String> names, Object? i) =>
      i is int && i >= 0 && i < names.length ? names[i] : names.first;

  /// Medicines with their logged doses inlined (taken / skipped, oldest
  /// first). Dose times stay the stored JSON list (`[{"t":"08:00","q":1}]`).
  List<Map<String, Object?>> medicines() {
    final doses = <String, List<Map<String, Object?>>>{};
    for (final d in s.rows('medicine_doses')) {
      final status = d['status'];
      if (status != 1 && status != 2) continue;
      (doses['${d['medicine_id']}'] ??= []).add({
        'date': d['date'],
        'time': _hhmm(d['slot_minutes']),
        'status': status == 1 ? 'taken' : 'skipped',
        'quantity': d['quantity'] ?? 1,
        'at': iso(d['taken_at']),
      });
    }
    for (final list in doses.values) {
      list.sort(
        (a, b) =>
            '${a['date']} ${a['time']}'.compareTo('${b['date']} ${b['time']}'),
      );
    }
    return [
      for (final r in s.rows('medicines'))
        {
          'name': r['name'] ?? '',
          'strength': r['strength'] ?? '',
          'form': _name(_forms, r['form']),
          'food': _name(_food, r['food_timing']),
          'schedule': _name(_schedules, r['schedule_type']),
          'weekdaysMask': r['weekdays_mask'] ?? 127,
          'everyNDays': r['every_n_days'] ?? 2,
          'times': _times(r['doses_json']),
          'startDate': r['start_date'],
          'endDate': r['end_date'],
          'stockLeft': r['stock_left'],
          'refillAt': r['refill_at'],
          'note': r['note'] ?? '',
          'paused': _b(r['is_paused']),
          'doses': doses['${r['id']}'] ?? const <Map<String, Object?>>[],
          ..._common('medicine', r),
        },
    ];
  }

  /// `08:00×1; 20:00×0.5` from the stored dose JSON.
  static String _times(Object? json) {
    if (json is! String) return '';
    try {
      final list = jsonDecode(json);
      if (list is! List) return '';
      return [
        for (final e in list)
          if (e is Map) '${e['t']}×${e['q'] ?? 1}',
      ].join('; ');
    } on FormatException {
      return '';
    }
  }

  static String? _hhmm(Object? minutes) {
    if (minutes is! int) return null;
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }
}
