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
/// title + time, habits by name, logins by title + username + website
/// (the username / URL of existing vault items live in the encrypted
/// payload and are read with the unlocked vault through [vaultLogin]; an
/// item that can't be read never counts as a duplicate, so distinct logins
/// are never dropped). Existing items are read from one DB snapshot.
/// Why: importing the same export twice must not double everything.
/// Logins go to the vault bridge one by one (encrypted with the unlocked
/// session), so the counts stay exact if the vault locks half-way.
/// [write] throws only before anything was written; after that every
/// failure is per item and listed in the [ImportResult].
/// Nothing here logs item contents.
/// ============================================================
library;

import 'dart:typed_data';

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

/// Username + website of an existing vault item (decrypted in memory with
/// the unlocked vault), or null when it can't be read.
typedef VaultLoginReader =
    Future<({String username, String url})?> Function(
      String itemId,
      Uint8List encryptedPayload,
    );

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
    this.vaultLogin,
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

  /// Reads existing vault logins for dedupe (null = titles can't be
  /// compared with usernames: nothing in the vault counts as a duplicate).
  final VaultLoginReader? vaultLogin;

  static String _n(Object? s) => '${s ?? ''}'.trim().toLowerCase();
  static String _day(DateTime? d) => d == null ? '' : DateUtilsX.dayKey(d);
  static DateTime? _sec(Object? v) =>
      v is int ? DateTime.fromMillisecondsSinceEpoch(v * 1000) : null;

  /// Website for dedupe: no scheme, no `www.`, no trailing slash.
  static String _site(String url) => _n(url)
      .replaceFirst(RegExp(r'^[a-z][a-z0-9+.-]*://'), '')
      .replaceFirst(RegExp(r'^www\.'), '')
      .replaceFirst(RegExp(r'/+$'), '');

  static String _loginKey(String title, String username, String url) =>
      '${_n(title)}|${_n(username)}|${_site(url)}';

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
    final vaultLogins = <String>{};
    if (b.logins.isNotEmpty && vaultLogin != null) {
      for (final r in existing.rows('vault_items')) {
        final id = r['id'], blob = r['encrypted_payload'];
        if (r['deleted_at'] != null || id is! String || blob is! Uint8List) {
          continue;
        }
        final login = await vaultLogin!(id, blob);
        if (login == null) continue; // unreadable: never a duplicate
        vaultLogins.add(
          _loginKey('${r['title'] ?? ''}', login.username, login.url),
        );
      }
    }

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
        final key = _loginKey(l.title, l.username, l.url);
        if (vaultLogins.contains(key) || !inFile.add(key)) {
          duplicates++;
          tick();
        } else {
          fresh.add(l);
        }
      }
      for (final (i, l) in fresh.indexed) {
        try {
          final saved = await vault.importLogins([l]);
          if (saved == 1) {
            imported++;
          } else {
            failures.add('${_label(l)}: could not be saved');
          }
        } on VaultUnavailable catch (e) {
          // Nothing written yet → the caller unlocks and retries.
          if (i == 0) rethrow;
          final left = fresh.length - i;
          failures.add(
            '$left ${left == 1 ? 'password was' : 'passwords were'} not '
            'imported: ${e.message}',
          );
          for (var j = i; j < fresh.length; j++) {
            tick();
          }
          break;
        } on Object {
          if (i == 0) rethrow;
          failures.add('${_label(l)}: could not be saved');
        }
        tick();
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

  /// A login's name for the failure list (never its secrets).
  static String _label(ImportedLogin l) =>
      l.title.trim().isEmpty ? 'Imported login' : l.title.trim();
}
