/// ============================================================
/// NOTE EDITOR HEADER — back · folder + save status · pin · more
/// ============================================================
///
/// Screen 08 top bar: round back button, centred folder name over the
/// auto-save status ("AUTO-SAVED" with a cloud, "SAVING…", "NOT SAVED"),
/// and the Lock + Pin + More round buttons. Pure presentation: callbacks
/// only.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/notes/presentation/state/note_editor_state.dart';

class NoteEditorHeader extends StatelessWidget {
  const NoteEditorHeader({
    required this.folderName,
    required this.status,
    required this.onBack,
    this.pinned = false,
    this.locked = false,
    this.onLock,
    this.onPin,
    this.onMore,
    this.showStatus = true,
    super.key,
  });

  /// Folder of the note ("Ideas"); "Notes" when it has none.
  final String folderName;
  final NoteSaveStatus status;
  final VoidCallback onBack;
  final bool pinned;

  /// The note has its own PIN (the icon shows a closed padlock).
  final bool locked;

  /// The lock button: lock the note with a PIN, or (locked) Change / Remove.
  /// Null hides it (read-only notes).
  final VoidCallback? onLock;

  /// Null hides the button (locked / read-only notes).
  final VoidCallback? onPin;
  final VoidCallback? onMore;
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.xl,
        AppSpacing.xxs,
        AppSpacing.xl,
        0,
      ),
      child: SizedBox(
        height: AppSizes.roundButton + AppSpacing.xs,
        // The title is centred between the buttons (mockup), not on screen.
        child: Row(
          children: [
            _Halo(child: FFBackButton(onPressed: onBack)),
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.sm,
                ),
                child: Center(
                  child: _Title(
                    folderName: folderName,
                    status: showStatus ? status : null,
                  ),
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onLock != null) ...[
                  _Halo(
                    child: FFRoundIconButton(
                      icon: locked
                          ? FontAwesomeIcons.lock
                          : FontAwesomeIcons.lockOpen,
                      semanticLabel: locked
                          ? 'Note is locked. Change or remove the PIN'
                          : 'Lock note with a PIN',
                      iconColor: locked ? null : context.ff.inkFaint,
                      onPressed: onLock,
                    ),
                  ),
                  if (onPin != null || onMore != null)
                    const SizedBox(width: 10),
                ],
                if (onPin != null)
                  _Halo(
                    child: FFRoundIconButton(
                      icon: FontAwesomeIcons.thumbtack,
                      semanticLabel: pinned ? 'Unpin note' : 'Pin note',
                      iconColor: pinned ? null : context.ff.inkFaint,
                      onPressed: onPin,
                    ),
                  ),
                if (onPin != null && onMore != null) const SizedBox(width: 10),
                if (onMore != null)
                  _Halo(
                    child: FFRoundIconButton(
                      icon: FontAwesomeIcons.ellipsis,
                      semanticLabel: 'More note actions',
                      onPressed: onMore,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.folderName, required this.status});

  final String folderName;
  final NoteSaveStatus? status;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final s = status;
    final (IconData icon, String label, Color color) = switch (s) {
      NoteSaveStatus.saving => (
        FontAwesomeIcons.arrowsRotate,
        'Saving…',
        ff.inkFaint,
      ),
      NoteSaveStatus.failed => (
        FontAwesomeIcons.triangleExclamation,
        'Not saved',
        ff.danger,
      ),
      _ => (FontAwesomeIcons.cloudArrowUp, 'Auto-saved', ff.success),
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text(
            folderName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.navTitle.copyWith(fontSize: 15),
          ),
        ),
        if (s != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Semantics(
            liveRegion: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 11, color: color),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.sectionLabel.copyWith(
                      fontSize: 9.5,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Soft all-round halo behind the round buttons — on the white editor
/// canvas the card shadow alone is too faint (mockup).
class _Halo extends StatelessWidget {
  const _Halo({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          for (final s in ff.cardShadow)
            BoxShadow(
              color: s.color,
              blurRadius: s.blurRadius / 2,
              offset: Offset(0, s.offset.dy / 2),
            ),
        ],
      ),
      child: child,
    );
  }
}
