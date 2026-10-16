/// ============================================================
/// LIBRARY ACTIONS — what the Library hub and its collections do
/// ============================================================
///
/// * [openLibraryItem]      open any item of a mixed list (vault items ask
///   for the vault PIN first).
/// * [showTagActions]       long-press a tag: rename · colour · delete
///   (confirmation + 5 s Undo that re-tags the active items).
/// * [showLibraryMoreMenu]  header ⋯: Show counts, show / hide modules,
///   Tags & Folders.
/// Why: widgets stay layout-only; writes go through repositories and the
/// settings controller.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/items/tag.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/library/presentation/widgets/choice_sheets.dart';
import 'package:focusflow/features/library/presentation/widgets/library_modules_sheet.dart';
import 'package:focusflow/features/vault/presentation/vault_gate.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:go_router/go_router.dart';

/// Pushes the item's editor / detail; vault items unlock first.
Future<void> openLibraryItem(BuildContext context, ItemRef item) async {
  if (item.type == ItemType.vault && !await ensureVaultUnlocked(context)) {
    return;
  }
  if (!context.mounted) return;
  await context.push(AppRoutes.open(item));
}

/// Tag colours offered by "Change colour" (stored as the solid `RRGGBB`).
const Map<String, ModuleColors> libraryTagColours = {
  'Emerald': TagPalette.ideas,
  'Blue': TagPalette.work,
  'Pink': TagPalette.personal,
  'Amber': TagPalette.finance,
  'Violet': TagPalette.design,
  'Sky': TagPalette.travel,
};

/// `RRGGBB` of [c]'s solid colour.
String libraryHex(ModuleColors c) => c.solid
    .toARGB32()
    .toRadixString(16)
    .padLeft(8, '0')
    .substring(2)
    .toUpperCase();

/// Display colours of [tag]: its stored colour when it is one of
/// [libraryTagColours], else the name-based palette pick.
ModuleColors libraryTagColors(Tag tag) {
  final hex = tag.colorHex?.toUpperCase();
  for (final c in libraryTagColours.values) {
    if (libraryHex(c) == hex) return c;
  }
  return TagPalette.forName(tag.name);
}

/// Long-press menu of a tag (Library cloud, Tags & Folders).
Future<void> showTagActions(BuildContext context, WidgetRef ref, Tag tag) {
  final colors = libraryTagColors(tag);
  return showFFActionSheet(
    context,
    FFActionSheetData(
      header: FFActionSheetHeader(
        title: tag.label,
        icon: FontAwesomeIcons.hashtag,
        colors: colors,
        meta: '${tag.usageCount} ${tag.usageCount == 1 ? 'item' : 'items'}',
      ),
      actions: [
        FFActionItem(
          icon: FontAwesomeIcons.pen,
          label: 'Rename tag',
          colors: TagPalette.work,
          onTap: () => _renameTag(context, ref, tag),
        ),
        FFActionItem(
          icon: FontAwesomeIcons.palette,
          label: 'Change colour',
          colors: TagPalette.design,
          onTap: () => _recolourTag(context, ref, tag),
        ),
        FFActionItem(
          icon: FontAwesomeIcons.solidTrashCan,
          label: 'Delete tag',
          colors: ModuleStyle.scan.colors,
          destructive: true,
          onTap: () => deleteTag(context, ref, tag),
        ),
      ],
    ),
  );
}

Future<void> _renameTag(BuildContext context, WidgetRef ref, Tag tag) async {
  final name = await showTextInputSheet(
    context,
    title: 'Rename tag',
    hint: 'Tag name',
    initial: tag.name,
  );
  if (name == null || Tag.normalize(name).isEmpty) return;
  await ref.read(tagsRepositoryProvider).rename(tag.id, name);
}

Future<void> _recolourTag(BuildContext context, WidgetRef ref, Tag tag) async {
  final picked = await showChoiceSheet<String?>(
    context,
    title: 'Tag colour',
    selected: tag.colorHex?.toUpperCase(),
    options: [
      ChoiceOption(
        value: null,
        label: 'Automatic',
        icon: FontAwesomeIcons.wandMagicSparkles,
        colors: TagPalette.forName(tag.name),
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
  if (picked == null) return;
  await ref.read(tagsRepositoryProvider).recolor(tag.id, picked.value);
}

/// Deletes [tag] after confirmation; Undo re-creates it (same colour) on
/// every item that carried it — archived and recently deleted ones too.
/// (The re-created tag gets a new id; a soft-delete in TagsRepository
/// would keep it.)
Future<void> deleteTag(BuildContext context, WidgetRef ref, Tag tag) async {
  final ok = await showFFConfirm(
    context,
    title: 'Delete ${tag.label}?',
    message: 'The tag is removed from every item. The items are kept.',
    confirmLabel: 'Delete tag',
    destructive: true,
    icon: FontAwesomeIcons.solidTrashCan,
  );
  if (!ok || !context.mounted) return;
  final items = ref.read(itemsRepositoryProvider);
  final tags = ref.read(tagsRepositoryProvider);
  final tagged = await _refsTagged(ref, tag.id);
  await tags.delete(tag.id);
  if (!context.mounted) return;
  showUndoSnackbar(
    context,
    message: '${tag.label} deleted',
    icon: FontAwesomeIcons.solidTrashCan,
    onUndo: () async {
      await tags.findOrCreate(tag.name, colorHex: tag.colorHex);
      if (tagged.isNotEmpty) await items.addTags(tagged, [tag.name]);
    },
  );
}

/// Refs of every item tagged [tagId]: active ones from the tag query, plus
/// archived / trashed ones (which that query leaves out) checked one by one
/// — only on a tag delete, so the extra reads are fine.
Future<List<ItemRef>> _refsTagged(WidgetRef ref, String tagId) async {
  final items = ref.read(itemsRepositoryProvider);
  final tags = ref.read(tagsRepositoryProvider);
  final out = [for (final s in await items.watchByTag(tagId).first) s.ref];
  final hidden = [
    ...await items.watchArchived().first,
    ...await items.watchTrash().first,
  ];
  for (final s in hidden) {
    if (out.contains(s.ref)) continue;
    final of = await tags.watchTagsOf(s.ref).first;
    if (of.any((t) => t.id == tagId)) out.add(s.ref);
  }
  return out;
}

/// The header's ⋯ menu.
Future<void> showLibraryMoreMenu(BuildContext context, WidgetRef ref) {
  final showCounts = ref.read(settingsProvider).libraryShowCounts;
  return showFFActionSheet(
    context,
    FFActionSheetData(
      header: FFActionSheetHeader(
        title: 'Library',
        icon: FontAwesomeIcons.layerGroup,
        colors: TagPalette.ideas,
        meta: 'View options',
      ),
      actions: [
        FFActionItem(
          icon: showCounts
              ? FontAwesomeIcons.solidEyeSlash
              : FontAwesomeIcons.solidEye,
          label: showCounts ? 'Hide counts' : 'Show counts',
          colors: TagPalette.work,
          onTap: () => ref
              .read(settingsProvider.notifier)
              .update((s) => s.copyWith(libraryShowCounts: !showCounts)),
        ),
        FFActionItem(
          icon: FontAwesomeIcons.tableCellsLarge,
          label: 'Reorder / hide spaces',
          colors: TagPalette.design,
          onTap: () => showLibraryModulesSheet(context),
        ),
        FFActionItem(
          icon: FontAwesomeIcons.tags,
          label: 'Tags & Folders',
          colors: TagPalette.finance,
          onTap: () => context.push(AppRoutes.tags),
        ),
      ],
    ),
  );
}
