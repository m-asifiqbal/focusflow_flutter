/// Fixture-based tests for every importer (pure Dart): CSV codec, Google
/// Keep (json + Takeout zip), Evernote .enex, Todoist, Bitwarden,
/// 1Password, Loop Habit (zip with checkmarks), FocusFlow JSON/CSV round
/// trip through the export writers, and format detection.
library;

import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/sync/snapshot.dart';
import 'package:focusflow/features/backup/domain/entities/export_options.dart';
import 'package:focusflow/features/backup/domain/entities/import_bundle.dart';
import 'package:focusflow/features/backup/domain/services/csv_codec.dart';
import 'package:focusflow/features/backup/domain/services/export_filter.dart';
import 'package:focusflow/features/backup/domain/services/export_writers.dart';
import 'package:focusflow/features/backup/domain/services/importers/import_detector.dart';

List<int> _b(String s) => utf8.encode(s);

List<int> _zip(Map<String, String> files) {
  final a = Archive();
  for (final e in files.entries) {
    a.addFile(ArchiveFile.string(e.key, e.value));
  }
  return ZipEncoder().encodeBytes(a);
}

const _keepNote = '''
{"color":"DEFAULT","isTrashed":false,"isPinned":true,"isArchived":false,
 "title":"Packing","userEditedTimestampUsec":1718000000000000,
 "createdTimestampUsec":1717000000000000,
 "listContent":[{"text":"Passport","isChecked":true},{"text":"Charger","isChecked":false}],
 "labels":[{"name":"Travel"}]}
''';

