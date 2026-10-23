/// ============================================================
/// QUICK ADD TILES — the module grid of screen 04
/// ============================================================
///
/// What: Note · Task · Reminder · Habit · Medicine · Password · Scan, each a
/// white 22-radius card with a solid 46 pt module icon tile, a 15 pt title
/// and an uppercase caption (Ideas, To-dos, Alerts, Routine, Doses, Secure,
/// OCR). Reflows to two columns when the sheet is narrow or text is large;
/// the tiles of an incomplete last row share its width.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';

typedef _TileSpec = ({
  AppModule module,
  String title,
  String caption,
  String semantics,
});

/// A function, not a const list: the texts follow the active language.
List<_TileSpec> _tiles() => [
  (
    module: AppModule.notes,
    title: tr('Note'),
    caption: tr('Ideas'),
    semantics: tr('New note'),
  ),
  (
    module: AppModule.tasks,
    title: tr('Task'),
    caption: tr('To-dos'),
    semantics: tr('New task'),
  ),
  (
    module: AppModule.reminders,
    title: tr('Reminder'),
    caption: tr('Alerts'),
    semantics: tr('New reminder'),
  ),
  (
    module: AppModule.habits,
    title: tr('Habit'),
    caption: tr('Routine'),
    semantics: tr('New habit'),
  ),
  (
    module: AppModule.medicines,
    title: tr('Medicine'),
    caption: tr('Doses'),
    semantics: tr('New medicine'),
  ),
  (
    module: AppModule.vault,
    title: tr('Password'),
    caption: tr('Secure'),
    semantics: tr('New password'),
  ),
  (
    module: AppModule.scan,
    title: tr('Scan'),
    caption: tr('OCR'),
    semantics: tr('Scan text into a note'),
  ),
];

class QuickAddTileGrid extends StatelessWidget {
  const QuickAddTileGrid({required this.onTap, super.key});

  final ValueChanged<AppModule> onTap;

  /// Below this width per text-scale unit, three columns would crowd
  /// "Password"/"Reminder"; use two.
  static const double _threeColumnMinWidth = 300;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final columns = constraints.maxWidth / scale >= _threeColumnMinWidth
            ? 3
            : 2;
        const gap = AppSpacing.rowLeadingGap;
        final tiles = _tiles();
        return Column(
          children: [
            for (var row = 0; row * columns < tiles.length; row++) ...[
              if (row > 0) const SizedBox(height: gap),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (
                      var c = 0;
                      c < columns && row * columns + c < tiles.length;
                      c++
                    ) ...[
                      if (c > 0) const SizedBox(width: gap),
                      Expanded(
                        child: _QuickAddTile(
                          spec: tiles[row * columns + c],
                          onTap: onTap,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _QuickAddTile extends StatelessWidget {
  const _QuickAddTile({required this.spec, required this.onTap});

  final _TileSpec spec;
  final ValueChanged<AppModule> onTap;

  // Measured against design/04 (title 15 pt; caption 11 pt, tighter
  // tracking than the shared section label).
  static const double _titleSize = 15;
  static const double _captionSize = 11;
  static const double _captionTracking = 0.8;

  @override
  Widget build(BuildContext context) {
    final style = ModuleStyle.of(spec.module);
    final ff = context.ff;
    return FFCard(
      radius: AppRadii.card,
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.rowLeadingGap,
        AppSpacing.rowLeadingGap,
        AppSpacing.sm,
        AppSpacing.lg,
      ),
      onTap: () => onTap(spec.module),
      semanticLabel: spec.semantics,
      // The card's label ("New note") says it all; skip title + caption.
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            FFIconTile(
              icon: style.icon,
              colors: style.colors,
              size: AppSizes.iconTileLg,
            ),
            const SizedBox(height: AppSpacing.md),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                spec.title,
                maxLines: 1,
                style: context.text.cardTitle.copyWith(fontSize: _titleSize),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              spec.caption.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.sectionLabel.copyWith(
                fontSize: _captionSize,
                letterSpacing: _captionTracking,
                color: ff.inkFaint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
