/// ============================================================
/// NOTE LINK SHEET — "Linked note" picker of the task editor
/// ============================================================
///
/// What: a searchable list of active notes (live) plus "No linked note";
/// resolves to a [Picked] `(id, title)` (null value = unlink), or null
/// when dismissed.
/// Why: tasks link one note (e.g. "Q3 Roadmap"); the link is saved with the
/// task, so the sheet only returns the choice.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/tasks/presentation/providers/task_editor_providers.dart';
import 'package:focusflow/features/tasks/presentation/widgets/pickers/picker_common.dart';

/// The picked note.
typedef NoteLink = ({String id, String title});

/// Opens the note picker; [currentId] marks the linked note.
Future<Picked<NoteLink?>?> showNoteLinkSheet(
  BuildContext context, {
  String? currentId,
}) {
  return showFFBottomSheet<Picked<NoteLink?>>(
    context,
    wrap: false,
    builder: (_) => _NoteLinkSheet(currentId: currentId),
  );
}

class _NoteLinkSheet extends ConsumerStatefulWidget {
  const _NoteLinkSheet({this.currentId});

  final String? currentId;

  @override
  ConsumerState<_NoteLinkSheet> createState() => _NoteLinkSheetState();
}

class _NoteLinkSheetState extends ConsumerState<_NoteLinkSheet> {
  String _query = '';

  void _pop(NoteLink? link) => Navigator.of(context).pop(Picked(link));

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(linkableNotesProvider(_query));
    final noteTint = ModuleStyle.notes.colors;
    return FFBottomSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetHeader(tr('Linked note')),
          FFSearchField(
            hint: tr('Search notes'),
            onChanged: (q) => setState(() => _query = q),
            onClear: () => setState(() => _query = ''),
          ),
          const SizedBox(height: AppSpacing.lg),
          switch (notes) {
            AsyncData(:final value) => FFGroupedList(
              dividerIndent: AppSpacing.lg,
              children: [
                if (widget.currentId != null && _query.isEmpty)
                  OptionRow(
                    label: tr('No linked note'),
                    icon: FontAwesomeIcons.linkSlash,
                    colors: ActionTints.lock,
                    selected: false,
                    onTap: () => _pop(null),
                  ),
                for (final n in value)
                  OptionRow(
                    label: n.displayTitle,
                    icon: n.isLocked
                        ? FontAwesomeIcons.lock
                        : FontAwesomeIcons.solidNoteSticky,
                    colors: noteTint,
                    selected: n.id == widget.currentId,
                    onTap: () => _pop((id: n.id, title: n.displayTitle)),
                  ),
                if (value.isEmpty)
                  FFListRow(
                    title: _query.isEmpty
                        ? tr('No notes yet')
                        : tr('No matching notes'),
                    enabled: false,
                  ),
              ],
            ),
            AsyncError() => FFErrorBanner(
              message: tr('Couldn\'t load notes'),
              onRetry: () => ref.invalidate(linkableNotesProvider(_query)),
            ),
            _ => const FFSkeletonRow(),
          },
        ],
      ),
    );
  }
}
