/// ============================================================
/// NOTES TOOLBAR — folder chips + "Last edited ⇅ · Select" (screen 07)
/// ============================================================
///
/// What: the horizontally scrolling folder chips (All, Ideas, Work… and
/// "+ New folder") and the row with the sort control (left) and Select
/// (right).
/// Why: the chips come live from [noteFoldersProvider]; the selected chip
/// and sort are read from the list providers so every change refilters.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/notes/presentation/providers/notes_providers.dart';
import 'package:focusflow/features/notes/presentation/widgets/notes_menus.dart';
import 'package:focusflow/shared/item_actions/item_selection.dart';

/// Chip value of "+ New folder" (never a real folder id).
const String _newFolder = '\u0000new-folder';

class NotesFolderChips extends ConsumerWidget {
  const NotesFolderChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(noteFoldersProvider).valueOrNull ?? const [];
    final selected = ref.watch(
      notesListFilterProvider.select((f) => f.folderId),
    );
    return FFChipBar<String?>(
      selected: selected,
      items: [
        FFChipItem(value: null, label: tr('All')),
        for (final f in folders) FFChipItem(value: f.id, label: f.name),
        FFChipItem(
          value: _newFolder,
          label: tr('New folder'),
          icon: FontAwesomeIcons.plus,
        ),
      ],
      onSelected: (value) {
        if (value == _newFolder) {
          promptNewNoteFolder(context, ref);
          return;
        }
        ref.read(notesListFilterProvider.notifier).selectFolder(value);
      },
    );
  }
}

/// "⇅ Last edited" (opens the sort picker) and "☑ Select".
class NotesSortRow extends ConsumerWidget {
  const NotesSortRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ff = context.ff;
    final sort = ref.watch(notesSortProvider);
    final style = context.text.meta.copyWith(fontSize: 14);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.screen,
        AppSpacing.xs,
        AppSpacing.screen,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: _RowButton(
                semanticLabel: tr('Sort: {label}', {'label': sort.label}),
                onTap: () => pickNotesSort(context, ref),
                icon: Icon(
                  FontAwesomeIcons.arrowDownWideShort,
                  size: 14,
                  color: ff.inkFaint,
                ),
                label: Text(
                  sort.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style.copyWith(color: ff.inkFaint),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          _RowButton(
            semanticLabel: tr('Select notes'),
            onTap: () => ref
                .read(itemSelectionProvider(notesSelectionScope).notifier)
                .start(),
            icon: Icon(
              FontAwesomeIcons.squareCheck,
              size: 15,
              color: ff.primary,
            ),
            label: Text(
              tr('Select'),
              style: style.copyWith(
                color: ff.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RowButton extends StatelessWidget {
  const _RowButton({
    required this.semanticLabel,
    required this.onTap,
    required this.icon,
    required this.label,
  });

  final String semanticLabel;
  final VoidCallback onTap;
  final Widget icon;
  final Widget label;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semanticLabel,
    excludeSemantics: true,
    child: FFPressable(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.minTap),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: AppSpacing.sm),
            Flexible(child: label),
          ],
        ),
      ),
    ),
  );
}
