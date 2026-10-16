/// ============================================================
/// NOTE BODY ACTIONS — what the editor's buttons do to the open note
/// ============================================================
///
/// Toolbar formatting on the Quill selection (heading / bold / italic /
/// bullets / checklist / quote), image insertion (gallery or camera →
/// attachments → embed), voice dictation (speech_to_text → text at the
/// cursor), and the header / tags-row follow-ups (More sheet, folder,
/// tags, reminder, restore). Writes go through the editor controller or
/// the shared item pickers — never straight to the database.
/// ============================================================
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/items/tag.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/notes/data/files/note_image_picker.dart';
import 'package:focusflow/features/notes/data/voice/voice_dictation.dart';
import 'package:focusflow/features/notes/domain/entities/note.dart';
import 'package:focusflow/features/notes/presentation/note_item_actions.dart';
import 'package:focusflow/features/notes/presentation/notes_format.dart';
import 'package:focusflow/features/notes/presentation/notifiers/note_editor_controller.dart';
import 'package:focusflow/features/notes/presentation/providers/notes_providers.dart';
import 'package:focusflow/features/notes/presentation/widgets/note_editor_toolbar.dart';
import 'package:focusflow/shared/item_actions/item_actions_sheet.dart';
import 'package:focusflow/shared/item_actions/item_lifecycle_actions.dart';
import 'package:focusflow/shared/item_actions/item_pickers.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:go_router/go_router.dart';

/// Relative image path → file in the app documents directory.
typedef NoteImageResolver = File? Function(String relativePath);

/// The editor meta line parts ("Edited today, 9:12 AM", "214 words",
/// "Reminder Fri").
({String edited, String words, String? reminder}) noteMeta(
  WidgetRef ref,
  Note note,
) {
  final now = ref.read(clockProvider).now();
  final use24h = ref.watch(settingsProvider.select((s) => s.use24HourTime));
  final at = note.reminderAt;
  return (
    edited: NotesFormat.edited(note.updatedAt, now, use24h: use24h),
    words: NotesFormat.words(note.wordCount),
    reminder: at == null ? null : NotesFormat.reminder(at, now, use24h: use24h),
  );
}

/// Restores an archived / deleted note (banner of read-only notes).
Future<void> restoreNote(BuildContext context, WidgetRef ref, Note note) =>
    note.isDeleted
    ? restoreFromTrash(context, ref, [note.ref], title: note.displayTitle)
    : restoreFromArchive(context, ref, [note.ref], title: note.displayTitle);

class NoteBodyActions {
  NoteBodyActions({
    required this.quill,
    required this.controller,
    required this.onListening,
  });

  final QuillController quill;
  final NoteEditorController controller;

  /// Dictation started / stopped (the toolbar tints the mic).
  final ValueChanged<bool> onListening;

  bool listening = false;

  /// Set once the editor is going away: late recognition callbacks must
  /// never touch the (soon disposed) Quill controller.
  bool _closed = false;
  String _lastWords = '';
  int _voiceStart = 0;
  int _voiceLength = 0;
  String _voicePrefix = '';

  // ── Formatting ──

  /// Formats applied at the cursor / selection.
  Set<NoteFormat> activeFormats() {
    final attrs = quill.getSelectionStyle().attributes;
    final list = attrs[Attribute.list.key]?.value;
    return {
      if (attrs[Attribute.header.key]?.value != null) NoteFormat.heading,
      if (attrs.containsKey(Attribute.bold.key)) NoteFormat.bold,
      if (attrs.containsKey(Attribute.italic.key)) NoteFormat.italic,
      if (list == Attribute.ul.value) NoteFormat.bullets,
      if (list == Attribute.checked.value || list == Attribute.unchecked.value)
        NoteFormat.checklist,
      if (attrs.containsKey(Attribute.blockQuote.key)) NoteFormat.quote,
    };
  }

  /// Toggles [format] on the selection (block formats on its lines).
  void toggle(NoteFormat format) {
    final on = activeFormats().contains(format);
    final Attribute<Object?> attribute = switch (format) {
      NoteFormat.heading => Attribute.h3,
      NoteFormat.bold => Attribute.bold,
      NoteFormat.italic => Attribute.italic,
      NoteFormat.bullets => Attribute.ul,
      NoteFormat.checklist => Attribute.unchecked,
      NoteFormat.quote => Attribute.blockQuote,
    };
    quill.formatSelection(on ? Attribute.clone(attribute, null) : attribute);
  }

  // ── Image ──

