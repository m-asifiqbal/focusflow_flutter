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
///
/// Performance: a keystroke or cursor move must not rebuild the screen.
/// Only the toolbar listens to Quill (through a value-equal
/// [NoteToolState], so it rebuilds only when Undo / formats / colour
/// change), edits hand the controller a lazy draft (serialised once per
/// save, not per key), and the Quill styles are built once per theme.
/// ============================================================
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/features/notes/presentation/widgets/note_caret_handle.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/notes/data/voice/voice_dictation.dart';
import 'package:focusflow/features/notes/domain/entities/note.dart';
import 'package:focusflow/features/notes/presentation/note_lock_flows.dart';
import 'package:focusflow/features/notes/presentation/notifiers/note_editor_controller.dart';
import 'package:focusflow/features/notes/presentation/providers/notes_providers.dart';
import 'package:focusflow/features/notes/presentation/state/note_editor_state.dart';
import 'package:focusflow/features/notes/presentation/widgets/note_body_actions.dart';
import 'package:focusflow/features/notes/presentation/widgets/note_editor_header.dart';
import 'package:focusflow/features/notes/presentation/widgets/note_editor_meta.dart';
import 'package:focusflow/features/notes/presentation/widgets/note_editor_toolbar.dart';
import 'package:focusflow/features/notes/presentation/widgets/note_quill_styles.dart';
import 'package:focusflow/features/notes/presentation/widgets/note_metrics.dart';
import 'package:focusflow/features/notes/presentation/widgets/note_read_only_banner.dart';

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
  final _editorKey = GlobalKey<QuillEditorState>();
  final _titleFocus = FocusNode();
  StreamSubscription<DocChange>? _changes;
  late final NoteBodyActions _actions;
  late final VoiceDictation _voice;
  final _tools = ValueNotifier(const NoteToolState());
  late String _lastTitle;
  DefaultStyles? _styles;
  Object? _stylesKey;

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
    _lastTitle = note.title;
    _title = TextEditingController(text: note.title)..addListener(_onTitle);
    _changes = _quill.document.changes.listen((change) {
      if (change.source == ChangeSource.local) _onEdit();
    });
    _quill.addListener(_syncTools);
    _actions = NoteBodyActions(
      quill: _quill,
      controller: widget.controller,
      onListening: (on) {
        if (mounted) setState(() {});
      },
    );
    _syncTools();
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

  /// The header's padlock: lock this note with its own PIN, or — when it is
  /// locked already — Change PIN / Remove lock. A note locked from here stays
  /// open for this editing session.
  Future<void> _lock(Note note) async {
    await widget.controller.flush();
    if (!mounted) return;
    if (note.isLocked) {
      await showNoteLockOptions(context, ref, note);
    } else if (await lockNoteWithPin(context, ref, note)) {
      widget.controller.markUnlocked();
    }
  }

  void _onEdit() => widget.controller.onEdited(_draft);

  NoteDraft _draft() => NoteDraft(
    title: _title.text,
    deltaJson: jsonEncode(_quill.document.toDelta().toJson()),
  );

  /// The title controller also notifies on cursor moves: only text counts.
  void _onTitle() {
    if (_title.text == _lastTitle) return;
    _lastTitle = _title.text;
    _onEdit();
  }

  void _syncTools() => _tools.value = _actions.toolState();

  /// Quill styles, rebuilt only when the theme / text styles / direction
  /// change (not on every note re-delivery).
  DefaultStyles _quillStyles(BuildContext context) {
    final key = (context.ff, context.text, Directionality.of(context));
    if (key != _stylesKey || _styles == null) {
      _stylesKey = key;
      _styles = noteQuillStyles(context);
    }
    return _styles!;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _quill.removeListener(_syncTools);
    _tools.dispose();
    final controller = widget.controller;
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
          controller.capture();
          changes?.cancel();
          quill.dispose();
          title.dispose();
        }),
      );
    } else {
      unawaited(_actions.close(_voice));
      controller.capture();
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
            folderName: note.folderName ?? tr('Notes'),
            status: widget.state.status,
            showStatus: !readOnly,
            pinned: note.isPinned,
            locked: note.isLocked,
            onLock: readOnly ? null : () => unawaited(_lock(note)),
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
          if (!readOnly) _toolbar(note),
        ],
      ),
    );
  }

  Widget _toolbar(Note note) {
    final collapsed = ref.watch(noteToolbarCollapsedProvider);
    return ValueListenableBuilder<NoteToolState>(
      valueListenable: _tools,
      builder: (context, tools, _) => NoteEditorToolbar(
        colorHex: note.colorHex,
        onColor: widget.controller.setColor,
        tools: tools,
        onUndo: _quill.undo,
        onRedo: () {
          if (_quill.hasRedo) _quill.redo();
        },
        onFormat: _actions.toggle,
        onTextColor: _actions.setTextColor,
        onImage: () => _actions.addImage(context, ref),
        onVoice: () => _actions.toggleVoice(context, ref),
        listening: _actions.listening,
        collapsed: collapsed,
        onCollapsed: ref.read(noteToolbarCollapsedProvider.notifier).set,
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
        hintText: tr('Title'),
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
    // Quill shows no handle for a plain caret; NoteCaretHandle adds a
    // draggable one (Android) so the cursor can be slid, not only tapped.
    return NoteCaretHandle(
      controller: _quill,
      focusNode: _bodyFocus,
      editorKey: _editorKey,
      scrollController: _scroll,
      readOnly: _readOnly,
      child: _editor(context, resolve),
    );
  }

  Widget _editor(BuildContext context, NoteImageResolver? resolve) {
    final ff = context.ff;
    return QuillEditor(
      key: _editorKey,
      controller: _quill,
      focusNode: _bodyFocus,
      scrollController: _scroll,
      config: QuillEditorConfig(
        scrollable: false,
        expands: false,
        padding: EdgeInsets.zero,
        minHeight: NoteEditorMetrics.bodyMinHeight,
        placeholder: tr('Start writing…'),
        textCapitalization: TextCapitalization.sentences,
        keyboardAppearance: Theme.of(context).brightness,
        customStyles: _quillStyles(context),
        // Markdown-style starts: "1. " begins a numbered list, "- " bullets.
        // Experimental in flutter_quill 11 (pinned ^11.4): if an upgrade
        // changes it, the analyzer flags this line.
        // ignore: experimental_member_use
        spaceShortcutEvents: [
          formatOrderedNumberToList,
          formatHyphenToBulletList,
        ],
        customStyleBuilder: (attr) =>
            noteCustomStyle(attr, ff) ?? const TextStyle(),
        embedBuilders: [NoteImageEmbedBuilder(resolve ?? (_) => null)],
        checkBoxReadOnly: _readOnly,
      ),
    );
  }
}
