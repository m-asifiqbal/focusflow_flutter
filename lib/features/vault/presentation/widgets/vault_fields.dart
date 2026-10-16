/// ============================================================
/// VAULT FIELDS — glass cards of labelled rows (screens 19 / 20)
/// ============================================================
///
/// * [VaultCard]        — glass card (radius 24) stacking rows with
///   full-width hairlines.
/// * [VaultFieldLabel]  — "USERNAME" (12 w700, tracked, muted emerald).
/// * [VaultFieldRow]    — label over a value + trailing round buttons.
/// * [VaultRoundButton] — 40 pt emerald-tint disc (44 pt tap target) for
///   copy / reveal / open / scan.
/// * [VaultSectionLabel] — "CREDENTIALS" above an editor card.
/// Sizes measured from the 1170-px mockups (÷ 3).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/vault/presentation/vault_style.dart';
import 'package:focusflow/features/vault/presentation/vault_tokens.dart';

/// Card corner radius of the detail / editor cards.
const double vaultCardRadius = AppRadii.dialog - 6;

/// Inner horizontal padding of a field row.
const double vaultFieldInset = AppSpacing.lg;

class VaultCard extends StatelessWidget {
  const VaultCard({required this.children, this.dashed = false, super.key});

  final List<Widget> children;

  /// Dashed emerald outline, no fill ("+ Add field").
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    const radius = BorderRadius.all(Radius.circular(vaultCardRadius));
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) Divider(height: 1, thickness: 1, color: ff.vaultBorder),
          children[i],
        ],
      ],
    );
    if (dashed) {
      return CustomPaint(
        painter: _DashedBorder(ff.vaultAccent.withValues(alpha: 0.45)),
        child: ClipRRect(borderRadius: radius, child: column),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ff.vaultSurface,
        borderRadius: radius,
        border: Border.all(color: ff.vaultBorder),
      ),
      child: ClipRRect(borderRadius: radius, child: column),
    );
  }
}

/// Text styles shared by the vault field rows.
extension VaultFieldText on BuildContext {
  /// "USERNAME" — Nunito 12 w700, tracked.
  TextStyle get vaultLabelStyle => text.sectionLabel.copyWith(
    fontSize: VaultType.meta,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.3,
    color: ff.vaultFieldLabel,
  );

  /// A field's value — Nunito 16 w500 white.
  TextStyle get vaultValueStyle => text.rowTitle.copyWith(
    fontSize: VaultType.value,
    fontWeight: FontWeight.w500,
    height: 1.35,
    color: ff.vaultInk,
  );

  /// Passwords / codes — mono 16.5 bold.
  TextStyle get vaultMonoStyle => text.mono.copyWith(
    fontSize: VaultType.valueLg,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: 0,
    color: ff.vaultInk,
  );
}

class VaultFieldLabel extends StatelessWidget {
  const VaultFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: context.vaultLabelStyle);
}

/// "CREDENTIALS" / "ORGANISE" above an editor card.
class VaultSectionLabel extends StatelessWidget {
  const VaultSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    // Inside the editor's 20-pt gutter: the label starts at 24 pt.
    padding: const EdgeInsetsDirectional.fromSTEB(
      AppSpacing.xs,
      AppSpacing.section,
      AppSpacing.xs,
      AppSpacing.md,
    ),
    child: Semantics(
      header: true,
      child: Text(text.toUpperCase(), style: context.vaultLabelStyle),
    ),
  );
}

/// Label above [value]; [actions] (round buttons) at the end.
class VaultFieldRow extends StatelessWidget {
  const VaultFieldRow({
    required this.label,
    required this.value,
    this.actions = const [],
    this.onLongPress,
    this.minHeight = VaultSizes.fieldRow,
    super.key,
  });

  final String label;
  final Widget value;
  final List<Widget> actions;
  final VoidCallback? onLongPress;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          vaultFieldInset,
          AppSpacing.md + 1,
          vaultFieldInset - 2,
          AppSpacing.md + 1,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  VaultFieldLabel(label),
                  const SizedBox(height: AppSpacing.xs + 1),
                  value,
                ],
              ),
            ),
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.xs),
              actions[i],
            ],
          ],
        ),
      ),
    );
    if (onLongPress == null) return row;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: onLongPress,
      child: row,
    );
  }
}

class VaultRoundButton extends StatelessWidget {
  const VaultRoundButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    this.size = VaultSizes.roundButton,
    this.iconSize = VaultSizes.roundGlyph,
    super.key,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return Semantics(
      container: true,
      button: true,
      label: semanticLabel,
      onTap: onTap,
      excludeSemantics: true,
      child: FFPressable(
        onTap: onTap,
        scale: 0.92,
        child: SizedBox(
          width: AppSizes.minTap,
          height: AppSizes.minTap,
          child: Center(
            child: Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ff.vaultAccentSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: iconSize, color: ff.vaultAccentBright),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  _DashedBorder(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = VaultSizes.dashStroke;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(vaultCardRadius),
        ).deflate(0.8),
      );
    const dash = VaultSizes.dash, gap = VaultSizes.dashGap;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color;
}
