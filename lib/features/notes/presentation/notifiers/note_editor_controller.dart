/// ============================================================
/// NOTE EDITOR CONTROLLER — load / create, debounced auto-save, discard
/// ============================================================
///
/// `noteEditorControllerProvider(args)` (AsyncNotifier):
///   * opens an existing note, or creates a new one for `/notes/new`
///     (folder / tag / text prefilled, default colour from Settings);
///   * [onChanged] / [onEdited] debounce writes by 600 ms ("Saving…" →
///     "AUTO-SAVED"); [flush] writes immediately (back, app paused,
///     dispose). [onEdited] takes a *reader*: the editor reports each
///     keystroke for free and the note is serialised once, at save time —
///     not per keystroke (which made typing in long notes stutter);
///   * derives plain text, checklist, word count and cover image from the
///     Delta (NoteContent) so lists and search stay in sync;
///   * [close] prunes images removed from the body and discards a new
///     note that is still empty.
/// Note contents are never logged.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/utils/app_logger.dart';
import 'package:focusflow/features/notes/domain/repository/notes_repository.dart';
import 'package:focusflow/features/notes/domain/services/note_content.dart';
import 'package:focusflow/features/notes/presentation/providers/notes_providers.dart';
import 'package:focusflow/features/notes/presentation/state/note_editor_state.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

/// Thrown when the requested note no longer exists.
class NoteNotFoundException implements Exception {
  const NoteNotFoundException();

  @override
  String toString() => 'This note no longer exists.';
}

