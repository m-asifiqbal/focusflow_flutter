/// ============================================================
/// REPOSITORY PROVIDERS — one provider per repository contract
/// ============================================================
///
/// Presentation code reads the *contract* (`ref.watch(notesRepositoryProvider)`)
/// and never sees Drift. Every repository shares the same four dependencies
/// (database, clock, device id, id generator — see RepositoryBase), so tests
/// override [databaseProvider] / [clockProvider] / [deviceIdProvider] and get
/// a fully wired, isolated graph for free.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/items/attachment_files.dart';
import 'package:focusflow/core/items/data/folders_repository_impl.dart';
import 'package:focusflow/core/items/data/items_repository_impl.dart';
import 'package:focusflow/core/items/data/repository_base.dart';
import 'package:focusflow/core/items/data/tags_repository_impl.dart';
import 'package:focusflow/core/items/folders_repository.dart';
import 'package:focusflow/core/items/items_repository.dart';
import 'package:focusflow/core/items/tags_repository.dart';
import 'package:focusflow/core/utils/clock.dart';
import 'package:focusflow/features/backup/data/repository/backup_records_repository_impl.dart';
import 'package:focusflow/features/backup/domain/repository/backup_records_repository.dart';
import 'package:focusflow/features/habits/data/repository/habits_repository_impl.dart';
import 'package:focusflow/features/habits/domain/repository/habits_repository.dart';
import 'package:focusflow/features/insights/data/repository/focus_sessions_repository_impl.dart';
import 'package:focusflow/features/insights/domain/repository/focus_sessions_repository.dart';
import 'package:focusflow/features/notes/data/repository/notes_repository_impl.dart';
import 'package:focusflow/features/notes/domain/repository/notes_repository.dart';
import 'package:focusflow/features/notifications_center/data/repository/inbox_repository_impl.dart';
import 'package:focusflow/features/notifications_center/domain/repository/inbox_repository.dart';
import 'package:focusflow/features/reminders/data/repository/reminders_repository_impl.dart';
import 'package:focusflow/features/reminders/domain/repository/reminders_repository.dart';
import 'package:focusflow/features/tasks/data/repository/tasks_repository_impl.dart';
import 'package:focusflow/features/tasks/domain/repository/tasks_repository.dart';
import 'package:focusflow/features/vault/data/repository/vault_repository_impl.dart';
import 'package:focusflow/features/vault/domain/repository/vault_repository.dart';
import 'package:focusflow/shared/providers/core_providers.dart';

/// Shared constructor arguments, so each provider below is one line of wiring.
typedef _Deps = ({
  AppDatabase db,
  Clock clock,
  String deviceId,
  IdGenerator newId,
});

_Deps _deps(Ref ref) {
  final uuid = ref.watch(uuidProvider);
  return (
    db: ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
    deviceId: ref.watch(deviceIdProvider),
    newId: uuid.v4,
  );
}

/// Where attachment / cover files live (override with a no-op store in tests).
final attachmentFileStoreProvider = Provider<AttachmentFileStore>(
  (ref) => const LocalAttachmentFileStore(),
);

// ── Shared item kernel ──

/// Lifecycle, pin/favourite, colour, folder, tags, collections, purge.
final itemsRepositoryProvider = Provider<ItemsRepository>((ref) {
  final d = _deps(ref);
  return ItemsRepositoryImpl(
    db: d.db,
    clock: d.clock,
    deviceId: d.deviceId,
    newId: d.newId,
    files: ref.watch(attachmentFileStoreProvider),
    reminders: ref.watch(remindersRepositoryProvider),
    habits: ref.watch(habitsRepositoryProvider),
  );
});

final foldersRepositoryProvider = Provider<FoldersRepository>((ref) {
  final d = _deps(ref);
  return FoldersRepositoryImpl(
    db: d.db,
    clock: d.clock,
    deviceId: d.deviceId,
    newId: d.newId,
  );
});

final tagsRepositoryProvider = Provider<TagsRepository>((ref) {
  final d = _deps(ref);
  return TagsRepositoryImpl(
    db: d.db,
    clock: d.clock,
    deviceId: d.deviceId,
    newId: d.newId,
  );
});

// ── Modules ──

final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  final d = _deps(ref);
  return NotesRepositoryImpl(
    db: d.db,
    clock: d.clock,
    deviceId: d.deviceId,
    newId: d.newId,
  );
});

final tasksRepositoryProvider = Provider<TasksRepository>((ref) {
  final d = _deps(ref);
  return TasksRepositoryImpl(
    db: d.db,
    clock: d.clock,
    deviceId: d.deviceId,
    newId: d.newId,
  );
});

final remindersRepositoryProvider = Provider<RemindersRepository>((ref) {
  final d = _deps(ref);
  return RemindersRepositoryImpl(
    db: d.db,
    clock: d.clock,
    deviceId: d.deviceId,
    newId: d.newId,
  );
});

final habitsRepositoryProvider = Provider<HabitsRepository>((ref) {
  final d = _deps(ref);
  return HabitsRepositoryImpl(
    db: d.db,
    clock: d.clock,
    deviceId: d.deviceId,
    newId: d.newId,
  );
});

/// Ciphertext only — encryption/decryption happens in the vault session
/// (core/crypto), never in the repository.
final vaultRepositoryProvider = Provider<VaultRepository>((ref) {
  final d = _deps(ref);
  return VaultRepositoryImpl(
    db: d.db,
    clock: d.clock,
    deviceId: d.deviceId,
    newId: d.newId,
  );
});

// ── Supporting data ──

final inboxRepositoryProvider = Provider<InboxRepository>((ref) {
  final d = _deps(ref);
  return InboxRepositoryImpl(
    db: d.db,
    clock: d.clock,
    deviceId: d.deviceId,
    newId: d.newId,
  );
});

final focusSessionsRepositoryProvider = Provider<FocusSessionsRepository>((
  ref,
) {
  final d = _deps(ref);
  return FocusSessionsRepositoryImpl(
    db: d.db,
    clock: d.clock,
    deviceId: d.deviceId,
    newId: d.newId,
  );
});

final backupRecordsRepositoryProvider = Provider<BackupRecordsRepository>((
  ref,
) {
  final d = _deps(ref);
  return BackupRecordsRepositoryImpl(
    db: d.db,
    clock: d.clock,
    deviceId: d.deviceId,
    newId: d.newId,
  );
});
