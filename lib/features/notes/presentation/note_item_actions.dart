/// ============================================================
/// NOTE ITEM ACTIONS — the note rows of the shared actions sheet (09)
/// ============================================================
///
/// Trailing rows: Share / export (PDF, TXT, Markdown) and the note's lock —
/// "Lock with a PIN" (the user picks a PIN for this note alone) or, on a
/// locked note, "Change note PIN" / "Remove note lock"; the editor adds Word
/// count. Changing, removing and exporting a locked note ask for its PIN
/// ([verifyNotePin]).
/// Owned by the notes feature; see shared/item_actions/module_item_actions.dart.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/item_summary.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/notes/domain/entities/note.dart';
import 'package:focusflow/features/notes/domain/services/note_content.dart';
import 'package:focusflow/features/notes/domain/services/note_export.dart';
import 'package:focusflow/features/notes/presentation/notes_format.dart';
import 'package:focusflow/features/notes/presentation/providers/notes_providers.dart';
import 'package:focusflow/features/notes/presentation/note_lock_flows.dart';
import 'package:focusflow/shared/item_actions/module_item_actions.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

/// Module rows for [item] (screen 09 order: … Set reminder, Share /
/// export, Lock with a PIN). Each row's onTap runs after the sheet
/// closes. "Word count" is added by the editor's More menu only
/// ([noteWordCountAction]).
Future<ModuleItemActions> noteItemActions(
  BuildContext context,
  WidgetRef ref,
  ItemSummary item,
) async {
  final note = await ref.read(notesRepositoryProvider).getNote(item.ref.id);
  if (note == null || !context.mounted) return ModuleItemActions.none;
  final share = FFActionItem(
    icon: FontAwesomeIcons.shareNodes,
    label: 'Share / export (PDF, TXT, MD)',
    colors: ActionTints.share,
    onTap: () => shareNote(context, ref, note),
  );
  return ModuleItemActions(
    readSafe: [share],
    trailing: [
      share,
      if (note.isLocked) ...[
        FFActionItem(
          icon: FontAwesomeIcons.lock,
          label: 'Change note PIN',
          colors: ActionTints.lock,
          onTap: () => unawaited(changeNotePin(context, ref, note)),
        ),
        FFActionItem(
          icon: FontAwesomeIcons.lockOpen,
          label: 'Remove note lock',
          colors: ActionTints.lock,
          onTap: () => unawaited(removeNoteLock(context, ref, note)),
        ),
      ] else
        FFActionItem(
          icon: FontAwesomeIcons.lock,
          label: 'Lock with a PIN',
          colors: ActionTints.lock,
          onTap: () => unawaited(lockNoteWithPin(context, ref, note)),
        ),
    ],
  );
}

/// The editor's extra "Word count" row of the shared actions sheet.
FFActionItem noteWordCountAction(BuildContext context, Note note) =>
    FFActionItem(
      icon: FontAwesomeIcons.fileLines,
      label: 'Word count',
      colors: TagPalette.work,
      onTap: () => showNoteWordCount(context, note),
    );

/// Format picker (PDF / TXT / Markdown) → share sheet.
Future<void> shareNote(BuildContext context, WidgetRef ref, Note note) async {
  if (note.isLocked &&
      !await verifyNotePin(
        context,
        ref,
        note,
        title: 'Enter PIN to export',
        subtitle: 'Exports are not encrypted.',
      )) {
    return;
  }
  if (!context.mounted) return;
  NoteExportFormat? format;
  await showFFActionSheet(
    context,
    FFActionSheetData(
      header: FFActionSheetHeader(
        title: 'Export note',
        icon: FontAwesomeIcons.shareNodes,
        colors: ActionTints.share,
        meta: note.displayTitle,
      ),
      actions: [
        for (final f in NoteExportFormat.values)
          FFActionItem(
            icon: switch (f) {
              NoteExportFormat.pdf => FontAwesomeIcons.solidFilePdf,
              NoteExportFormat.text => FontAwesomeIcons.fileLines,
              NoteExportFormat.markdown => FontAwesomeIcons.markdown,
            },
            label: f.label,
            colors: ModuleStyle.notes.colors,
            onTap: () => format = f,
          ),
      ],
    ),
  );
  final picked = format;
  if (picked == null || !context.mounted) return;
  final now = ref.read(clockProvider).now();
  try {
    final service = await ref.read(noteShareServiceReadyProvider.future);
    await service.share(
      note,
      picked,
      subtitle:
          '${NotesFormat.edited(note.updatedAt, now)} · '
          '${NotesFormat.words(note.wordCount)}',
    );
  } catch (_) {
    if (context.mounted) {
      showFFToast(
        context,
        "Couldn't export this note",
        icon: FontAwesomeIcons.triangleExclamation,
      );
    }
  }
}

/// Words, characters and reading time of [note].
Future<void> showNoteWordCount(BuildContext context, Note note) {
  final content = NoteContent.fromDeltaJson(note.contentDelta);
  final words = content.wordCount(note.title);
  final chars = '${note.title} ${content.plainText}'
      .replaceAll(RegExp(r'\s'), '')
      .length;
  final minutes = (words / 200).ceil().clamp(1, 999);
  return showFFDialog<void>(
    context,
    builder: (context) => FFDialog(
      icon: FontAwesomeIcons.fileLines,
      title: 'Word count',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CountRow('Words', '$words'),
          _CountRow('Characters', '$chars'),
          _CountRow('Reading time', '$minutes min'),
        ],
      ),
      actions: [
        FFPrimaryButton(
          label: 'Done',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );
}

class _CountRow extends StatelessWidget {
  const _CountRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
    child: Row(
      children: [
        Expanded(child: Text(label, style: context.text.bodySmall)),
        Text(value, style: context.text.cardTitle),
      ],
    ),
  );
}
