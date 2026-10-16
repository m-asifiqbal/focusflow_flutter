/// ============================================================
/// IMPORT WRITER — stores an ImportBundle through the repositories
/// ============================================================
///
/// What: writes parsed notes / tasks / reminders / habits / logins via the
/// module repositories (so FTS, sync columns, tags and notifications stay
/// consistent), skipping duplicates and collecting per-item failures for
/// the partial-failure report.
/// Dedupe ("title + date"): notes by title + created day (or title + body
/// when the source has no date), tasks by title + due day, reminders by
/// title + time, habits by name, logins by title (+ username within the
/// file). Existing items are read from one DB snapshot up front.
/// Why: importing the same export twice must not double everything.
/// Logins go to the vault bridge (encrypted with the unlocked session);
/// nothing here logs item contents.
/// ============================================================
library;

import 'package:drift/drift.dart' show Variable;
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/items/items_repository.dart';
import 'package:focusflow/core/sync/snapshot.dart';
import 'package:focusflow/core/sync/vault_bridge.dart';
import 'package:focusflow/core/utils/clock.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/backup/domain/entities/import_bundle.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/domain/entities/habit_frequency.dart';
import 'package:focusflow/features/habits/domain/repository/habits_repository.dart';
import 'package:focusflow/features/notes/domain/repository/notes_repository.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder.dart';
import 'package:focusflow/features/reminders/domain/repository/reminders_repository.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:focusflow/features/tasks/domain/repository/tasks_repository.dart';

/// Progress callback: items written so far of [total].
typedef ImportProgress = void Function(int done, int total);

class ImportWriter {
  ImportWriter({
    required this.db,
    required this.snapshot,
    required this.notes,
    required this.tasks,
    required this.reminders,
    required this.habits,
    required this.items,
    required this.vault,
    required this.clock,
  });

  final AppDatabase db;
  final Future<DbSnapshot> Function() snapshot;
  final NotesRepository notes;
  final TasksRepository tasks;
  final RemindersRepository reminders;
  final HabitsRepository habits;
  final ItemsRepository items;
  final VaultBackupBridge vault;
  final Clock clock;

  static String _n(Object? s) => '${s ?? ''}'.trim().toLowerCase();
  static String _day(DateTime? d) => d == null ? '' : DateUtilsX.dayKey(d);
  static DateTime? _sec(Object? v) =>
      v is int ? DateTime.fromMillisecondsSinceEpoch(v * 1000) : null;
  static String _body(String text) {
    final t = text.trim();
    return _n(t.length > 80 ? t.substring(0, 80) : t);
  }

