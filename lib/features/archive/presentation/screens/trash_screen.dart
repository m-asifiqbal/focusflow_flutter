/// ============================================================
/// RECENTLY DELETED — `/library/trash` (screen 24)
/// ============================================================
///
/// What: soft-deleted items, newest first, each with its purge countdown
/// ("29 days"); the rose "Auto-deletes after 30 days" card; "N ITEMS" /
/// "2 SELECTED · 5 ITEMS" label; swipe → Recover / Delete forever; tap or
/// long-press → multi-select (Cancel · All); sticky raised bar
/// "Recover all · Empty trash" or "Recover (2) · Delete (2)".
/// Why: the last chance to get an item back. Permanent deletes ask for
/// confirmation (dialog 28, permanent variant — no Undo); recovering shows
/// the Undo snackbar. The purge itself runs at startup (items kernel).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/item_summary.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/archive/presentation/archive_actions.dart';
import 'package:focusflow/features/archive/presentation/archive_format.dart';
import 'package:focusflow/features/archive/presentation/providers/archive_providers.dart';
import 'package:focusflow/features/archive/presentation/widgets/archive_bottom_bar.dart';
import 'package:focusflow/features/archive/presentation/widgets/archive_header.dart';
import 'package:focusflow/features/archive/presentation/widgets/archive_notice.dart';
import 'package:focusflow/features/archive/presentation/widgets/archive_rows.dart';
import 'package:focusflow/shared/item_actions/item_selection.dart';
import 'package:focusflow/shared/providers/core_providers.dart';

class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(trashProvider);
    final items = async.valueOrNull;
    final sel = ref.watch(itemSelectionProvider(kTrashScope));
    final selection = ref.read(itemSelectionProvider(kTrashScope).notifier);
    final actions = ArchiveActions(context, ref, ArchiveList.trash);
    final selecting = sel.active;
    final all = items ?? const <ItemSummary>[];
    final picked = selectedOf(all, sel);
    final now = ref.watch(clockProvider).now();

    final Widget content;
    if (items == null) {
      content = async.hasError
          ? FFEmptyState.compact(
              colors: TagPalette.high,
              icon: FontAwesomeIcons.triangleExclamation,
              title: "Couldn't load Recently Deleted",
              body: 'Your items are safe. Try again.',
              ctaLabel: 'Retry',
              ctaIcon: FontAwesomeIcons.arrowsRotate,
              onCta: () => ref.invalidate(trashProvider),
            )
          : const FFSkeletonList(kind: FFSkeletonKind.row, count: 5);
    } else if (items.isEmpty) {
      content = const Padding(
        padding: EdgeInsetsDirectional.only(top: AppSpacing.xxl),
        child: FFEmptyState(
          colors: TagPalette.ideas,
          icon: FontAwesomeIcons.trashCan,
          title: 'Nothing in Recently Deleted',
          body:
              'Deleted items stay here for 30 days, so you can recover '
              'them if you change your mind.',
        ),
      );
    } else {
      content = FFGroupedList(
        label: ArchiveFormat.countLabel(
          items.length,
          selected: selecting ? picked.length : null,
        ),
        dividerIndent: kArchiveDividerIndent,
        children: [
          for (final s in items)
            TrashedItemRow(
              key: ValueKey(s.ref),
              item: s,
              now: now,
              selecting: selecting,
              selected: sel.contains(s.ref),
              actions: ArchiveRowActions(
                onTap: () => actions.tap(s),
                onLongPress: () => actions.longPress(s),
                onRestore: () => actions.restore([s]),
                onDelete: () => actions.delete([s]),
              ),
            ),
        ],
      );
    }

    final compact = ArchiveBottomBar.compact(context);
    return FFScaffold(
      bottomBar: all.isEmpty
          ? null
          : ArchiveBottomBar(
              raised: true,
              start: FFSecondaryButton(
                icon: compact ? null : FontAwesomeIcons.arrowRotateLeft,
                label: selecting
                    ? ArchiveFormat.withCount('Recover', picked.length)
                    : 'Recover all',
                onPressed: selecting && picked.isEmpty
                    ? null
                    : () => actions.restore(selecting ? picked : all),
              ),
              end: FFDangerButton(
                icon: compact ? null : FontAwesomeIcons.trashCan,
                label: selecting
                    ? ArchiveFormat.withCount('Delete', picked.length)
                    : 'Empty trash',
                onPressed: selecting && picked.isEmpty
                    ? null
                    : () => actions.delete(selecting ? picked : all),
              ),
            ),
      body: Builder(
        builder: (context) => ListView(
          padding: EdgeInsetsDirectional.only(
            bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.xxl,
          ),
          children: [
            ArchiveHeader(
              title: 'Recently Deleted',
              selecting: selecting,
              canSelect: all.isNotEmpty,
              allSelected: all.isNotEmpty && picked.length == all.length,
              onSelect: selection.start,
              onCancel: selection.clear,
              onToggleAll: () =>
                  actions.toggleAll([for (final s in all) s.ref]),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.grouped,
                AppSpacing.xs,
                AppSpacing.grouped,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ArchiveNotice(
                    tone: ArchiveNoticeTone.danger,
                    icon: FontAwesomeIcons.solidClock,
                    title: 'Auto-deletes after 30 days',
                    body:
                        'Items here are removed permanently from this '
                        'device and your Drive backup.',
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  content,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
