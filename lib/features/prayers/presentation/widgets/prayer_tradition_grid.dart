/// ============================================================
/// PRAYER TRADITION GRID — the "pick a tradition" tiles
/// ============================================================
///
/// What: Islam, Christianity, Hinduism, Buddhism, Judaism and "Start from
/// scratch" as rows of two equal-height tiles (icon, name, a hint of what
/// it brings); the [selected] one is highlighted, the [current] one (the
/// tradition chosen in setup) carries a small check.
/// Why: "Set up Prayer" and the Prayer page's + sheet ask the same first
/// question the same way.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';

extension PrayerTraditionLook on PrayerTradition {
  IconData get icon => switch (this) {
    PrayerTradition.islam => FontAwesomeIcons.solidMoon,
    PrayerTradition.christianity => FontAwesomeIcons.cross,
    PrayerTradition.hinduism => FontAwesomeIcons.om,
    PrayerTradition.buddhism => FontAwesomeIcons.dharmachakra,
    PrayerTradition.judaism => FontAwesomeIcons.starOfDavid,
    PrayerTradition.custom => FontAwesomeIcons.plus,
  };

  /// What the tradition's starting set brings.
  String get hint => switch (this) {
    PrayerTradition.islam => tr('5 daily prayers · fasting'),
    PrayerTradition.christianity => tr('Morning and evening prayer'),
    PrayerTradition.hinduism => tr('Sandhya · puja'),
    PrayerTradition.buddhism => tr('Chanting · meditation'),
    PrayerTradition.judaism => tr('3 daily services'),
    PrayerTradition.custom => tr('Your own practice'),
  };

  /// Tile title ("Start from scratch" for your own practice).
  String get tileTitle =>
      this == PrayerTradition.custom ? tr('Start from scratch') : label;
}

class PrayerTraditionGrid extends StatelessWidget {
  const PrayerTraditionGrid({
    required this.onPick,
    this.selected,
    this.current,
    super.key,
  });

  final ValueChanged<PrayerTradition> onPick;
  final PrayerTradition? selected;

  /// The tradition in use (marked with a check).
  final PrayerTradition? current;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final text = context.text;
    Widget tile(PrayerTradition t) {
      final on = t == selected;
      final card = Semantics(
        button: true,
        selected: on,
        label: [
          t.tileTitle,
          t.hint,
          if (t == current) tr('Current'),
        ].join(', '),
        excludeSemantics: true,
        child: FFPressable(
          onTap: () => onPick(t),
          child: Container(
            padding: const EdgeInsetsDirectional.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: on ? ff.primarySoft : ff.surface,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(
                color: on ? ff.primary : ff.surfaceBorder,
                width: on ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  t.icon,
                  size: 18,
                  color: on ? ff.primaryStrong : ff.inkMuted,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.tileTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.rowTitle.copyWith(fontSize: 14.5),
                      ),
                      Text(
                        t.hint,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.meta.copyWith(
                          color: ff.inkMuted,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (t != current) return card;
      // In the corner, so the hint keeps its full width.
      return Stack(
        fit: StackFit.expand,
        children: [
          card,
          PositionedDirectional(
            top: AppSpacing.sm,
            end: AppSpacing.sm,
            child: Icon(
              FontAwesomeIcons.solidCircleCheck,
              size: 14,
              color: ff.primary,
            ),
          ),
        ],
      );
    }

    // Rows of two equal-height tiles (not a fixed-ratio grid): the hints
    // wrap to a second line and the tiles grow with the text scale.
    const all = PrayerTradition.values;
    return Column(
      children: [
        for (var i = 0; i < all.length; i += 2) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: tile(all[i])),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: i + 1 < all.length
                      ? tile(all[i + 1])
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
