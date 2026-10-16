/// ============================================================
/// NOTES PROVIDERS — live data + services for screens 07 / 08
/// ============================================================
///
/// * [notesListFilterProvider] — folder chip + search text of the list.
/// * [notesListProvider]       — live notes for the filter and the sort
///   persisted in Settings (pinned first, from the repository).
/// * [notesCountsProvider] / [noteFoldersProvider] — header + chips.
/// * [noteProvider]            — one live note (editor, sheets).
/// * file / share / voice services, overridable in tests.
/// ============================================================
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/folder.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/settings/app_settings.dart' as settings;
import 'package:focusflow/features/notes/data/export/note_pdf_builder.dart';
import 'package:focusflow/features/notes/data/export/note_share_service.dart';
import 'package:focusflow/features/notes/data/files/note_file_store.dart';
import 'package:focusflow/features/notes/data/files/note_image_picker.dart';
import 'package:focusflow/features/notes/data/voice/voice_dictation.dart';
import 'package:focusflow/features/notes/domain/entities/note.dart';
import 'package:focusflow/features/notes/domain/repository/notes_repository.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:path_provider/path_provider.dart';

/// Selection scope of the notes list (see shared/item_actions/item_selection).
const String notesSelectionScope = 'notes';

/// Folder chip + tag filter (search field's sliders) + search text.
@immutable
class NotesListFilter {
  const NotesListFilter({this.folderId, this.tagId, this.text = ''});

  /// Selected folder chip (null = All).
  final String? folderId;

  /// Tag picked from the search field's filter button (null = any).
  final String? tagId;
  final String text;

  /// True when anything narrows the list (empty state copy).
  bool get isFiltered => folderId != null || tagId != null || text.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is NotesListFilter &&
      other.folderId == folderId &&
      other.tagId == tagId &&
      other.text == text;

  @override
  int get hashCode => Object.hash(folderId, tagId, text);
}

class NotesListFilterController extends AutoDisposeNotifier<NotesListFilter> {
  @override
  NotesListFilter build() => const NotesListFilter();

  void selectFolder(String? folderId) => state = NotesListFilter(
    folderId: folderId,
    tagId: state.tagId,
    text: state.text,
  );

  void selectTag(String? tagId) => state = NotesListFilter(
    folderId: state.folderId,
    tagId: tagId,
    text: state.text,
  );

  void search(String text) => state = NotesListFilter(
    folderId: state.folderId,
    tagId: state.tagId,
    text: text.trim(),
  );
}

final notesListFilterProvider =
    NotifierProvider.autoDispose<NotesListFilterController, NotesListFilter>(
      NotesListFilterController.new,
    );

/// Settings › Notes sort, as the repository's sort enum.
NotesSort notesSortOf(settings.NotesSort s) => NotesSort.values.byName(s.name);

/// The repository sort as the persisted settings value.
settings.NotesSort settingsSortOf(NotesSort s) =>
    settings.NotesSort.values.byName(s.name);

final notesSortProvider = Provider.autoDispose<NotesSort>(
  (ref) => notesSortOf(ref.watch(settingsProvider.select((s) => s.notesSort))),
);

/// Grid (masonry) or list view, persisted in Settings › Notes.
final notesViewProvider = Provider.autoDispose<settings.NotesView>(
  (ref) => ref.watch(settingsProvider.select((s) => s.notesView)),
);

/// Live notes of the list screen (pinned first).
final notesListProvider = StreamProvider.autoDispose<List<Note>>((ref) {
  final filter = ref.watch(notesListFilterProvider);
  final sort = ref.watch(notesSortProvider);
  return ref
      .watch(notesRepositoryProvider)
      .watchNotes(
        NotesQuery(
          folderId: filter.folderId,
          tagId: filter.tagId,
          text: filter.text,
          sort: sort,
        ),
      );
});

/// "48 notes · 3 pinned" + per-folder counts.
final notesCountsProvider = StreamProvider.autoDispose<NotesCounts>(
  (ref) => ref.watch(notesRepositoryProvider).watchCounts(),
);

/// Note folders (chips), in manual order with counts.
final noteFoldersProvider = StreamProvider.autoDispose<List<Folder>>(
  (ref) => ref.watch(foldersRepositoryProvider).watchFolders(ItemType.note),
);

/// One note, live (null when gone).
final noteProvider = StreamProvider.autoDispose.family<Note?, String>(
  (ref, id) => ref.watch(notesRepositoryProvider).watchNote(id),
);

// ── Services ──

/// The app documents directory (override in tests with a temp dir).
final appDocumentsDirProvider = FutureProvider<Directory>(
  (ref) => getApplicationDocumentsDirectory(),
);

/// Images of notes (copy in, resolve relative paths, delete).
final noteFileStoreProvider = FutureProvider<NoteFileStore>(
  (ref) async => NoteFileStore(await ref.watch(appDocumentsDirProvider.future)),
);

/// PDF / TXT / MD export + share sheet.
final noteShareServiceProvider = Provider<NoteShareService>((ref) {
  final store = ref.watch(noteFileStoreProvider).valueOrNull;
  return NoteShareService(pdf: NotePdfBuilder(resolveImage: store?.resolve));
});

/// [noteShareServiceProvider] once the file store is loaded, so a PDF
/// export never misses its images because the documents directory wasn't
/// resolved yet. A store failure still exports (text only).
final noteShareServiceReadyProvider = FutureProvider<NoteShareService>((
  ref,
) async {
  try {
    await ref.watch(noteFileStoreProvider.future);
  } catch (_) {
    // Export without images rather than not at all.
  }
  return ref.watch(noteShareServiceProvider);
});

/// Speech-to-text for the editor's mic button (fake it in tests).
final voiceDictationProvider = Provider<VoiceDictation>(
  (ref) => DeviceVoiceDictation(),
);

/// Gallery / camera picker for the editor's image button (fake in tests).
final noteImagePickerProvider = Provider<NoteImagePicker>(
  (ref) => DeviceNoteImagePicker(),
);
