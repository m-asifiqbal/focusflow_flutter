/// ============================================================
/// NOTE EDITOR VIEW — the open note: header, tags, title, Quill, toolbar
/// ============================================================
///
/// Owns the UI controllers (Quill document, title text, scroll, focus) of
/// one open note and forwards every edit to [NoteEditorController], which
/// debounces the save. The live [Note] (pin, colour, tags, folder, meta)
/// comes from `noteProvider`, so changes made elsewhere (actions sheet,
/// another screen) show up immediately. Archived / deleted notes open
/// read-only with a Restore banner.
/// ============================================================
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/notes/data/voice/voice_dictation.dart';
import 'package:focusflow/features/notes/domain/entities/note.dart';
import 'package:focusflow/features/notes/presentation/notifiers/note_editor_controller.dart';
import 'package:focusflow/features/notes/presentation/providers/notes_providers.dart';
import 'package:focusflow/features/notes/presentation/state/note_editor_state.dart';
import 'package:focusflow/features/notes/presentation/widgets/note_body_actions.dart';
import 'package:focusflow/features/notes/presentation/widgets/note_editor_header.dart';
import 'package:focusflow/features/notes/presentation/widgets/note_editor_meta.dart';
import 'package:focusflow/features/notes/presentation/widgets/note_editor_toolbar.dart';
import 'package:focusflow/features/notes/presentation/widgets/note_quill_styles.dart';
import 'package:focusflow/features/notes/presentation/widgets/note_metrics.dart';

class NoteEditorView extends ConsumerStatefulWidget {
  const NoteEditorView({
    required this.note,
    required this.state,
    required this.controller,
    required this.onBack,
    super.key,
  });

  /// The live note (re-delivered on every change).
  final Note note;
  final NoteEditorState state;
  final NoteEditorController controller;
  final VoidCallback onBack;

  @override
  ConsumerState<NoteEditorView> createState() => _NoteEditorViewState();
}

