/// ============================================================
/// TAGS & FOLDERS ACTIONS — the sheets behind Settings › Tags & folders
/// ============================================================
///
/// What: [showTagManageSheet] (rename · colour · merge into… · delete) and
/// [showFolderManageSheet] (rename · colour · delete), plus
/// [createFolderFlow] and [folderColors]. Merge and delete confirm first
/// and then offer Undo for 5 s.
/// Why: one place for the flows; the Library's sheet primitives
/// (text input, choice list, tag palette) are reused so tags look and
/// behave the same as in Library › Tags & Folders.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/folder.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/items/tag.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/library/presentation/library_actions.dart';
import 'package:focusflow/features/library/presentation/widgets/choice_sheets.dart';
import 'package:focusflow/features/settings/presentation/notifiers/tags_folders_controller.dart';

/// Display colours of [f]: its palette colour, else the module's.
ModuleColors folderColors(Folder f) {
  final hex = f.colorHex?.toUpperCase();
  for (final c in libraryTagColours.values) {
    if (libraryHex(c) == hex) return c;
  }
  return f.module.style.colors;
}

String _items(int n) => '$n ${n == 1 ? 'item' : 'items'}';

Future<String?> _pickColour(
  BuildContext context, {
  required String title,
  required String? selected,
  required ModuleColors automatic,
}) async {
  final picked = await showChoiceSheet<String?>(
    context,
    title: title,
    selected: selected?.toUpperCase(),
    options: [
      ChoiceOption(
        value: null,
        label: 'Automatic',
        icon: FontAwesomeIcons.wandMagicSparkles,
        colors: automatic,
      ),
      for (final e in libraryTagColours.entries)
        ChoiceOption(
          value: libraryHex(e.value),
          label: e.key,
          icon: FontAwesomeIcons.solidCircle,
          colors: e.value,
        ),
    ],
  );
  // `null` = dismissed; a record with null value = "Automatic".
  return picked == null ? selected : picked.value;
}

/// Tag row menu.
Future<void> showTagManageSheet(
  BuildContext context,
  WidgetRef ref,
  Tag tag,
  List<Tag> all,
) {
  final c = ref.read(tagsFoldersControllerProvider);
  final others = [
    for (final t in all)
      if (t.id != tag.id) t,
  ];
  return showFFActionSheet(
    context,
    FFActionSheetData(
      header: FFActionSheetHeader(
        title: tag.label,
        icon: FontAwesomeIcons.hashtag,
        colors: libraryTagColors(tag),
        meta: _items(tag.usageCount),
      ),
      actions: [
        FFActionItem(
          icon: FontAwesomeIcons.pen,
          label: 'Rename tag',
          colors: TagPalette.work,
          onTap: () async {
            final name = await showTextInputSheet(
              context,
              title: 'Rename tag',
              hint: 'Tag name',
              initial: tag.name,
            );
            if (name == null || Tag.normalize(name).isEmpty) return;
            await c.renameTag(tag, name);
          },
        ),
        FFActionItem(
          icon: FontAwesomeIcons.palette,
          label: 'Change colour',
          colors: TagPalette.design,
          onTap: () async {
            final hex = await _pickColour(
              context,
              title: 'Tag colour',
              selected: tag.colorHex,
              automatic: TagPalette.forName(tag.name),
            );
            if (hex != tag.colorHex) await c.recolorTag(tag, hex);
          },
        ),
        if (others.isNotEmpty)
          FFActionItem(
            icon: FontAwesomeIcons.codeMerge,
            label: 'Merge into…',
            colors: TagPalette.finance,
            onTap: () => _mergeTag(context, ref, tag, others),
          ),
        FFActionItem(
          icon: FontAwesomeIcons.solidTrashCan,
          label: 'Delete tag',
          colors: ModuleStyle.scan.colors,
          destructive: true,
          onTap: () => _deleteTag(context, ref, tag),
        ),
      ],
    ),
  );
}

