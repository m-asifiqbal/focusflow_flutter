/// ============================================================
/// NOTES LIST STATES — loading, empty and error bodies (screen 07)
/// ============================================================
///
/// * [NotesLoadingState] two columns of skeleton cards.
/// * [NotesEmptyState]   "Write your first note" (no notes at all, with a
///   tappable hint that pre-fills quick capture) or
///   "No notes in Work" / "No matching notes" (a filter is on).
/// * [NotesErrorState]   load failure with Retry.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/quick_add/presentation/quick_add.dart';

class NotesLoadingState extends StatelessWidget {
  const NotesLoadingState({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: tr('Loading notes'),
    child: const Padding(
      padding: EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.screen),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: [
                FFSkeletonCard(lines: 4),
                SizedBox(height: AppSpacing.cardGap),
                FFSkeletonCard(lines: 2, showTag: false),
              ],
            ),
          ),
          SizedBox(width: AppSpacing.cardGap),
          Expanded(
            child: Column(
              children: [
                FFSkeletonCard(lines: 2),
                SizedBox(height: AppSpacing.cardGap),
                FFSkeletonCard(lines: 3),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class NotesEmptyState extends StatelessWidget {
  const NotesEmptyState({
    required this.hasNotes,
    required this.onCreate,
    this.folderName,
    this.onClearFilter,
    super.key,
  });

  /// False when there are no notes at all (first-run copy).
  final bool hasNotes;

  /// The selected folder chip, for "No notes in Work".
  final String? folderName;
  final VoidCallback onCreate;
  final VoidCallback? onClearFilter;

  /// Example capture of the first-run hint; parses as a note.
  static String get hintText => tr('Gift ideas for Sam #ideas');

  @override
  Widget build(BuildContext context) {
    final colors = ModuleStyle.notes.colors;
    if (!hasNotes) {
      return FFEmptyState(
        colors: colors,
        icon: ModuleStyle.notes.icon,
        title: tr('Write your first note'),
        body: tr(
          'Capture ideas, checklists and meeting notes. They stay on this device, encrypted.',
        ),
        ctaLabel: tr('New note'),
        ctaIcon: FontAwesomeIcons.plus,
        onCta: onCreate,
        // Screen 29: the hint pre-fills quick capture (plain text → note).
        hint: tr('Try: "{hintText}"', {'hintText': hintText}),
        onHint: () => showQuickAdd(context, text: hintText),
      );
    }
    return FFEmptyState.compact(
      colors: colors,
      icon: FontAwesomeIcons.magnifyingGlass,
      title: folderName != null
          ? tr('No notes in {folderName}', {'folderName': folderName})
          : tr('No matching notes'),
      body: folderName != null
          ? tr('Notes you add to this folder show up here.')
          : tr('Try another word or clear the filters.'),
      ctaLabel: folderName != null ? tr('New note') : tr('Clear filters'),
      ctaIcon: folderName != null ? FontAwesomeIcons.plus : null,
      onCta: folderName != null ? onCreate : onClearFilter,
    );
  }
}

class NotesErrorState extends StatelessWidget {
  const NotesErrorState({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => FFEmptyState.compact(
    colors: ModuleStyle.notes.colors,
    icon: FontAwesomeIcons.triangleExclamation,
    title: tr('Couldn\'t load your notes'),
    body: tr('Something went wrong reading the notes on this device.'),
    ctaLabel: tr('Retry'),
    ctaIcon: FontAwesomeIcons.arrowsRotate,
    onCta: onRetry,
  );
}
