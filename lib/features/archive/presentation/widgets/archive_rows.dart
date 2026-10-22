/// ============================================================
/// ARCHIVE ROWS — one row of Archive (23) and of Recently Deleted (24)
/// ============================================================
///
/// What: the shared ItemSummaryRow (module tile · title · meta) with
///  * Archive: a soft "restore" button (box-open), habits' saved streak
///    as meta, swipe → Restore / Delete;
///  * Trash: the purge countdown in rose ("29 days"), swipe → Recover /
///    Delete forever.
/// In selection mode a check circle leads the row, selected rows are
/// tinted and swiping is off. Actions are callbacks (the screens route
/// them through item_lifecycle_actions.dart).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/item_summary.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/archive/presentation/archive_format.dart';
import 'package:focusflow/features/archive/presentation/providers/archive_providers.dart';
import 'package:focusflow/features/library/presentation/widgets/item_summary_row.dart';

/// Divider indent of the Archive / Trash cards (measured on the mockups:
/// the hairline starts just after the module tile).
const double kArchiveDividerIndent = AppSpacing.dividerInset;

/// Row title / meta sizes measured on design/23 and design/24.
const double _kTitleSize = 15;
const double _kMetaSize = 12.5;

/// Row callbacks shared by both screens.
@immutable
class ArchiveRowActions {
  const ArchiveRowActions({
    required this.onTap,
    required this.onLongPress,
    required this.onRestore,
    required this.onDelete,
  });

  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onRestore;
  final VoidCallback onDelete;
}

/// A row of the Archive screen.
class ArchivedItemRow extends ConsumerWidget {
  const ArchivedItemRow({
    required this.item,
    required this.now,
    required this.actions,
    this.selecting = false,
    this.selected = false,
    super.key,
  });

  final ItemSummary item;
  final DateTime now;
  final ArchiveRowActions actions;
  final bool selecting;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ff = context.ff;
    final archivedAt = item.archivedAt;
    String? streak;
    if (item.type == ItemType.habit && archivedAt != null) {
      final args = (id: item.id, archivedAt: archivedAt);
      streak = ArchiveFormat.streakSaved(
        ref.watch(archivedHabitStreakProvider(args)).valueOrNull,
      );
    }
    return FFSwipeActions(
      enabled: !selecting,
      radius: 0,
      gap: 0,
      endActions: [
        FFSwipeAction(
          icon: FontAwesomeIcons.boxOpen,
          label: tr('Restore'),
          color: ff.primary,
          onTap: actions.onRestore,
        ),
        FFSwipeAction.delete(onTap: actions.onDelete),
      ],
      child: ItemSummaryRow(
        item: item,
        meta: ArchiveFormat.archivedMeta(item, now, streak: streak),
        titleSize: _kTitleSize,
        metaSize: _kMetaSize,
        strikeCompleted: false,
        leading: selecting ? SelectionMark(selected: selected) : null,
        highlighted: selecting && selected,
        selected: selecting ? selected : null,
        onTap: actions.onTap,
        onLongPress: actions.onLongPress,
        chevron: false,
        trailing: selecting
            ? null
            : RestoreButton(
                semanticLabel: tr('Restore {displayTitle}', {
                  'displayTitle': item.displayTitle,
                }),
                onPressed: actions.onRestore,
              ),
      ),
    );
  }
}

/// A row of Recently Deleted.
class TrashedItemRow extends StatelessWidget {
  const TrashedItemRow({
    required this.item,
    required this.now,
    required this.actions,
    this.selecting = false,
    this.selected = false,
    super.key,
  });

  final ItemSummary item;
  final DateTime now;
  final ArchiveRowActions actions;
  final bool selecting;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final days = ArchiveFormat.daysLeftOf(item, now);
    return FFSwipeActions(
      enabled: !selecting,
      radius: 0,
      gap: 0,
      endActions: [
        FFSwipeAction(
          icon: FontAwesomeIcons.arrowRotateLeft,
          label: tr('Recover'),
          color: ff.primary,
          onTap: actions.onRestore,
        ),
        FFSwipeAction.delete(onTap: actions.onDelete, label: tr('Delete')),
      ],
      child: ItemSummaryRow(
        item: item,
        meta: ArchiveFormat.deletedMeta(item, now),
        titleSize: _kTitleSize,
        metaSize: _kMetaSize,
        semanticsSuffix: ArchiveFormat.daysLeftSemantics(days),
        leading: selecting ? SelectionMark(selected: selected) : null,
        highlighted: selecting && selected,
        selected: selecting ? selected : null,
        onTap: actions.onTap,
        onLongPress: actions.onLongPress,
        chevron: false,
        trailing: ExcludeSemantics(
          child: Text(
            ArchiveFormat.daysLeft(days),
            style: context.text.body.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: ff.danger,
            ),
          ),
        ),
      ),
    );
  }
}

/// The selection circle leading a row (visual only — the whole row is the
/// tap target and carries the selected state for screen readers).
class SelectionMark extends StatelessWidget {
  const SelectionMark({required this.selected, super.key});

  final bool selected;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: FFCheckCircle(
      checked: selected,
      onChanged: null,
      color: context.ff.primary,
      size: 24,
      tapTarget: 24,
    ),
  );
}

/// Archive's soft square restore button (36 pt, 44 pt tap target).
class RestoreButton extends StatelessWidget {
  const RestoreButton({
    required this.semanticLabel,
    required this.onPressed,
    super.key,
  });

  final String semanticLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return Semantics(
      container: true,
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: FFPressable(
        onTap: onPressed,
        child: SizedBox.square(
          dimension: AppSizes.minTap,
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: ff.isDark
                    ? ff.primarySoft
                    : ff.primarySoft.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(AppRadii.tile),
              ),
              alignment: Alignment.center,
              child: Icon(
                FontAwesomeIcons.boxOpen,
                size: 15,
                color: ff.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
