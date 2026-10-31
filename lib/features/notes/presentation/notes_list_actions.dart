/// ============================================================
/// NOTES LIST ACTIONS — writes behind the notes list controls (screen 07)
/// ============================================================
///
/// * [setNotesView] / [setNotesSort] persist the view toggle and the sort
///   control in Settings › Notes.
/// * [moveNote] — drop a dragged card onto another one (any sort; the
///   list then sorts by Manual).
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
/// Works from any sort: the shown order, with the move, becomes the manual
/// order and the list switches to "Manual" (so the note stays where it was
/// dropped). True when it switched.
Future<bool> moveNote(
  WidgetRef ref,
  List<Note> visible,
  String draggedId,
  String targetId,
) async {
  if (draggedId == targetId) return false;
  final from = visible.indexWhere((n) => n.id == draggedId);
  final to = visible.indexWhere((n) => n.id == targetId);
  if (from < 0 || to < 0) return false;
  final order = [for (final n in visible) n.id]..removeAt(from);
  final target = order.indexOf(targetId);
  order.insert(from < to ? target + 1 : target, draggedId);
  await ref.read(notesRepositoryProvider).setManualOrder(order);
  if (ref.read(notesSortProvider) == NotesSort.manual) return false;
  await setNotesSort(ref, NotesSort.manual);
  return true;
}

/// Creates (or finds) a note folder named [name] and selects its chip.
Future<String> createNoteFolder(WidgetRef ref, String name) async {
  final id = await ref
      .read(foldersRepositoryProvider)
      .create(ItemType.note, name);
  ref.read(notesListFilterProvider.notifier).selectFolder(id);
  return id;
}
