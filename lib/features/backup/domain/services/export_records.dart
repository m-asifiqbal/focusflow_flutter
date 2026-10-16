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

  static String? _hhmm(Object? minutes) {
    if (minutes is! int) return null;
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }
}
