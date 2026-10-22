/// ============================================================
/// SCREEN 08 — NOTE EDITOR (`/notes/:id`, `/notes/new?text=&folderId=&tag=`)
/// ============================================================
///
/// Opens (or creates) the note through `noteEditorControllerProvider` and
/// shows, in order: a skeleton while loading, an error with retry, the
/// PIN lock for locked notes (the note's own PIN, [verifyNotePin]), then
/// the editor itself ([NoteEditorView]). Leaving the screen — back button,
/// swipe, or any navigation — saves pending edits and discards a new note
/// that is still empty (`NoteEditorController.close`). If the open note is
/// archived or deleted from its More sheet, the editor closes itself.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/utils/app_logger.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/notes/domain/entities/note.dart';
import 'package:focusflow/features/notes/presentation/note_lock_flows.dart';
import 'package:focusflow/features/notes/presentation/notifiers/note_editor_controller.dart';
import 'package:focusflow/features/notes/presentation/providers/notes_providers.dart';
import 'package:focusflow/features/notes/presentation/state/note_editor_state.dart';
import 'package:focusflow/features/notes/presentation/widgets/note_editor_view.dart';
import 'package:focusflow/features/notes/presentation/widgets/note_metrics.dart';
import 'package:go_router/go_router.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({
    this.noteId,
    this.text,
    this.folderId,
    this.tag,
    super.key,
  });

  /// Existing note; null creates a new one (prefilled from the query).
  final String? noteId;
  final String? text;
  final String? folderId;
  final String? tag;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  /// One controller per opened screen (see [NoteEditorArgs.session]).
  late final NoteEditorArgs _args = NoteEditorArgs(
    noteId: widget.noteId,
    text: widget.text,
    folderId: widget.folderId,
    tag: widget.tag,
    session: Object(),
  );
  NoteEditorController? _controller;
  bool? _openedActive;
  bool _askedUnlock = false;
  bool _leaving = false;

  @override
  void dispose() {
    // Saves + discards an untouched new note; keeps its provider alive.
    final controller = _controller;
    if (controller != null) {
      unawaited(
        controller.close().catchError((Object e) {
          AppLogger.w('Closing the note editor failed: ${e.runtimeType}');
          return false;
        }),
      );
    }
    super.dispose();
  }

  void _back() {
    if (_leaving) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.notes);
    }
  }

  Future<void> _unlock(NoteEditorController controller, Note note) async {
    final ok = await verifyNotePin(
      context,
      ref,
      note,
      subtitle: tr('Enter this note\'s PIN to read and edit it.'),
    );
    if (ok && mounted) controller.markUnlocked();
  }

  @override
  Widget build(BuildContext context) {
    final provider = noteEditorControllerProvider(_args);
    _controller = ref.watch(provider.notifier);
    final editor = ref.watch(provider);

    return editor.when(
      skipLoadingOnReload: true,
      loading: () => _NoteEditorSkeleton(onBack: _back),
      error: (error, _) => _NoteEditorError(
        message: error is NoteNotFoundException
            ? error.toString()
            : tr('Something went wrong while opening it.'),
        onBack: _back,
        onRetry: error is NoteNotFoundException
            ? null
            : () => ref.invalidate(provider),
      ),
      data: (state) => _loaded(state),
    );
  }

  Widget _loaded(NoteEditorState state) {
    final controller = _controller!;
    final noteProv = noteProvider(state.noteId);
    ref.listen(noteProv, (_, next) {
      final note = next.valueOrNull;
      // Archived / deleted from the More sheet → leave the editor.
      if (_openedActive == true && (note == null || !note.isActive)) {
        _openedActive = false;
        _back();
        _leaving = true;
      }
    });
    final async = ref.watch(noteProv);
    final Note? note = async.valueOrNull;
    if (note == null) {
      return async.hasError
          ? _NoteEditorError(
              message: tr('Something went wrong while opening it.'),
              onBack: _back,
              onRetry: () => ref.invalidate(noteProv),
            )
          : _NoteEditorSkeleton(onBack: _back);
    }
    _openedActive ??= note.isActive;

    // Each note opens with its own PIN: another note being open, or the
    // Vault being unlocked, says nothing about this one.
    if (note.isLocked && !state.unlocked) {
      if (!_askedUnlock) {
        _askedUnlock = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_unlock(controller, note));
        });
      }
      return _NoteLocked(
        onBack: _back,
        onUnlock: () => _unlock(controller, note),
      );
    }
    return NoteEditorView(
      note: note,
      state: state,
      controller: controller,
      onBack: _back,
    );
  }
}

class _BackOnly extends StatelessWidget {
  const _BackOnly({required this.onBack, required this.child});

  final VoidCallback onBack;
  final Widget child;

  @override
  Widget build(BuildContext context) => FFScaffold(
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FFNavHeader(leading: FFBackButton(onPressed: onBack)),
        Expanded(child: child),
      ],
    ),
  );
}

class _NoteEditorSkeleton extends StatelessWidget {
  const _NoteEditorSkeleton({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => _BackOnly(
    onBack: onBack,
    child: const FFShimmer(
      child: Padding(
        padding: EdgeInsetsDirectional.all(AppSpacing.screen),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FFSkeleton(
              width: NoteEditorMetrics.skeletonMetaWidth,
              height: NoteEditorMetrics.skeletonMeta,
            ),
            SizedBox(height: AppSpacing.xl),
            FFSkeleton(
              widthFactor: 0.8,
              height: NoteEditorMetrics.skeletonTitle,
            ),
            SizedBox(height: AppSpacing.md),
            FFSkeleton(
              widthFactor: 0.5,
              height: NoteEditorMetrics.skeletonLine,
            ),
            SizedBox(height: AppSpacing.xxl),
            FFSkeleton(height: NoteEditorMetrics.skeletonLine),
            SizedBox(height: AppSpacing.md),
            FFSkeleton(height: NoteEditorMetrics.skeletonLine),
            SizedBox(height: AppSpacing.md),
            FFSkeleton(
              widthFactor: 0.6,
              height: NoteEditorMetrics.skeletonLine,
            ),
          ],
        ),
      ),
    ),
  );
}

class _NoteEditorError extends StatelessWidget {
  const _NoteEditorError({
    required this.message,
    required this.onBack,
    this.onRetry,
  });

  final String message;
  final VoidCallback onBack;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => _BackOnly(
    onBack: onBack,
    child: FFEmptyState(
      colors: ModuleStyle.notes.colors,
      icon: FontAwesomeIcons.triangleExclamation,
      title: tr('Couldn\'t open this note'),
      body: message,
      ctaLabel: onRetry == null ? tr('Back to notes') : tr('Try again'),
      ctaIcon: onRetry == null
          ? FontAwesomeIcons.arrowLeft
          : FontAwesomeIcons.arrowsRotate,
      onCta: onRetry ?? onBack,
    ),
  );
}

class _NoteLocked extends StatelessWidget {
  const _NoteLocked({required this.onBack, required this.onUnlock});

  final VoidCallback onBack;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) => _BackOnly(
    onBack: onBack,
    child: FFEmptyState(
      colors: ModuleStyle.vault.colors,
      icon: FontAwesomeIcons.lock,
      title: tr('This note is locked'),
      body: tr('Enter its PIN to read and edit it.'),
      ctaLabel: tr('Unlock'),
      ctaIcon: FontAwesomeIcons.lockOpen,
      onCta: onUnlock,
    ),
  );
}