  /// Writes [b]. Throws [VaultUnavailable] up front when the bundle has
  /// logins but the vault is locked (the caller unlocks and retries).
  Future<ImportResult> write(
    ImportBundle b, {
    ImportProgress? onProgress,
  }) async {
    final existing = await snapshot();
    final seen = <String>{};
    for (final r in existing.rows('notes')) {
      if (r['deleted_at'] != null) continue;
      seen
        ..add('n|${_n(r['title'])}|${_day(_sec(r['created_at']))}')
        ..add('n|${_n(r['title'])}|${_body('${r['plain_text'] ?? ''}')}');
    }
    for (final r in existing.rows('tasks')) {
      if (r['deleted_at'] != null) continue;
      final due = r['due_date'];
      seen.add(
        't|${_n(r['title'])}|${due is int ? _day(DateUtilsX.fromStoredDay(DateTime.fromMillisecondsSinceEpoch(due * 1000))) : ''}',
      );
    }
    for (final r in existing.rows('reminders')) {
      if (r['deleted_at'] != null) continue;
      seen.add('r|${_n(r['title'])}|${r['trigger_at']}');
    }
    for (final r in existing.rows('habits')) {
      if (r['deleted_at'] == null) seen.add('h|${_n(r['name'])}');
    }
    final vaultTitles = {
      for (final r in existing.rows('vault_items'))
        if (r['deleted_at'] == null) _n(r['title']),
    };

    var imported = 0, duplicates = 0;
    final failures = <String>[];
    var done = 0;
    final total = b.itemCount;
    void tick() => onProgress?.call(++done, total);

    Future<void> guard(String label, Future<void> Function() body) async {
      try {
        await body();
        imported++;
      } catch (e) {
        failures.add(
          '$label: ${e is ImportFormatException ? e.message : 'could not be saved'}',
        );
      }
      tick();
    }

    // Logins first: a locked vault fails before anything is written.
    if (b.logins.isNotEmpty) {
      final fresh = <ImportedLogin>[];
      final inFile = <String>{};
      for (final l in b.logins) {
        final dup =
            vaultTitles.contains(_n(l.title)) ||
            !inFile.add('${_n(l.title)}|${_n(l.username)}');
        if (dup) {
          duplicates++;
          tick();
        } else {
          fresh.add(l);
        }
      }
      if (fresh.isNotEmpty) {
        // Throws VaultUnavailable when locked: nothing half-written.
        final saved = await vault.importLogins(fresh);
        imported += saved;
        if (saved < fresh.length) {
          failures.add('${fresh.length - saved} passwords could not be saved');
        }
        for (var i = 0; i < fresh.length; i++) {
          tick();
        }
      }
    }

    for (final n in b.notes) {
      final key = n.createdAt != null
          ? 'n|${_n(n.title)}|${_day(n.createdAt)}'
          : 'n|${_n(n.title)}|${_body(n.text)}';
      if (!seen.add(key)) {
        duplicates++;
        tick();
        continue;
      }
      await guard(n.title.isEmpty ? 'Untitled note' : n.title, () async {
        final id = await notes.createEmpty(
          title: n.title,
          initialText: n.text,
          tagNames: n.tags,
        );
        if (n.createdAt case final c?) {
          await db.customUpdate(
            'UPDATE notes SET created_at = ? WHERE id = ?',
            variables: [
              Variable.withInt(c.millisecondsSinceEpoch ~/ 1000),
              Variable.withString(id),
            ],
            updates: {db.notes},
          );
        }
        final ref = ItemRef(ItemType.note, id);
        if (n.pinned) await items.setPinned([ref], true);
        if (n.archived) await items.archive([ref]);
      });
    }

    final now = clock.now();
    for (final t in b.tasks) {
      if (!seen.add('t|${_n(t.title)}|${_day(t.due)}')) {
        duplicates++;
        tick();
        continue;
      }
      await guard(t.title, () async {
        final id = await tasks.save(
          TaskItem.draft(
            now: now,
            title: t.title,
            dueDate: t.due,
            dueTimeMinutes: t.due == null ? null : t.dueTimeMinutes,
            priority: TaskPriority.values[t.priority.clamp(0, 3)],
          ).copyWith(
            notes: t.notes,
            completedAt: t.completedAt,
            createdAt: t.createdAt,
          ),
        );
        for (final s in t.subtasks) {
          final sid = await tasks.addSubtask(id, s.title);
          if (s.done) await tasks.toggleSubtask(sid);
        }
        final ref = ItemRef(ItemType.task, id);
        if (t.tags.isNotEmpty) await items.setTags(ref, t.tags);
        if (t.archived) await items.archive([ref]);
      });
    }

    for (final r in b.reminders) {
      final at = r.at.millisecondsSinceEpoch ~/ 1000;
      if (!seen.add('r|${_n(r.title)}|$at')) {
        duplicates++;
        tick();
        continue;
      }
      await guard(r.title, () async {
        await reminders.save(
          Reminder(
            id: '',
            title: r.title,
            note: r.note,
            triggerAt: r.at,
            createdAt: r.createdAt ?? now,
            updatedAt: now,
          ),
        );
      });
    }

    for (final h in b.habits) {
      if (!seen.add('h|${_n(h.name)}')) {
        duplicates++;
        tick();
        continue;
      }
      await guard(h.name, () async {
        final start = h.startDate ?? DateUtilsX.dateOnly(now);
        final id = await habits.save(
          Habit.draft(
            startDate: start,
            name: h.name,
            kind: h.quit ? HabitKind.quit : HabitKind.build,
            targetCount: h.targetCount,
            unit: h.unit,
            frequency: HabitFrequency.fromStorage(
              type: h.frequencyType,
              weekdaysMask: h.weekdaysMask,
              timesPerWeek: h.timesPerWeek,
              everyNDays: h.everyNDays,
            ),
          ),
        );
        for (final e in h.logs.entries) {
          final day = DateTime.tryParse(e.key);
          if (day == null) continue;
          await habits.setLog(id, day, count: e.value);
        }
      });
    }

    return ImportResult(
      imported: imported,
      duplicates: duplicates,
      failed: failures.length,
      failures: failures,
    );
  }
}