  /// Gallery / camera → copied into attachments → embedded at the cursor.
  Future<void> addImage(BuildContext context, WidgetRef ref) async {
    final source = await _pickSource(context);
    if (source == null || !context.mounted) return;
    final picker = ref.read(noteImagePickerProvider);
    final String? path;
    try {
      path = await picker.pick(source);
    } catch (_) {
      if (context.mounted) {
        showFFToast(
          context,
          source == NoteImageSource.camera
              ? 'Camera access is off — allow it in Settings'
              : 'Photo access is off — allow it in Settings',
          icon: FontAwesomeIcons.triangleExclamation,
        );
      }
      return;
    }
    if (path == null) return;
    final relative = await controller.addImage(path);
    if (!context.mounted) return;
    if (relative == null) {
      showFFToast(
        context,
        "Couldn't add the image",
        icon: FontAwesomeIcons.triangleExclamation,
      );
      return;
    }
    final sel = quill.selection;
    final end = quill.document.length - 1;
    final index = sel.isValid ? sel.start.clamp(0, end) : end;
    final length = sel.isValid
        ? (sel.end - sel.start).clamp(0, end - index)
        : 0;
    quill.replaceText(
      index,
      length,
      BlockEmbed.image(relative),
      TextSelection.collapsed(offset: index + 1),
    );
  }

  Future<NoteImageSource?> _pickSource(BuildContext context) async {
    NoteImageSource? picked;
    await showFFActionSheet(
      context,
      FFActionSheetData(
        actions: [
          FFActionItem(
            icon: FontAwesomeIcons.images,
            label: 'Choose from library',
            colors: ModuleStyle.notes.colors,
            onTap: () => picked = NoteImageSource.gallery,
          ),
          FFActionItem(
            icon: FontAwesomeIcons.camera,
            label: 'Take photo',
            colors: ModuleStyle.scan.colors,
            onTap: () => picked = NoteImageSource.camera,
          ),
        ],
      ),
    );
    return picked;
  }

  // ── Voice ──

  /// Starts dictation at the cursor, or stops it.
  Future<void> toggleVoice(BuildContext context, WidgetRef ref) async {
    final voice = ref.read(voiceDictationProvider);
    if (listening) {
      await voice.stop();
      _setListening(false);
      return;
    }
    final sel = quill.selection;
    final end = quill.document.length - 1;
    _voiceStart = sel.isValid ? sel.start.clamp(0, end) : end;
    _voiceLength = 0;
    _lastWords = '';
    final before = _voiceStart == 0
        ? ''
        : quill.document.toPlainText().substring(_voiceStart - 1, _voiceStart);
    _voicePrefix = before.isEmpty || before.trim().isEmpty ? '' : ' ';
    final ok = await voice.start(
      onText: _insertDictation,
      onDone: (text) {
        _insertDictation(text);
        _setListening(false);
      },
    );
    if (!ok) {
      if (context.mounted) {
        showFFToast(
          context,
          "Speech recognition isn't available",
          icon: FontAwesomeIcons.microphone,
        );
      }
      return;
    }
    _setListening(true);
  }

  void _setListening(bool on) {
    if (listening == on) return;
    listening = on;
    onListening(on);
  }

  void _insertDictation(String words) {
    if (_closed) return;
    _lastWords = words;
    final text = words.trim().isEmpty ? '' : '$_voicePrefix${words.trim()}';
    final end = quill.document.length - 1;
    final start = _voiceStart.clamp(0, end);
    quill.replaceText(
      start,
      _voiceLength.clamp(0, end - start),
      text,
      TextSelection.collapsed(offset: start + text.length),
    );
    _voiceLength = text.length;
  }

  /// Stops a running dictation when the editor closes: waits for the
  /// recogniser to stop (its final result may arrive meanwhile and is
  /// inserted), makes sure the last transcript is in the body, then ignores
  /// any later callback. The caller disposes the Quill controller only
  /// after this completes.
  Future<void> close(VoiceDictation voice) async {
    if (_closed) return;
    try {
      if (listening) {
        try {
          await voice.stop();
        } catch (_) {
          // A failing recogniser must not block closing the editor.
        }
        if (_lastWords.trim().isNotEmpty) _insertDictation(_lastWords);
      }
    } finally {
      _closed = true;
      listening = false;
    }
  }

  // ── Header / tags row ──

  /// The shared item actions sheet (screen 09) after saving pending edits.
  Future<void> showMore(BuildContext context, WidgetRef ref, Note note) async {
    await controller.flush();
    if (!context.mounted) return;
    await showItemActions(
      context,
      ref,
      note.ref,
      extraActions: [noteWordCountAction(context, note)],
    );
  }

  Future<void> moveToFolder(BuildContext context, WidgetRef ref, Note note) =>
      moveItemsToFolder(context, ref, ItemType.note, [note.ref]);

  Future<void> addTags(BuildContext context, WidgetRef ref, Note note) =>
      addTagsToItems(context, ref, [note.ref]);

  /// Removes [tag] from the note with an Undo snackbar.
  Future<void> removeTag(BuildContext context, Tag tag) async {
    await controller.removeTag(tag.name);
    if (!context.mounted) return;
    showUndoSnackbar(
      context,
      message: '#${tag.name} removed',
      icon: FontAwesomeIcons.tag,
      onUndo: () => unawaited(controller.addTag(tag.name)),
    );
  }

  void openReminder(BuildContext context, Note note) {
    final id = note.reminderId;
    if (id != null) unawaited(context.push(AppRoutes.reminder(id)));
  }
}
