/// ============================================================
/// NOTES MENUS — the sheets behind the notes list controls (screen 07)
/// ============================================================
///
/// * [showNotesMoreMenu]   header ⋯: add note, select, sort, new folder, tags &
///   folders, archive, recently deleted.
/// * [pickNotesSort]       "Last edited ⇅": Last edited, Created,
///   Title A–Z, Colour, Manual (drag).
/// * [pickNotesTagFilter]  the search field's sliders: filter by tag.
/// * [promptNewNoteFolder] the "+ New folder" chip.
/// Why: pickers only; the writes live in notes_list_actions.dart.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/library/presentation/widgets/choice_sheets.dart';
import 'package:focusflow/features/notes/domain/repository/notes_repository.dart';
import 'package:focusflow/features/notes/presentation/notes_list_actions.dart';
import 'package:focusflow/features/notes/presentation/providers/notes_providers.dart';
import 'package:focusflow/shared/item_actions/item_selection.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:go_router/go_router.dart';

/// Icon of each sort option.
IconData notesSortIcon(NotesSort sort) => switch (sort) {
  NotesSort.lastEdited => FontAwesomeIcons.clockRotateLeft,
  NotesSort.created => FontAwesomeIcons.calendarPlus,
  NotesSort.titleAz => FontAwesomeIcons.arrowDownAZ,
  NotesSort.colour => FontAwesomeIcons.palette,
  NotesSort.manual => FontAwesomeIcons.gripVertical,
};

/// The header's ⋯ menu.
Future<void> showNotesMoreMenu(BuildContext context, WidgetRef ref) =>
    showFFActionSheet(
      context,
      FFActionSheetData(
        header: FFActionSheetHeader(
          title: tr('Notes'),
          icon: ModuleStyle.notes.icon,
          colors: ModuleStyle.notes.colors,
          meta: tr('View options'),
        ),
        actions: [
          FFActionItem(
            icon: FontAwesomeIcons.plus,
            label: tr('Add new note'),
            colors: ModuleStyle.notes.colors,
            // Into the folder being viewed, like the screen's own New note.
            onTap: () => context.push(
              AppRoutes.newNoteWith(
                folderId: ref.read(notesListFilterProvider).folderId,
              ),
            ),
          ),
          FFActionItem(
            icon: FontAwesomeIcons.solidSquareCheck,
            label: tr('Select notes'),
            colors: ModuleStyle.notes.colors,
            onTap: () => ref
                .read(itemSelectionProvider(notesSelectionScope).notifier)
                .start(),
          ),
          FFActionItem(
            icon: FontAwesomeIcons.arrowDownWideShort,
            label: tr('Sort by…'),
            colors: TagPalette.design,
            onTap: () => pickNotesSort(context, ref),
          ),
          FFActionItem(
            icon: FontAwesomeIcons.folderPlus,
            label: tr('New folder'),
            colors: TagPalette.work,
            onTap: () => promptNewNoteFolder(context, ref),
          ),
          FFActionItem(
            icon: FontAwesomeIcons.tags,
            label: tr('Tags & folders'),
            colors: TagPalette.travel,
            onTap: () => context.push(AppRoutes.tags),
          ),
          FFActionItem(
            icon: FontAwesomeIcons.boxArchive,
            label: tr('Archive'),
            colors: ActionTints.lock,
            onTap: () => context.push(AppRoutes.archive),
          ),
          FFActionItem(
            icon: FontAwesomeIcons.trashCan,
            label: tr('Recently deleted'),
            colors: TagPalette.high,
            onTap: () => context.push(AppRoutes.trash),
          ),
        ],
      ),
    );

/// Sort picker; persists the choice.
Future<void> pickNotesSort(BuildContext context, WidgetRef ref) async {
  final current = ref.read(notesSortProvider);
  final choice = await showChoiceSheet<NotesSort>(
    context,
    title: tr('Sort notes'),
    selected: current,
    options: [
      for (final s in NotesSort.values)
        ChoiceOption(
          value: s,
          label: s == NotesSort.manual ? tr('Manual (drag)') : s.label,
          icon: notesSortIcon(s),
          colors: ModuleStyle.notes.colors,
          subtitle: s == NotesSort.manual
              ? tr('Long-press and drag a note to move it')
              : null,
        ),
    ],
  );
  if (choice == null) return;
  await setNotesSort(ref, choice.value);
}

/// Tag filter of the search field ("Any tag" clears it).
Future<void> pickNotesTagFilter(BuildContext context, WidgetRef ref) async {
  final tags = await ref.read(tagsRepositoryProvider).watchTags().first;
  if (!context.mounted) return;
  final current = ref.read(notesListFilterProvider).tagId;
  final choice = await showChoiceSheet<String?>(
    context,
    title: tr('Filter by tag'),
    selected: current,
    options: [
      ChoiceOption(
        value: null,
        label: tr('Any tag'),
        icon: FontAwesomeIcons.tags,
        colors: TagPalette.ideas,
      ),
      for (final t in tags)
        ChoiceOption(
          value: t.id,
          label: '#${t.name}',
          icon: FontAwesomeIcons.tag,
          colors: TagPalette.forName(t.name),
        ),
    ],
  );
  if (choice == null) return;
  ref.read(notesListFilterProvider.notifier).selectTag(choice.value);
}

/// Asks for a folder name and creates it (selects the new chip).
Future<void> promptNewNoteFolder(BuildContext context, WidgetRef ref) async {
  final name = await showTextInputSheet(
    context,
    title: tr('New folder'),
    hint: tr('Folder name'),
    confirmLabel: tr('Create folder'),
  );
  if (name == null) return;
  await createNoteFolder(ref, name);
}
