/// ============================================================
/// FF CHIPS — pill filter chips + the horizontally scrolling chip bar
/// ============================================================
///
/// Active: filled primary (or a module colour), white text, soft glow.
/// Inactive: surface + 1.5 px chipBorder, primary-strong text.
/// Optional leading icon ("Today" sun) and count ("Notes 15").
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/ff_pressable.dart';
import 'package:focusflow/core/widgets/src/ff_token_gaps.dart';

class FFChip extends StatelessWidget {
  const FFChip({
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
    this.count,
    this.activeColor,
    this.height = AppSizes.chip,
    this.vault = false,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final int? count;

  /// Fill when [selected] (module colour); defaults to primary.
  final Color? activeColor;
  final double height;

  /// Dark glass vault variant.
  final bool vault;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final Color bg;
    final Color fg;
    final Color borderColor;
    if (selected) {
      bg = activeColor ?? (vault ? ff.vaultChipActive : ff.primary);
      fg = activeColor != null || vault ? ff.onGradient : ff.onPrimary;
      borderColor = bg;
    } else if (vault) {
      bg = ff.vaultSurface;
      fg = ff.vaultInk.withValues(alpha: 0.85);
      borderColor = ff.vaultBorder;
    } else {
      bg = ff.surface;
      fg = ff.primaryStrong;
      borderColor = ff.chipBorder;
    }
    // 13 pt — measured against the chip labels in design/07.
    final style = context.text.buttonSmall.copyWith(fontSize: 13, color: fg);
    return Semantics(
      button: true,
      selected: selected,
      label: count == null ? label : '$label, $count',
      excludeSemantics: true,
      child: FFPressable(
        onTap: onTap,
        scale: 0.96,
        child: AnimatedContainer(
          duration: context.motion(AppMotion.fast),
          curve: AppMotion.curve,
          constraints: BoxConstraints(
            minHeight: height,
            minWidth: 52,
            maxWidth: 280,
          ),
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: selected
                ? [
                    BoxShadow(
                      offset: const Offset(0, 8),
                      blurRadius: 16,
                      spreadRadius: -6,
                      color: bg.withValues(alpha: 0.45),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 12.5, color: fg),
                const SizedBox(width: 7),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 5),
                Text(
                  '$count',
                  maxLines: 1,
                  style: style.copyWith(color: fg.withValues(alpha: 0.8)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One entry of an [FFChipBar].
@immutable
class FFChipItem<T> {
  const FFChipItem({
    required this.value,
    required this.label,
    this.icon,
    this.count,
    this.activeColor,
  });

  final T value;
  final String label;
  final IconData? icon;
  final int? count;
  final Color? activeColor;
}

/// Horizontally scrollable single-select chip row (8 pt gaps). Runs to the
/// screen edges like the mockups; [padding] insets the first/last chip.
class FFChipBar<T> extends StatelessWidget {
  const FFChipBar({
    required this.items,
    required this.selected,
    required this.onSelected,
    this.padding = const EdgeInsetsDirectional.symmetric(
      horizontal: AppSpacing.screen,
    ),
    this.vault = false,
    super.key,
  });

  final List<FFChipItem<T>> items;
  final T? selected;
  final ValueChanged<T> onSelected;
  final EdgeInsetsGeometry padding;
  final bool vault;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      padding: padding.add(
        const EdgeInsetsDirectional.only(top: 2, bottom: AppSpacing.sm),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            FFChip(
              label: items[i].label,
              icon: items[i].icon,
              count: items[i].count,
              activeColor: items[i].activeColor,
              selected: items[i].value == selected,
              vault: vault,
              onTap: () => onSelected(items[i].value),
            ),
          ],
        ],
      ),
    );
  }
}
