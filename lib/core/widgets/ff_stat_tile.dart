/// ============================================================
/// FF STAT TILE — tinted KPI tile (tasks list) / glass tile (home hero)
/// ============================================================
///
/// Tinted: module soft fill, value in the module solid colour, muted label
/// (screen 10: "7 Today", "2 Overdue"…). [glass]: white @15% on the hero
/// gradient with white text (screen 03: "4/7 Tasks").
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/ff_pressable.dart';
import 'package:focusflow/core/widgets/src/ff_token_gaps.dart';

class FFStatTile extends StatelessWidget {
  const FFStatTile({
    required this.value,
    required this.label,
    this.colors,
    this.glass = false,
    this.onTap,
    this.selected = false,
    super.key,
  });

  /// Glass variant for gradient heroes.
  const FFStatTile.glass({
    required this.value,
    required this.label,
    this.onTap,
    super.key,
  }) : colors = null,
       glass = true,
       selected = false;

  final String value;
  final String label;

  /// Module/status trio; defaults to the primary family.
  final ModuleColors? colors;
  final bool glass;
  final VoidCallback? onTap;

  /// Adds a 1.5 pt ring in the tile colour (active filter).
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final Color bg;
    final Color valueColor;
    final Color labelColor;
    Color? ring;
    if (glass) {
      bg = ff.onGradient.withValues(alpha: 0.15);
      valueColor = ff.onGradient;
      labelColor = ff.onGradient.withValues(alpha: 0.85);
    } else {
      final c = colors;
      final soft = c?.softFor(ff.brightness) ?? ff.primarySoft;
      bg = ff.isDark ? soft : soft.withValues(alpha: soft.a * 0.55);
      valueColor = c?.solid ?? ff.primary;
      labelColor = ff.inkMuted;
      if (selected) ring = valueColor;
    }
    final tile = Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 6, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.statTile),
        border: ring == null ? null : Border.all(color: ring, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.stat.copyWith(
              // Glass tiles (Home hero, mockup 03) are smaller than the
              // tinted summary tiles (screen 10).
              fontSize: glass ? 18.5 : 22,
              color: valueColor,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          // Four tiles in a row (screen 10) leave ~60 pt per label: shrink
          // a long label ("Upcoming") to fit instead of truncating it.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              label,
              maxLines: 1,
              style: context.text.meta.copyWith(
                fontSize: glass ? 12 : 13,
                color: labelColor,
              ),
            ),
          ),
        ],
      ),
    );
    return Semantics(
      label: '$value $label',
      button: onTap != null,
      selected: selected,
      excludeSemantics: true,
      child: onTap == null ? tile : FFPressable(onTap: onTap, child: tile),
    );
  }
}
