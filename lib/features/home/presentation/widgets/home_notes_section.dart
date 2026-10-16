/// ============================================================
/// HOME NOTES SECTION — "Recent Notes ……… See All"
/// ============================================================
///
/// What: the four most recent notes (pinned first) as two-column cards,
/// reusing the notes list's NoteCard (note colour, first tag, pin mark,
/// checklist preview, "2H AGO" footer). Empty: compact empty state with
/// "New note".
/// Why: one card design for notes everywhere; tap opens the editor,
/// long-press the shared item actions sheet.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/home/presentation/home_tokens.dart';
import 'package:focusflow/features/home/presentation/providers/home_providers.dart';
import 'package:focusflow/features/home/presentation/widgets/home_section_states.dart';
import 'package:focusflow/features/notes/domain/entities/note.dart';
import 'package:focusflow/features/notes/presentation/widgets/note_card.dart';
import 'package:focusflow/features/tasks/presentation/providers/minute_clock.dart';
import 'package:focusflow/shared/item_actions/item_actions_sheet.dart';
import 'package:go_router/go_router.dart';
import 'package:focusflow/features/home/presentation/widgets/home_section_link.dart';

class HomeNotesSection extends ConsumerWidget {
  const HomeNotesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(homeRecentNotesProvider);
    final Widget body = notes.when(
      skipLoadingOnReload: true,
      error: (_, _) => HomeErrorCard(
        onRetry: () => ref.invalidate(homeRecentNotesProvider),
      ),
      loading: () => const FFSkeletonList(count: 1),
      data: (value) => value.isEmpty
          ? HomeEmptyCard(
              colors: ModuleStyle.notes.colors,
              icon: ModuleStyle.notes.icon,
              title: 'No notes yet',
              body: 'Jot down an idea — it will show up here.',
              ctaLabel: 'New note',
              onCta: () => context.push(AppRoutes.newNote),
            )
          : _NotesGrid(notes: value),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FFSectionHeader(
          title: 'Recent Notes',
          trailing: HomeSectionLink(
            'See All',
            onPressed: () => context.push(AppRoutes.notes),
          ),
        ),
        const SizedBox(height: HomeDimens.linkHeaderGap),
        body,
      ],
    );
  }
}

class _NotesGrid extends ConsumerWidget {
  const _NotesGrid({required this.notes});

  final List<Note> notes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(minuteClockProvider);
    Widget card(Note n) => NoteCard(
      key: ValueKey(n.id),
      note: n,
      now: now,
      onTap: () => context.push(AppRoutes.note(n.id)),
      onLongPress: () => showItemActions(context, ref, n.ref),
    );

    final rows = <Widget>[];
    for (var i = 0; i < notes.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: HomeDimens.noteGap));
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: card(notes[i])),
            const SizedBox(width: HomeDimens.noteGap),
            Expanded(
              child: i + 1 < notes.length
                  ? card(notes[i + 1])
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}
