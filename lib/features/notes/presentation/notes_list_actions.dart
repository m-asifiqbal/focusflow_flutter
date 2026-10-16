/// ============================================================
/// NOTES LIST ACTIONS — writes behind the notes list controls (screen 07)
/// ============================================================
///
/// * [setNotesView] / [setNotesSort] persist the view toggle and the sort
///   control in Settings › Notes.
/// * [moveNote] — Manual sort: drop a dragged card onto another one.
/// * [createNoteFolder] — the "+ New folder" chip.
/// Why: widgets stay layout-only; everything goes through the settings
/// controller and the repositories (live streams refresh the list).
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/settings/app_settings.dart' as settings;
import 'package:focusflow/features/notes/domain/entities/note.dart';
import 'package:focusflow/features/notes/domain/repository/notes_repository.dart';
import 'package:focusflow/features/notes/presentation/providers/notes_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

/// Grid ↔ list, persisted.
Future<void> setNotesView(WidgetRef ref, settings.NotesView view) => ref
    .read(settingsProvider.notifier)
    .update((s) => s.copyWith(notesView: view));

/// Sort control, persisted.
Future<void> setNotesSort(WidgetRef ref, NotesSort sort) => ref
    .read(settingsProvider.notifier)
    .update((s) => s.copyWith(notesSort: settingsSortOf(sort)));

/// Moves [draggedId] to the slot of [targetId] within [visible] (the list
/// as shown): below the target when dragged downwards, above otherwise.
Future<void> moveNote(
  WidgetRef ref,
  List<Note> visible,
  String draggedId,
  String targetId,
) async {
  if (draggedId == targetId) return;
  final from = visible.indexWhere((n) => n.id == draggedId);
  final to = visible.indexWhere((n) => n.id == targetId);
  if (from < 0 || to < 0) return;
  final rest = [...visible]..removeAt(from);
  final target = rest.indexWhere((n) => n.id == targetId);
  final String? afterId;
  final String? beforeId;
  if (from < to) {
    afterId = targetId;
    beforeId = target + 1 < rest.length ? rest[target + 1].id : null;
  } else {
    afterId = target > 0 ? rest[target - 1].id : null;
    beforeId = targetId;
  }
  await ref
      .read(notesRepositoryProvider)
      .reorder(draggedId, afterId: afterId, beforeId: beforeId);
}

/// Creates (or finds) a note folder named [name] and selects its chip.
Future<String> createNoteFolder(WidgetRef ref, String name) async {
  final id = await ref
      .read(foldersRepositoryProvider)
      .create(ItemType.note, name);
  ref.read(notesListFilterProvider.notifier).selectFolder(id);
  return id;
}
