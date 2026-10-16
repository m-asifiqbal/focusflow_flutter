/// ============================================================
/// LIBRARY — screen 05 (`/library`, tab 2): the all-spaces hub
/// ============================================================
///
/// What: large header ("Library" · "113 items across 5 spaces", Search,
/// ⋯), the module cards (Notes, Tasks, Reminders, Habits + the wide
/// Vault card), COLLECTIONS (Pinned, Favourites, Tags & Folders, Archive,
/// Recently Deleted) and the TAGS cloud.
/// Why: a tab root — everything is live from libraryCountsProvider /
/// libraryTagsProvider / vaultStatusProvider; drill-ins are pushed inside
/// the Library branch so the tab bar stays visible.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/items/library_counts.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/library/presentation/library_actions.dart';
import 'package:focusflow/features/library/presentation/library_format.dart';
import 'package:focusflow/features/library/presentation/providers/library_providers.dart';
import 'package:focusflow/features/library/presentation/widgets/library_sections.dart';
import 'package:focusflow/features/tasks/presentation/providers/minute_clock.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:go_router/go_router.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  /// Gap before a section label (vault card → "COLLECTIONS", design/05).
  static const double _sectionGap = 26;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final failed = ref.watch(
      libraryCountsProvider.select((a) => a.hasError && !a.hasValue),
    );
    // Keeps "today" fresh: day-relative counts roll over at midnight.
    return MinuteTicker(
      child: FFScaffold(
        safeBottom: false,
        body: ListView(
          padding: EdgeInsetsDirectional.only(bottom: bottom + AppSpacing.xxxl),
          children: [
            const _Header(),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.screen,
              ),
              child: failed
                  ? FFEmptyState.compact(
                      colors: TagPalette.high,
                      icon: FontAwesomeIcons.triangleExclamation,
                      title: "Couldn't load your library",
                      body: 'Your items are safe. Try again.',
                      ctaLabel: 'Retry',
                      ctaIcon: FontAwesomeIcons.arrowsRotate,
                      onCta: () => ref.invalidate(libraryCountsProvider),
                    )
                  : const LibraryModuleGrid(),
            ),
            const SizedBox(height: _sectionGap),
            const Padding(
              padding: EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.grouped,
              ),
              child: LibraryCollections(),
            ),
            const SizedBox(height: _sectionGap),
            const Padding(
              padding: EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.screen,
              ),
              child: LibraryTagsSection(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(libraryCountsProvider).valueOrNull;
    final hidden = ref.watch(
      settingsProvider.select((s) => s.hiddenLibraryModules),
    );
    final modules = libraryVisibleModules(hidden);
    return FFLargeHeader(
      title: 'Library',
      subtitle: counts == null
          ? ' '
          : LibraryFormat.headerSubtitle(
              modules.fold(0, (sum, t) => sum + _total(counts, t)),
              spaces: modules.length,
            ),
      actions: [
        FFRoundIconButton(
          icon: FontAwesomeIcons.magnifyingGlass,
          semanticLabel: 'Search',
          onPressed: () => context.push(AppRoutes.search),
        ),
        FFRoundIconButton(
          icon: FontAwesomeIcons.ellipsis,
          semanticLabel: 'More options',
          onPressed: () => showLibraryMoreMenu(context, ref),
        ),
      ],
    );
  }

  static int _total(LibraryCounts c, ItemType t) => switch (t) {
    ItemType.note => c.notesTotal,
    ItemType.task => c.tasksTotal,
    ItemType.reminder => c.remindersTotal,
    ItemType.habit => c.habitsTotal,
    ItemType.vault => c.vaultTotal,
  };
}
