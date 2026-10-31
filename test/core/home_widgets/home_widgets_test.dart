/// Android home-screen widgets, Dart side: the snapshot the widgets render
/// (what it holds, what it leaves out — privacy), the action a tap on a check
/// circle performs, and the route whitelist of widget taps.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/home_widgets/home_widget_channel.dart';
import 'package:focusflow/core/home_widgets/widget_actions.dart';
import 'package:focusflow/core/home_widgets/widget_snapshot_builder.dart';
import 'package:focusflow/core/platform/launcher_shortcuts.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine.dart';
import 'package:focusflow/features/notes/domain/entities/note.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../helpers/test_container.dart';

final _now = DateTime(2026, 10, 31, 9, 30);
final _today = DateTime(2026, 10, 31);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TestHarness h;
  setUp(() async => h = await TestHarness.create(now: _now));
  tearDown(() => h.dispose());

  WidgetSnapshotBuilder builder([AppSettings? s]) => WidgetSnapshotBuilder(
    tasks: h.read(tasksRepositoryProvider),
    reminders: h.read(remindersRepositoryProvider),
    habits: h.read(habitsRepositoryProvider),
    medicines: h.read(medicinesRepositoryProvider),
    notes: h.read(notesRepositoryProvider),
    settings: s ?? const AppSettings(),
    now: _now,
  );

  Future<String> task(String title, {DateTime? due, bool done = false}) async {
    final repo = h.read(tasksRepositoryProvider);
    final id = await repo.save(
      TaskItem.draft(
        now: _now,
        title: title,
        dueDate: due ?? _today,
        dueTimeMinutes: 10 * 60,
      ),
    );
    if (done) await repo.complete(id);
    return id;
  }

  Future<void> seed() async {
    await task('Pay rent', due: DateTime(2026, 10, 29));
    await task('Write report');
    await task('Send invoice', done: true);
    await h
        .read(remindersRepositoryProvider)
        .save(
          Reminder.draft(
            triggerAt: DateTime(2026, 10, 31, 18),
            title: 'Call mum',
          ),
        );
    await h
        .read(medicinesRepositoryProvider)
        .save(
          Medicine.draft(
            startDate: _today,
            name: 'Metformin',
          ).copyWith(doses: const [DoseTime(8 * 60), DoseTime(20 * 60)]),
        );
    final notes = h.read(notesRepositoryProvider);
    await notes.createEmpty(title: 'Shopping list');
  }

  test('the snapshot holds today, ordered, with routes and counts', () async {
    await seed();
    final s = await builder().build();
    expect(s['v'], widgetSnapshotVersion);
    expect(s['day'], '2026-10-31');

    final tasks = s['tasks']! as Map;
    final items = (tasks['items']! as List).cast<Map>();
    // Overdue first, then today, completed last.
    expect(
      [for (final i in items) i['t']],
      ['Pay rent', 'Write report', 'Send invoice'],
    );
    expect(items.first['od'], isTrue);
    expect(items.first['sub'], 'Overdue');
    expect(items.last['done'], isTrue);
    expect(tasks['n'], 2); // open tasks
    expect(items[1]['r'], AppRoutes.task(items[1]['id']! as String));

    final reminders = (s['reminders']! as Map)['items']! as List;
    expect(reminders.single['t'], 'Call mum');

    final meds = s['medicines']! as Map;
    expect(meds['total'], 2);
    expect((meds['items']! as List).first['st'], 'due');

    final routes = s['routes']! as Map;
    expect(routes['add:tasks'], AppRoutes.newTaskPath);
    // Every word the native side shows is provided.
    expect((s['labels']! as Map)['left'], contains('{n}'));

    // Plain JSON, small enough for a SharedPreferences value.
    expect(jsonEncode(s).length, lessThan(30000));
  });

  test('completed tasks can be left out (setting)', () async {
    await seed();
    final s = await builder(
      const AppSettings(widgetsShowCompleted: false),
    ).build();
    final titles = [
      for (final i in (s['tasks']! as Map)['items']! as List) (i as Map)['t'],
    ];
    expect(titles, isNot(contains('Send invoice')));
  });

  test('privacy: no note text when off, no text and no title when locked', () {
    final b = builder(const AppSettings(widgetsShowNoteText: false));
    final off = b.compose(
      taskList: const [],
      reminderList: const [],
      habitList: const [],
      slots: const [],
      noteList: [
        _note('n1', 'Secret plan', 'buy gold and hide it'),
        _note('n2', 'Locked one', 'PIN protected text', locked: true),
      ],
    );
    final noteItems = ((off['notes']! as Map)['items']! as List).cast<Map>();
    expect(noteItems[0]['t'], 'Secret plan');
    expect(noteItems[0]['sub'], '');
    // A locked note never shows its title or text, whatever the setting.
    expect(noteItems[1]['t'], isNot('Locked one'));
    expect(noteItems[1]['sub'], '');
    expect(noteItems[1]['lock'], isTrue);

    final on = builder().compose(
      taskList: const [],
      reminderList: const [],
      habitList: const [],
      slots: const [],
      noteList: [
        _note('n1', 'Secret plan', 'buy gold   and\nhide it'),
        _note('n2', 'Locked one', 'PIN protected text', locked: true),
      ],
    );
    final shown = ((on['notes']! as Map)['items']! as List).cast<Map>();
    expect(shown[0]['sub'], 'buy gold and hide it'); // whitespace folded
    expect(shown[1]['sub'], '');
    expect(jsonEncode(on), isNot(contains('PIN protected')));
  });

  test('a long preview is cut', () {
    final s = builder().compose(
      taskList: const [],
      reminderList: const [],
      habitList: const [],
      slots: const [],
      noteList: [_note('n', 'Long', 'word ' * 100)],
    );
    final sub = (((s['notes']! as Map)['items']! as List).single as Map)['sub'];
    expect((sub as String).length, WidgetSnapshotBuilder.previewChars + 1);
    expect(sub.endsWith('…'), isTrue);
  });

  test('a widget tap completes the task for real', () async {
    final id = await task('Write report');
    final changed = await runWidgetAction(h.read, {
      'action': 'complete',
      'kind': 'task',
      'id': id,
    });
    expect(changed, isTrue);
    expect(
      (await h.read(tasksRepositoryProvider).getTask(id))!.isCompleted,
      isTrue,
    );
    // Again: nothing left to change, and no error.
    expect(
      await runWidgetAction(h.read, {
        'action': 'complete',
        'kind': 'task',
        'id': id,
      }),
      isFalse,
    );
  });

  test('a widget tap takes a dose; bad input changes nothing', () async {
    final meds = h.read(medicinesRepositoryProvider);
    final id = await meds.save(
      Medicine.draft(
        startDate: _today,
        name: 'Metformin',
      ).copyWith(doses: const [DoseTime(8 * 60)]),
    );
    expect(
      await runWidgetAction(h.read, {
        'action': 'take',
        'id': id,
        'day': '2026-10-31',
        'min': 8 * 60,
      }),
      isTrue,
    );
    expect((await meds.doseLog(id, _today, 8 * 60))!.isTaken, isTrue);

    for (final bad in <Map<String, Object?>>[
      {},
      {'action': 'explode', 'id': id},
      {'action': 'take', 'id': id},
      {'action': 'take', 'id': id, 'day': 'x', 'min': 1},
      {'action': 'complete', 'id': 'missing'},
    ]) {
      expect(await runWidgetAction(h.read, bad), isFalse, reason: '$bad');
    }
  });

  group('widget routes', () {
    test('only app item / list / editor paths are accepted', () {
      for (final ok in [
        '/tasks/abc-123',
        '/tasks/new',
        '/notes/new?text=hi',
        '/habits/h1',
        '/medicines/m1',
        '/reminders/new',
        '/library/tasks',
        '/home',
        '/item/task/42',
      ]) {
        expect(LauncherTarget.fromKey('route:$ok')?.route, ok, reason: ok);
      }
      for (final bad in [
        '/vault/item/1',
        '/settings/backup',
        '//evil.example',
        'https://evil.example',
        '/tasks/../vault',
        '/tasks/a b',
        'tasks/1',
        '',
      ]) {
        expect(LauncherTarget.fromKey('route:$bad'), isNull, reason: bad);
      }
      // Launcher shortcuts keep working.
      expect(LauncherTarget.fromKey('new_note')?.route, AppRoutes.newNote);
      expect(LauncherTarget.fromKey('bogus'), isNull);
    });
  });

  test('without the native side every channel call just says no', () async {
    const c = HomeWidgetChannel();
    expect(await c.push('{}'), isFalse);
    expect(await c.requestPin('tasks'), isFalse);
    expect(await c.counts(), isEmpty);
  });
}

Note _note(String id, String title, String text, {bool locked = false}) => Note(
  id: id,
  title: title,
  plainText: text,
  isLocked: locked,
  createdAt: _now,
  updatedAt: _now,
);
