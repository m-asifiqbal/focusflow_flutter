/// ============================================================
/// NOTE CARD — one card of the notes masonry grid (screen 07)
/// ============================================================
///
/// What: radius-22 card in the note's colour with the first tag, the pin
/// (or lock) mark, title (15.5 w600), up to 6 preview lines, an optional
/// cover image and checklist preview, and the "TODAY · IDEAS" footer. In
/// multi-select mode a check circle sits top-right.
/// Why: pure presentation over a [Note]; taps / long-presses are handled by
/// the caller (open, select, actions sheet), swipes by ItemSwipe.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/notes/domain/entities/note.dart';
import 'package:focusflow/features/notes/presentation/notes_format.dart';
import 'package:focusflow/features/notes/presentation/widgets/note_card_parts.dart';

class NoteCard extends StatelessWidget {
  const NoteCard({
    required this.note,
    required this.now,
    this.selecting = false,
    this.selected = false,
    this.onTap,
    this.onLongPress,
    super.key,
  });

  final Note note;

  /// "Today" / "Yesterday" reference for the footer.
  final DateTime now;
  final bool selecting;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Spoken summary of the card.
  static String semanticsOf(Note note, {bool selected = false}) => [
    note.displayTitle,
    if (note.isPinned) 'pinned',
    if (note.isLocked) 'locked',
    if (selected) 'selected',
  ].join(', ');

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final bg = NoteColors.background(
      note.colorHex,
      Theme.of(context).brightness,
    );
    final locked = note.isLocked;
    final cover = locked ? null : note.coverImagePath;
    final tag = note.tags.isEmpty ? null : note.tags.first;
    final preview = NotesFormat.cardPreview(note);
    final checklist = locked ? const <ChecklistItem>[] : note.checklist;
    final marks = !selecting && (note.isPinned || locked);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (cover != null)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              0,
            ),
            child: NoteCover(path: cover),
          ),
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            AppSpacing.lg,
            cover != null ? AppSpacing.md : AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.lg + 2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (tag != null || marks || selecting) ...[
                Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: tag == null ? null : FFTag(tag.name),
                      ),
                    ),
                    // The mockup's pin sits a little above the tag's centre.
                    if (marks && note.isPinned)
                      Transform.translate(
                        offset: const Offset(0, -AppSpacing.xs),
                        child: const NotePinMark(),
                      ),
                    if (marks && note.isPinned && locked)
                      const SizedBox(width: AppSpacing.sm),
                    if (marks && locked) const NoteLockMark(),
                    // Room for the selection circle.
                    if (selecting) const SizedBox(width: 24, height: 17),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              Text(
                note.displayTitle,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: NoteCardText.title(context),
              ),
              if (preview.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  preview,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: NoteCardText.preview(context),
                ),
              ],
              if (checklist.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                NoteChecklistPreview(items: checklist),
              ],
              if (locked) const NoteLockedPreview(),
              const SizedBox(height: AppSpacing.md),
              Text(
                NotesFormat.cardFooter(note, now).toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: NoteCardText.footer(context),
              ),
            ],
          ),
        ),
      ],
    );

    return Stack(
      children: [
        FFCard(
          color: bg,
          padding: EdgeInsetsDirectional.zero,
          onTap: onTap,
          onLongPress: onLongPress,
          semanticLabel: semanticsOf(note, selected: selected),
          child: content,
        ),
        if (selecting)
          PositionedDirectional(
            top: AppSpacing.md,
            end: AppSpacing.md,
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: selected ? null : ff.cardShadow,
                  ),
                  child: NoteSelectMark(selected: selected),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