class NoteEditorController
    extends AutoDisposeFamilyAsyncNotifier<NoteEditorState, NoteEditorArgs> {
  static const Duration debounce = Duration(milliseconds: 600);

  late NotesRepository _repo;
  Timer? _timer;
  NoteDraft? _pending;
  NoteDraft Function()? _read;
  NoteDraft? _saved;
  String? _cover;
  String? _noteId;
  bool _disposed = false;
  bool _closed = false;
  Future<void> _writes = Future.value();
  Future<void>? _closeGate;

  @override
  Future<NoteEditorState> build(NoteEditorArgs arg) async {
    _repo = ref.read(notesRepositoryProvider);
    ref.onDispose(() {
      _disposed = true;
      _timer?.cancel();
      _resolve();
      final pending = _pending;
      _pending = null;
      // Never lose an edit: finish the write even after the screen closed.
      if (pending != null) unawaited(_write(pending, notify: false));
    });

    final id = arg.noteId ?? await _create(arg);
    final note = await _repo.getNote(id);
    if (note == null) throw const NoteNotFoundException();
    _saved = NoteDraft(title: note.title, deltaJson: note.contentDelta);
    _cover = note.coverImagePath;
    _noteId = id;
    return NoteEditorState(noteId: id, createdHere: arg.isNew);
  }

  Future<String> _create(NoteEditorArgs arg) {
    final tag = arg.tag?.trim() ?? '';
    return _repo.createEmpty(
      folderId: arg.folderId,
      colorHex: ref.read(settingsProvider).notesDefaultColor,
      tagNames: [if (tag.isNotEmpty) tag],
      initialText: arg.text ?? '',
    );
  }

  NoteEditorState? get _current => state.valueOrNull;

  void _setStatus(NoteSaveStatus status) {
    if (_disposed) return;
    final s = _current;
    if (s != null && s.status != status) {
      state = AsyncData(s.copyWith(status: status));
    }
  }

  /// The editor content changed — saved [debounce] after the last change.
  void onChanged(NoteDraft draft) {
    if (_current == null) return;
    _timer?.cancel();
    _read = null;
    if (draft == _saved) {
      _pending = null;
      _setStatus(NoteSaveStatus.saved);
      return;
    }
    _pending = draft;
    _setStatus(NoteSaveStatus.saving);
    _timer = Timer(debounce, () => unawaited(flush()));
  }

  /// The editor content changed; [read] builds the draft when the save
  /// runs. Cheap enough to call on every keystroke.
  void onEdited(NoteDraft Function() read) {
    if (_current == null) return;
    _timer?.cancel();
    _read = read;
    _pending = null;
    _setStatus(NoteSaveStatus.saving);
    _timer = Timer(debounce, () => unawaited(flush()));
  }

  /// Builds a pending [onEdited] draft now. The editor calls this before
  /// disposing the controllers the reader uses.
  void capture() => _resolve();

  void _resolve() {
    final read = _read;
    if (read == null) return;
    _read = null;
    try {
      _pending = read();
    } catch (e) {
      AppLogger.w('Reading the note draft failed: ${e.runtimeType}');
    }
  }

  /// Writes any pending change now (back, app paused).
  Future<void> flush() async {
    _timer?.cancel();
    _resolve();
    final pending = _pending;
    _pending = null;
    if (pending != null && pending != _saved) {
      await _write(pending);
    } else if (pending != null) {
      _setStatus(NoteSaveStatus.saved); // edited back to what is stored
    }
    await _writes;
  }

  Future<void> _write(NoteDraft draft, {bool notify = true}) {
    final id = _noteId;
    if (id == null) return Future.value();
    Future<void> run() async {
      final content = NoteContent.fromDeltaJson(draft.deltaJson);
      try {
        await _repo.saveContent(
          id,
          title: draft.title.trim(),
          deltaJson: draft.deltaJson,
          plainText: content.plainText,
          checklist: content.checklist,
          wordCount: content.wordCount(draft.title),
        );
        if (content.coverImage != _cover) {
          _cover = content.coverImage;
          await _repo.setCover(id, _cover);
        }
        _saved = draft;
        if (notify && _pending == null && _timer?.isActive != true) {
          _setStatus(NoteSaveStatus.saved);
        }
      } catch (e) {
        AppLogger.w('Note auto-save failed: ${e.runtimeType}');
        if (notify) _setStatus(NoteSaveStatus.failed);
      }
    }

    // Serialise writes so an older draft never overwrites a newer one.
    return _writes = _writes.then((_) => run());
  }

  /// [close] waits for [work] before its final save — the view hands in
  /// "stop dictation and insert the final words" so they are not lost.
  void holdCloseUntil(Future<void> work) {
    _closeGate = work.catchError((Object _) {});
  }

  /// A locked note was unlocked with the vault PIN.
  void markUnlocked() {
    final s = _current;
    if (s != null) state = AsyncData(s.copyWith(unlocked: true));
  }

  /// Copies the picked image into the note's attachments and returns its
  /// relative path (to embed in the body), or null on failure.
  Future<String?> addImage(String sourcePath) async {
    final id = _current?.noteId;
    if (id == null) return null;
    try {
      final store = await ref.read(noteFileStoreProvider.future);
      final stored = await store.importImage(
        sourcePath,
        ref.read(uuidProvider).v4(),
      );
      await _repo.addAttachment(
        id,
        localPath: stored.relativePath,
        fileName: stored.fileName,
        mimeType: stored.mimeType,
        sizeBytes: stored.sizeBytes,
      );
      return stored.relativePath;
    } catch (e) {
      AppLogger.w('Adding a note image failed: ${e.runtimeType}');
      return null;
    }
  }

  // ── Note attributes (header, tags row, colour row) ──

  /// Card colour from the editor's colour row ([NoteColors.hexes]); white
  /// is stored as null (the default card).
  Future<void> setColor(String? hex) async {
    final id = _noteId;
    if (id == null) return;
    final value = hex == null || hex.toUpperCase() == 'FFFFFF' ? null : hex;
    await _repo.setColor(id, value);
  }

  Future<void> setPinned(bool pinned) async {
    final id = _noteId;
    if (id != null) await _repo.setPinned(id, pinned);
  }

  /// Adds tag [name] (created when missing). Leading `#` is ignored.
  Future<void> addTag(String name) async {
    final id = _noteId;
    final clean = name.replaceAll('#', '').trim();
    if (id == null || clean.isEmpty) return;
    final note = await _repo.getNote(id);
    if (note == null) return;
    final names = [for (final t in note.tags) t.name];
    if (names.any((n) => n.toLowerCase() == clean.toLowerCase())) return;
    await _repo.setTags(id, [...names, clean]);
  }

  Future<void> removeTag(String name) async {
    final id = _noteId;
    if (id == null) return;
    final note = await _repo.getNote(id);
    if (note == null) return;
    await _repo.setTags(id, [
      for (final t in note.tags)
        if (t.name.toLowerCase() != name.toLowerCase()) t.name,
    ]);
  }

  /// Leaving the editor (called once when the screen goes away): saves,
  /// drops images no longer in the body and discards a new note that is
  /// still empty. Returns true when the note was discarded. Keeps the
  /// provider alive until done, so it is safe to call from `dispose`.
  Future<bool> close() async {
    if (_closed) return false;
    _closed = true;
    final link = ref.keepAlive();
    try {
      final NoteEditorState s;
      try {
        s = state.valueOrNull ?? await future;
      } catch (_) {
        return false; // never opened (missing note) — nothing to save.
      }
      final gate = _closeGate;
      if (gate != null) await gate;
      await flush();
      final keep = NoteContent.fromDeltaJson(
        _saved?.deltaJson ?? '[]',
      ).imagePaths.toSet();
      try {
        final orphaned = await _repo.pruneAttachments(s.noteId, keep);
        if (orphaned.isNotEmpty) {
          final store = await ref.read(noteFileStoreProvider.future);
          for (final path in orphaned) {
            await store.delete(path);
          }
        }
      } catch (e) {
        AppLogger.w('Pruning note images failed: ${e.runtimeType}');
      }
      if (!s.createdHere) return false;
      return await _repo.deleteIfEmpty(s.noteId);
    } finally {
      link.close();
    }
  }
}

final noteEditorControllerProvider = AsyncNotifierProvider.autoDispose
    .family<NoteEditorController, NoteEditorState, NoteEditorArgs>(
      NoteEditorController.new,
    );
