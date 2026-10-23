/// ============================================================
/// ITEM ACTIONS SHEET — long-press actions for any item (screen 09)
/// ============================================================
///
/// One entry point for every list, card and search result in all five
/// modules:
///
///   showItemActions(context, ref, item)            // single item
///   showSelectionActions(context, ref, items)      // multi-select
///
/// Generic rows (pin, favourite, duplicate, colour, tags/folder, reminder)
/// are built here; module rows come from each feature's
/// `<module>ItemActions` (see module_item_actions.dart). Archive / Delete
/// go through item_lifecycle_actions.dart (Undo snackbar, confirm dialog).
/// The visual is core/widgets/ff_action_sheet.dart.
/// ============================================================
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/item_summary.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/ff_action_sheet.dart';
import 'package:focusflow/core/widgets/ff_snackbar.dart';
import 'package:focusflow/features/habits/presentation/habit_item_actions.dart';
import 'package:focusflow/features/medicines/presentation/medicine_item_actions.dart';
import 'package:focusflow/features/notes/presentation/note_item_actions.dart';
import 'package:focusflow/features/reminders/presentation/reminder_item_actions.dart';
import 'package:focusflow/features/tasks/presentation/task_item_actions.dart';
import 'package:focusflow/features/vault/presentation/vault_item_actions.dart';
import 'package:focusflow/shared/item_actions/item_lifecycle_actions.dart';
import 'package:focusflow/shared/item_actions/item_pickers.dart';
import 'package:focusflow/shared/item_actions/module_item_actions.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

/// "Note · Ideas · Edited today".
String itemActionsMeta(ItemSummary item, DateTime now) {
  final day = DateUtilsX.relativeDay(item.updatedAt, now);
  final edited = switch (day) {
    'Today' || 'Yesterday' || 'Tomorrow' => day.toLowerCase(),
    _ => day,
  };
  return [
    item.type.label,
    if (item.folderName != null && item.folderName!.isNotEmpty)
      item.folderName!,
    'Edited $edited',
  ].join(' · ');
}

/// Opens the actions sheet for one item. No-op when the item is gone.
/// [extraActions] are appended after the module rows (e.g. the note
/// editor's "Word count", which the list's sheet doesn't show).
Future<void> showItemActions(
  BuildContext context,
  WidgetRef ref,
  ItemRef itemRef, {
  List<FFActionItem> extraActions = const [],
}) async {
  final item = await ref.read(itemsRepositoryProvider).get(itemRef);
  if (item == null || !context.mounted) return;
  final module = await _moduleActions(context, ref, item);
  if (!context.mounted) return;
  final style = item.type.style;
  final header = FFActionSheetHeader(
    title: item.displayTitle,
    icon: style.icon,
    colors: style.colors,
    meta: itemActionsMeta(item, ref.read(clockProvider).now()),
  );
  if (!item.isActive) {
    return _showInactiveItemActions(
      context,
      ref,
      item,
      header: header,
      actions: [...module.readSafe, ...extraActions],
    );
  }
  final items = ref.read(itemsRepositoryProvider);
  final refs = [item.ref];
  final type = item.type;

  final generic = <FFActionItem>[
    if (type != ItemType.vault)
      FFActionItem(
        icon: FontAwesomeIcons.thumbtack,
        label: item.isPinned ? tr('Unpin') : tr('Pin to top'),
        colors: ModuleStyle.notes.colors,
        onTap: () => items.setPinned(refs, !item.isPinned),
      ),
    FFActionItem(
      icon: FontAwesomeIcons.solidStar,
      label: item.isFavorite
          ? tr('Remove from favourites')
          : tr('Add to favourites'),
      colors: ModuleStyle.vault.colors,
      onTap: () => items.setFavorite(refs, !item.isFavorite),
    ),
    if (type != ItemType.vault)
      FFActionItem(
        icon: FontAwesomeIcons.solidCopy,
        label: tr('Duplicate'),
        colors: ModuleStyle.tasks.colors,
        onTap: () async {
          await items.duplicate(item.ref);
          if (!context.mounted) return;
          showFFToast(
            context,
            tr('{type} duplicated', {'type': type.label}),
            icon: FontAwesomeIcons.solidCopy,
          );
        },
      ),
    if (type == ItemType.note || type == ItemType.habit)
      FFActionItem(
        icon: FontAwesomeIcons.palette,
        label: tr('Change colour'),
        colors: TagPalette.design,
        onTap: () => pickItemColour(context, ref, refs, current: item.colorHex),
      ),
    FFActionItem(
      icon: FontAwesomeIcons.tag,
      label: switch (type) {
        ItemType.task => tr('Edit tags / move to list'),
        ItemType.habit ||
        ItemType.reminder ||
        ItemType.medicine => tr('Edit tags'),
        _ => tr('Edit tags / move to folder'),
      },
      colors: TagPalette.travel,
      onTap: () => editItemTagsAndFolder(context, ref, item),
    ),
    if (type == ItemType.note)
      FFActionItem(
        icon: FontAwesomeIcons.solidBell,
        label: tr('Set reminder'),
        colors: ModuleStyle.reminders.colors,
        onTap: () => setItemReminder(context, ref, item),
      ),
  ];

  await showFFActionSheet(
    context,
    FFActionSheetData(
      header: header,
      actions: [
        ...module.leading,
        ...generic,
        ...module.trailing,
        ...extraActions,
      ],
      onArchive: () =>
          archiveItems(context, ref, refs, title: item.displayTitle),
      onDelete: () => deleteItems(context, ref, refs, title: item.displayTitle),
    ),
  );
}