Future<void> _mergeTag(
  BuildContext context,
  WidgetRef ref,
  Tag source,
  List<Tag> others,
) async {
  final picked = await showChoiceSheet<Tag>(
    context,
    title: 'Merge ${source.label} into',
    options: [
      for (final t in others)
        ChoiceOption(
          value: t,
          label: t.label,
          subtitle: _items(t.usageCount),
          icon: FontAwesomeIcons.hashtag,
          colors: libraryTagColors(t),
        ),
    ],
  );
  if (picked == null || !context.mounted) return;
  final target = picked.value;
  final ok = await showFFConfirm(
    context,
    title: 'Merge ${source.label} into ${target.label}?',
    message:
        'Items tagged ${source.label} get ${target.label} instead, and '
        '${source.label} is removed.',
    confirmLabel: 'Merge',
    icon: FontAwesomeIcons.codeMerge,
  );
  if (!ok) return;
  final undo = await ref
      .read(tagsFoldersControllerProvider)
      .mergeTag(source, target);
  if (!context.mounted) return;
  showUndoSnackbar(
    context,
    message: '${source.label} merged into ${target.label}',
    icon: FontAwesomeIcons.codeMerge,
    onUndo: undo,
  );
}

Future<void> _deleteTag(BuildContext context, WidgetRef ref, Tag tag) async {
  final ok = await showFFConfirm(
    context,
    title: 'Delete ${tag.label}?',
    message: 'The tag is removed from every item. The items are kept.',
    confirmLabel: 'Delete tag',
    destructive: true,
    icon: FontAwesomeIcons.solidTrashCan,
  );
  if (!ok) return;
  final undo = await ref.read(tagsFoldersControllerProvider).deleteTag(tag);
  if (!context.mounted) return;
  showUndoSnackbar(
    context,
    message: '${tag.label} deleted',
    icon: FontAwesomeIcons.solidTrashCan,
    onUndo: undo,
  );
}

/// Folder row menu.
Future<void> showFolderManageSheet(
  BuildContext context,
  WidgetRef ref,
  Folder folder,
) {
  final c = ref.read(tagsFoldersControllerProvider);
  return showFFActionSheet(
    context,
    FFActionSheetData(
      header: FFActionSheetHeader(
        title: folder.name,
        icon: FontAwesomeIcons.solidFolder,
        colors: folderColors(folder),
        meta: _items(folder.itemCount),
      ),
      actions: [
        FFActionItem(
          icon: FontAwesomeIcons.pen,
          label: 'Rename',
          colors: TagPalette.work,
          onTap: () async {
            final name = await showTextInputSheet(
              context,
              title: 'Rename folder',
              hint: 'Folder name',
              initial: folder.name,
            );
            if (name != null) await c.renameFolder(folder, name);
          },
        ),
        FFActionItem(
          icon: FontAwesomeIcons.palette,
          label: 'Change colour',
          colors: TagPalette.design,
          onTap: () async {
            final hex = await _pickColour(
              context,
              title: 'Folder colour',
              selected: folder.colorHex,
              automatic: folder.module.style.colors,
            );
            if (hex != folder.colorHex) await c.recolorFolder(folder, hex);
          },
        ),
        FFActionItem(
          icon: FontAwesomeIcons.solidTrashCan,
          label: 'Delete folder',
          colors: ModuleStyle.scan.colors,
          destructive: true,
          onTap: () => _deleteFolder(context, ref, folder),
        ),
      ],
    ),
  );
}

Future<void> _deleteFolder(
  BuildContext context,
  WidgetRef ref,
  Folder folder,
) async {
  final ok = await showFFConfirm(
    context,
    title: 'Delete “${folder.name}”?',
    message: folder.itemCount == 0
        ? 'The folder is empty.'
        : 'Its ${_items(folder.itemCount)} are kept and moved out of the '
              'folder.',
    confirmLabel: 'Delete folder',
    destructive: true,
    icon: FontAwesomeIcons.solidTrashCan,
  );
  if (!ok) return;
  final undo = await ref
      .read(tagsFoldersControllerProvider)
      .deleteFolder(folder);
  if (!context.mounted) return;
  showUndoSnackbar(
    context,
    message: '“${folder.name}” deleted',
    icon: FontAwesomeIcons.solidTrashCan,
    onUndo: undo,
  );
}

/// "New folder" / "New list" row.
Future<void> createFolderFlow(
  BuildContext context,
  WidgetRef ref,
  ItemType module,
) async {
  final noun = module == ItemType.task ? 'list' : 'folder';
  final name = await showTextInputSheet(
    context,
    title: 'New $noun',
    hint: '${noun[0].toUpperCase()}${noun.substring(1)} name',
    confirmLabel: 'Create',
  );
  if (name == null) return;
  await ref.read(tagsFoldersControllerProvider).createFolder(module, name);
}
