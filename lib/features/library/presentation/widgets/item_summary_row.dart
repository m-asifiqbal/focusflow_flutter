/// ============================================================
/// ITEM SUMMARY ROW — one item of a mixed, cross-module list
/// ============================================================
///
/// What: soft module tile (40 pt) · Lexend title (+ lock when locked) ·
/// muted meta ("Task · Due Today 5:00 PM") · optional trailing widget
/// (chevron by default). Used inside an FFGroupedList by Pinned,
/// Favourites, the by-tag list, Archive (23) and Recently Deleted (24).
/// Why: one row widget for every module, so mixed lists look the same
/// everywhere; it shows only [ItemSummary] data, which never has secrets.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/items/item_summary.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';

class ItemSummaryRow extends StatelessWidget {
  const ItemSummaryRow({
    required this.item,
    required this.meta,
    this.onTap,
    this.onLongPress,
    this.trailing,
    this.chevron = true,
    this.leading,
    this.highlighted = false,
    this.selected,
    this.semanticsSuffix,
    this.titleSize = 16,
    this.metaSize = 13.5,
    this.strikeCompleted = true,
    super.key,
  });

  final ItemSummary item;

  /// Second line (see LibraryFormat.rowMeta).
  final String meta;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Replaces the chevron (Archive's restore button, Trash's days left).
  final Widget? trailing;
  final bool chevron;

  /// Before the module tile (Archive / Trash selection circle).
  final Widget? leading;

  /// Tints the row (a selected row in Archive / Trash).
  final bool highlighted;

  /// Selection state for screen readers (null = not selectable).
  final bool? selected;

  /// Read after the meta (e.g. Trash's "29 days until deleted permanently").
  final String? semanticsSuffix;

  /// Title / meta font sizes (Archive & Trash rows are a touch smaller —
  /// measured on design/23 and design/24).
  final double titleSize;
  final double metaSize;

  /// Strikes through a completed task's title (off in Archive, whose meta
  /// already says "completed").
  final bool strikeCompleted;

  /// Leading tile size; dividers of the list are inset to its end.
  static const double tile = 40;

  /// FFGroupedList divider indent matching [tile] (16 + 40 + 14).
  static const double dividerIndent = AppSpacing.lg + tile + 14;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final style = item.type.style;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final row = Semantics(
      button: onTap != null,
      selected: selected,
      label:
          '${item.displayTitle}${item.isLocked ? ', locked' : ''}. $meta'
          '${semanticsSuffix == null ? '' : ', $semanticsSuffix'}',
      onLongPressHint: onLongPress == null ? null : 'More actions',
      // The texts are in [label]; a [trailing] button keeps its own node.
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 68),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: AppSpacing.rowLeadingGap),
                ],
                FFIconTile.soft(
                  icon: style.icon,
                  colors: style.colors,
                  size: tile,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                item.displayTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.text.cardTitle.copyWith(
                                  fontSize: titleSize,
                                  decoration:
                                      strikeCompleted && item.isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                  decorationColor: ff.inkFaint,
                                ),
                              ),
                            ),
                            if (item.isLocked) ...[
                              const SizedBox(width: 6),
                              Icon(
                                FontAwesomeIcons.lock,
                                size: 11,
                                color: ff.inkFaint,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.meta.copyWith(
                            fontSize: metaSize,
                            fontWeight: FontWeight.w400,
                            color: ff.inkFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  trailing!,
                ] else if (chevron && onTap != null) ...[
                  const SizedBox(width: 10),
                  Icon(
                    rtl
                        ? FontAwesomeIcons.chevronLeft
                        : FontAwesomeIcons.chevronRight,
                    size: 13,
                    color: ff.inkFaint,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    if (!highlighted) return row;
    return Ink(
      color: ff.primarySoft.withValues(alpha: ff.isDark ? 0.8 : 0.45),
      child: row,
    );
  }
}