/// The sheet of an archived or trashed item: nothing that edits it, never
/// archive (a trashed item) or delete it again (that would restart its
/// 30 days). Archived → Restore + Delete; trashed → Recover + Delete
/// forever. [actions] are read-safe module / caller rows (Share / export…).
Future<void> _showInactiveItemActions(
  BuildContext context,
  WidgetRef ref,
  ItemSummary item, {
  required FFActionSheetHeader header,
  required List<FFActionItem> actions,
}) {
  final refs = [item.ref];
  final title = item.displayTitle;
  final trashed = item.isDeleted;
  return showFFActionSheet(
    context,
    FFActionSheetData(
      header: header,
      actions: [
        FFActionItem(
          icon: FontAwesomeIcons.rotateLeft,
          label: trashed ? tr('Recover') : tr('Restore'),
          colors: ModuleStyle.notes.colors,
          onTap: () => trashed
              ? restoreFromTrash(context, ref, refs, title: title)
              : restoreFromArchive(context, ref, refs, title: title),
        ),
        if (item.type != ItemType.vault)
          FFActionItem(
            icon: FontAwesomeIcons.solidCopy,
            label: tr('Duplicate'),
            colors: ModuleStyle.tasks.colors,
            onTap: () async {
              await ref.read(itemsRepositoryProvider).duplicate(item.ref);
              if (!context.mounted) return;
              showFFToast(
                context,
                tr('{type} duplicated', {'type': item.type.label}),
                icon: FontAwesomeIcons.solidCopy,
              );
            },
          ),
        ...actions,
      ],
      deleteLabel: trashed ? tr('Delete forever') : tr('Delete'),
      onDelete: () => trashed
          ? deleteItemsForever(context, ref, refs, title: title)
          : deleteItems(context, ref, refs, offerArchive: false, title: title),
    ),
  );
}

