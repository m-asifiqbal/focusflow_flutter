/// ============================================================
/// LIBRARY TAG CLOUD — the "TAGS" wrap on the Library hub (screen 05)
/// ============================================================
///
/// What: white rounded pills ("#work") with a mint border and emerald
/// extra-bold label, wrapped. Tap → the tag's mixed list; long-press →
/// rename / colour / delete. Why: the visual pill is 33 pt tall like the
/// mockup, but each sits in a 44 pt-tall hit box (accessibility rule).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/items/tag.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/widgets.dart';

class LibraryTagCloud extends StatelessWidget {
  const LibraryTagCloud({
    required this.tags,
    required this.onTap,
    required this.onLongPress,
    super.key,
  });

  final List<Tag> tags;
  final ValueChanged<Tag> onTap;
  final ValueChanged<Tag> onLongPress;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8.5,
    // Pills are 32 pt inside 44 pt tap targets; overlap the targets by 3 pt
    // so the visible gap between rows is the mockup's 9 pt.
    runSpacing: -3,
    children: [
      for (final t in tags)
        LibraryTagPill(
          tag: t,
          onTap: () => onTap(t),
          onLongPress: () => onLongPress(t),
        ),
    ],
  );
}

/// One "#tag" pill.
class LibraryTagPill extends StatelessWidget {
  const LibraryTagPill({
    required this.tag,
    required this.onTap,
    this.onLongPress,
    super.key,
  });

  final Tag tag;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// Corner radius of the 32 pt pill (design/05).
  static const double radius = 12;

  /// Visible pill height (design/05); the tap target is 44.
  static const double height = 32;

  /// Widths of the loading placeholders (short / medium / long tag).
  static const List<double> skeletonWidths = [70, 84, 96];

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return Semantics(
      button: true,
      label:
          '${tag.label}, ${tag.usageCount} '
          '${tag.usageCount == 1 ? 'item' : 'items'}',
      onLongPressHint: tr('Rename, recolour or delete'),
      excludeSemantics: true,
      child: FFPressable(
        onTap: onTap,
        onLongPress: onLongPress,
        scale: 0.96,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSizes.minTap,
            minWidth: AppSizes.minTap,
          ),
          child: Center(
            widthFactor: 1,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 260),
              // 13 × 1.25 line + 2 × 6.8 padding + 2 × 1 border ≈ 32 pt.
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: 12,
                vertical: 6.8,
              ),
              decoration: BoxDecoration(
                color: ff.surface,
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: ff.chipBorder),
              ),
              child: Text(
                tag.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.body.copyWith(
                  fontSize: 13,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  color: ff.primaryStrong,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
