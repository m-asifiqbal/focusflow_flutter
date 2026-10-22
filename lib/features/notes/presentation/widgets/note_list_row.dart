/// ============================================================
/// NOTE LIST ROW — the compact list view of the notes list (screen 07)
/// ============================================================
///
/// What: a row card with the note tile (tinted by the note colour, lock
/// icon when locked), title, a one-line preview and the edit day; pin mark
/// or the multi-select circle at the end.
/// Why: the alternative to the masonry grid (Settings › Notes default
/// view); same data and callbacks as [NoteCard].
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/notes/domain/entities/note.dart';
import 'package:focusflow/features/notes/presentation/notes_format.dart';
import 'package:focusflow/features/notes/presentation/widgets/note_card.dart';
import 'package:focusflow/features/notes/presentation/widgets/note_card_parts.dart';

class NoteListRow extends StatelessWidget {
  const NoteListRow({
    required this.note,
    required this.now,
    this.selecting = false,
    this.selected = false,
    this.onTap,
    this.onLongPress,
    super.key,
  });

  final Note note;
  final DateTime now;
  final bool selecting;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final brightness = Theme.of(context).brightness;
    final tinted = note.colorHex != null && note.colorHex != 'FFFFFF';
    final preview = note.isLocked
        ? tr('Locked with Vault PIN')
        : NotesFormat.cardPreview(note);
    final checklist = note.checklist;
    final subtitle = preview.isNotEmpty
        ? preview
        : checklist.isEmpty
        ? null
        : tr('{done}/{total} checked', {
            'done': note.checklistDone,
            'total': checklist.length,
          });
    final colors = ModuleStyle.notes.colors;

    return FFCard(
      radius: AppRadii.row,
      color: tinted ? NoteColors.background(note.colorHex, brightness) : null,
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.md + 2,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      onTap: onTap,
      onLongPress: onLongPress,
      semanticLabel: NoteCard.semanticsOf(note, selected: selected),
      child: Row(
        children: [
          FFIconTile.soft(
            icon: note.isLocked
                ? FontAwesomeIcons.lock
                : ModuleStyle.notes.icon,
            colors: colors,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  note.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.rowTitle,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NoteCardText.preview(context),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (selecting)
            ExcludeSemantics(child: NoteSelectMark(selected: selected))
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  NotesFormat.day(note.updatedAt, now),
                  style: context.text.caption.copyWith(color: ff.inkFaint),
                ),
                if (note.isPinned) ...[
                  const SizedBox(height: AppSpacing.xs + 2),
                  const NotePinMark(size: 11),
                ],
              ],
            ),
        ],
      ),
    );
  }
}