class _NoteEditorViewState extends ConsumerState<NoteEditorView>
    with WidgetsBindingObserver {
  late final QuillController _quill;
  late final TextEditingController _title;
  final _scroll = ScrollController();
  final _bodyFocus = FocusNode();
  final _titleFocus = FocusNode();
  StreamSubscription<DocChange>? _changes;
  late final NoteBodyActions _actions;
  late final VoiceDictation _voice;

  bool get _readOnly => !widget.note.isActive;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _voice = ref.read(voiceDictationProvider);
    final note = widget.note;
    _quill = QuillController(
      document: _document(note.contentDelta),
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: _readOnly,
    );
    _title = TextEditingController(text: note.title)..addListener(_onEdit);
    _changes = _quill.document.changes.listen((change) {
      if (change.source == ChangeSource.local) _onEdit();
    });
    _quill.addListener(_onSelection);
    _actions = NoteBodyActions(
      quill: _quill,
      controller: widget.controller,
      onListening: (on) {
        if (mounted) setState(() {});
      },
    );
    // A brand-new note starts in the title (or after prefilled text).
    if (widget.state.createdHere) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _readOnly) return;
        if (note.plainText.isEmpty) {
          _titleFocus.requestFocus();
        } else {
          _quill.moveCursorToEnd();
          _bodyFocus.requestFocus();
        }
      });
    }
  }

  static Document _document(String json) {
    try {
      final ops = jsonDecode(json);
      if (ops is List && ops.isNotEmpty) return Document.fromJson(ops);
    } catch (_) {
      // Fall through: an unreadable body opens empty rather than crashing.
    }
    return Document();
  }

  @override
  void didUpdateWidget(NoteEditorView old) {
    super.didUpdateWidget(old);
    _quill.readOnly = _readOnly;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Never lose an edit when the app is backgrounded or killed.
    if (state != AppLifecycleState.resumed) {
      unawaited(widget.controller.flush());
    }
  }

  void _onEdit() => widget.controller.onChanged(
    NoteDraft(
      title: _title.text,
      deltaJson: jsonEncode(_quill.document.toDelta().toJson()),
    ),
  );

  void _onSelection() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _quill.removeListener(_onSelection);
    if (_actions.listening) {
      // Dictation running: stop it first, let the final words land in the
      // body (and reach the controller's last save), then dispose Quill.
      final quill = _quill;
      final title = _title;
      final changes = _changes;
      final stopping = _actions.close(_voice);
      widget.controller.holdCloseUntil(stopping);
      unawaited(
        stopping.whenComplete(() {
          changes?.cancel();
          quill.dispose();
          title.dispose();
        }),
      );
    } else {
      unawaited(_actions.close(_voice));
      _changes?.cancel();
      _quill.dispose();
      _title.dispose();
    }
    _scroll.dispose();
    _bodyFocus.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final note = widget.note;
    final readOnly = _readOnly;
    final store = ref.watch(noteFileStoreProvider).valueOrNull;
    final base = ff.isDark ? ff.canvas : ff.surface;
    final background = Color.alphaBlend(
      NoteColors.background(note.colorHex, Theme.of(context).brightness),
      base,
    );
    final meta = noteMeta(ref, note);

    return FFScaffold(
      backgroundColor: background,
      safeBottom: readOnly,
      body: Column(
        children: [
          NoteEditorHeader(
            folderName: note.folderName ?? 'Notes',
            status: widget.state.status,
            showStatus: !readOnly,
            pinned: note.isPinned,
            onBack: widget.onBack,
            onPin: readOnly
                ? null
                : () => widget.controller.setPinned(!note.isPinned),
            onMore: () => _actions.showMore(context, ref, note),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _scroll,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.screen,
                AppSpacing.md,
                AppSpacing.screen,
                AppSpacing.xxxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (readOnly) ...[
                    NoteReadOnlyBanner(note: note),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  NoteTagsRow(
                    folderName: note.folderName,
                    tags: note.tags,
                    onFolder: readOnly
                        ? null
                        : () => _actions.moveToFolder(context, ref, note),
                    onTag: readOnly
                        ? null
                        : (tag) => _actions.removeTag(context, tag),
                    onAdd: readOnly
                        ? null
                        : () => _actions.addTags(context, ref, note),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _titleField(context, readOnly),
                  const SizedBox(height: AppSpacing.sm),
                  NoteMetaLine(
                    edited: meta.edited,
                    words: meta.words,
                    reminder: meta.reminder,
                    onReminder: () => _actions.openReminder(context, note),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _body(context, store?.resolve),
                ],
              ),
            ),
          ),
          if (!readOnly)
            NoteEditorToolbar(
              colorHex: note.colorHex,
              onColor: widget.controller.setColor,
              canUndo: _quill.hasUndo,
              onUndo: _quill.undo,
              onRedo: () {
                if (_quill.hasRedo) _quill.redo();
              },
              active: _actions.activeFormats(),
              onFormat: _actions.toggle,
              onImage: () => _actions.addImage(context, ref),
              onVoice: () => _actions.toggleVoice(context, ref),
              listening: _actions.listening,
            ),
        ],
      ),
    );
  }

  Widget _titleField(BuildContext context, bool readOnly) {
    final ff = context.ff;
    final style = context.text.largeTitle.copyWith(
      fontSize: NoteEditorMetrics.titleSize,
      height: NoteEditorMetrics.titleLineHeight,
      color: ff.ink,
    );
    return TextField(
      controller: _title,
      focusNode: _titleFocus,
      readOnly: readOnly,
      maxLines: null,
      minLines: 1,
      textInputAction: TextInputAction.next,
      textCapitalization: TextCapitalization.sentences,
      onSubmitted: (_) => _bodyFocus.requestFocus(),
      style: style,
      cursorColor: ff.primary,
      decoration: InputDecoration(
        hintText: 'Title',
        hintStyle: style.copyWith(color: ff.inkFaint),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: false,
        isCollapsed: true,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _body(BuildContext context, NoteImageResolver? resolve) {
    final ff = context.ff;
    return QuillEditor(
      controller: _quill,
      focusNode: _bodyFocus,
      scrollController: _scroll,
      config: QuillEditorConfig(
        scrollable: false,
        expands: false,
        padding: EdgeInsets.zero,
        minHeight: NoteEditorMetrics.bodyMinHeight,
        placeholder: 'Start writing…',
        textCapitalization: TextCapitalization.sentences,
        keyboardAppearance: Theme.of(context).brightness,
        customStyles: noteQuillStyles(context),
        customStyleBuilder: (attr) =>
            noteCustomStyle(attr, ff) ?? const TextStyle(),
        embedBuilders: [NoteImageEmbedBuilder(resolve ?? (_) => null)],
        checkBoxReadOnly: _readOnly,
      ),
    );
  }
}

/// Archived / Recently Deleted notes open read-only.
class NoteReadOnlyBanner extends ConsumerWidget {
  const NoteReadOnlyBanner({required this.note, super.key});

  final Note note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deleted = note.isDeleted;
    return FFInfoBanner(
      icon: deleted ? FontAwesomeIcons.trashCan : FontAwesomeIcons.boxArchive,
      text: deleted
          ? 'In Recently Deleted — restore it to edit.'
          : 'Archived — restore it to edit.',
      actionLabel: 'Restore',
      onAction: () => restoreNote(context, ref, note),
    );
  }
}
