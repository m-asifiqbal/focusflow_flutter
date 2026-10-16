/// ============================================================
/// LIBRARY COLLECTION — Pinned (`/library/pinned`), Favourites
/// (`/library/favourites`) and one tag (`/library/tags/:tagId`)
/// ============================================================
///
/// What: a mixed list of active items from every module, grouped by
/// module ("NOTES", "TASKS"…) with the shared [ItemSummaryRow]. Tap opens
/// the item (vault items unlock first); long-press opens the item actions
/// sheet, so unpinning / unfavouriting / un-tagging removes the row live.
/// The tag variant's ⋯ renames / recolours / deletes the tag.
/// Why: one screen for the three "collections" of screen 05.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/item_summary.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/library/presentation/library_actions.dart';
import 'package:focusflow/features/library/presentation/library_format.dart';
import 'package:focusflow/features/library/presentation/providers/library_providers.dart';
import 'package:focusflow/features/library/presentation/widgets/item_summary_row.dart';
import 'package:focusflow/shared/item_actions/item_actions_sheet.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

class LibraryCollectionScreen extends ConsumerWidget {
  const LibraryCollectionScreen({required this.kind, this.tagId, super.key})
    : assert(kind != LibraryCollection.tag || tagId != null);

  const LibraryCollectionScreen.tag(String this.tagId, {super.key})
    : kind = LibraryCollection.tag;

  final LibraryCollection kind;
  final String? tagId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = (kind: kind, tagId: tagId);
    final async = ref.watch(libraryCollectionItemsProvider(args));
    final items = async.valueOrNull;
    final tag = kind == LibraryCollection.tag
        ? ref.watch(libraryTagProvider(tagId!))
        : null;
    final tagGone = tag != null && tag.hasValue && tag.value == null;
    final title = switch (kind) {
      LibraryCollection.pinned => 'Pinned',
      LibraryCollection.favourites => 'Favourites',
      LibraryCollection.tag => tag?.valueOrNull?.label ?? '#',
    };
    final bottom = MediaQuery.paddingOf(context).bottom;

    final Widget body;
    if (tagGone) {
      body = _empty(
        context,
        icon: FontAwesomeIcons.hashtag,
        title: 'Tag deleted',
        text: 'This tag no longer exists. Its items were kept.',
      );
    } else if (items == null) {
      body = async.hasError
          ? FFEmptyState.compact(
              colors: TagPalette.high,
              icon: FontAwesomeIcons.triangleExclamation,
              title: "Couldn't load these items",
              body: 'Your items are safe. Try again.',
              ctaLabel: 'Retry',
              ctaIcon: FontAwesomeIcons.arrowsRotate,
              onCta: () => ref.invalidate(libraryCollectionItemsProvider(args)),
            )
          : const FFSkeletonList(kind: FFSkeletonKind.row, count: 5);
    } else if (items.isEmpty) {
      body = switch (kind) {
        LibraryCollection.pinned => _empty(
          context,
          icon: FontAwesomeIcons.thumbtack,
          title: 'Nothing pinned yet',
          text:
              'Long-press any note, task, reminder or habit and choose '
              'Pin to keep it here.',
        ),
        LibraryCollection.favourites => _empty(
          context,
          icon: FontAwesomeIcons.solidStar,
          title: 'No favourites yet',
          text: 'Long-press an item and choose Favourite to collect it here.',
        ),
        LibraryCollection.tag => _empty(
          context,
          icon: FontAwesomeIcons.hashtag,
          title: 'No items with this tag',
          text: 'Add the tag to notes, tasks and more to see them here.',
        ),
      };
    } else {
      body = _ItemGroups(items: items);
    }

    return FFScaffold(
      safeBottom: false,
      body: ListView(
        padding: EdgeInsetsDirectional.only(bottom: bottom + AppSpacing.xxxl),
        children: [
          FFNavHeader(
            leading: const FFBackButton(label: 'Library'),
            title: title,
            subtitle: items == null ? null : LibraryFormat.items(items.length),
            trailing: [
              if (kind == LibraryCollection.tag && tag?.valueOrNull != null)
                FFRoundIconButton(
                  icon: FontAwesomeIcons.ellipsis,
                  semanticLabel: 'Tag options',
                  onPressed: () =>
                      showTagActions(context, ref, tag!.valueOrNull!),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.grouped,
            ),
            child: body,
          ),
        ],
      ),
    );
  }

  Widget _empty(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String text,
  }) => Padding(
    padding: const EdgeInsetsDirectional.only(top: AppSpacing.xxxl),
    child: FFEmptyState(
      colors: TagPalette.ideas,
      icon: icon,
      title: title,
      body: text,
    ),
  );
}

/// The items grouped by module, in module order, one card per module.
class _ItemGroups extends ConsumerWidget {
  const _ItemGroups({required this.items});

  final List<ItemSummary> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider).now();
    final use24h = ref.watch(settingsProvider.select((s) => s.use24HourTime));
    final groups = <ItemType, List<ItemSummary>>{
      for (final t in ItemType.values) t: [],
    };
    for (final s in items) {
      groups[s.type]!.add(s);
    }
    final children = <Widget>[];
    for (final e in groups.entries) {
      if (e.value.isEmpty) continue;
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: AppSpacing.section));
      }
      children.add(
        FFGroupedList(
          label: e.key.plural,
          dividerIndent: ItemSummaryRow.dividerIndent,
          children: [
            for (final s in e.value)
              ItemSummaryRow(
                item: s,
                meta: LibraryFormat.rowMeta(s, now, use24h: use24h),
                onTap: () => openLibraryItem(context, s.ref),
                onLongPress: () => showItemActions(context, ref, s.ref),
              ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}
