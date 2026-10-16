/// ============================================================
/// SCREEN 18 — Vault item list (inner tabs "Vault" and "Favourites")
/// ============================================================
///
/// Header with the live auto-lock countdown · search (titles only) ·
/// category tiles · breach banner · filter chips (All · Favourites ·
/// folders) · "A – Z" + Sort · grouped rows. Everything is live: rows come
/// from [vaultListProvider] (repository stream + in-memory decryption of
/// the username line only).
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/domain/repository/vault_repository.dart';
import 'package:focusflow/features/vault/presentation/notifiers/vault_session_controller.dart';
import 'package:focusflow/features/vault/presentation/providers/vault_list_providers.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_alphabet_scrubber.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_filter_sheet.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_header.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_item_row.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_list_widgets.dart';
import 'package:focusflow/features/vault/presentation/widgets/vault_tab_bar.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:focusflow/features/vault/presentation/vault_tokens.dart';

class VaultListView extends ConsumerStatefulWidget {
  const VaultListView({this.favouritesTab = false, super.key});

  /// The "Favourites" inner tab: same list, favourites only, no tiles.
  final bool favouritesTab;

  @override
  ConsumerState<VaultListView> createState() => _VaultListViewState();
}

class _VaultListViewState extends ConsumerState<VaultListView> {
  /// First row of each index letter, for the alphabet scrubber.
  final Map<String, GlobalKey> _letterKeys = {};

  GlobalKey _keyFor(String letter) =>
      _letterKeys.putIfAbsent(letter, () => GlobalKey(debugLabel: letter));

