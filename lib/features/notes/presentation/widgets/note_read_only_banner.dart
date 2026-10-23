/// ============================================================
/// NOTE READ-ONLY BANNER — "Archived — restore it to edit."
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/notes/domain/entities/note.dart';
import 'package:focusflow/features/notes/presentation/widgets/note_body_actions.dart';

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
          ? tr('In Recently Deleted — restore it to edit.')
          : tr('Archived — restore it to edit.'),
      actionLabel: tr('Restore'),
      onAction: () => restoreNote(context, ref, note),
    );
  }
}
