/// ============================================================
/// EXPORT TILES — FORMAT / SAVE TO tiles and the INCLUDE checkbox (35)
/// ============================================================
///
/// What: [ExportChoiceTile] (selected = solid primary fill for FORMAT, or
/// a 2 pt primary ring for SAVE TO), [ExportCheckbox] (rounded square).
/// Why: screen 35 shows these as tile grids, not list rows; they are
/// specific to this screen so they live in the feature, built only from
/// tokens (dark mode and accent colour for free).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';

enum ExportTileStyle {
  /// Selected = solid primary (FORMAT).
  filled,

  /// Selected = primary ring (SAVE TO).
  ring,
}

class ExportChoiceTile extends StatelessWidget {
  const ExportChoiceTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.iconWidget,
    this.iconColor,
    this.subtitle,
    this.style = ExportTileStyle.filled,
    this.enabled = true,
    super.key,
  });

  final String label;
  final String? subtitle;
  final IconData? icon;

  /// Instead of [icon] (the Drive logo).
  final Widget? iconWidget;
  final Color? iconColor;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final ExportTileStyle style;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final text = context.text;
    final filled = selected && style == ExportTileStyle.filled;
    final fg = filled ? ff.onPrimary : ff.ink;
    final sub = filled ? ff.onPrimary.withValues(alpha: 0.85) : ff.inkFaint;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: [label, ?subtitle].join(', '),
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: FFPressable(
          onTap: enabled ? onTap : null,
          child: AnimatedContainer(
            duration: context.motion(AppMotion.fast),
            constraints: const BoxConstraints(minHeight: 78),
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.xxs,
              AppSpacing.lg,
              AppSpacing.xxs,
              AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: filled ? ff.primaryStrong : ff.surface,
              borderRadius: BorderRadius.circular(AppRadii.row),
              border: Border.all(
                color: selected && style == ExportTileStyle.ring
                    ? ff.primary
                    : Colors.transparent,
                width: 2,
              ),
              boxShadow: filled ? ff.heroShadow : ff.cardShadow,
            ),
            child: Column(
              mainAxisAlignment: subtitle == null
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                iconWidget ??
                    Icon(
                      icon,
                      size: 17,
                      color: filled ? ff.onPrimary : (iconColor ?? ff.ink),
                    ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: text.cardTitle.copyWith(fontSize: 13.5, color: fg),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: text.meta.copyWith(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w400,
                      color: sub,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Rounded-square checkbox of the INCLUDE list (the row handles taps).
class ExportCheckbox extends StatelessWidget {
  const ExportCheckbox({required this.checked, this.enabled = true, super.key});

  final bool checked;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: AnimatedContainer(
        duration: context.motion(AppMotion.fast),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: checked ? ff.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.tileSm),
          border: Border.all(
            color: checked ? ff.primary : ff.chipBorder,
            width: 2,
          ),
        ),
        child: checked
            ? Icon(FontAwesomeIcons.check, size: 12, color: ff.onPrimary)
            : null,
      ),
    );
  }
}