  void _jumpTo(String letter) {
    final target = _letterKeys[letter]?.currentContext;
    if (target == null) return;
    unawaited(
      Scrollable.ensureVisible(
        target,
        alignment: 0.05,
        duration: context.motion(AppMotion.fast),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final favouritesTab = widget.favouritesTab;
    final base = ref.watch(vaultQueryProvider);
    final query = favouritesTab
        ? VaultQuery(favouritesOnly: true, text: base.text, sort: base.sort)
        : base;
    final counts = ref.watch(vaultCountsProvider).valueOrNull;
    final remaining = ref.watch(vaultAutoLockRemainingProvider).valueOrNull;
    final entries = ref.watch(vaultListProvider(query));
    final total = counts?.total ?? 0;
    final filter = ref.read(vaultQueryProvider.notifier);

    final subtitle = remaining == null
        ? 'Unlocked'
        : 'Unlocked · auto-locks in ${formatCountdown(remaining)}';

    final rows = entries.valueOrNull ?? const <VaultListEntry>[];
    final scrubber =
        query.sort == VaultSort.az &&
        query.text.trim().isEmpty &&
        rows.length >= kVaultScrubberMinRows;
    final firstOfLetter = <String, String>{};
    if (scrubber) {
      for (final e in rows) {
        firstOfLetter.putIfAbsent(
          vaultIndexLetter(e.record.title),
          () => e.record.id,
        );
      }
    }

    final list = CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: VaultHeader(
            subtitle: subtitle,
            onLock: () =>
                unawaited(ref.read(vaultSessionProvider.notifier).lock()),
            onAdd: () => unawaited(context.push(AppRoutes.newVaultItem())),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.screen,
            ),
            child: FFSearchField(
              vault: true,
              hint: 'Search ${total == 1 ? '1 account' : '$total accounts'}…',
              onChanged: filter.setText,
              onClear: () => filter.setText(''),
              onFilter: () => showVaultFilterSheet(context),
              filterActive: base.type != null || base.sort != VaultSort.az,
              filterSemanticLabel: 'Filter and sort',
            ),
          ),
        ),
        if (!favouritesTab) ...[
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
          SliverToBoxAdapter(
            child: VaultCategoryTiles(
              counts: counts,
              selected: base.type,
              onSelect: filter.toggleType,
            ),
          ),
          if ((counts?.breached ?? 0) > 0) ...[
            const SliverToBoxAdapter(child: SizedBox(height: VaultSizes.gapLg)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.screen,
                ),
                child: VaultBreachBanner(
                  count: counts!.breached,
                  onFix: () => _fixBreaches(context, ref),
                ),
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: VaultSizes.gapSm)),
          SliverToBoxAdapter(child: _FilterChips(total: total)),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),
        ] else
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
        SliverToBoxAdapter(
          child: VaultSectionHeader(sort: base.sort, onSort: filter.toggleSort),
        ),
        ...entries.when(
          skipLoadingOnReload: true,
          loading: () => [
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.grouped,
                ),
                child: FFSkeletonList(count: 4, kind: FFSkeletonKind.row),
              ),
            ),
          ],
          error: (e, _) => [
            SliverToBoxAdapter(
              child: FFEmptyState.compact(
                colors: ModuleStyle.vault.colors,
                icon: FontAwesomeIcons.circleExclamation,
                title: "Couldn't load your vault",
                body: 'Something went wrong while reading the vault.',
                ctaLabel: 'Retry',
                ctaIcon: FontAwesomeIcons.arrowRotateRight,
                onCta: () => ref.invalidate(vaultListProvider(query)),
              ),
            ),
          ],
          data: (rows) => [
            if (rows.isEmpty)
              SliverToBoxAdapter(
                child: _EmptyList(
                  vaultEmpty: total == 0,
                  favourites: query.favouritesOnly,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.grouped,
                ),
                sliver: SliverToBoxAdapter(
                  child: VaultItemGroup(
                    children: [
                      for (final e in rows)
                        _row(
                          e,
                          firstOfLetter[vaultIndexLetter(e.record.title)],
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: MediaQuery.paddingOf(context).bottom + AppSpacing.xxl,
          ),
        ),
      ],
    );
    if (!scrubber) return list;
    return Stack(
      children: [
        list,
        PositionedDirectional(
          end: 0,
          top: 0,
          bottom: MediaQuery.paddingOf(context).bottom,
          child: Center(
            child: VaultAlphabetScrubber(
              letters: firstOfLetter.keys.toList(),
              onLetter: _jumpTo,
              haptics: ref.watch(
                settingsProvider.select((s) => s.hapticsEnabled),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// A row; the first of its letter carries the scrubber's jump key.
  Widget _row(VaultListEntry e, String? firstIdOfLetter) {
    final row = VaultItemRow(key: ValueKey(e.record.id), entry: e);
    if (firstIdOfLetter != e.record.id) return row;
    return KeyedSubtree(
      key: _keyFor(vaultIndexLetter(e.record.title)),
      child: row,
    );
  }

  void _fixBreaches(BuildContext context, WidgetRef ref) {
    final breached = ref.read(vaultBreachedProvider);
    if (breached.length == 1) {
      unawaited(context.push(AppRoutes.vaultItem(breached.first.id)));
    } else {
      ref.read(vaultTabProvider.notifier).select(VaultTab.security);
    }
  }
}

class _FilterChips extends ConsumerWidget {
  const _FilterChips({required this.total});

  final int total;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = ref.watch(vaultQueryProvider);
    final folders = ref.watch(vaultFoldersProvider).valueOrNull ?? const [];
    final filter = ref.read(vaultQueryProvider.notifier);
    final selected = q.favouritesOnly ? '#fav' : (q.folderId ?? '#all');
    return FFChipBar<String>(
      vault: true,
      selected: selected,
      items: [
        FFChipItem(value: '#all', label: 'All', count: total),
        const FFChipItem(value: '#fav', label: 'Favourites'),
        for (final f in folders) FFChipItem(value: f.id, label: f.name),
      ],
      onSelected: (v) => switch (v) {
        '#all' => filter.showAll(),
        '#fav' => filter.showFavourites(),
        _ => filter.showFolder(v),
      },
    );
  }
}

class _EmptyList extends StatelessWidget {
  const _EmptyList({required this.vaultEmpty, required this.favourites});

  final bool vaultEmpty;
  final bool favourites;

  @override
  Widget build(BuildContext context) {
    final colors = ModuleStyle.vault.colors;
    if (vaultEmpty) {
      return FFEmptyState.compact(
        colors: colors,
        icon: FontAwesomeIcons.key,
        title: 'Add your first password',
        body:
            'Logins, cards, Wi-Fi and secure notes — encrypted on this '
            'device with your master PIN.',
        ctaLabel: 'Add password',
        onCta: () => unawaited(context.push(AppRoutes.newVaultItem())),
        hint: 'Import from Bitwarden / 1Password CSV',
        onHint: () => unawaited(context.push(AppRoutes.settingsImportExport)),
      );
    }
    return FFEmptyState.compact(
      colors: colors,
      icon: favourites
          ? FontAwesomeIcons.solidHeart
          : FontAwesomeIcons.magnifyingGlass,
      title: favourites ? 'No favourites yet' : 'Nothing matches',
      body: favourites
          ? 'Swipe a password or use its menu to add it to Favourites.'
          : 'Try another search, category or folder.',
    );
  }
}
