/// ============================================================
/// LIBRARY SECTIONS — the three blocks of the Library hub (screen 05)
/// ============================================================
///
/// * [LibraryModuleGrid]   2-column module cards; the Vault card spans
///   both columns (live Locked / Unlocked from vaultStatusProvider).
/// * [LibraryCollections]  "COLLECTIONS": Pinned, Favourites, Tags &
///   Folders, Archive, Recently Deleted with live counts.
/// * [LibraryTagsSection]  "TAGS": the tag cloud (tap → tag list,
///   long-press → rename / colour / delete).
/// Why: each watches only the providers it needs, so a tag rename does
/// not rebuild the module cards.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/items/library_counts.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/insights/presentation/widgets/focus_timer_sheet.dart';
import 'package:focusflow/features/library/presentation/library_actions.dart';
import 'package:focusflow/features/library/presentation/library_format.dart';
import 'package:focusflow/features/library/presentation/providers/library_providers.dart';
import 'package:focusflow/features/library/presentation/widgets/library_module_card.dart';
import 'package:focusflow/features/library/presentation/widgets/library_tag_cloud.dart';
import 'package:focusflow/features/vault/presentation/vault_gate.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:go_router/go_router.dart';

/// Module list route of each card.
String libraryModuleRoute(ItemType type) => switch (type) {
  ItemType.note => AppRoutes.notes,
  ItemType.task => AppRoutes.tasks,
  ItemType.reminder => AppRoutes.reminders,
  ItemType.habit => AppRoutes.habits,
  ItemType.vault => AppRoutes.vault,
};

/// Every module in the user's hub order ([order] = `ItemType.key`s from
/// `AppSettings.libraryModuleOrder`; unknown keys are skipped, missing
/// modules follow in default order). Vault always comes last: it is the
/// full-width card under the 2-column grid.
List<ItemType> orderedLibraryModules(List<String> order) {
  final out = <ItemType>[
    for (final key in order)
      ...ItemType.values.where((t) => t.key == key && t != ItemType.vault),
  ];
  for (final t in ItemType.values) {
    if (t != ItemType.vault && !out.contains(t)) out.add(t);
  }
  return [...out.toSet(), ItemType.vault];
}

/// The visible modules in hub order (settings may hide and reorder them).
List<ItemType> libraryVisibleModules(
  Set<String> hidden, [
  List<String> order = const [],
]) => [
  for (final t in orderedLibraryModules(order))
    if (!hidden.contains(t.key)) t,
];

class LibraryModuleGrid extends ConsumerWidget {
  const LibraryModuleGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final counts = ref.watch(libraryCountsProvider).valueOrNull;
    final vault = ref.watch(vaultStatusProvider);
    final now = ref.watch(clockProvider).now();
    final modules = libraryVisibleModules(
      settings.hiddenLibraryModules,
      settings.libraryModuleOrder,
    );
    final small = modules.where((t) => t != ItemType.vault).toList();

    Widget card(ItemType t) => LibraryModuleCard(
      type: t,
      lines: counts == null
          ? null
          : LibraryFormat.card(
              t,
              counts,
              now: now,
              vault: vault,
              use24h: settings.use24HourTime,
            ),
      showCount: settings.libraryShowCounts,
      locked: t == ItemType.vault && vault != VaultStatus.unlocked,
      onTap: () => context.push(libraryModuleRoute(t)),
    );

    final rows = <Widget>[
      for (var i = 0; i < small.length; i += 2)
        i + 1 < small.length
            ? IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: card(small[i])),
                    const SizedBox(width: AppSpacing.cardGap),
                    Expanded(child: card(small[i + 1])),
                  ],
                ),
              )
            : card(small[i]),
      if (modules.contains(ItemType.vault)) card(ItemType.vault),
      FFSecondaryButton(
        label: tr('Start a focus session'),
        icon: FontAwesomeIcons.stopwatch,
        onPressed: () => showFocusTimer(context),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.cardGap),
          rows[i],
        ],
      ],
    );
  }
}

class LibraryCollections extends ConsumerWidget {
  const LibraryCollections({super.key});

  static const double _twoLineRow = 69;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(libraryCountsProvider).valueOrNull;
    final show = ref.watch(settingsProvider.select((s) => s.libraryShowCounts));
    Widget row(
      String title,
      IconData icon,
      ModuleColors colors,
      String route,
      int Function(LibraryCounts) pick, {
      String? subtitle,
    }) {
      final n = !show || c == null ? null : pick(c);
      final r = FFListRow(
        leading: FFIconTile(icon: icon, colors: colors, size: 32),
        title: title,
        subtitle: subtitle,
        value: n?.toString(),
        chevron: true,
        semanticLabel: [
          title,
          if (n != null) LibraryFormat.items(n),
          ?subtitle,
        ].join(', '),
        onTap: () => context.push(route),
      );
      // The two-line row is 69 pt tall on design/05 (one-line rows: 61).
      return subtitle == null
          ? r
          : ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _twoLineRow),
              child: r,
            );
    }

    return FFGroupedList(
      label: tr('Collections'),
      children: [
        row(
          tr('Pinned'),
          FontAwesomeIcons.thumbtack,
          TagPalette.ideas,
          AppRoutes.pinned,
          (c) => c.pinned,
        ),
        row(
          tr('Favourites'),
          FontAwesomeIcons.solidStar,
          TagPalette.finance,
          AppRoutes.favourites,
          (c) => c.favourites,
        ),
        row(
          tr('Tags & Folders'),
          FontAwesomeIcons.tags,
          TagPalette.design,
          AppRoutes.tags,
          (c) => c.tagsAndFolders,
        ),
        row(
          tr('Archive'),
          FontAwesomeIcons.boxArchive,
          ActionTints.lock,
          AppRoutes.archive,
          (c) => c.archived,
        ),
        row(
          tr('Recently Deleted'),
          FontAwesomeIcons.solidTrashCan,
          ModuleStyle.scan.colors,
          AppRoutes.trash,
          (c) => c.trash,
          subtitle: tr('Auto-deletes after 30 days'),
        ),
      ],
    );
  }
}

class LibraryTagsSection extends ConsumerWidget {
  const LibraryTagsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(libraryTagsProvider);
    final tags = async.valueOrNull;
    final Widget body;
    if (tags == null) {
      body = async.hasError
          ? FFTextButton(
              label: tr('Couldn\'t load tags · Retry'),
              onPressed: () => ref.invalidate(libraryTagsProvider),
              padding: EdgeInsetsDirectional.zero,
            )
          : Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.md,
              children: [
                for (final w in LibraryTagPill.skeletonWidths)
                  FFSkeleton(
                    width: w,
                    height: LibraryTagPill.height,
                    radius: LibraryTagPill.radius,
                  ),
              ],
            );
    } else if (tags.isEmpty) {
      body = Text(
        tr('Tags you add to notes, tasks and more show up here.'),
        style: context.text.bodySmall,
      );
    } else {
      body = LibraryTagCloud(
        tags: tags,
        onTap: (t) => context.push(AppRoutes.tag(t.id)),
        onLongPress: (t) => showTagActions(context, ref, t),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FFSectionLabel(
          tr('Tags'),
          padding: EdgeInsetsDirectional.only(bottom: AppSpacing.xs),
        ),
        body,
      ],
    );
  }
}