/// Opens the multi-select variant ("3 items selected") for [itemRefs].
/// [onDone] runs after an action that should end selection mode.
Future<void> showSelectionActions(
  BuildContext context,
  WidgetRef ref,
  List<ItemRef> itemRefs, {
  VoidCallback? onDone,
}) async {
  if (itemRefs.isEmpty) return;
  final items = ref.read(itemsRepositoryProvider);
  final types = itemRefs.map((r) => r.type).toSet();
  final single = types.length == 1 ? types.first : null;
  var allPinned = true;
  for (final r in itemRefs) {
    if ((await items.get(r))?.isPinned != true) {
      allPinned = false;
      break;
    }
  }
  if (!context.mounted) return;
  // Ends selection only when the action went through (a dismissed picker
  // or cancelled confirm keeps the selection).
  Future<void> run(Future<bool> Function() action) async {
    if (await action()) onDone?.call();
  }

  await showFFActionSheet(
    context,
    FFActionSheetData(
      header: FFActionSheetHeader.selection(
        itemRefs.length,
        selectedTitle: _selectedTitle(single, itemRefs.length),
      ),
      actions: [
        if (single != ItemType.vault)
          FFActionItem(
            icon: FontAwesomeIcons.thumbtack,
            label: allPinned ? tr('Unpin') : tr('Pin to top'),
            colors: ModuleStyle.notes.colors,
            onTap: () => run(() => togglePinItems(context, ref, itemRefs)),
          ),
        FFActionItem(
          icon: FontAwesomeIcons.solidStar,
          label: tr('Add to favourites'),
          colors: ModuleStyle.vault.colors,
          onTap: () => run(() async {
            await items.setFavorite(itemRefs, true);
            return true;
          }),
        ),
        FFActionItem(
          icon: FontAwesomeIcons.tag,
          label: tr('Add tags'),
          colors: TagPalette.travel,
          onTap: () => run(() => addTagsToItems(context, ref, itemRefs)),
        ),
        if (single == ItemType.note ||
            single == ItemType.task ||
            single == ItemType.vault)
          FFActionItem(
            icon: FontAwesomeIcons.solidFolder,
            label: single == ItemType.task
                ? tr('Move to list')
                : tr('Move to folder'),
            colors: TagPalette.work,
            onTap: () =>
                run(() => moveItemsToFolder(context, ref, single!, itemRefs)),
          ),
      ],
      onArchive: () => run(() => archiveItems(context, ref, itemRefs)),
      onDelete: () => run(() => deleteItems(context, ref, itemRefs)),
    ),
  );
}

Future<ModuleItemActions> _moduleActions(
  BuildContext context,
  WidgetRef ref,
  ItemSummary item,
) => switch (item.type) {
  ItemType.note => noteItemActions(context, ref, item),
  ItemType.task => taskItemActions(context, ref, item),
  ItemType.reminder => reminderItemActions(context, ref, item),
  ItemType.habit => habitItemActions(context, ref, item),
  ItemType.medicine => medicineItemActions(context, ref, item),
  ItemType.vault => vaultItemActions(context, ref, item),
};

/// "3 notes selected" — one whole text per type (the noun is not a suffix
/// in every language); "N items selected" for a mix.
String _selectedTitle(ItemType? type, int count) => switch (type) {
  ItemType.note => tr(
    '{count, plural, one {# note selected} other {# notes selected}}',
    {'count': count},
  ),
  ItemType.task => tr(
    '{count, plural, one {# task selected} other {# tasks selected}}',
    {'count': count},
  ),
  ItemType.reminder => tr(
    '{count, plural, one {# reminder selected} other {# reminders selected}}',
    {'count': count},
  ),
  ItemType.habit => tr(
    '{count, plural, one {# habit selected} other {# habits selected}}',
    {'count': count},
  ),
  ItemType.medicine => tr(
    '{count, plural, one {# medicine selected} other {# medicines selected}}',
    {'count': count},
  ),
  ItemType.vault => tr(
    '{count, plural, one {# password selected} other {# passwords selected}}',
    {'count': count},
  ),
  null => tr(
    '{count, plural, one {# item selected} other {# items selected}}',
    {'count': count},
  ),
};