void main() {
  group('CsvCodec', () {
    test('quotes, escaped quotes, embedded newlines, BOM', () {
      final rows = CsvCodec.decode('﻿a,b\r\n"x, y","he said ""hi""\nok"\n');
      expect(rows, [
        ['a', 'b'],
        ['x, y', 'he said "hi"\nok'],
      ]);
      expect(CsvCodec.decode(CsvCodec.encode(rows)), rows);
    });
  });

  test('Google Keep: single json and Takeout zip, trashed skipped', () {
    final one = ImportDetector.parse('Packing.json', _b(_keepNote));
    expect(one.source, ImportSource.googleKeep);
    final n = one.notes.single;
    expect(n.title, 'Packing');
    expect(n.text, '- [x] Passport\n- [ ] Charger');
    expect(n.tags, ['Travel']);
    expect(n.pinned, isTrue);
    expect(n.createdAt!.year, 2024);

    final zip = _zip({
      'Takeout/Keep/Packing.json': _keepNote,
      'Takeout/Keep/Old.json': _keepNote.replaceFirst(
        '"isTrashed":false',
        '"isTrashed":true',
      ),
      'Takeout/Keep/Labels.txt': 'Travel',
    });
    final b = ImportDetector.parse('takeout.zip', zip);
    expect(b.notes, hasLength(1));
    expect(b.problems.single.message, contains('trashed'));
  });

  test('Evernote .enex: title, ENML text, checklists, tags, date', () {
    const enex = '''<?xml version="1.0" encoding="UTF-8"?>
<en-export application="Evernote">
<note><title>Ideas &amp; plans</title>
<content><![CDATA[<?xml version="1.0"?><en-note><div>First line</div><div><en-todo checked="true"/>Done</div><div><en-todo/>Todo &lt;soon&gt;</div></en-note>]]></content>
<created>20240115T093000Z</created><tag>work</tag><tag>q1</tag></note>
</en-export>''';
    final b = ImportDetector.parse('My.enex', _b(enex));
    final n = b.notes.single;
    expect(b.source, ImportSource.evernote);
    expect(n.title, 'Ideas & plans');
    expect(n.text, 'First line\n[x] Done\n[ ] Todo <soon>');
    expect(n.tags, ['work', 'q1']);
    expect(n.createdAt!.toUtc(), DateTime.utc(2024, 1, 15, 9, 30));
  });

  test('Todoist CSV: priority, labels, subtasks, notes, NL dates', () {
    const csv =
        'TYPE,CONTENT,DESCRIPTION,PRIORITY,INDENT,AUTHOR,RESPONSIBLE,DATE,'
        'DATE_LANG,TIMEZONE\n'
        'section,Home,,,,,,,,\n'
        'task,Pay rent @money,Bank app,1,1,,,2026-07-01,en,UTC\n'
        'note,Use the joint account,,,,,,,,\n'
        'task,Check balance,,4,2,,,,en,UTC\n'
        'task,Water plants,,3,1,,,every mon,en,UTC\n';
    final b = ImportDetector.parse('Home.csv', _b(csv));
    expect(b.source, ImportSource.todoist);
    expect(b.tasks, hasLength(2));
    final rent = b.tasks.first;
    expect(rent.title, 'Pay rent');
    expect(rent.priority, 3);
    expect(rent.tags, ['money']);
    expect(rent.due, DateTime(2026, 7, 1));
    expect(rent.notes, 'Bank app\n\nUse the joint account');
    expect(rent.subtasks.single.title, 'Check balance');
    final plants = b.tasks.last;
    expect(plants.due, isNull);
    expect(plants.priority, 1);
    expect(plants.notes, 'Due: every mon');
  });

  test('Bitwarden CSV: logins only, favourite, folder, totp', () {
    const csv =
        'folder,favorite,type,name,notes,fields,reprompt,login_uri,'
        'login_username,login_password,login_totp\n'
        'Work,1,login,GitHub,,,0,https://github.com,asif,s3cret!,JBSWY3DP\n'
        ',,note,Wifi,router,,0,,,,\n';
    final b = ImportDetector.parse('bitwarden_export.csv', _b(csv));
    expect(b.source, ImportSource.bitwarden);
    final l = b.logins.single;
    expect(l.title, 'GitHub');
    expect(l.username, 'asif');
    expect(l.password, 's3cret!');
    expect(l.url, 'https://github.com');
    expect(l.totpSecret, 'JBSWY3DP');
    expect(l.folder, 'Work');
    expect(l.isFavorite, isTrue);
    expect(b.problems.single.message, contains('1 non-login'));
  });

  test('1Password CSV', () {
    const csv =
        'Title,Url,Username,Password,OTPAuth,Favorite,Archived,Tags,Notes\n'
        'Netflix,https://netflix.com,me@x.com,pw1,,true,false,Media,\n'
        'Old,https://old.com,a,b,,false,true,,\n';
    final b = ImportDetector.parse('1PasswordExport.csv', _b(csv));
    expect(b.source, ImportSource.onePassword);
    expect(b.logins.single.title, 'Netflix');
    expect(b.logins.single.folder, 'Media');
    expect(b.logins.single.isFavorite, isTrue);
  });

  test('Loop Habit zip: frequency, numeric target, checked days', () {
    final zip = _zip({
      'Habits.csv':
          'Position,Name,Type,Question,Description,FrequencyNumerator,'
          'FrequencyDenominator,Color,Unit,Target Type,Target Value,Archived\n'
          '001,Meditate,0,Did you meditate?,,1,1,#FF0000,,,,false\n'
          '002,Run,0,,,3,7,#00FF00,,,,false\n'
          '003,Water,1,,,1,1,#0000FF,glasses,0,8,false\n',
      'Checkmarks.csv':
          'Date,Meditate,Run,Water,\n'
          '2026-06-12,2,0,6000,\n'
          '2026-06-11,2,2,8000,\n'
          '2026-06-10,1,-1,0,\n',
      '001 Meditate/Checkmarks.csv': 'Date,Value\n2026-06-12,2\n',
    });
    final b = ImportDetector.parse('Loop Habits CSV 2026-06-13.zip', zip);
    expect(b.source, ImportSource.loopHabit);
    final m = b.habits[0], r = b.habits[1], w = b.habits[2];
    expect(m.frequencyType, 0);
    expect(m.logs, {'2026-06-12': 1, '2026-06-11': 1});
    expect(m.startDate, DateTime(2026, 6, 11));
    expect(r.frequencyType, 2);
    expect(r.timesPerWeek, 3);
    expect(r.logs.keys, ['2026-06-11']);
    expect(w.targetCount, 8);
    expect(w.unit, 'glasses');
    expect(w.logs, {'2026-06-12': 6, '2026-06-11': 8});
  });

  group('FocusFlow export round trip', () {
    final s = DbSnapshot({
      'tags': [
        {'id': 't1', 'name': 'home'},
      ],
      'notes': [
        {
          'id': 'n1', 'title': 'Groceries', 'plain_text': 'Milk', //
          'created_at': 1718000000, 'updated_at': 1718000000,
          'is_pinned': 1,
        },
        {
          'id': 'n2', 'title': 'Trashed', 'plain_text': '', //
          'created_at': 1718000000, 'updated_at': 1718000000,
          'deleted_at': 1718000100,
        },
      ],
      'tasks': [
        {
          'id': 'k1', 'title': 'Pay rent', 'notes': '', 'priority': 3, //
          'due_date': DateTime.utc(2026, 7, 1).millisecondsSinceEpoch ~/ 1000,
          'due_time_minutes': 540,
          'created_at': 1718000000, 'updated_at': 1718000000,
          'archived_at': 1718000500,
        },
      ],
      'subtasks': [
        {'id': 's1', 'task_id': 'k1', 'title': 'Transfer', 'done': 1},
      ],
      'item_tags': [
        {'item_id': 'k1', 'item_type': 'task', 'tag_id': 't1'},
      ],
      'habits': [
        {
          'id': 'h1', 'name': 'Read', 'target_count': 1, //
          'frequency_type': 2, 'times_per_week': 4, 'start_date': '2026-06-01',
          'created_at': 1718000000, 'updated_at': 1718000000,
        },
      ],
      'habit_logs': [
        {'id': 'l1', 'habit_id': 'h1', 'date': '2026-06-02', 'count': 1},
      ],
      'vault_items': [
        {'id': 'v1', 'title': 'Bank', 'created_at': 1, 'updated_at': 1},
      ],
    });

    test('filter drops trash, archived on demand, vault unless chosen', () {
      final f = ExportFilter.apply(
        s,
        modules: ExportModule.values.toSet(),
        includeArchived: false,
      );
      expect(f.rows('notes').map((r) => r['id']), ['n1']);
      expect(f.rows('tasks'), isEmpty);
      expect(f.rows('subtasks'), isEmpty);
      expect(f.rows('vault_items'), hasLength(1));
      final g = ExportFilter.apply(
        s,
        modules: {ExportModule.tasks},
        includeArchived: true,
      );
      expect(g.rows('tasks'), hasLength(1));
      expect(g.rows('subtasks'), hasLength(1));
      expect(g.rows('notes'), isEmpty);
      expect(g.rows('tombstones'), isEmpty);
    });

    test('JSON export imports back', () {
      final mods = {
        ExportModule.notes,
        ExportModule.tasks,
        ExportModule.habits,
      };
      final f = ExportFilter.apply(s, modules: mods, includeArchived: true);
      final bytes = ExportWriters.json(f, mods, now: DateTime(2026, 6, 13));
      final b = ImportDetector.parse('export.json', bytes);
      expect(b.source, ImportSource.focusflowJson);
      expect(b.notes.single.title, 'Groceries');
      expect(b.notes.single.pinned, isTrue);
      final t = b.tasks.single;
      expect(t.priority, 3);
      expect(t.due, DateTime(2026, 7, 1));
      expect(t.dueTimeMinutes, 540);
      expect(t.tags, ['home']);
      expect(t.archived, isTrue);
      expect(t.subtasks.single, (title: 'Transfer', done: true));
      expect(b.habits.single.timesPerWeek, 4);
      expect(b.habits.single.logs, {'2026-06-02': 1});
      expect(b.logins, isEmpty);
    });

    test('CSV export (zip of modules) imports back', () {
      final mods = {ExportModule.notes, ExportModule.tasks};
      final f = ExportFilter.apply(s, modules: mods, includeArchived: true);
      final out = ExportWriters.csv(f, mods);
      expect(out.extension, 'zip');
      final b = ImportDetector.parse('export.zip', out.bytes);
      expect(b.notes.single.title, 'Groceries');
      expect(b.tasks.single.title, 'Pay rent');
      expect(b.tasks.single.subtasks.single.done, isTrue);
    });

    test('Markdown notes', () {
      final md = ExportWriters.markdownNotes(
        ExportFilter.apply(
          s,
          modules: {ExportModule.notes},
          includeArchived: true,
        ),
      );
      expect(md.keys, ['notes/Groceries.md']);
      expect(md.values.single, startsWith('# Groceries\n\nMilk'));
    });
  });

  test('generic CSV: dated rows become tasks, others notes', () {
    const csv = 'Title,Notes,Due\nCall bank,,2026-06-20\nRecipe,Mix it,\n';
    final b = ImportDetector.parse('list.csv', _b(csv));
    expect(b.source, ImportSource.genericCsv);
    expect(b.tasks.single.title, 'Call bank');
    expect(b.notes.single.title, 'Recipe');
  });

  test('detector: ffbackup and unreadable files', () {
    expect(ImportDetector.isFfBackup('x.ffbackup', const []), isTrue);
    expect(
      ImportDetector.isFfBackup(
        'x.zip',
        _zip({'manifest.json': '{}', 'db.json': '{}'}),
      ),
      isTrue,
    );
    expect(
      () => ImportDetector.parse('photo.bin', const [0, 1, 2]),
      throwsA(isA<ImportFormatException>()),
    );
    expect(
      () => ImportDetector.parse('a.json', _b('{"hello":1}')),
      throwsA(isA<ImportFormatException>()),
    );
  });
}
