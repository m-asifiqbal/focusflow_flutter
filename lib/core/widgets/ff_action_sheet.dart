/// ============================================================
/// FF ACTION SHEET — the long-press "item actions" sheet (screen 09)
/// ============================================================
///
/// Header (module tile · title · meta) → divider → [FFActionRow]s with
/// soft-tinted 38 pt tiles → sticky Archive (slate) / Delete (rose) pair.
/// Pure UI: callers pass an [FFActionSheetData]; tapping a row closes the
/// sheet first, then runs its callback. [FFActionSheetHeader.selection]
/// renders the multi-select header ("3 items selected").
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/ff_bottom_sheet.dart';
import 'package:focusflow/core/widgets/ff_buttons.dart';
import 'package:focusflow/core/widgets/ff_icon_tile.dart';
import 'package:focusflow/core/widgets/ff_tag.dart';
import 'package:focusflow/core/widgets/src/ff_token_gaps.dart';
import 'package:focusflow/core/theme/fa_icons.dart';

/// Header of an [FFActionSheet].
@immutable
class FFActionSheetHeader {
  const FFActionSheetHeader({
    required this.title,
    required this.icon,
    required this.colors,
    this.meta,
  }) : selectedCount = null;

  /// Multi-select header: "3 items selected".
  const FFActionSheetHeader.selection(
    int count, {
    String noun = 'item',
    this.meta,
  }) : selectedCount = count,
       title = '$count $noun${count == 1 ? '' : 's'} selected',
       icon = null,
       colors = null;

  final String title;
  final IconData? icon;
  final ModuleColors? colors;

  /// "Note · Ideas · Edited today".
  final String? meta;
  final int? selectedCount;
}

/// One row of an [FFActionSheet].
@immutable
class FFActionItem {
  const FFActionItem({
    required this.icon,
    required this.label,
    required this.colors,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;

  /// Tile tint + icon colour (use [ModuleStyle]/[TagPalette] trios).
  final ModuleColors colors;
  final VoidCallback onTap;
  final bool destructive;
}

/// Everything an [FFActionSheet] shows.
@immutable
class FFActionSheetData {
  const FFActionSheetData({
    required this.actions,
    this.header,
    this.onArchive,
    this.onDelete,
    this.archiveLabel = 'Archive',
    this.deleteLabel = 'Delete',
  });

  final FFActionSheetHeader? header;
  final List<FFActionItem> actions;

  /// Bottom-left button (hidden when null).
  final VoidCallback? onArchive;

  /// Bottom-right button (hidden when null).
  final VoidCallback? onDelete;
  final String archiveLabel;
  final String deleteLabel;
}

/// Opens the actions sheet for [data]. Completes when the sheet closes.
Future<void> showFFActionSheet(BuildContext context, FFActionSheetData data) {
  return showFFBottomSheet<void>(
    context,
    wrap: false,
    builder: (sheetContext) => FFActionSheet(
      data: data,
      onDone: () => Navigator.of(sheetContext).pop(),
    ),
  );
}

class FFActionSheet extends StatelessWidget {
  const FFActionSheet({required this.data, this.onDone, super.key});

  final FFActionSheetData data;

  /// Called before any action's callback (closes the sheet).
  final VoidCallback? onDone;

  void _run(VoidCallback action) {
    onDone?.call();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final hasFooter = data.onArchive != null || data.onDelete != null;
    return FFBottomSheet(
      padding: const EdgeInsetsDirectional.fromSTEB(
        FFBottomSheet.inset,
        AppSpacing.xl,
        FFBottomSheet.inset,
        AppSpacing.sm,
      ),
      footer: hasFooter
          ? Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Row(
                children: [
                  if (data.onArchive != null)
                    Expanded(
                      child: FFSecondaryButton(
                        label: data.archiveLabel,
                        icon: FontAwesomeIcons.boxArchive,
                        variant: FFSecondaryVariant.soft,
                        foreground: ff.neutralInk,
                        background: ff.surfaceMuted,
                        onPressed: () => _run(data.onArchive!),
                      ),
                    ),
                  if (data.onArchive != null && data.onDelete != null)
                    const SizedBox(width: AppSpacing.md),
                  if (data.onDelete != null)
                    Expanded(
                      child: FFSoftDangerButton(
                        label: data.deleteLabel,
                        icon: FontAwesomeIcons.trashCan,
                        onPressed: () => _run(data.onDelete!),
                      ),
                    ),
                ],
              ),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (data.header != null) ...[
            _Header(header: data.header!),
            const SizedBox(height: AppSpacing.lg),
            const FFDividerInset(indent: 0),
            const SizedBox(height: AppSpacing.sm),
          ],
          for (final action in data.actions)
            FFActionRow(
              icon: action.icon,
              iconColors: action.colors,
              label: action.label,
              destructive: action.destructive,
              onTap: () => _run(action.onTap),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.header});

  final FFActionSheetHeader header;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final count = header.selectedCount;
    final Widget tile = count != null
        ? Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ff.primarySoft,
              borderRadius: BorderRadius.circular(AppRadii.tileLg),
            ),
            child: Text(
              '$count',
              maxLines: 1,
              style: context.text.stat.copyWith(
                fontSize: 18,
                color: ff.primaryStrong,
              ),
            ),
          )
        : FFIconTile(icon: header.icon!, colors: header.colors!, size: 44);
    return Row(
      children: [
        tile,
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                header.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                // 17 pt, tight tracking — measured against design/09 (the
                // mockup title fits one line at 390 pt).
                style: context.text.cardTitle.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              if (header.meta != null) ...[
                const SizedBox(height: 2),
                Text(
                  header.meta!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.meta.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: ff.inkFaint,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A tappable action row: tinted 38 pt tile + label (min height 62).
class FFActionRow extends StatelessWidget {
  const FFActionRow({
    required this.icon,
    required this.iconColors,
    required this.label,
    required this.onTap,
    this.destructive = false,
    super.key,
  });

  final IconData icon;
  final ModuleColors iconColors;
  final String label;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.button),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 62),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                FFIconTile(
                  icon: icon,
                  colors: iconColors,
                  style: FFIconTileStyle.tint,
                  size: AppSizes.iconTile,
                  iconSize: 15,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.rowTitle.copyWith(
                      fontSize: 16.5,
                      color: destructive ? ff.dangerStrong : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
